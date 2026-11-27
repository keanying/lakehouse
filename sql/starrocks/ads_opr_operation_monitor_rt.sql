-- ads.ads_opr_operation_monitor_rt  运营实时监控
-- 粒度：tenant_id × 今日
-- 来源：dws_opr_device_rt, dws_opr_notify_rt, dws_opr_complaint_rt, dws_opr_code_pool_rt
-- 生成方式：StarRocks 异步物化视图（每分钟刷新）；字段 15 个：直接翻译 4 · 规则翻译 11 · 待确认 0
-- 多来源：各来源按粒度键预聚合后 UNION ALL 合并，再按公式计算
-- 补 0 / 补空列：多来源 UNION ALL 时，某来源不产出的指标补 0 或空，外层按粒度 SUM 后即为各来源之和，不影响结果

CREATE MATERIALIZED VIEW IF NOT EXISTS ads.ads_opr_operation_monitor_rt  -- 异步物化视图，StarRocks 定时刷新
REFRESH ASYNC EVERY (INTERVAL 1 MINUTE)
AS
WITH
src_device AS (                                       -- 来源「设备实时状态」按粒度键预聚合
  SELECT
    s.travel_date AS travel_date,                     -- 数据日期
    s.tenant_id AS tenant_id,                         -- 租户ID
    SUM(s.offline_times_qty) AS offline_times_qty,    -- 设备离线次数
    NULL AS notify_send_qty,                          -- 通知发送数：此来源不产出，补空
    NULL AS notify_fail_qty,                          -- 通知失败数：此来源不产出，补空
    NULL AS notify_success_qty,                       -- 通知成功数：此来源不产出，补空
    NULL AS complaint_qty,                            -- 投诉数：此来源不产出，补空
    NULL AS complaint_overdue_qty,                    -- 投诉超SLA数：此来源不产出，补空
    SUM(s.device_total_qty) AS device_total_qty,      -- 设备数
    NULL AS code_capacity_qty,                        -- 码池容量：此来源不产出，补空
    NULL AS code_allocated_qty                        -- 已分配码数：此来源不产出，补空
  FROM dws.dws_opr_device_rt s                        -- 来源表「设备实时状态」
  WHERE s.travel_date = DATE_FORMAT(CURDATE(), '%Y%m%d')  -- 只取今日数据
  GROUP BY s.travel_date, s.tenant_id                 -- 按粒度键汇总
),
src_notify AS (                                       -- 来源「通知实时发送」按粒度键预聚合
  SELECT
    s.travel_date AS travel_date,                     -- 数据日期
    s.tenant_id AS tenant_id,                         -- 租户ID
    NULL AS offline_times_qty,                        -- 设备离线次数：此来源不产出，补空
    SUM(s.notify_send_qty) AS notify_send_qty,        -- 通知发送数
    SUM(s.notify_fail_qty) AS notify_fail_qty,        -- 通知失败数
    SUM(s.notify_success_qty) AS notify_success_qty,  -- 通知成功数
    NULL AS complaint_qty,                            -- 投诉数：此来源不产出，补空
    NULL AS complaint_overdue_qty,                    -- 投诉超SLA数：此来源不产出，补空
    NULL AS device_total_qty,                         -- 设备数：此来源不产出，补空
    NULL AS code_capacity_qty,                        -- 码池容量：此来源不产出，补空
    NULL AS code_allocated_qty                        -- 已分配码数：此来源不产出，补空
  FROM dws.dws_opr_notify_rt s                        -- 来源表「通知实时发送」
  WHERE s.travel_date = DATE_FORMAT(CURDATE(), '%Y%m%d')  -- 只取今日数据
  GROUP BY s.travel_date, s.tenant_id                 -- 按粒度键汇总
),
src_complaint AS (                                    -- 来源「投诉实时处理」按粒度键预聚合
  SELECT
    s.travel_date AS travel_date,                     -- 数据日期
    s.tenant_id AS tenant_id,                         -- 租户ID
    NULL AS offline_times_qty,                        -- 设备离线次数：此来源不产出，补空
    NULL AS notify_send_qty,                          -- 通知发送数：此来源不产出，补空
    NULL AS notify_fail_qty,                          -- 通知失败数：此来源不产出，补空
    NULL AS notify_success_qty,                       -- 通知成功数：此来源不产出，补空
    SUM(s.complaint_qty) AS complaint_qty,            -- 投诉数
    SUM(s.complaint_overdue_qty) AS complaint_overdue_qty,  -- 投诉超SLA数
    NULL AS device_total_qty,                         -- 设备数：此来源不产出，补空
    NULL AS code_capacity_qty,                        -- 码池容量：此来源不产出，补空
    NULL AS code_allocated_qty                        -- 已分配码数：此来源不产出，补空
  FROM dws.dws_opr_complaint_rt s                     -- 来源表「投诉实时处理」
  WHERE s.travel_date = DATE_FORMAT(CURDATE(), '%Y%m%d')  -- 只取今日数据
  GROUP BY s.travel_date, s.tenant_id                 -- 按粒度键汇总
),
src_code_pool AS (                                    -- 来源「码池实时余量」按粒度键预聚合
  SELECT
    s.travel_date AS travel_date,                     -- 数据日期
    s.tenant_id AS tenant_id,                         -- 租户ID
    NULL AS offline_times_qty,                        -- 设备离线次数：此来源不产出，补空
    NULL AS notify_send_qty,                          -- 通知发送数：此来源不产出，补空
    NULL AS notify_fail_qty,                          -- 通知失败数：此来源不产出，补空
    NULL AS notify_success_qty,                       -- 通知成功数：此来源不产出，补空
    NULL AS complaint_qty,                            -- 投诉数：此来源不产出，补空
    NULL AS complaint_overdue_qty,                    -- 投诉超SLA数：此来源不产出，补空
    NULL AS device_total_qty,                         -- 设备数：此来源不产出，补空
    SUM(s.code_capacity_qty) AS code_capacity_qty,    -- 码池容量
    SUM(s.code_allocated_qty) AS code_allocated_qty   -- 已分配码数
  FROM dws.dws_opr_code_pool_rt s                     -- 来源表「码池实时余量」
  WHERE s.travel_date = DATE_FORMAT(CURDATE(), '%Y%m%d')  -- 只取今日数据
  GROUP BY s.travel_date, s.tenant_id                 -- 按粒度键汇总
),
all_src AS (                                          -- 各来源字段已对齐，UNION ALL 合并（比多表 FULL JOIN 少 shuffle）
  SELECT * FROM src_device
  UNION ALL
  SELECT * FROM src_notify
  UNION ALL
  SELECT * FROM src_complaint
  UNION ALL
  SELECT * FROM src_code_pool
),
merged AS (                                           -- 按粒度键汇总，计算派生指标
  SELECT
    u.travel_date,                                    -- 数据日期
    u.tenant_id,                                      -- 租户ID
    SUM(u.offline_times_qty) AS offline_times_today_qty,  -- 今日实时设备离线次数
    SUM(u.notify_send_qty) AS notify_send_today_qty,  -- 今日实时通知发送数
    SUM(u.notify_fail_qty) AS notify_fail_today_qty,  -- 今日实时通知失败数
    SUM(u.notify_success_qty) * 100 / NULLIF(SUM(u.notify_send_qty), 0) AS notify_success_today_rate,  -- 今日实时通知成功率
    SUM(u.complaint_qty) AS complaint_today_qty,      -- 今日实时投诉数
    SUM(u.complaint_overdue_qty) AS complaint_overdue_today_qty,  -- 今日实时投诉超SLA数
    (SUM(u.complaint_qty) - SUM(u.complaint_overdue_qty)) * 100 / NULLIF(SUM(u.complaint_qty), 0) AS complaint_sla_today_rate,  -- 今日实时投诉SLA达成率
    SUM(u.device_total_qty) AS device_total_now_qty,  -- 当前设备数
    SUM(u.code_capacity_qty) AS code_capacity_now_qty,  -- 当前码池容量
    SUM(u.code_allocated_qty) AS code_allocated_now_qty,  -- 当前已分配码数
    SUM(u.code_allocated_qty) * 100 / NULLIF(SUM(u.code_capacity_qty), 0) AS code_pool_usage_now_rate,  -- 当前码池使用率
    NOW() AS update_time                              -- 最近一次写入时间
  FROM all_src u
  GROUP BY u.travel_date, u.tenant_id                 -- 按粒度键汇总
),
tenant_cur AS (                                       -- 「租户（商户/供应商/分销商）维度」当前有效版本，只取名称类字段
  SELECT tenant_id, tenant_name
  FROM dim.dim_sup_tenant_zip
  WHERE end_date = '9999-12-31'                       -- 只取拉链当前有效版本
)
SELECT
  merged.travel_date,                                 -- 数据日期
  merged.tenant_id,                                   -- 租户ID
  tenant_cur.tenant_name AS tenant_name,              -- 租户名称
  merged.offline_times_today_qty,                     -- 今日实时设备离线次数
  merged.notify_send_today_qty,                       -- 今日实时通知发送数
  merged.notify_fail_today_qty,                       -- 今日实时通知失败数
  merged.notify_success_today_rate,                   -- 今日实时通知成功率
  merged.complaint_today_qty,                         -- 今日实时投诉数
  merged.complaint_overdue_today_qty,                 -- 今日实时投诉超SLA数
  merged.complaint_sla_today_rate,                    -- 今日实时投诉SLA达成率
  merged.device_total_now_qty,                        -- 当前设备数
  merged.code_capacity_now_qty,                       -- 当前码池容量
  merged.code_allocated_now_qty,                      -- 当前已分配码数
  merged.code_pool_usage_now_rate,                    -- 当前码池使用率
  merged.update_time                                  -- 最近一次写入时间
FROM merged
LEFT JOIN tenant_cur                                  -- 关联「租户（商户/供应商/分销商）维度」，补 tenant_name
  ON tenant_cur.tenant_id = merged.tenant_id;         -- 按 tenant_id 关联
