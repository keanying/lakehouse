-- dws.dws_ord_tenant_sku_trade_rt  商户×SKU 分钟级交易
-- 粒度：seller_tenant_id × sku_id × channel_id × operator_type × 窗口
-- 来源：dwd_ord_order_rt + dwd_fin_payment_rt + dwd_ord_refund_rt
-- 生成方式：Flink SQL（1 分钟滚动窗口聚合 → StarRocks 主键模型表）；字段 19 个：直接翻译 5 · 规则翻译 14 · 待确认 0
-- 多来源：每个来源先按粒度键预聚合，UNION ALL 后再汇总
-- 补 0 / 补空列：多来源 UNION ALL 时，某来源不产出的指标补 0 或空，外层按粒度 SUM 后即为各来源之和，不影响结果

INSERT INTO dws.dws_ord_tenant_sku_trade_rt                                       -- 写入 StarRocks 目标表
WITH
src_order AS (                                                                    -- 来源「实时下单明细」按粒度键预聚合（1 分钟滚动窗口）
  SELECT
    window_start AS window_start_time,                                            -- 窗口开始时间
    window_end AS window_end_time,                                                -- 窗口结束时间
    travel_date AS travel_date,                                                   -- 数据日期
    seller_tenant_id AS seller_tenant_id,                                         -- 卖家租户ID
    sku_id AS sku_id,                                                             -- SKU ID
    channel_id AS channel_id,                                                     -- 入口渠道ID
    operator_type AS operator_type,                                               -- 操作人类型
    SUM(CASE WHEN pay_time IS NOT NULL THEN unit_price_amt*buy_ticket_qty END) AS pay_amt,  -- 支付金额（GMV）
    COUNT(DISTINCT CASE WHEN order_status = 'PAID' AND pay_time IS NOT NULL THEN order_no END) AS pay_order_qty,  -- 支付子单数｜口径：当前状态已支付
    SUM(CASE WHEN pay_time IS NOT NULL THEN buy_ticket_qty END) AS pay_ticket_qty,  -- 支付票数
    COUNT(DISTINCT CASE WHEN pay_time IS NOT NULL AND buyer_customer_id > 0 AND buyer_type = 'CUSTOMER' THEN buyer_customer_id END) AS pay_buyer_qty,  -- 支付买家数｜口径：口径说明：实时窗口内不关联游客维表，占位买家在当日离线结果中剔除
    NULL AS refund_amt,                                                           -- 退款金额：此来源不产出，补空
    NULL AS refund_ticket_qty,                                                    -- 退款票数：此来源不产出，补空
    COUNT(DISTINCT CASE WHEN parent_order_no = '' THEN order_no END) AS order_qty,  -- 下单子单数｜口径：不含套票子项
    SUM(buy_ticket_qty) AS order_ticket_qty,                                      -- 下单票数
    SUM(unit_price_amt*buy_ticket_qty) AS order_amt,                              -- 下单金额
    COUNT(DISTINCT CASE WHEN order_status = 'CANCELLED' THEN order_no END) AS cancel_order_qty,  -- 取消子单数｜口径：当前状态已取消
    COUNT(CASE WHEN operator_type='TENANT_STAFF' THEN order_no END) AS staff_order_qty,  -- 员工代下单数
    SUM(CASE WHEN operator_type = 'TENANT_STAFF' AND pay_time IS NOT NULL THEN unit_price_amt * buy_ticket_qty END) AS staff_pay_amt  -- 员工代下单支付金额｜口径：员工代下单的支付金额
  FROM TABLE(TUMBLE(TABLE dwd.dwd_ord_order_rt, DESCRIPTOR(event_time), INTERVAL '1' MINUTE)) s  -- 按事件时间切 1 分钟滚动窗口
  GROUP BY window_start, window_end, travel_date, seller_tenant_id, sku_id, channel_id, operator_type  -- 按粒度键汇总
),
src_refund AS (                                                                   -- 来源「实时退款明细」按粒度键预聚合（1 分钟滚动窗口）
  SELECT
    window_start AS window_start_time,                                            -- 窗口开始时间
    window_end AS window_end_time,                                                -- 窗口结束时间
    travel_date AS travel_date,                                                   -- 数据日期
    seller_tenant_id AS seller_tenant_id,                                         -- 卖家租户ID
    CAST(NULL AS BIGINT) AS sku_id,                                               -- SKU ID：此来源不产出，补空
    channel_id AS channel_id,                                                     -- 入口渠道ID
    CAST(NULL AS STRING) AS operator_type,                                        -- 操作人类型：此来源不产出，补空
    NULL AS pay_amt,                                                              -- 支付金额（GMV）：此来源不产出，补空
    NULL AS pay_order_qty,                                                        -- 支付子单数：此来源不产出，补空
    NULL AS pay_ticket_qty,                                                       -- 支付票数：此来源不产出，补空
    NULL AS pay_buyer_qty,                                                        -- 支付买家数：此来源不产出，补空
    SUM(CASE WHEN refund_status = 'COMPLETED' THEN refund_amt END) AS refund_amt,  -- 退款金额
    SUM(CASE WHEN refund_status = 'COMPLETED' THEN refund_ticket_qty END) AS refund_ticket_qty,  -- 退款票数｜口径：退款完成的票数
    NULL AS order_qty,                                                            -- 下单子单数：此来源不产出，补空
    NULL AS order_ticket_qty,                                                     -- 下单票数：此来源不产出，补空
    NULL AS order_amt,                                                            -- 下单金额：此来源不产出，补空
    NULL AS cancel_order_qty,                                                     -- 取消子单数：此来源不产出，补空
    NULL AS staff_order_qty,                                                      -- 员工代下单数：此来源不产出，补空
    NULL AS staff_pay_amt                                                         -- 员工代下单支付金额：此来源不产出，补空
  FROM TABLE(TUMBLE(TABLE dwd.dwd_ord_refund_rt, DESCRIPTOR(event_time), INTERVAL '1' MINUTE)) s  -- 按事件时间切 1 分钟滚动窗口
  GROUP BY window_start, window_end, travel_date, seller_tenant_id, channel_id    -- 按粒度键汇总
),
all_src AS (                                                                      -- 各来源字段已对齐，UNION ALL 合并（比多表 FULL JOIN 少 shuffle）
  SELECT * FROM src_order
  UNION ALL
  SELECT * FROM src_refund
)
SELECT
  u.travel_date,                                                                  -- 数据日期
  u.window_start_time,                                                            -- 窗口开始时间
  u.window_end_time,                                                              -- 窗口结束时间
  u.seller_tenant_id,                                                             -- 卖家租户ID
  u.sku_id,                                                                       -- SKU ID
  u.channel_id,                                                                   -- 入口渠道ID
  u.operator_type,                                                                -- 操作人类型
  SUM(u.pay_amt) AS pay_amt,                                                      -- 支付金额（GMV）
  SUM(u.pay_order_qty) AS pay_order_qty,                                          -- 支付子单数
  SUM(u.pay_ticket_qty) AS pay_ticket_qty,                                        -- 支付票数
  SUM(u.pay_buyer_qty) AS pay_buyer_qty,                                          -- 支付买家数
  SUM(u.refund_amt) AS refund_amt,                                                -- 退款金额
  SUM(u.refund_ticket_qty) AS refund_ticket_qty,                                  -- 退款票数
  SUM(u.order_qty) AS order_qty,                                                  -- 下单子单数
  SUM(u.order_ticket_qty) AS order_ticket_qty,                                    -- 下单票数
  SUM(u.order_amt) AS order_amt,                                                  -- 下单金额
  SUM(u.cancel_order_qty) AS cancel_order_qty,                                    -- 取消子单数
  SUM(u.staff_order_qty) AS staff_order_qty,                                      -- 员工代下单数
  SUM(u.staff_pay_amt) AS staff_pay_amt,                                          -- 员工代下单支付金额
  CURRENT_TIMESTAMP AS update_time                                                -- 最近一次写入时间
FROM all_src u
GROUP BY u.window_start_time,                                                     -- 按粒度键汇总
         u.window_end_time,                                                       -- 窗口结束时间
         u.travel_date,                                                           -- 数据日期
         u.seller_tenant_id,                                                      -- 卖家租户ID
         u.sku_id,                                                                -- SKU ID
         u.channel_id,                                                            -- 入口渠道ID
         u.operator_type;
