-- ads.ads_ord_sku_sales_rank_rt  SKU 实时销售排行
-- 粒度：seller_tenant_id × sku_id × 今日
-- 来源：dws_ord_tenant_sku_trade_rt
-- 生成方式：StarRocks 异步物化视图（每分钟刷新）；字段 10 个：直接翻译 6 · 规则翻译 4 · 待确认 0
-- 来源按粒度键预聚合后按公式计算

CREATE MATERIALIZED VIEW IF NOT EXISTS ads.ads_ord_sku_sales_rank_rt  -- 异步物化视图，StarRocks 定时刷新
REFRESH ASYNC EVERY (INTERVAL 1 MINUTE)
AS
WITH
src_tenant_sku_trade AS (                            -- 来源「商户×SKU 分钟级交易」按粒度键预聚合
  SELECT
    s.travel_date AS travel_date,                    -- 数据日期
    s.seller_tenant_id AS seller_tenant_id,          -- 卖家租户ID
    s.sku_id AS sku_id,                              -- SKU ID
    SUM(s.pay_amt) AS pay_amt,                       -- 支付金额（GMV）
    SUM(s.pay_ticket_qty) AS pay_ticket_qty,         -- 支付票数
    SUM(s.refund_ticket_qty) AS refund_ticket_qty    -- 退款票数
  FROM dws.dws_ord_tenant_sku_trade_rt s             -- 来源表「商户×SKU 分钟级交易」
  WHERE s.travel_date = DATE_FORMAT(CURDATE(), '%Y%m%d')  -- 只取今日数据
  GROUP BY s.travel_date, s.seller_tenant_id, s.sku_id  -- 按粒度键汇总
),
merged AS (                                          -- 按粒度键汇总，计算派生指标
  SELECT
    u.travel_date,                                   -- 数据日期
    u.seller_tenant_id,                              -- 卖家租户ID
    u.sku_id,                                        -- SKU ID
    u.pay_amt AS pay_today_amt,                      -- 今日实时支付金额（GMV）
    u.pay_ticket_qty AS pay_ticket_today_qty,        -- 今日实时支付票数
    u.refund_ticket_qty AS refund_ticket_today_qty,  -- 今日实时退款票数
    u.pay_amt / NULLIF(u.pay_ticket_qty, 0) AS avg_ticket_price_today_amt,  -- 今日实时平均票价
    NOW() AS update_time                             -- 最近一次写入时间
  FROM src_tenant_sku_trade u
),
tenant_cur AS (                                      -- 「租户（商户/供应商/分销商）维度」当前有效版本，只取名称类字段
  SELECT tenant_id, tenant_name
  FROM dim.dim_sup_tenant_zip
  WHERE end_date = '9999-12-31'                      -- 只取拉链当前有效版本
),
sku_cur AS (                                         -- 「SKU维度」当前有效版本，只取名称类字段
  SELECT sku_id, sku_name
  FROM dim.dim_prd_sku_zip
  WHERE end_date = '9999-12-31'                      -- 只取拉链当前有效版本
)
SELECT
  merged.travel_date,                                -- 数据日期
  merged.seller_tenant_id,                           -- 卖家租户ID
  merged.sku_id,                                     -- SKU ID
  tenant_cur.tenant_name AS seller_tenant_name,      -- 卖家租户名称
  sku_cur.sku_name AS sku_name,                      -- SKU 名称
  merged.pay_today_amt,                              -- 今日实时支付金额（GMV）
  merged.pay_ticket_today_qty,                       -- 今日实时支付票数
  merged.refund_ticket_today_qty,                    -- 今日实时退款票数
  merged.avg_ticket_price_today_amt,                 -- 今日实时平均票价
  merged.update_time                                 -- 最近一次写入时间
FROM merged
LEFT JOIN tenant_cur                                 -- 关联「租户（商户/供应商/分销商）维度」，补 seller_tenant_name
  ON tenant_cur.tenant_id = merged.seller_tenant_id  -- 按 seller_tenant_id→tenant_id 关联
LEFT JOIN sku_cur                                    -- 关联「SKU维度」，补 sku_name
  ON sku_cur.sku_id = merged.sku_id;                 -- 按 sku_id 关联
