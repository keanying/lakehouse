-- dws.dws_ord_tenant_sku_channel_trade_di  商户×SKU×渠道 交易日汇总
-- 粒度：travel_date × seller_tenant_id × sku_id × channel_id × app_ref_code × operator_type
-- 来源：dwd_ord_order_di, dwd_ord_order_status_log_di, dwd_ord_order_group_di
-- 生成方式：Spark SQL / Hive；字段 27 个：直接翻译 5 · 规则翻译 22 · 待确认 0
-- 多来源：每个来源先按粒度键预聚合，UNION ALL 后再汇总

WITH
src_order_group AS (                                                          -- 来源「聚合单明细」按粒度键预聚合
  SELECT
    seller_tenant_id AS seller_tenant_id,                                     -- 卖家租户ID
    CAST(NULL AS BIGINT) AS sku_id,                                           -- SKU ID：本来源无，补空对齐 UNION ALL
    channel_id AS channel_id,                                                 -- 入口渠道ID
    app_ref_code AS app_ref_code,                                             -- 对接端引用
    operator_type AS operator_type,                                           -- 操作人类型
    COUNT(DISTINCT order_group_no) AS order_group_qty,                        -- 下单聚合单数
    NULL AS order_qty,                                                        -- 下单子单数：本来源无，补空对齐 UNION ALL
    NULL AS order_ticket_qty,                                                 -- 下单票数：本来源无，补空对齐 UNION ALL
    NULL AS order_amt,                                                        -- 下单金额：本来源无，补空对齐 UNION ALL
    NULL AS pay_order_qty,                                                    -- 支付子单数：本来源无，补空对齐 UNION ALL
    NULL AS pay_ticket_qty,                                                   -- 支付票数：本来源无，补空对齐 UNION ALL
    NULL AS pay_amt,                                                          -- 支付金额（GMV）：本来源无，补空对齐 UNION ALL
    NULL AS pay_buyer_qty,                                                    -- 支付买家数：本来源无，补空对齐 UNION ALL
    CAST(NULL AS BINARY) AS pay_buyer_bitmap,                                 -- 支付买家数去重位图：本来源无，补空对齐 UNION ALL
    NULL AS cancel_order_qty,                                                 -- 取消子单数：本来源无，补空对齐 UNION ALL
    NULL AS cancel_amt,                                                       -- 取消金额：本来源无，补空对齐 UNION ALL
    NULL AS staff_order_qty,                                                  -- 员工代下单数：本来源无，补空对齐 UNION ALL
    NULL AS combo_order_qty,                                                  -- 套票主单数：本来源无，补空对齐 UNION ALL
    COUNT(DISTINCT CASE WHEN pay_status='PAID' THEN order_group_no END) AS pay_order_group_qty,  -- 支付聚合单数
    NULL AS cost_amt,                                                         -- 成本金额：本来源无，补空对齐 UNION ALL
    NULL AS pay_minute_qty,                                                   -- 下单到支付总时长：本来源无，补空对齐 UNION ALL
    NULL AS timeout_cancel_order_qty,                                         -- 超时取消子单数：本来源无，补空对齐 UNION ALL
    NULL AS advance_book_day_qty                                              -- 提前预订天数合计：本来源无，补空对齐 UNION ALL
  FROM dwd.dwd_ord_order_group_di s                                           -- 来源表「聚合单明细」
  WHERE s.travel_date = '${bizdate}'                                          -- 只取当日分区
  GROUP BY seller_tenant_id, channel_id, app_ref_code, operator_type          -- 按粒度键汇总
),
src_order AS (                                                                -- 来源「子单明细」按粒度键预聚合
  SELECT
    seller_tenant_id AS seller_tenant_id,                                     -- 卖家租户ID
    sku_id AS sku_id,                                                         -- SKU ID
    channel_id AS channel_id,                                                 -- 入口渠道ID
    app_ref_code AS app_ref_code,                                             -- 对接端引用
    operator_type AS operator_type,                                           -- 操作人类型
    NULL AS order_group_qty,                                                  -- 下单聚合单数：本来源无，补空对齐 UNION ALL
    COUNT(DISTINCT CASE WHEN s.parent_order_no = '' THEN s.order_no END) AS order_qty,  -- 下单子单数｜口径：不含套票子项（parent_order_no 非空的子单）
    SUM(buy_ticket_qty) AS order_ticket_qty,                                  -- 下单票数
    SUM(unit_price_amt*buy_ticket_qty) AS order_amt,                          -- 下单金额
    NULL AS pay_order_qty,                                                    -- 支付子单数：本来源无，补空对齐 UNION ALL
    SUM(CASE WHEN pay_time IS NOT NULL THEN buy_ticket_qty END) AS pay_ticket_qty,  -- 支付票数
    SUM(CASE WHEN pay_time IS NOT NULL THEN unit_price_amt*buy_ticket_qty END) AS pay_amt,  -- 支付金额（GMV）
    COUNT(DISTINCT CASE WHEN s.pay_time IS NOT NULL                           -- 支付买家数｜口径：已支付的真人买家，剔除匿名与占位买家
        AND s.buyer_customer_id > 0
          AND rb.rb_customer_type = 'REAL' THEN s.buyer_customer_id END) AS pay_buyer_qty,  -- 支付买家数
    BITMAP_UNION(TO_BITMAP(CASE WHEN s.pay_time IS NOT NULL                   -- 支付买家数去重位图｜口径：同上，去重位图
        AND s.buyer_customer_id > 0
          AND rb.rb_customer_type = 'REAL' THEN s.buyer_customer_id END)) AS pay_buyer_bitmap,  -- 支付买家数去重位图
    NULL AS cancel_order_qty,                                                 -- 取消子单数：本来源无，补空对齐 UNION ALL
    SUM(CASE WHEN s.cancel_time IS NOT NULL THEN s.order_amt END) AS cancel_amt,  -- 取消金额｜口径：已取消子单的下单金额
    COUNT(CASE WHEN operator_type='TENANT_STAFF' THEN order_no END) AS staff_order_qty,  -- 员工代下单数
    COUNT(CASE WHEN combo_type=1 THEN order_no END) AS combo_order_qty,       -- 套票主单数
    NULL AS pay_order_group_qty,                                              -- 支付聚合单数：本来源无，补空对齐 UNION ALL
    SUM(CASE WHEN pay_time IS NOT NULL THEN cost_price_amt * buy_ticket_qty END) AS cost_amt,  -- 成本金额
    NULL AS pay_minute_qty,                                                   -- 下单到支付总时长：本来源无，补空对齐 UNION ALL
    NULL AS timeout_cancel_order_qty,                                         -- 超时取消子单数：本来源无，补空对齐 UNION ALL
    SUM(CASE WHEN s.pay_time IS NOT NULL THEN DATEDIFF(s.play_date, TO_DATE(s.pay_time)) * s.buy_ticket_qty END) AS advance_book_day_qty  -- 提前预订天数合计｜口径：（游玩日 − 支付日）× 票数
  FROM dwd.dwd_ord_order_di s                                                 -- 来源表「子单明细」
  LEFT JOIN (SELECT customer_id AS rb_customer_id, customer_type AS rb_customer_type FROM dim.dim_cus_customer_zip
             WHERE travel_date = '${bizdate}'                                 -- 只取当日分区
               AND end_date = '9999-12-31') rb ON rb.rb_customer_id = s.buyer_customer_id  -- 只取拉链当前有效版本
  WHERE s.travel_date = '${bizdate}'                                          -- 只取当日分区
  GROUP BY seller_tenant_id, sku_id, channel_id, app_ref_code, operator_type  -- 按粒度键汇总
),
src_order_status_log AS (                                                     -- 来源「子单状态流转明细」按粒度键预聚合
  SELECT
    seller_tenant_id AS seller_tenant_id,                                     -- 卖家租户ID
    sku_id AS sku_id,                                                         -- SKU ID
    CAST(NULL AS BIGINT) AS channel_id,                                       -- 入口渠道ID：本来源无，补空对齐 UNION ALL
    CAST(NULL AS STRING) AS app_ref_code,                                     -- 对接端引用：本来源无，补空对齐 UNION ALL
    CAST(NULL AS STRING) AS operator_type,                                    -- 操作人类型：本来源无，补空对齐 UNION ALL
    NULL AS order_group_qty,                                                  -- 下单聚合单数：本来源无，补空对齐 UNION ALL
    NULL AS order_qty,                                                        -- 下单子单数：本来源无，补空对齐 UNION ALL
    NULL AS order_ticket_qty,                                                 -- 下单票数：本来源无，补空对齐 UNION ALL
    NULL AS order_amt,                                                        -- 下单金额：本来源无，补空对齐 UNION ALL
    COUNT(DISTINCT CASE WHEN after_status='PAID' THEN order_no END) AS pay_order_qty,  -- 支付子单数
    NULL AS pay_ticket_qty,                                                   -- 支付票数：本来源无，补空对齐 UNION ALL
    NULL AS pay_amt,                                                          -- 支付金额（GMV）：本来源无，补空对齐 UNION ALL
    NULL AS pay_buyer_qty,                                                    -- 支付买家数：本来源无，补空对齐 UNION ALL
    CAST(NULL AS BINARY) AS pay_buyer_bitmap,                                 -- 支付买家数去重位图：本来源无，补空对齐 UNION ALL
    COUNT(DISTINCT CASE WHEN after_status='CANCELLED' THEN order_no END) AS cancel_order_qty,  -- 取消子单数
    NULL AS cancel_amt,                                                       -- 取消金额：本来源无，补空对齐 UNION ALL
    NULL AS staff_order_qty,                                                  -- 员工代下单数：本来源无，补空对齐 UNION ALL
    NULL AS combo_order_qty,                                                  -- 套票主单数：本来源无，补空对齐 UNION ALL
    NULL AS pay_order_group_qty,                                              -- 支付聚合单数：本来源无，补空对齐 UNION ALL
    NULL AS cost_amt,                                                         -- 成本金额：本来源无，补空对齐 UNION ALL
    SUM(CASE WHEN before_status = 'PENDING_PAY' AND after_status = 'PAID' THEN stay_minute_qty END) AS pay_minute_qty,  -- 下单到支付总时长｜口径：待支付 → 已支付的停留分钟（下单到支付耗时）
    COUNT(CASE WHEN s.before_status = 'PENDING_PAY'                           -- 超时取消子单数｜口径：待支付 → 已取消，且取消时间不早于聚合单支付超时时间
        AND s.after_status = 'CANCELLED'
          AND s.change_time >= og.og_pay_timeout_time THEN s.order_no END) AS timeout_cancel_order_qty,  -- 超时取消子单数
    NULL AS advance_book_day_qty                                              -- 提前预订天数合计：本来源无，补空对齐 UNION ALL
  FROM dwd.dwd_ord_order_status_log_di s                                      -- 来源表「子单状态流转明细」
  LEFT JOIN (SELECT order_group_no AS og_no, MAX(pay_timeout_time) AS og_pay_timeout_time FROM dwd.dwd_ord_order_group_di
             WHERE travel_date >= DATE_FORMAT(DATE_SUB(TO_DATE('${bizdate}', 'yyyyMMdd'), 400), 'yyyyMMdd')
                 GROUP BY order_group_no) og ON og.og_no = s.order_group_no   -- 按粒度键汇总
  WHERE s.travel_date = '${bizdate}'                                          -- 只取当日分区
  GROUP BY seller_tenant_id, sku_id                                           -- 按粒度键汇总
),
all_src AS (                                                                  -- 各来源字段已对齐，UNION ALL 合并（比多表 FULL JOIN 少 shuffle）
  SELECT * FROM src_order_group
  UNION ALL
  SELECT * FROM src_order
  UNION ALL
  SELECT * FROM src_order_status_log
)
INSERT OVERWRITE TABLE dws.dws_ord_tenant_sku_channel_trade_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  u.seller_tenant_id,                                                         -- 卖家租户ID
  u.sku_id,                                                                   -- SKU ID
  u.channel_id,                                                               -- 入口渠道ID
  u.app_ref_code,                                                             -- 对接端引用
  u.operator_type,                                                            -- 操作人类型
  SUM(u.order_group_qty) AS order_group_qty,                                  -- 下单聚合单数
  SUM(u.order_qty) AS order_qty,                                              -- 下单子单数
  SUM(u.order_ticket_qty) AS order_ticket_qty,                                -- 下单票数
  SUM(u.order_amt) AS order_amt,                                              -- 下单金额
  SUM(u.pay_order_qty) AS pay_order_qty,                                      -- 支付子单数
  SUM(u.pay_ticket_qty) AS pay_ticket_qty,                                    -- 支付票数
  SUM(u.pay_amt) AS pay_amt,                                                  -- 支付金额（GMV）
  SUM(u.pay_buyer_qty) AS pay_buyer_qty,                                      -- 支付买家数
  BITMAP_UNION(u.pay_buyer_bitmap) AS pay_buyer_bitmap,                       -- 支付买家数去重位图
  SUM(u.cancel_order_qty) AS cancel_order_qty,                                -- 取消子单数
  SUM(u.cancel_amt) AS cancel_amt,                                            -- 取消金额
  SUM(u.staff_order_qty) AS staff_order_qty,                                  -- 员工代下单数
  SUM(u.combo_order_qty) AS combo_order_qty,                                  -- 套票主单数
  SUM(u.pay_order_group_qty) AS pay_order_group_qty,                          -- 支付聚合单数
  SUM(u.cost_amt) AS cost_amt,                                                -- 成本金额
  SUM(u.pay_minute_qty) AS pay_minute_qty,                                    -- 下单到支付总时长
  SUM(u.timeout_cancel_order_qty) AS timeout_cancel_order_qty,                -- 超时取消子单数
  SUM(u.advance_book_day_qty) AS advance_book_day_qty,                        -- 提前预订天数合计
  CURRENT_TIMESTAMP() AS etl_time                                             -- ETL 加载时间
FROM all_src u
GROUP BY u.seller_tenant_id, u.sku_id, u.channel_id, u.app_ref_code, u.operator_type;  -- 按粒度键汇总
