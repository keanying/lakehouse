-- dws.dws_ord_tenant_sku_channel_trade_di  商户×SKU×渠道 交易日汇总
-- 粒度：travel_date × seller_tenant_id × sku_id × channel_id × app_ref_code × operator_type
-- 来源：dwd_ord_order_di, dwd_ord_order_status_log_di, dwd_ord_order_group_di
-- 生成方式：Spark SQL / Hive；字段 27 个：直接翻译 5 · 规则翻译 10 · 待确认 12
-- 多来源：每个来源先按粒度键预聚合，UNION ALL 后再汇总
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

WITH
src_order_group AS (                                                              -- 来源「聚合单明细」按粒度键预聚合
  SELECT
    seller_tenant_id AS seller_tenant_id,                                         -- 卖家租户ID
    CAST(NULL AS BIGINT) AS sku_id,
    channel_id AS channel_id,                                                     -- 入口渠道ID
    app_ref_code AS app_ref_code,                                                 -- 对接端引用
    operator_type AS operator_type,                                               -- 操作人类型
    COUNT(DISTINCT order_group_no) AS order_group_qty,                            -- 下单聚合单数
    NULL AS order_qty,
    NULL AS order_ticket_qty,
    NULL AS order_amt,
    NULL AS pay_order_qty,
    NULL AS pay_ticket_qty,
    NULL AS pay_amt,
    NULL AS pay_buyer_qty,
    CAST(NULL AS BINARY) AS pay_buyer_bitmap,
    NULL AS cancel_order_qty,
    NULL AS cancel_amt,
    NULL AS staff_order_qty,
    NULL AS combo_order_qty,
    COUNT(DISTINCT CASE WHEN pay_status='PAID' THEN order_group_no END) AS pay_order_group_qty,  -- 支付聚合单数
    NULL AS cost_amt,
    NULL AS pay_minute_qty,
    NULL AS timeout_cancel_order_qty,
    NULL AS advance_book_day_qty
  FROM dwd.dwd_ord_order_group_di s                                               -- 来源表「聚合单明细」
  WHERE s.travel_date = '${bizdate}'                                              -- 只取当日分区
  GROUP BY seller_tenant_id, channel_id, app_ref_code, operator_type              -- 按粒度键汇总
),
src_order AS (                                                                    -- 来源「子单明细」按粒度键预聚合
  SELECT
    seller_tenant_id AS seller_tenant_id,                                         -- 卖家租户ID
    sku_id AS sku_id,                                                             -- SKU ID
    channel_id AS channel_id,                                                     -- 入口渠道ID
    app_ref_code AS app_ref_code,                                                 -- 对接端引用
    operator_type AS operator_type,                                               -- 操作人类型
    NULL AS order_group_qty,
    COUNT(DISTINCT CASE WHEN 1 = 1 THEN order_no END) AS order_qty,               -- 下单子单数｜待确认：combo 子项除外
    SUM(buy_ticket_qty) AS order_ticket_qty,                                      -- 下单票数
    SUM(unit_price_amt*buy_ticket_qty) AS order_amt,                              -- 下单金额
    NULL AS pay_order_qty,
    SUM(CASE WHEN pay_time IS NOT NULL THEN buy_ticket_qty END) AS pay_ticket_qty,  -- 支付票数
    SUM(CASE WHEN pay_time IS NOT NULL THEN unit_price_amt*buy_ticket_qty END) AS pay_amt,  -- 支付金额（GMV）
    COUNT(DISTINCT CASE WHEN 1 = 1 THEN buyer_customer_id END) AS pay_buyer_qty,  -- 支付买家数｜待确认：buyer_customer_id>0 and kind='REAL'
    BITMAP_UNION(TO_BITMAP(CASE WHEN 1 = 1 THEN buyer_customer_id END)) AS pay_buyer_bitmap,  -- 支付买家数去重位图｜待确认：buyer_customer_id>0 and kind='REAL'
    NULL AS cancel_order_qty,
    SUM(CASE WHEN 1 = 1 THEN order_amt END) AS cancel_amt,                        -- 取消金额｜待确认：of cancelled orders
    COUNT(CASE WHEN operator_type='TENANT_STAFF' THEN order_no END) AS staff_order_qty,  -- 员工代下单数
    COUNT(CASE WHEN 1 = 1 THEN order_no END) AS combo_order_qty,                  -- 套票主单数｜待确认：combo_flag=1
    NULL AS pay_order_group_qty,
    SUM(CASE WHEN pay_time IS NOT NULL THEN cost_price_amt * buy_ticket_qty END) AS cost_amt,  -- 成本金额
    NULL AS pay_minute_qty,
    NULL AS timeout_cancel_order_qty,
    NULL AS advance_book_day_qty                                                  -- 待确认：sum(datediff(play_date, pay_date) * buy_ticket_qty)
  FROM dwd.dwd_ord_order_di s                                                     -- 来源表「子单明细」
  WHERE s.travel_date = '${bizdate}'                                              -- 只取当日分区
  GROUP BY seller_tenant_id, sku_id, channel_id, app_ref_code, operator_type      -- 按粒度键汇总
),
src_order_status_log AS (                                                         -- 来源「子单状态流转明细」按粒度键预聚合
  SELECT
    seller_tenant_id AS seller_tenant_id,                                         -- 卖家租户ID
    sku_id AS sku_id,                                                             -- SKU ID
    CAST(NULL AS BIGINT) AS channel_id,
    CAST(NULL AS STRING) AS app_ref_code,
    CAST(NULL AS STRING) AS operator_type,
    NULL AS order_group_qty,
    NULL AS order_qty,
    NULL AS order_ticket_qty,
    NULL AS order_amt,
    COUNT(DISTINCT CASE WHEN after_status='PAID' THEN order_no END) AS pay_order_qty,  -- 支付子单数
    NULL AS pay_ticket_qty,
    NULL AS pay_amt,
    NULL AS pay_buyer_qty,
    CAST(NULL AS BINARY) AS pay_buyer_bitmap,
    COUNT(DISTINCT CASE WHEN after_status='CANCELLED' THEN order_no END) AS cancel_order_qty,  -- 取消子单数
    NULL AS cancel_amt,
    NULL AS staff_order_qty,
    NULL AS combo_order_qty,
    NULL AS pay_order_group_qty,
    NULL AS cost_amt,
    NULL AS pay_minute_qty,                                                       -- 待确认：sum(minutes(pay_time - create_time))
    COUNT(CASE WHEN 1 = 1 THEN order_no END) AS timeout_cancel_order_qty,         -- 超时取消子单数｜待确认：after_status='CANCELLED' and reason='PAY_TIMEOUT'
    NULL AS advance_book_day_qty
  FROM dwd.dwd_ord_order_status_log_di s                                          -- 来源表「子单状态流转明细」
  WHERE s.travel_date = '${bizdate}'                                              -- 只取当日分区
  GROUP BY seller_tenant_id, sku_id                                               -- 按粒度键汇总
),
all_src AS (                                                                      -- 各来源字段已对齐，UNION ALL 合并（比多表 FULL JOIN 少 shuffle）
  SELECT * FROM src_order_group
  UNION ALL
  SELECT * FROM src_order
  UNION ALL
  SELECT * FROM src_order_status_log
)
INSERT OVERWRITE TABLE dws.dws_ord_tenant_sku_channel_trade_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  u.seller_tenant_id,                                                             -- 卖家租户ID
  u.sku_id,                                                                       -- SKU ID
  u.channel_id,                                                                   -- 入口渠道ID
  u.app_ref_code,                                                                 -- 对接端引用
  u.operator_type,                                                                -- 操作人类型
  SUM(u.order_group_qty) AS order_group_qty,                                      -- 下单聚合单数
  SUM(u.order_qty) AS order_qty,                                                  -- 下单子单数
  SUM(u.order_ticket_qty) AS order_ticket_qty,                                    -- 下单票数
  SUM(u.order_amt) AS order_amt,                                                  -- 下单金额
  SUM(u.pay_order_qty) AS pay_order_qty,                                          -- 支付子单数
  SUM(u.pay_ticket_qty) AS pay_ticket_qty,                                        -- 支付票数
  SUM(u.pay_amt) AS pay_amt,                                                      -- 支付金额（GMV）
  SUM(u.pay_buyer_qty) AS pay_buyer_qty,                                          -- 支付买家数
  BITMAP_UNION(u.pay_buyer_bitmap) AS pay_buyer_bitmap,                           -- 支付买家数去重位图
  SUM(u.cancel_order_qty) AS cancel_order_qty,                                    -- 取消子单数
  SUM(u.cancel_amt) AS cancel_amt,                                                -- 取消金额
  SUM(u.staff_order_qty) AS staff_order_qty,                                      -- 员工代下单数
  SUM(u.combo_order_qty) AS combo_order_qty,                                      -- 套票主单数
  SUM(u.pay_order_group_qty) AS pay_order_group_qty,                              -- 支付聚合单数
  SUM(u.cost_amt) AS cost_amt,                                                    -- 成本金额
  SUM(u.pay_minute_qty) AS pay_minute_qty,                                        -- 下单到支付总时长
  SUM(u.timeout_cancel_order_qty) AS timeout_cancel_order_qty,                    -- 超时取消子单数
  SUM(u.advance_book_day_qty) AS advance_book_day_qty,                            -- 提前预订天数合计
  CURRENT_TIMESTAMP() AS etl_time                                                 -- ETL 加载时间
FROM all_src u
GROUP BY u.seller_tenant_id, u.sku_id, u.channel_id, u.app_ref_code, u.operator_type;  -- 按粒度键汇总
