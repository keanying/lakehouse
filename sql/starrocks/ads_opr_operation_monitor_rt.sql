-- ads.ads_opr_operation_monitor_rt  运营实时监控
-- 粒度：tenant_id × 今日
-- 来源：dws_opr_device_rt, dws_opr_notify_rt, dws_opr_complaint_rt, dws_opr_code_pool_rt
-- 生成方式：StarRocks 异步物化视图（每分钟刷新）；字段 15 个：直接翻译 4 · 规则翻译 11 · 待确认 0
-- 多来源：各来源按粒度键汇总后 UNION ALL 合并，再按公式计算

CREATE MATERIALIZED VIEW IF NOT EXISTS ads.ads_opr_operation_monitor_rt
REFRESH ASYNC EVERY (INTERVAL 1 MINUTE)
AS
SELECT
  x.travel_date,
  x.tenant_id,
  d1.tenant_name AS tenant_name,
  x.offline_times_today_qty,
  x.notify_send_today_qty,
  x.notify_fail_today_qty,
  x.notify_success_today_rate,
  x.complaint_today_qty,
  x.complaint_overdue_today_qty,
  x.complaint_sla_today_rate,
  x.device_total_now_qty,
  x.code_capacity_now_qty,
  x.code_allocated_now_qty,
  x.code_pool_usage_now_rate,
  x.update_time
FROM (
SELECT
  u.travel_date,
  u.tenant_id,
  SUM(u.offline_times_qty) AS offline_times_today_qty,
  SUM(u.notify_send_qty) AS notify_send_today_qty,
  SUM(u.notify_fail_qty) AS notify_fail_today_qty,
  SUM(u.notify_success_qty) * 100 / NULLIF(SUM(u.notify_send_qty), 0) AS notify_success_today_rate,
  SUM(u.complaint_qty) AS complaint_today_qty,
  SUM(u.complaint_overdue_qty) AS complaint_overdue_today_qty,
  (SUM(u.complaint_qty) - SUM(u.complaint_overdue_qty)) * 100 / NULLIF(SUM(u.complaint_qty), 0) AS complaint_sla_today_rate,
  SUM(u.device_total_qty) AS device_total_now_qty,
  SUM(u.code_capacity_qty) AS code_capacity_now_qty,
  SUM(u.code_allocated_qty) AS code_allocated_now_qty,
  SUM(u.code_allocated_qty) * 100 / NULLIF(SUM(u.code_capacity_qty), 0) AS code_pool_usage_now_rate,
  NOW() AS update_time
FROM (
  -- 来源：dws_opr_device_rt
  SELECT
    s.travel_date AS travel_date,
    s.tenant_id AS tenant_id,
    SUM(s.offline_times_qty) AS offline_times_qty,
    NULL AS notify_send_qty,
    NULL AS notify_fail_qty,
    NULL AS notify_success_qty,
    NULL AS complaint_qty,
    NULL AS complaint_overdue_qty,
    SUM(s.device_total_qty) AS device_total_qty,
    NULL AS code_capacity_qty,
    NULL AS code_allocated_qty
  FROM dws.dws_opr_device_rt s
  WHERE s.travel_date = DATE_FORMAT(CURDATE(), '%Y%m%d')
  GROUP BY s.travel_date, s.tenant_id
  UNION ALL
  -- 来源：dws_opr_notify_rt
  SELECT
    s.travel_date AS travel_date,
    s.tenant_id AS tenant_id,
    NULL AS offline_times_qty,
    SUM(s.notify_send_qty) AS notify_send_qty,
    SUM(s.notify_fail_qty) AS notify_fail_qty,
    SUM(s.notify_success_qty) AS notify_success_qty,
    NULL AS complaint_qty,
    NULL AS complaint_overdue_qty,
    NULL AS device_total_qty,
    NULL AS code_capacity_qty,
    NULL AS code_allocated_qty
  FROM dws.dws_opr_notify_rt s
  WHERE s.travel_date = DATE_FORMAT(CURDATE(), '%Y%m%d')
  GROUP BY s.travel_date, s.tenant_id
  UNION ALL
  -- 来源：dws_opr_complaint_rt
  SELECT
    s.travel_date AS travel_date,
    s.tenant_id AS tenant_id,
    NULL AS offline_times_qty,
    NULL AS notify_send_qty,
    NULL AS notify_fail_qty,
    NULL AS notify_success_qty,
    SUM(s.complaint_qty) AS complaint_qty,
    SUM(s.complaint_overdue_qty) AS complaint_overdue_qty,
    NULL AS device_total_qty,
    NULL AS code_capacity_qty,
    NULL AS code_allocated_qty
  FROM dws.dws_opr_complaint_rt s
  WHERE s.travel_date = DATE_FORMAT(CURDATE(), '%Y%m%d')
  GROUP BY s.travel_date, s.tenant_id
  UNION ALL
  -- 来源：dws_opr_code_pool_rt
  SELECT
    s.travel_date AS travel_date,
    s.tenant_id AS tenant_id,
    NULL AS offline_times_qty,
    NULL AS notify_send_qty,
    NULL AS notify_fail_qty,
    NULL AS notify_success_qty,
    NULL AS complaint_qty,
    NULL AS complaint_overdue_qty,
    NULL AS device_total_qty,
    SUM(s.code_capacity_qty) AS code_capacity_qty,
    SUM(s.code_allocated_qty) AS code_allocated_qty
  FROM dws.dws_opr_code_pool_rt s
  WHERE s.travel_date = DATE_FORMAT(CURDATE(), '%Y%m%d')
  GROUP BY s.travel_date, s.tenant_id
) u
GROUP BY u.travel_date, u.tenant_id
) x
LEFT JOIN dim.dim_sup_tenant_zip d1 ON d1.tenant_id = x.tenant_id AND d1.end_date = '9999-12-31';
