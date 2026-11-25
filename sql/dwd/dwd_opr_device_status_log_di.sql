-- dwd.dwd_opr_device_status_log_di  设备状态变更明细
-- 粒度：1行=1次设备状态/心跳变化
-- 来源：ods_opr_device_df（相邻快照/binlog）
-- 生成方式：Spark SQL / Hive；字段 12 个：直接翻译 9 · 规则翻译 1 · 待确认 2
-- 流水/状态变更类：保留每条变更记录
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT OVERWRITE TABLE dwd.dwd_opr_device_status_log_di PARTITION (travel_date = '${bizdate}')
SELECT
  a.id                                                         AS device_id,
  a.device_no                                                  AS device_no,
  a.tenant_id                                                  AS tenant_id,
  a.device_type                                                AS device_type,
  a.device_group_id                                            AS device_group_id,
  a.poi_id                                                     AS poi_id,
  a.device_status                                              AS before_status,  -- 待确认：ods_opr_device_df.device_status 昨日快照
  a.device_status                                              AS after_status,  -- 待确认：ods_opr_device_df.device_status 今日快照
  a.last_heartbeat                                             AS last_heartbeat_time,
  a.update_time                                                AS change_time,
  (UNIX_TIMESTAMP(a.update_time) - UNIX_TIMESTAMP(LAG(a.update_time) OVER (PARTITION BY a.id ORDER BY a.update_time))) / 60 AS status_minute_qty,
  CURRENT_TIMESTAMP()                                          AS etl_time
FROM ods.ods_opr_device_df a
WHERE a.travel_date = '${bizdate}';
