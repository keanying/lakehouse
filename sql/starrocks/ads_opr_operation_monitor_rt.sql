-- ads.ads_opr_operation_monitor_rt  运营实时监控
-- 粒度：tenant_id × 今日
-- 来源：dws_opr_device_rt, dws_opr_notify_rt, dws_opr_complaint_rt, dws_opr_code_pool_rt
-- 生成方式：StarRocks 异步物化视图（每分钟刷新）；字段 15 个：直接翻译 4 · 规则翻译 11 · 待确认 0
-- 多来源：各来源按粒度键汇总后 UNION ALL 合并，再按公式计算

CREATE MATERIALIZED VIEW IF NOT EXISTS ads.ads_opr_operation_monitor_rt  -- 异步物化视图，StarRocks 定时刷新
REFRESH ASYNC EVERY (INTERVAL 1 MINUTE)
AS
SELECT
  x.travel_date,                                          -- 数据日期
  x.tenant_id,                                            -- 租户ID
  d1.tenant_name AS tenant_name,                          -- 租户名称
  x.offline_times_today_qty,                              -- 今日实时设备离线次数
  x.notify_send_today_qty,                                -- 今日实时通知发送数
  x.notify_fail_today_qty,                                -- 今日实时通知失败数
  x.notify_success_today_rate,                            -- 今日实时通知成功率
  x.complaint_today_qty,                                  -- 今日实时投诉数
  x.complaint_overdue_today_qty,                          -- 今日实时投诉超SLA数
  x.complaint_sla_today_rate,                             -- 今日实时投诉SLA达成率
  x.device_total_now_qty,                                 -- 当前设备数
  x.code_capacity_now_qty,                                -- 当前码池容量
  x.code_allocated_now_qty,                               -- 当前已分配码数
  x.code_pool_usage_now_rate,                             -- 当前码池使用率
  x.update_time                                           -- 最近一次写入时间
FROM (
SELECT
  u.travel_date,                                          -- 数据日期
  u.tenant_id,                                            -- 租户ID
  SUM(u.offline_times_qty) AS offline_times_today_qty,    -- 今日实时设备离线次数
  SUM(u.notify_send_qty) AS notify_send_today_qty,        -- 今日实时通知发送数
  SUM(u.notify_fail_qty) AS notify_fail_today_qty,        -- 今日实时通知失败数
  SUM(u.notify_success_qty) * 100 / NULLIF(SUM(u.notify_send_qty), 0) AS notify_success_today_rate,  -- 今日实时通知成功率
  SUM(u.complaint_qty) AS complaint_today_qty,            -- 今日实时投诉数
  SUM(u.complaint_overdue_qty) AS complaint_overdue_today_qty,  -- 今日实时投诉超SLA数
  (SUM(u.complaint_qty) - SUM(u.complaint_overdue_qty)) * 100 / NULLIF(SUM(u.complaint_qty), 0) AS complaint_sla_today_rate,  -- 今日实时投诉SLA达成率
  SUM(u.device_total_qty) AS device_total_now_qty,        -- 当前设备数
  SUM(u.code_capacity_qty) AS code_capacity_now_qty,      -- 当前码池容量
  SUM(u.code_allocated_qty) AS code_allocated_now_qty,    -- 当前已分配码数
  SUM(u.code_allocated_qty) * 100 / NULLIF(SUM(u.code_capacity_qty), 0) AS code_pool_usage_now_rate,  -- 当前码池使用率
  NOW() AS update_time                                    -- 最近一次写入时间
FROM (
  -- 来源：dws_opr_device_rt
  SELECT
    s.travel_date AS travel_date,                         -- 数据日期
    s.tenant_id AS tenant_id,                             -- 租户ID
    SUM(s.offline_times_qty) AS offline_times_qty,
    NULL AS notify_send_qty,
    NULL AS notify_fail_qty,
    NULL AS notify_success_qty,
    NULL AS complaint_qty,
    NULL AS complaint_overdue_qty,
    SUM(s.device_total_qty) AS device_total_qty,
    NULL AS code_capacity_qty,
    NULL AS code_allocated_qty
  FROM dws.dws_opr_device_rt s                            -- 来源表「设备实时状态」
  WHERE s.travel_date = DATE_FORMAT(CURDATE(), '%Y%m%d')  -- 只取今日数据
  GROUP BY s.travel_date, s.tenant_id                     -- 按粒度键汇总
  UNION ALL                                               -- 合并各来源
  -- 来源：dws_opr_notify_rt
  SELECT
    s.travel_date AS travel_date,                         -- 数据日期
    s.tenant_id AS tenant_id,                             -- 租户ID
    NULL AS offline_times_qty,
    SUM(s.notify_send_qty) AS notify_send_qty,
    SUM(s.notify_fail_qty) AS notify_fail_qty,
    SUM(s.notify_success_qty) AS notify_success_qty,
    NULL AS complaint_qty,
    NULL AS complaint_overdue_qty,
    NULL AS device_total_qty,
    NULL AS code_capacity_qty,
    NULL AS code_allocated_qty
  FROM dws.dws_opr_notify_rt s                            -- 来源表「通知实时发送」
  WHERE s.travel_date = DATE_FORMAT(CURDATE(), '%Y%m%d')  -- 只取今日数据
  GROUP BY s.travel_date, s.tenant_id                     -- 按粒度键汇总
  UNION ALL                                               -- 合并各来源
  -- 来源：dws_opr_complaint_rt
  SELECT
    s.travel_date AS travel_date,                         -- 数据日期
    s.tenant_id AS tenant_id,                             -- 租户ID
    NULL AS offline_times_qty,
    NULL AS notify_send_qty,
    NULL AS notify_fail_qty,
    NULL AS notify_success_qty,
    SUM(s.complaint_qty) AS complaint_qty,
    SUM(s.complaint_overdue_qty) AS complaint_overdue_qty,
    NULL AS device_total_qty,
    NULL AS code_capacity_qty,
    NULL AS code_allocated_qty
  FROM dws.dws_opr_complaint_rt s                         -- 来源表「投诉实时处理」
  WHERE s.travel_date = DATE_FORMAT(CURDATE(), '%Y%m%d')  -- 只取今日数据
  GROUP BY s.travel_date, s.tenant_id                     -- 按粒度键汇总
  UNION ALL                                               -- 合并各来源
  -- 来源：dws_opr_code_pool_rt
  SELECT
    s.travel_date AS travel_date,                         -- 数据日期
    s.tenant_id AS tenant_id,                             -- 租户ID
    NULL AS offline_times_qty,
    NULL AS notify_send_qty,
    NULL AS notify_fail_qty,
    NULL AS notify_success_qty,
    NULL AS complaint_qty,
    NULL AS complaint_overdue_qty,
    NULL AS device_total_qty,
    SUM(s.code_capacity_qty) AS code_capacity_qty,
    SUM(s.code_allocated_qty) AS code_allocated_qty
  FROM dws.dws_opr_code_pool_rt s                         -- 来源表「码池实时余量」
  WHERE s.travel_date = DATE_FORMAT(CURDATE(), '%Y%m%d')  -- 只取今日数据
  GROUP BY s.travel_date, s.tenant_id                     -- 按粒度键汇总
) u                                                       -- 各来源合并后的明细
GROUP BY u.travel_date, u.tenant_id                       -- 按粒度键汇总
) x                                                       -- 汇总结果，外层再补维度名称
LEFT JOIN dim.dim_sup_tenant_zip d1 ON d1.tenant_id = x.tenant_id AND d1.end_date = '9999-12-31';  -- 关联「租户（商户/供应商/分销商）维度」，取维度名称
