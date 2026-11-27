-- ads.ads_ord_tenant_trade_overview_rt  商户经营实时概览
-- 粒度：seller_tenant_id × 今日
-- 来源：dws_ord_tenant_sku_trade_rt, dws_ord_tenant_sku_verify_rt
-- 生成方式：StarRocks 异步物化视图（每分钟刷新）；字段 18 个：直接翻译 4 · 规则翻译 14 · 待确认 0
-- 多来源：各来源按粒度键预聚合后 UNION ALL 合并，再按公式计算
-- 补 0 / 补空列：多来源 UNION ALL 时，某来源不产出的指标补 0 或空，外层按粒度 SUM 后即为各来源之和，不影响结果

CREATE MATERIALIZED VIEW IF NOT EXISTS ads.ads_ord_tenant_trade_overview_rt  -- 异步物化视图，StarRocks 定时刷新
REFRESH ASYNC EVERY (INTERVAL 1 MINUTE)
AS
WITH
src_tenant_sku_trade AS (                             -- 来源「商户×SKU 分钟级交易」按粒度键预聚合
  SELECT
    s.travel_date AS travel_date,                     -- 数据日期
    s.seller_tenant_id AS seller_tenant_id,           -- 卖家租户ID
    SUM(s.pay_amt) AS pay_amt,                        -- 支付金额（GMV）
    SUM(s.refund_amt) AS refund_amt,                  -- 退款金额
    SUM(s.pay_order_qty) AS pay_order_qty,            -- 支付子单数
    SUM(s.pay_ticket_qty) AS pay_ticket_qty,          -- 支付票数
    SUM(s.pay_buyer_qty) AS pay_buyer_qty,            -- 支付买家数
    SUM(s.order_qty) AS order_qty,                    -- 下单子单数
    SUM(s.refund_ticket_qty) AS refund_ticket_qty,    -- 退款票数
    NULL AS verify_ticket_qty,                        -- 核销票数：此来源不产出，补空
    NULL AS verify_amt                                -- 核销金额：此来源不产出，补空
  FROM dws.dws_ord_tenant_sku_trade_rt s              -- 来源表「商户×SKU 分钟级交易」
  WHERE s.travel_date = DATE_FORMAT(CURDATE(), '%Y%m%d')  -- 只取今日数据
  GROUP BY s.travel_date, s.seller_tenant_id          -- 按粒度键汇总
),
src_tenant_sku_verify AS (                            -- 来源「商户×SKU 实时核销」按粒度键预聚合
  SELECT
    s.travel_date AS travel_date,                     -- 数据日期
    s.seller_tenant_id AS seller_tenant_id,           -- 卖家租户ID
    NULL AS pay_amt,                                  -- 支付金额（GMV）：此来源不产出，补空
    NULL AS refund_amt,                               -- 退款金额：此来源不产出，补空
    NULL AS pay_order_qty,                            -- 支付子单数：此来源不产出，补空
    NULL AS pay_ticket_qty,                           -- 支付票数：此来源不产出，补空
    NULL AS pay_buyer_qty,                            -- 支付买家数：此来源不产出，补空
    NULL AS order_qty,                                -- 下单子单数：此来源不产出，补空
    NULL AS refund_ticket_qty,                        -- 退款票数：此来源不产出，补空
    SUM(s.verify_ticket_qty) AS verify_ticket_qty,    -- 核销票数
    SUM(s.verify_amt) AS verify_amt                   -- 核销金额
  FROM dws.dws_ord_tenant_sku_verify_rt s             -- 来源表「商户×SKU 实时核销」
  WHERE s.travel_date = DATE_FORMAT(CURDATE(), '%Y%m%d')  -- 只取今日数据
  GROUP BY s.travel_date, s.seller_tenant_id          -- 按粒度键汇总
),
all_src AS (                                          -- 各来源字段已对齐，UNION ALL 合并（比多表 FULL JOIN 少 shuffle）
  SELECT * FROM src_tenant_sku_trade
  UNION ALL
  SELECT * FROM src_tenant_sku_verify
),
merged AS (                                           -- 按粒度键汇总，计算派生指标
  SELECT
    u.travel_date,                                    -- 数据日期
    u.seller_tenant_id,                               -- 卖家租户ID
    SUM(u.pay_amt) AS pay_today_amt,                  -- 今日实时支付金额（GMV）
    SUM(u.pay_amt) - SUM(u.refund_amt) AS net_pay_today_amt,  -- 今日实时净成交金额
    SUM(u.pay_order_qty) AS pay_order_today_qty,      -- 今日实时支付子单数
    SUM(u.pay_ticket_qty) AS pay_ticket_today_qty,    -- 今日实时支付票数
    SUM(u.pay_buyer_qty) AS pay_buyer_today_qty,      -- 今日实时支付买家数
    SUM(u.order_qty) AS order_today_qty,              -- 今日实时下单子单数
    SUM(u.refund_amt) AS refund_today_amt,            -- 今日实时退款金额
    SUM(u.refund_ticket_qty) AS refund_ticket_today_qty,  -- 今日实时退款票数
    SUM(u.verify_ticket_qty) AS verify_ticket_today_qty,  -- 今日实时核销票数
    SUM(u.verify_amt) AS verify_today_amt,            -- 今日实时核销金额
    SUM(u.pay_amt) / NULLIF(SUM(u.pay_ticket_qty), 0) AS avg_ticket_price_today_amt,  -- 今日实时平均票价
    SUM(u.pay_amt) / NULLIF(SUM(u.pay_buyer_qty), 0) AS per_customer_today_amt,  -- 今日实时客单价
    SUM(u.refund_ticket_qty) * 100 / NULLIF(SUM(u.pay_ticket_qty), 0) AS refund_today_rate,  -- 今日实时退票率
    SUM(u.pay_order_qty) * 100 / NULLIF(SUM(u.order_qty), 0) AS pay_conversion_today_rate,  -- 今日实时下单支付转化率
    NOW() AS update_time                              -- 最近一次写入时间
  FROM all_src u
  GROUP BY u.travel_date, u.seller_tenant_id          -- 按粒度键汇总
),
tenant_cur AS (                                       -- 「租户（商户/供应商/分销商）维度」当前有效版本，只取名称类字段
  SELECT tenant_id, tenant_name
  FROM dim.dim_sup_tenant_zip
  WHERE end_date = '9999-12-31'                       -- 只取拉链当前有效版本
)
SELECT
  merged.travel_date,                                 -- 数据日期
  merged.seller_tenant_id,                            -- 卖家租户ID
  tenant_cur.tenant_name AS seller_tenant_name,       -- 卖家租户名称
  merged.pay_today_amt,                               -- 今日实时支付金额（GMV）
  merged.net_pay_today_amt,                           -- 今日实时净成交金额
  merged.pay_order_today_qty,                         -- 今日实时支付子单数
  merged.pay_ticket_today_qty,                        -- 今日实时支付票数
  merged.pay_buyer_today_qty,                         -- 今日实时支付买家数
  merged.order_today_qty,                             -- 今日实时下单子单数
  merged.refund_today_amt,                            -- 今日实时退款金额
  merged.refund_ticket_today_qty,                     -- 今日实时退款票数
  merged.verify_ticket_today_qty,                     -- 今日实时核销票数
  merged.verify_today_amt,                            -- 今日实时核销金额
  merged.avg_ticket_price_today_amt,                  -- 今日实时平均票价
  merged.per_customer_today_amt,                      -- 今日实时客单价
  merged.refund_today_rate,                           -- 今日实时退票率
  merged.pay_conversion_today_rate,                   -- 今日实时下单支付转化率
  merged.update_time                                  -- 最近一次写入时间
FROM merged
LEFT JOIN tenant_cur                                  -- 关联「租户（商户/供应商/分销商）维度」，补 seller_tenant_name
  ON tenant_cur.tenant_id = merged.seller_tenant_id;  -- 按 seller_tenant_id→tenant_id 关联
