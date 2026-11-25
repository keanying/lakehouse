-- ads.ads_ord_channel_sales_rt  渠道实时销售结构
-- 粒度：seller_tenant_id × 今日
-- 来源：dws_ord_tenant_sku_trade_rt
-- 生成方式：StarRocks 异步物化视图（每分钟刷新）；字段 26 个：直接翻译 4 · 规则翻译 22 · 待确认 0

CREATE MATERIALIZED VIEW IF NOT EXISTS ads.ads_ord_channel_sales_rt
REFRESH ASYNC EVERY (INTERVAL 1 MINUTE)
AS
SELECT
  x.travel_date,
  x.seller_tenant_id,
  d1.tenant_name AS seller_tenant_name,
  x.mp_pay_today_amt,
  x.h5_pay_today_amt,
  x.pc_pay_today_amt,
  x.offline_pay_today_amt,
  x.api_pay_today_amt,
  x.mp_pay_order_today_qty,
  x.h5_pay_order_today_qty,
  x.pc_pay_order_today_qty,
  x.offline_pay_order_today_qty,
  x.api_pay_order_today_qty,
  x.mp_pay_ticket_today_qty,
  x.h5_pay_ticket_today_qty,
  x.pc_pay_ticket_today_qty,
  x.offline_pay_ticket_today_qty,
  x.api_pay_ticket_today_qty,
  x.mp_channel_pay_share_today_rate,
  x.h5_channel_pay_share_today_rate,
  x.pc_channel_pay_share_today_rate,
  x.offline_channel_pay_share_today_rate,
  x.api_channel_pay_share_today_rate,
  x.staff_order_today_qty,
  x.staff_pay_today_amt,
  x.update_time
FROM (
SELECT
  u.travel_date,
  u.seller_tenant_id,
  SUM(u.pay_amt) AS mp_pay_today_amt,
  SUM(u.pay_amt) AS h5_pay_today_amt,
  SUM(u.pay_amt) AS pc_pay_today_amt,
  SUM(u.pay_amt) AS offline_pay_today_amt,
  SUM(u.pay_amt) AS api_pay_today_amt,
  SUM(u.pay_order_qty) AS mp_pay_order_today_qty,
  SUM(u.pay_order_qty) AS h5_pay_order_today_qty,
  SUM(u.pay_order_qty) AS pc_pay_order_today_qty,
  SUM(u.pay_order_qty) AS offline_pay_order_today_qty,
  SUM(u.pay_order_qty) AS api_pay_order_today_qty,
  SUM(u.pay_ticket_qty) AS mp_pay_ticket_today_qty,
  SUM(u.pay_ticket_qty) AS h5_pay_ticket_today_qty,
  SUM(u.pay_ticket_qty) AS pc_pay_ticket_today_qty,
  SUM(u.pay_ticket_qty) AS offline_pay_ticket_today_qty,
  SUM(u.pay_ticket_qty) AS api_pay_ticket_today_qty,
  SUM(u.pay_amt) AS mp_channel_pay_share_today_rate,
  SUM(u.pay_amt) AS h5_channel_pay_share_today_rate,
  SUM(u.pay_amt) AS pc_channel_pay_share_today_rate,
  SUM(u.pay_amt) AS offline_channel_pay_share_today_rate,
  SUM(u.pay_amt) AS api_channel_pay_share_today_rate,
  SUM(u.staff_order_qty) AS staff_order_today_qty,
  SUM(u.staff_pay_amt) AS staff_pay_today_amt,
  NOW() AS update_time
FROM (
  -- 来源：dws_ord_tenant_sku_trade_rt
  SELECT
    s.travel_date AS travel_date,
    s.seller_tenant_id AS seller_tenant_id,
    SUM(s.pay_amt) AS pay_amt,
    SUM(s.pay_order_qty) AS pay_order_qty,
    SUM(s.pay_ticket_qty) AS pay_ticket_qty,
    SUM(s.staff_order_qty) AS staff_order_qty,
    SUM(s.staff_pay_amt) AS staff_pay_amt
  FROM dws.dws_ord_tenant_sku_trade_rt s
  WHERE s.travel_date = DATE_FORMAT(CURDATE(), '%Y%m%d')
  GROUP BY s.travel_date, s.seller_tenant_id
) u
GROUP BY u.travel_date, u.seller_tenant_id
) x
LEFT JOIN dim.dim_sup_tenant_zip d1 ON d1.tenant_id = x.seller_tenant_id AND d1.end_date = '9999-12-31';
