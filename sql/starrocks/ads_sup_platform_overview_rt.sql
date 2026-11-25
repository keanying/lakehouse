-- ads.ads_sup_platform_overview_rt  平台实时大盘
-- 粒度：全平台 × 今日
-- 来源：dws_ord_tenant_sku_trade_rt, dws_ord_tenant_sku_verify_rt, dws_cus_tenant_growth_rt
-- 生成方式：StarRocks 异步物化视图（每分钟刷新）；字段 14 个：直接翻译 2 · 规则翻译 12 · 待确认 0
-- 多来源：各来源按粒度键汇总后 UNION ALL 合并，再按公式计算

CREATE MATERIALIZED VIEW IF NOT EXISTS ads.ads_sup_platform_overview_rt
REFRESH ASYNC EVERY (INTERVAL 1 MINUTE)
AS
SELECT
  u.travel_date,
  SUM(u.pay_amt) AS pay_today_amt,
  SUM(u.pay_amt_1) AS pay_1h_amt,
  SUM(u.pay_order_qty) AS pay_order_today_qty,
  SUM(u.pay_order_qty_1) AS pay_order_1h_qty,
  SUM(u.pay_buyer_qty) AS pay_buyer_today_qty,
  SUM(u.pay_buyer_qty_1) AS pay_buyer_1h_qty,
  SUM(u.refund_amt) AS refund_today_amt,
  SUM(u.refund_amt_1) AS refund_1h_amt,
  SUM(u.verify_ticket_qty) AS verify_ticket_today_qty,
  SUM(u.verify_ticket_qty_1) AS verify_ticket_1h_qty,
  SUM(u.new_customer_qty) AS new_customer_today_qty,
  SUM(u.new_customer_qty_1) AS new_customer_1h_qty,
  NOW() AS update_time
FROM (
  -- 来源：dws_ord_tenant_sku_trade_rt
  SELECT
    s.travel_date AS travel_date,
    SUM(s.pay_amt) AS pay_amt,
    SUM(CASE WHEN s.window_start_time >= NOW() - INTERVAL 1 HOUR THEN s.pay_amt END) AS pay_amt_1,
    SUM(s.pay_order_qty) AS pay_order_qty,
    SUM(CASE WHEN s.window_start_time >= NOW() - INTERVAL 1 HOUR THEN s.pay_order_qty END) AS pay_order_qty_1,
    SUM(s.pay_buyer_qty) AS pay_buyer_qty,
    SUM(CASE WHEN s.window_start_time >= NOW() - INTERVAL 1 HOUR THEN s.pay_buyer_qty END) AS pay_buyer_qty_1,
    SUM(s.refund_amt) AS refund_amt,
    SUM(CASE WHEN s.window_start_time >= NOW() - INTERVAL 1 HOUR THEN s.refund_amt END) AS refund_amt_1,
    NULL AS verify_ticket_qty,
    NULL AS verify_ticket_qty_1,
    NULL AS new_customer_qty,
    NULL AS new_customer_qty_1
  FROM dws.dws_ord_tenant_sku_trade_rt s
  WHERE s.travel_date = DATE_FORMAT(CURDATE(), '%Y%m%d')
  GROUP BY s.travel_date
  UNION ALL
  -- 来源：dws_ord_tenant_sku_verify_rt
  SELECT
    s.travel_date AS travel_date,
    NULL AS pay_amt,
    NULL AS pay_amt_1,
    NULL AS pay_order_qty,
    NULL AS pay_order_qty_1,
    NULL AS pay_buyer_qty,
    NULL AS pay_buyer_qty_1,
    NULL AS refund_amt,
    NULL AS refund_amt_1,
    SUM(s.verify_ticket_qty) AS verify_ticket_qty,
    SUM(CASE WHEN s.window_start_time >= NOW() - INTERVAL 1 HOUR THEN s.verify_ticket_qty END) AS verify_ticket_qty_1,
    NULL AS new_customer_qty,
    NULL AS new_customer_qty_1
  FROM dws.dws_ord_tenant_sku_verify_rt s
  WHERE s.travel_date = DATE_FORMAT(CURDATE(), '%Y%m%d')
  GROUP BY s.travel_date
  UNION ALL
  -- 来源：dws_cus_tenant_growth_rt
  SELECT
    s.travel_date AS travel_date,
    NULL AS pay_amt,
    NULL AS pay_amt_1,
    NULL AS pay_order_qty,
    NULL AS pay_order_qty_1,
    NULL AS pay_buyer_qty,
    NULL AS pay_buyer_qty_1,
    NULL AS refund_amt,
    NULL AS refund_amt_1,
    NULL AS verify_ticket_qty,
    NULL AS verify_ticket_qty_1,
    SUM(s.new_customer_qty) AS new_customer_qty,
    SUM(CASE WHEN s.window_start_time >= NOW() - INTERVAL 1 HOUR THEN s.new_customer_qty END) AS new_customer_qty_1
  FROM dws.dws_cus_tenant_growth_rt s
  WHERE s.travel_date = DATE_FORMAT(CURDATE(), '%Y%m%d')
  GROUP BY s.travel_date
) u
GROUP BY u.travel_date;
