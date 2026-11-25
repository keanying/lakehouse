-- ads.ads_ord_realtime_flow_rt  实时客流大屏
-- 粒度：tenant_id × verify_point_id × 窗口
-- 来源：dws_ord_verify_point_flow_rt
-- 生成方式：StarRocks 异步物化视图（每分钟刷新）；字段 17 个：直接翻译 8 · 规则翻译 9 · 待确认 0

CREATE MATERIALIZED VIEW IF NOT EXISTS ads.ads_ord_realtime_flow_rt
REFRESH ASYNC EVERY (INTERVAL 1 MINUTE)
AS
SELECT
  x.travel_date,
  x.window_start_time,
  x.window_end_time,
  x.tenant_id,
  x.verify_point_id,
  d1.tenant_name AS tenant_name,
  d2.verify_point_name AS verify_point_name,
  x.verify_person_today_qty,
  x.verify_person_1h_qty,
  x.verify_person_5m_qty,
  x.verify_fail_today_qty,
  x.verify_fail_1h_qty,
  x.verify_fail_5m_qty,
  x.verify_fail_today_rate,
  x.verify_fail_1h_rate,
  x.verify_fail_5m_rate,
  x.update_time
FROM (
SELECT
  u.travel_date,
  u.window_start_time,
  u.window_end_time,
  u.tenant_id,
  u.verify_point_id,
  SUM(u.verify_person_qty) AS verify_person_today_qty,
  SUM(u.verify_person_qty_1) AS verify_person_1h_qty,
  SUM(u.verify_person_qty_2) AS verify_person_5m_qty,
  SUM(u.verify_fail_qty) AS verify_fail_today_qty,
  SUM(u.verify_fail_qty_1) AS verify_fail_1h_qty,
  SUM(u.verify_fail_qty_2) AS verify_fail_5m_qty,
  SUM(u.verify_fail_qty) * 100 / NULLIF(SUM(u.verify_entitlement_qty), 0) AS verify_fail_today_rate,
  SUM(u.verify_fail_qty_1) * 100 / NULLIF(SUM(u.verify_entitlement_qty_1), 0) AS verify_fail_1h_rate,
  SUM(u.verify_fail_qty_2) * 100 / NULLIF(SUM(u.verify_entitlement_qty_2), 0) AS verify_fail_5m_rate,
  NOW() AS update_time
FROM (
  -- 来源：dws_ord_verify_point_flow_rt
  SELECT
    s.travel_date AS travel_date,
    s.window_start_time AS window_start_time,
    s.window_end_time AS window_end_time,
    s.seller_tenant_id AS tenant_id,
    s.verify_point_id AS verify_point_id,
    SUM(s.verify_person_qty) AS verify_person_qty,
    SUM(CASE WHEN s.window_start_time >= NOW() - INTERVAL 1 HOUR THEN s.verify_person_qty END) AS verify_person_qty_1,
    SUM(CASE WHEN s.window_start_time >= NOW() - INTERVAL 5 MINUTE THEN s.verify_person_qty END) AS verify_person_qty_2,
    SUM(s.verify_fail_qty) AS verify_fail_qty,
    SUM(CASE WHEN s.window_start_time >= NOW() - INTERVAL 1 HOUR THEN s.verify_fail_qty END) AS verify_fail_qty_1,
    SUM(CASE WHEN s.window_start_time >= NOW() - INTERVAL 5 MINUTE THEN s.verify_fail_qty END) AS verify_fail_qty_2,
    SUM(s.verify_entitlement_qty) AS verify_entitlement_qty,
    SUM(CASE WHEN s.window_start_time >= NOW() - INTERVAL 1 HOUR THEN s.verify_entitlement_qty END) AS verify_entitlement_qty_1,
    SUM(CASE WHEN s.window_start_time >= NOW() - INTERVAL 5 MINUTE THEN s.verify_entitlement_qty END) AS verify_entitlement_qty_2
  FROM dws.dws_ord_verify_point_flow_rt s
  WHERE s.travel_date = DATE_FORMAT(CURDATE(), '%Y%m%d')
  GROUP BY s.travel_date, s.window_start_time, s.window_end_time, s.seller_tenant_id, s.verify_point_id
) u
GROUP BY u.travel_date, u.window_start_time, u.window_end_time, u.tenant_id, u.verify_point_id
) x
LEFT JOIN dim.dim_sup_tenant_zip d1 ON d1.tenant_id = x.tenant_id AND d1.end_date = '9999-12-31'
LEFT JOIN dim.dim_opr_verify_point_df d2 ON d2.verify_point_id = x.verify_point_id;
