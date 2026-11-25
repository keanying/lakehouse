-- ads.ads_ord_sku_sales_rank_rt  SKU 实时销售排行
-- 粒度：seller_tenant_id × sku_id × 今日
-- 来源：dws_ord_tenant_sku_trade_rt
-- 生成方式：StarRocks 异步物化视图（每分钟刷新）；字段 10 个：直接翻译 6 · 规则翻译 4 · 待确认 0

CREATE MATERIALIZED VIEW IF NOT EXISTS ads.ads_ord_sku_sales_rank_rt
REFRESH ASYNC EVERY (INTERVAL 1 MINUTE)
AS
SELECT
  x.travel_date,
  x.seller_tenant_id,
  x.sku_id,
  d1.tenant_name AS seller_tenant_name,
  d2.sku_name AS sku_name,
  x.pay_today_amt,
  x.pay_ticket_today_qty,
  x.refund_ticket_today_qty,
  x.avg_ticket_price_today_amt,
  x.update_time
FROM (
SELECT
  u.travel_date,
  u.seller_tenant_id,
  u.sku_id,
  SUM(u.pay_amt) AS pay_today_amt,
  SUM(u.pay_ticket_qty) AS pay_ticket_today_qty,
  SUM(u.refund_ticket_qty) AS refund_ticket_today_qty,
  SUM(u.pay_amt) / NULLIF(SUM(u.pay_ticket_qty), 0) AS avg_ticket_price_today_amt,
  NOW() AS update_time
FROM (
  -- 来源：dws_ord_tenant_sku_trade_rt
  SELECT
    s.travel_date AS travel_date,
    s.seller_tenant_id AS seller_tenant_id,
    s.sku_id AS sku_id,
    SUM(s.pay_amt) AS pay_amt,
    SUM(s.pay_ticket_qty) AS pay_ticket_qty,
    SUM(s.refund_ticket_qty) AS refund_ticket_qty
  FROM dws.dws_ord_tenant_sku_trade_rt s
  WHERE s.travel_date = DATE_FORMAT(CURDATE(), '%Y%m%d')
  GROUP BY s.travel_date, s.seller_tenant_id, s.sku_id
) u
GROUP BY u.travel_date, u.seller_tenant_id, u.sku_id
) x
LEFT JOIN dim.dim_sup_tenant_zip d1 ON d1.tenant_id = x.seller_tenant_id AND d1.end_date = '9999-12-31'
LEFT JOIN dim.dim_prd_sku_zip d2 ON d2.sku_id = x.sku_id AND d2.end_date = '9999-12-31';
