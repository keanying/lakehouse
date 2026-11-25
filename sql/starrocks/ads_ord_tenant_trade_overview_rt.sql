-- ads.ads_ord_tenant_trade_overview_rt  商户经营实时概览
-- 粒度：seller_tenant_id × 今日
-- 来源：dws_ord_tenant_sku_trade_rt, dws_ord_tenant_sku_verify_rt
-- 生成方式：StarRocks 异步物化视图（每分钟刷新）；字段 18 个：直接翻译 4 · 规则翻译 14 · 待确认 0
-- 多来源：各来源按粒度键汇总后 UNION ALL 合并，再按公式计算

CREATE MATERIALIZED VIEW IF NOT EXISTS ads.ads_ord_tenant_trade_overview_rt
REFRESH ASYNC EVERY (INTERVAL 1 MINUTE)
AS
SELECT
  x.travel_date,
  x.seller_tenant_id,
  d1.tenant_name AS seller_tenant_name,
  x.pay_today_amt,
  x.net_pay_today_amt,
  x.pay_order_today_qty,
  x.pay_ticket_today_qty,
  x.pay_buyer_today_qty,
  x.order_today_qty,
  x.refund_today_amt,
  x.refund_ticket_today_qty,
  x.verify_ticket_today_qty,
  x.verify_today_amt,
  x.avg_ticket_price_today_amt,
  x.per_customer_today_amt,
  x.refund_today_rate,
  x.pay_conversion_today_rate,
  x.update_time
FROM (
SELECT
  u.travel_date,
  u.seller_tenant_id,
  SUM(u.pay_amt) AS pay_today_amt,
  SUM(u.pay_amt) - SUM(u.refund_amt) AS net_pay_today_amt,
  SUM(u.pay_order_qty) AS pay_order_today_qty,
  SUM(u.pay_ticket_qty) AS pay_ticket_today_qty,
  SUM(u.pay_buyer_qty) AS pay_buyer_today_qty,
  SUM(u.order_qty) AS order_today_qty,
  SUM(u.refund_amt) AS refund_today_amt,
  SUM(u.refund_ticket_qty) AS refund_ticket_today_qty,
  SUM(u.verify_ticket_qty) AS verify_ticket_today_qty,
  SUM(u.verify_amt) AS verify_today_amt,
  SUM(u.pay_amt) / NULLIF(SUM(u.pay_ticket_qty), 0) AS avg_ticket_price_today_amt,
  SUM(u.pay_amt) / NULLIF(SUM(u.pay_buyer_qty), 0) AS per_customer_today_amt,
  SUM(u.refund_ticket_qty) * 100 / NULLIF(SUM(u.pay_ticket_qty), 0) AS refund_today_rate,
  SUM(u.pay_order_qty) * 100 / NULLIF(SUM(u.order_qty), 0) AS pay_conversion_today_rate,
  NOW() AS update_time
FROM (
  -- 来源：dws_ord_tenant_sku_trade_rt
  SELECT
    s.travel_date AS travel_date,
    s.seller_tenant_id AS seller_tenant_id,
    SUM(s.pay_amt) AS pay_amt,
    SUM(s.refund_amt) AS refund_amt,
    SUM(s.pay_order_qty) AS pay_order_qty,
    SUM(s.pay_ticket_qty) AS pay_ticket_qty,
    SUM(s.pay_buyer_qty) AS pay_buyer_qty,
    SUM(s.order_qty) AS order_qty,
    SUM(s.refund_ticket_qty) AS refund_ticket_qty,
    NULL AS verify_ticket_qty,
    NULL AS verify_amt
  FROM dws.dws_ord_tenant_sku_trade_rt s
  WHERE s.travel_date = DATE_FORMAT(CURDATE(), '%Y%m%d')
  GROUP BY s.travel_date, s.seller_tenant_id
  UNION ALL
  -- 来源：dws_ord_tenant_sku_verify_rt
  SELECT
    s.travel_date AS travel_date,
    s.seller_tenant_id AS seller_tenant_id,
    NULL AS pay_amt,
    NULL AS refund_amt,
    NULL AS pay_order_qty,
    NULL AS pay_ticket_qty,
    NULL AS pay_buyer_qty,
    NULL AS order_qty,
    NULL AS refund_ticket_qty,
    SUM(s.verify_ticket_qty) AS verify_ticket_qty,
    SUM(s.verify_amt) AS verify_amt
  FROM dws.dws_ord_tenant_sku_verify_rt s
  WHERE s.travel_date = DATE_FORMAT(CURDATE(), '%Y%m%d')
  GROUP BY s.travel_date, s.seller_tenant_id
) u
GROUP BY u.travel_date, u.seller_tenant_id
) x
LEFT JOIN dim.dim_sup_tenant_zip d1 ON d1.tenant_id = x.seller_tenant_id AND d1.end_date = '9999-12-31';
