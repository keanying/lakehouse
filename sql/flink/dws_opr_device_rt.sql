-- dws.dws_opr_device_rt  设备实时状态
-- 粒度：tenant_id × device_id
-- 来源：dwd_opr_device_status_log_rt
-- 生成方式：Flink SQL（1 分钟滚动窗口聚合 → StarRocks 主键模型表）；字段 5 个：直接翻译 3 · 规则翻译 2 · 待确认 0

INSERT INTO dws.dws_opr_device_rt
SELECT
  u.window_start_time,
  u.window_end_time,
  u.travel_date,
  u.tenant_id,
  u.device_id,
  SUM(u.offline_times_qty) AS offline_times_qty,
  SUM(u.device_total_qty) AS device_total_qty,
  CURRENT_TIMESTAMP AS update_time
FROM (
  -- 来源：dwd_opr_device_status_log_rt
  SELECT
    window_start AS window_start_time,
    window_end AS window_end_time,
    travel_date AS travel_date,
    tenant_id AS tenant_id,
    device_id AS device_id,
    COUNT(CASE WHEN after_status='OFFLINE' THEN 1 END) AS offline_times_qty,
    COUNT(device_id) AS device_total_qty
  FROM TABLE(TUMBLE(TABLE dwd.dwd_opr_device_status_log_rt, DESCRIPTOR(event_time), INTERVAL '1' MINUTE)) s
  GROUP BY window_start, window_end, travel_date, tenant_id, device_id
) u
GROUP BY u.window_start_time, u.window_end_time, u.travel_date, u.tenant_id, u.device_id;
