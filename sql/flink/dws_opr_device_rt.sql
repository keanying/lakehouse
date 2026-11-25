-- dws.dws_opr_device_rt  设备实时状态
-- 粒度：tenant_id × device_id
-- 来源：dwd_opr_device_status_log_rt
-- 生成方式：Flink SQL（持续聚合（快照类，按主键更新） → StarRocks 主键模型表）；字段 5 个：直接翻译 3 · 规则翻译 2 · 待确认 0

INSERT INTO dws.dws_opr_device_rt
SELECT
  u.travel_date,
  u.tenant_id,
  u.device_id,
  SUM(u.offline_times_qty) AS offline_times_qty,
  SUM(u.device_total_qty) AS device_total_qty,
  CURRENT_TIMESTAMP AS update_time
FROM (
  -- 来源：dwd_opr_device_status_log_rt
  SELECT
    travel_date AS travel_date,
    tenant_id AS tenant_id,
    device_id AS device_id,
    COUNT(CASE WHEN after_status='OFFLINE' THEN 1 END) AS offline_times_qty,
    COUNT(device_id) AS device_total_qty
  FROM dwd.dwd_opr_device_status_log_rt s
  GROUP BY travel_date, tenant_id, device_id
) u
GROUP BY u.travel_date, u.tenant_id, u.device_id;
