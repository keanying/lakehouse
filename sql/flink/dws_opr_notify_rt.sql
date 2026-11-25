-- dws.dws_opr_notify_rt  通知实时发送
-- 粒度：tenant_id × notify_channel_type × 窗口
-- 来源：dwd_opr_notify_rt
-- 生成方式：Flink SQL（1 分钟滚动窗口聚合 → StarRocks 主键模型表）；字段 6 个：直接翻译 3 · 规则翻译 3 · 待确认 0

INSERT INTO dws.dws_opr_notify_rt                                               -- 写入 StarRocks 目标表
SELECT
  u.travel_date,                                                                -- 数据日期
  u.window_start_time,                                                          -- 窗口开始时间
  u.window_end_time,                                                            -- 窗口结束时间
  u.tenant_id,                                                                  -- 租户ID
  u.notify_channel_type,                                                        -- 通知渠道
  SUM(u.notify_send_qty) AS notify_send_qty,                                    -- 通知发送数
  SUM(u.notify_success_qty) AS notify_success_qty,                              -- 通知成功数
  SUM(u.notify_fail_qty) AS notify_fail_qty,                                    -- 通知失败数
  CURRENT_TIMESTAMP AS update_time                                              -- 最近一次写入时间
FROM (
  -- 来源：dwd_opr_notify_rt
  SELECT
    window_start AS window_start_time,                                          -- 窗口开始时间
    window_end AS window_end_time,                                              -- 窗口结束时间
    travel_date AS travel_date,                                                 -- 数据日期
    tenant_id AS tenant_id,                                                     -- 租户ID
    notify_channel_type AS notify_channel_type,                                 -- 通知渠道
    COUNT(notify_no) AS notify_send_qty,                                        -- 通知发送数
    COUNT(CASE WHEN send_status = 'SUCCESS' THEN 1 END) AS notify_success_qty,  -- 通知成功数
    COUNT(CASE WHEN send_status = 'FAILED' THEN 1 END) AS notify_fail_qty       -- 通知失败数
  FROM TABLE(TUMBLE(TABLE dwd.dwd_opr_notify_rt, DESCRIPTOR(event_time), INTERVAL '1' MINUTE)) s  -- 按事件时间切 1 分钟滚动窗口
  GROUP BY window_start, window_end, travel_date, tenant_id, notify_channel_type  -- 按粒度键汇总
) u                                                                             -- 各来源合并后的明细
GROUP BY u.window_start_time, u.window_end_time, u.travel_date, u.tenant_id, u.notify_channel_type;  -- 按粒度键汇总
