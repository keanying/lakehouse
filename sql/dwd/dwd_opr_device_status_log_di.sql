-- dwd.dwd_opr_device_status_log_di  设备状态变更明细
-- 粒度：1行=1次设备状态/心跳变化
-- 来源：ods_opr_device_df（相邻快照/binlog）
-- 生成方式：Spark SQL / Hive；字段 12 个：直接翻译 9 · 规则翻译 1 · 待确认 2
-- 流水/状态变更类：保留每条变更记录
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT OVERWRITE TABLE dwd.dwd_opr_device_status_log_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  a.id                                                         AS device_id,      -- 设备ID
  a.device_no                                                  AS device_no,      -- 设备编号
  a.tenant_id                                                  AS tenant_id,      -- 租户ID
  a.device_type                                                AS device_type,    -- 设备类型
  a.device_group_id                                            AS device_group_id,  -- 设备分组ID
  a.poi_id                                                     AS poi_id,         -- 所属 POI ID
  a.device_status                                              AS before_status,  -- 变更前状态｜待确认：ods_opr_device_df.device_status 昨日快照
  a.device_status                                              AS after_status,   -- 变更后状态｜待确认：ods_opr_device_df.device_status 今日快照
  a.last_heartbeat                                             AS last_heartbeat_time,  -- 最后心跳时间
  a.update_time                                                AS change_time,    -- 状态变更时间
  (UNIX_TIMESTAMP(a.update_time) - UNIX_TIMESTAMP(LAG(a.update_time) OVER (PARTITION BY a.id ORDER BY a.update_time))) / 60 AS status_minute_qty,  -- 前一状态持续时长（分钟）
  CURRENT_TIMESTAMP()                                          AS etl_time        -- ETL 加载时间
FROM ods.ods_opr_device_df a                                                      -- 主表「设备」
WHERE a.travel_date = '${bizdate}';                                               -- 只取当日分区
