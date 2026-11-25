-- ads.ads_inv_realtime_stock_rt  实时库存看板（对应 DP09）
-- 粒度：sku_id × pool_no
-- 来源：dws_inv_sku_stock_rt
-- 生成方式：StarRocks 异步物化视图（每分钟刷新）；字段 11 个：直接翻译 5 · 规则翻译 6 · 待确认 0

CREATE MATERIALIZED VIEW IF NOT EXISTS ads.ads_inv_realtime_stock_rt
REFRESH ASYNC EVERY (INTERVAL 1 MINUTE)
AS
SELECT
  x.travel_date,
  x.sku_id,
  x.pool_no,
  d1.sku_name AS sku_name,
  x.stock_available_now_qty,
  x.stock_frozen_now_qty,
  x.stock_sell_through_now_rate,
  x.sellout_pool_now_qty,
  x.prededuct_5m_qty,
  x.prededuct_release_5m_qty,
  x.update_time
FROM (
SELECT
  u.travel_date,
  u.sku_id,
  u.pool_no,
  SUM(u.stock_available_qty) AS stock_available_now_qty,
  SUM(u.stock_frozen_qty) AS stock_frozen_now_qty,
  SUM(u.stock_sold_qty) * 100 / NULLIF(SUM(u.stock_total_qty), 0) AS stock_sell_through_now_rate,
  SUM(u.sellout_pool_qty) AS sellout_pool_now_qty,
  SUM(u.prededuct_qty) AS prededuct_5m_qty,
  SUM(u.prededuct_release_qty) AS prededuct_release_5m_qty,
  NOW() AS update_time
FROM (
  -- 来源：dws_inv_sku_stock_rt
  SELECT
    s.travel_date AS travel_date,
    s.sku_id AS sku_id,
    s.pool_no AS pool_no,
    SUM(s.stock_available_qty) AS stock_available_qty,
    SUM(s.stock_frozen_qty) AS stock_frozen_qty,
    SUM(s.stock_sold_qty) AS stock_sold_qty,
    SUM(s.stock_total_qty) AS stock_total_qty,
    SUM(s.sellout_pool_qty) AS sellout_pool_qty,
    SUM(CASE WHEN s.window_start_time >= NOW() - INTERVAL 5 MINUTE THEN s.prededuct_qty END) AS prededuct_qty,
    SUM(CASE WHEN s.window_start_time >= NOW() - INTERVAL 5 MINUTE THEN s.prededuct_release_qty END) AS prededuct_release_qty
  FROM dws.dws_inv_sku_stock_rt s
  WHERE s.travel_date = DATE_FORMAT(CURDATE(), '%Y%m%d')
  GROUP BY s.travel_date, s.sku_id, s.pool_no
) u
GROUP BY u.travel_date, u.sku_id, u.pool_no
) x
LEFT JOIN dim.dim_prd_sku_zip d1 ON d1.sku_id = x.sku_id AND d1.end_date = '9999-12-31';
