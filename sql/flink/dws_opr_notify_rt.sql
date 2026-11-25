-- dws.dws_opr_notify_rt  通知实时发送
-- 粒度：tenant_id × notify_channel_type × 窗口
-- 来源：dwd_opr_notify_rt
-- 生成方式：Flink SQL（1 分钟滚动窗口聚合 → StarRocks 主键模型表）；字段 6 个：直接翻译 3 · 规则翻译 3 · 待确认 0

INSERT INTO dws.dws_opr_notify_rt
SELECT
  u.window_start_time,
  u.window_end_time,
  u.travel_date,
  u.tenant_id,
  u.notify_channel_type,
  SUM(u.notify_send_qty) AS notify_send_qty,
  SUM(u.notify_success_qty) AS notify_success_qty,
  SUM(u.notify_fail_qty) AS notify_fail_qty,
  CURRENT_TIMESTAMP AS update_time
FROM (
  -- 来源：dwd_opr_notify_rt
  SELECT
    window_start AS window_start_time,
    window_end AS window_end_time,
    travel_date AS travel_date,
    tenant_id AS tenant_id,
    notify_channel_type AS notify_channel_type,
    COUNT(notify_no) AS notify_send_qty,
    COUNT(CASE WHEN send_status = 'SUCCESS' THEN 1 END) AS notify_success_qty,
    COUNT(CASE WHEN send_status = 'FAILED' THEN 1 END) AS notify_fail_qty
  FROM TABLE(TUMBLE(TABLE dwd.dwd_opr_notify_rt, DESCRIPTOR(event_time), INTERVAL '1' MINUTE)) s
  GROUP BY window_start, window_end, travel_date, tenant_id, notify_channel_type
) u
GROUP BY u.window_start_time, u.window_end_time, u.travel_date, u.tenant_id, u.notify_channel_type;
