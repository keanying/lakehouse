-- ads.ads_ord_sku_sales_rank_rt  SKU 实时销售排行
-- 粒度：seller_tenant_id × sku_id × 今日
-- 来源：dws_ord_tenant_sku_trade_rt
-- 生成方式：StarRocks 异步物化视图（每分钟刷新）；字段 10 个：直接翻译 6 · 规则翻译 4 · 待确认 0

CREATE MATERIALIZED VIEW IF NOT EXISTS ads.ads_ord_sku_sales_rank_rt  -- 异步物化视图，StarRocks 定时刷新
REFRESH ASYNC EVERY (INTERVAL 1 MINUTE)
AS
SELECT
  x.travel_date,                                          -- 数据日期
  x.seller_tenant_id,                                     -- 卖家租户ID
  x.sku_id,                                               -- SKU ID
  d1.tenant_name AS seller_tenant_name,                   -- 卖家租户名称
  d2.sku_name AS sku_name,                                -- SKU 名称
  x.pay_today_amt,                                        -- 今日实时支付金额（GMV）
  x.pay_ticket_today_qty,                                 -- 今日实时支付票数
  x.refund_ticket_today_qty,                              -- 今日实时退款票数
  x.avg_ticket_price_today_amt,                           -- 今日实时平均票价
  x.update_time                                           -- 最近一次写入时间
FROM (
SELECT
  u.travel_date,                                          -- 数据日期
  u.seller_tenant_id,                                     -- 卖家租户ID
  u.sku_id,                                               -- SKU ID
  SUM(u.pay_amt) AS pay_today_amt,                        -- 今日实时支付金额（GMV）
  SUM(u.pay_ticket_qty) AS pay_ticket_today_qty,          -- 今日实时支付票数
  SUM(u.refund_ticket_qty) AS refund_ticket_today_qty,    -- 今日实时退款票数
  SUM(u.pay_amt) / NULLIF(SUM(u.pay_ticket_qty), 0) AS avg_ticket_price_today_amt,  -- 今日实时平均票价
  NOW() AS update_time                                    -- 最近一次写入时间
FROM (
  -- 来源：dws_ord_tenant_sku_trade_rt
  SELECT
    s.travel_date AS travel_date,                         -- 数据日期
    s.seller_tenant_id AS seller_tenant_id,               -- 卖家租户ID
    s.sku_id AS sku_id,                                   -- SKU ID
    SUM(s.pay_amt) AS pay_amt,
    SUM(s.pay_ticket_qty) AS pay_ticket_qty,
    SUM(s.refund_ticket_qty) AS refund_ticket_qty
  FROM dws.dws_ord_tenant_sku_trade_rt s                  -- 来源表「商户×SKU 分钟级交易」
  WHERE s.travel_date = DATE_FORMAT(CURDATE(), '%Y%m%d')  -- 只取今日数据
  GROUP BY s.travel_date, s.seller_tenant_id, s.sku_id    -- 按粒度键汇总
) u                                                       -- 各来源合并后的明细
GROUP BY u.travel_date, u.seller_tenant_id, u.sku_id      -- 按粒度键汇总
) x                                                       -- 汇总结果，外层再补维度名称
LEFT JOIN dim.dim_sup_tenant_zip d1 ON d1.tenant_id = x.seller_tenant_id AND d1.end_date = '9999-12-31'  -- 关联「租户（商户/供应商/分销商）维度」，取维度名称
LEFT JOIN dim.dim_prd_sku_zip d2 ON d2.sku_id = x.sku_id AND d2.end_date = '9999-12-31';  -- 关联「SKU维度」，取维度名称
