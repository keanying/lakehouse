-- ads.ads_ord_realtime_sales_rt  实时销售看板（对应 DP08）
-- 粒度：seller_tenant_id × 窗口
-- 来源：dws_ord_tenant_sku_trade_rt
-- 生成方式：StarRocks 异步物化视图（每分钟刷新）；字段 24 个：直接翻译 6 · 规则翻译 18 · 待确认 0

CREATE MATERIALIZED VIEW IF NOT EXISTS ads.ads_ord_realtime_sales_rt
REFRESH ASYNC EVERY (INTERVAL 1 MINUTE)
AS
SELECT
  x.travel_date,
  x.window_start_time,
  x.window_end_time,
  x.seller_tenant_id,
  d1.tenant_name AS seller_tenant_name,
  x.pay_today_amt,
  x.pay_1h_amt,
  x.pay_5m_amt,
  x.pay_order_today_qty,
  x.pay_order_1h_qty,
  x.pay_order_5m_qty,
  x.pay_ticket_today_qty,
  x.pay_ticket_1h_qty,
  x.pay_ticket_5m_qty,
  x.pay_buyer_today_qty,
  x.pay_buyer_1h_qty,
  x.pay_buyer_5m_qty,
  x.refund_today_amt,
  x.refund_1h_amt,
  x.refund_5m_amt,
  x.avg_ticket_price_today_amt,
  x.avg_ticket_price_1h_amt,
  x.avg_ticket_price_5m_amt,
  x.update_time
FROM (
SELECT
  u.travel_date,
  u.window_start_time,
  u.window_end_time,
  u.seller_tenant_id,
  SUM(u.pay_amt) AS pay_today_amt,
  SUM(u.pay_amt_1) AS pay_1h_amt,
  SUM(u.pay_amt_2) AS pay_5m_amt,
  SUM(u.pay_order_qty) AS pay_order_today_qty,
  SUM(u.pay_order_qty_1) AS pay_order_1h_qty,
  SUM(u.pay_order_qty_2) AS pay_order_5m_qty,
  SUM(u.pay_ticket_qty) AS pay_ticket_today_qty,
  SUM(u.pay_ticket_qty_1) AS pay_ticket_1h_qty,
  SUM(u.pay_ticket_qty_2) AS pay_ticket_5m_qty,
  SUM(u.pay_buyer_qty) AS pay_buyer_today_qty,
  SUM(u.pay_buyer_qty_1) AS pay_buyer_1h_qty,
  SUM(u.pay_buyer_qty_2) AS pay_buyer_5m_qty,
  SUM(u.refund_amt) AS refund_today_amt,
  SUM(u.refund_amt_1) AS refund_1h_amt,
  SUM(u.refund_amt_2) AS refund_5m_amt,
  SUM(u.pay_amt) / NULLIF(SUM(u.pay_ticket_qty), 0) AS avg_ticket_price_today_amt,
  SUM(u.pay_amt_1) / NULLIF(SUM(u.pay_ticket_qty_1), 0) AS avg_ticket_price_1h_amt,
  SUM(u.pay_amt_2) / NULLIF(SUM(u.pay_ticket_qty_2), 0) AS avg_ticket_price_5m_amt,
  NOW() AS update_time
FROM (
  -- 来源：dws_ord_tenant_sku_trade_rt
  SELECT
    s.travel_date AS travel_date,
    s.window_start_time AS window_start_time,
    s.window_end_time AS window_end_time,
    s.seller_tenant_id AS seller_tenant_id,
    SUM(s.pay_amt) AS pay_amt,
    SUM(CASE WHEN s.window_start_time >= NOW() - INTERVAL 1 HOUR THEN s.pay_amt END) AS pay_amt_1,
    SUM(CASE WHEN s.window_start_time >= NOW() - INTERVAL 5 MINUTE THEN s.pay_amt END) AS pay_amt_2,
    SUM(s.pay_order_qty) AS pay_order_qty,
    SUM(CASE WHEN s.window_start_time >= NOW() - INTERVAL 1 HOUR THEN s.pay_order_qty END) AS pay_order_qty_1,
    SUM(CASE WHEN s.window_start_time >= NOW() - INTERVAL 5 MINUTE THEN s.pay_order_qty END) AS pay_order_qty_2,
    SUM(s.pay_ticket_qty) AS pay_ticket_qty,
    SUM(CASE WHEN s.window_start_time >= NOW() - INTERVAL 1 HOUR THEN s.pay_ticket_qty END) AS pay_ticket_qty_1,
    SUM(CASE WHEN s.window_start_time >= NOW() - INTERVAL 5 MINUTE THEN s.pay_ticket_qty END) AS pay_ticket_qty_2,
    SUM(s.pay_buyer_qty) AS pay_buyer_qty,
    SUM(CASE WHEN s.window_start_time >= NOW() - INTERVAL 1 HOUR THEN s.pay_buyer_qty END) AS pay_buyer_qty_1,
    SUM(CASE WHEN s.window_start_time >= NOW() - INTERVAL 5 MINUTE THEN s.pay_buyer_qty END) AS pay_buyer_qty_2,
    SUM(s.refund_amt) AS refund_amt,
    SUM(CASE WHEN s.window_start_time >= NOW() - INTERVAL 1 HOUR THEN s.refund_amt END) AS refund_amt_1,
    SUM(CASE WHEN s.window_start_time >= NOW() - INTERVAL 5 MINUTE THEN s.refund_amt END) AS refund_amt_2
  FROM dws.dws_ord_tenant_sku_trade_rt s
  WHERE s.travel_date = DATE_FORMAT(CURDATE(), '%Y%m%d')
  GROUP BY s.travel_date, s.window_start_time, s.window_end_time, s.seller_tenant_id
) u
GROUP BY u.travel_date, u.window_start_time, u.window_end_time, u.seller_tenant_id
) x
LEFT JOIN dim.dim_sup_tenant_zip d1 ON d1.tenant_id = x.seller_tenant_id AND d1.end_date = '9999-12-31';
