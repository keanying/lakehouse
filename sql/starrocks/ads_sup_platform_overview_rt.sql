-- ads.ads_sup_platform_overview_rt  平台实时大盘
-- 粒度：全平台 × 今日
-- 来源：dws_ord_tenant_sku_trade_rt, dws_ord_tenant_sku_verify_rt, dws_cus_tenant_growth_rt
-- 生成方式：StarRocks 异步物化视图（每分钟刷新）；字段 14 个：直接翻译 2 · 规则翻译 12 · 待确认 0
-- 多来源：各来源按粒度键预聚合后 UNION ALL 合并，再按公式计算
-- 补 0 / 补空列：多来源 UNION ALL 时，某来源不产出的指标补 0 或空，外层按粒度 SUM 后即为各来源之和，不影响结果

CREATE MATERIALIZED VIEW IF NOT EXISTS ads.ads_sup_platform_overview_rt  -- 异步物化视图，StarRocks 定时刷新
REFRESH ASYNC EVERY (INTERVAL 1 MINUTE)
AS
WITH
src_tenant_sku_trade AS (                               -- 来源「商户×SKU 分钟级交易」按粒度键预聚合
  SELECT
    s.travel_date AS travel_date,                       -- 数据日期
    SUM(s.pay_amt) AS pay_amt,                          -- 支付金额（GMV）
    SUM(CASE WHEN s.window_start_time >= NOW() - INTERVAL 1 HOUR THEN s.pay_amt END) AS pay_amt_1,  -- 支付金额（GMV）（第 1 个来源的部分值，外层相加）
    SUM(s.pay_order_qty) AS pay_order_qty,              -- 支付子单数
    SUM(CASE WHEN s.window_start_time >= NOW() - INTERVAL 1 HOUR THEN s.pay_order_qty END) AS pay_order_qty_1,  -- 支付子单数（第 1 个来源的部分值，外层相加）
    SUM(s.pay_buyer_qty) AS pay_buyer_qty,              -- 支付买家数
    SUM(CASE WHEN s.window_start_time >= NOW() - INTERVAL 1 HOUR THEN s.pay_buyer_qty END) AS pay_buyer_qty_1,  -- 支付买家数（第 1 个来源的部分值，外层相加）
    SUM(s.refund_amt) AS refund_amt,                    -- 退款金额
    SUM(CASE WHEN s.window_start_time >= NOW() - INTERVAL 1 HOUR THEN s.refund_amt END) AS refund_amt_1,  -- 退款金额（第 1 个来源的部分值，外层相加）
    NULL AS verify_ticket_qty,                          -- 核销票数：此来源不产出，补空
    NULL AS verify_ticket_qty_1,                        -- verify_ticket_qty_1：此来源不产出，补空
    NULL AS new_customer_qty,                           -- 新注册游客数：此来源不产出，补空
    NULL AS new_customer_qty_1                          -- new_customer_qty_1：此来源不产出，补空
  FROM dws.dws_ord_tenant_sku_trade_rt s                -- 来源表「商户×SKU 分钟级交易」
  WHERE s.travel_date = DATE_FORMAT(CURDATE(), '%Y%m%d')  -- 只取今日数据
  GROUP BY s.travel_date                                -- 按粒度键汇总
),
src_tenant_sku_verify AS (                              -- 来源「商户×SKU 实时核销」按粒度键预聚合
  SELECT
    s.travel_date AS travel_date,                       -- 数据日期
    NULL AS pay_amt,                                    -- 支付金额（GMV）：此来源不产出，补空
    NULL AS pay_amt_1,                                  -- pay_amt_1：此来源不产出，补空
    NULL AS pay_order_qty,                              -- 支付子单数：此来源不产出，补空
    NULL AS pay_order_qty_1,                            -- pay_order_qty_1：此来源不产出，补空
    NULL AS pay_buyer_qty,                              -- 支付买家数：此来源不产出，补空
    NULL AS pay_buyer_qty_1,                            -- pay_buyer_qty_1：此来源不产出，补空
    NULL AS refund_amt,                                 -- 退款金额：此来源不产出，补空
    NULL AS refund_amt_1,                               -- refund_amt_1：此来源不产出，补空
    SUM(s.verify_ticket_qty) AS verify_ticket_qty,      -- 核销票数
    SUM(CASE WHEN s.window_start_time >= NOW() - INTERVAL 1 HOUR THEN s.verify_ticket_qty END) AS verify_ticket_qty_1,  -- 核销票数（第 1 个来源的部分值，外层相加）
    NULL AS new_customer_qty,                           -- 新注册游客数：此来源不产出，补空
    NULL AS new_customer_qty_1                          -- new_customer_qty_1：此来源不产出，补空
  FROM dws.dws_ord_tenant_sku_verify_rt s               -- 来源表「商户×SKU 实时核销」
  WHERE s.travel_date = DATE_FORMAT(CURDATE(), '%Y%m%d')  -- 只取今日数据
  GROUP BY s.travel_date                                -- 按粒度键汇总
),
src_tenant_growth AS (                                  -- 来源「游客实时增长」按粒度键预聚合
  SELECT
    s.travel_date AS travel_date,                       -- 数据日期
    NULL AS pay_amt,                                    -- 支付金额（GMV）：此来源不产出，补空
    NULL AS pay_amt_1,                                  -- pay_amt_1：此来源不产出，补空
    NULL AS pay_order_qty,                              -- 支付子单数：此来源不产出，补空
    NULL AS pay_order_qty_1,                            -- pay_order_qty_1：此来源不产出，补空
    NULL AS pay_buyer_qty,                              -- 支付买家数：此来源不产出，补空
    NULL AS pay_buyer_qty_1,                            -- pay_buyer_qty_1：此来源不产出，补空
    NULL AS refund_amt,                                 -- 退款金额：此来源不产出，补空
    NULL AS refund_amt_1,                               -- refund_amt_1：此来源不产出，补空
    NULL AS verify_ticket_qty,                          -- 核销票数：此来源不产出，补空
    NULL AS verify_ticket_qty_1,                        -- verify_ticket_qty_1：此来源不产出，补空
    SUM(s.new_customer_qty) AS new_customer_qty,        -- 新注册游客数
    SUM(CASE WHEN s.window_start_time >= NOW() - INTERVAL 1 HOUR THEN s.new_customer_qty END) AS new_customer_qty_1  -- 新注册游客数（第 1 个来源的部分值，外层相加）
  FROM dws.dws_cus_tenant_growth_rt s                   -- 来源表「游客实时增长」
  WHERE s.travel_date = DATE_FORMAT(CURDATE(), '%Y%m%d')  -- 只取今日数据
  GROUP BY s.travel_date                                -- 按粒度键汇总
),
all_src AS (                                            -- 各来源字段已对齐，UNION ALL 合并（比多表 FULL JOIN 少 shuffle）
  SELECT * FROM src_tenant_sku_trade
  UNION ALL
  SELECT * FROM src_tenant_sku_verify
  UNION ALL
  SELECT * FROM src_tenant_growth
)
SELECT
  u.travel_date,                                        -- 数据日期
  SUM(u.pay_amt) AS pay_today_amt,                      -- 今日实时支付金额（GMV）
  SUM(u.pay_amt_1) AS pay_1h_amt,                       -- 近1小时支付金额（GMV）
  SUM(u.pay_order_qty) AS pay_order_today_qty,          -- 今日实时支付子单数
  SUM(u.pay_order_qty_1) AS pay_order_1h_qty,           -- 近1小时支付子单数
  SUM(u.pay_buyer_qty) AS pay_buyer_today_qty,          -- 今日实时支付买家数
  SUM(u.pay_buyer_qty_1) AS pay_buyer_1h_qty,           -- 近1小时支付买家数
  SUM(u.refund_amt) AS refund_today_amt,                -- 今日实时退款金额
  SUM(u.refund_amt_1) AS refund_1h_amt,                 -- 近1小时退款金额
  SUM(u.verify_ticket_qty) AS verify_ticket_today_qty,  -- 今日实时核销票数
  SUM(u.verify_ticket_qty_1) AS verify_ticket_1h_qty,   -- 近1小时核销票数
  SUM(u.new_customer_qty) AS new_customer_today_qty,    -- 今日实时新注册游客数
  SUM(u.new_customer_qty_1) AS new_customer_1h_qty,     -- 近1小时新注册游客数
  NOW() AS update_time                                  -- 最近一次写入时间
FROM all_src u
GROUP BY u.travel_date;                                 -- 按粒度键汇总
