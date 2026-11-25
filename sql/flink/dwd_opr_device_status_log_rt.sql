-- dwd.dwd_opr_device_status_log_rt  实时设备状态变更
-- 粒度：1行=1次设备状态/心跳变化
-- 来源：ods_opr_device_rt
-- 生成方式：Flink SQL（CDC 源表 → StarRocks 主键模型表；维表 Lookup Join）；字段 13 个：直接翻译 9 · 规则翻译 2 · 待确认 2
-- 源表 ods.*_rt 为 Flink CDC 表（含 proc_time AS PROCTIME()），目标表在 StarRocks catalog 中
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT INTO dwd.dwd_opr_device_status_log_rt                                      -- 写入 StarRocks 目标表
SELECT
  DATE_FORMAT(a.binlog_time, 'yyyyMMdd')                       AS travel_date,    -- 数据日期
  a.id                                                         AS device_id,      -- 设备ID
  a.update_time                                                AS change_time,    -- 状态变更时间
  a.device_no                                                  AS device_no,      -- 设备编号
  a.tenant_id                                                  AS tenant_id,      -- 租户ID
  a.device_type                                                AS device_type,    -- 设备类型
  a.device_group_id                                            AS device_group_id,  -- 设备分组ID
  a.poi_id                                                     AS poi_id,         -- 所属 POI ID
  a.device_status                                              AS before_status,  -- 变更前状态｜待确认：ods_opr_device_rt.device_status 昨日快照
  a.device_status                                              AS after_status,   -- 变更后状态｜待确认：ods_opr_device_rt.device_status 今日快照
  a.last_heartbeat                                             AS last_heartbeat_time,  -- 最后心跳时间
  (UNIX_TIMESTAMP(a.update_time) - UNIX_TIMESTAMP(LAG(a.update_time) OVER (PARTITION BY a.id ORDER BY a.update_time))) / 60 AS status_minute_qty,  -- 前一状态持续时长（分钟）
  CURRENT_TIMESTAMP                                            AS event_time      -- 事件时间（binlog 时间）
FROM ods.ods_opr_device_rt a;
