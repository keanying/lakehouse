-- dwd.dwd_opr_device_status_log_di  设备状态变更明细
-- 粒度：1行=1次设备状态/心跳变化
-- 来源：ods_opr_device_df（相邻快照/binlog）
-- 生成方式：Spark SQL / Hive；字段 12 个：直接翻译 9 · 规则翻译 1 · 待确认 2
-- 流水/状态变更类：保留每条变更记录；每个 WITH 逻辑块只取用到的列并先过滤分区
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

WITH
device_chg AS (                                                                   -- 主表「设备」：保留每条变更记录，只取用到的列
  SELECT device_group_id, device_no, device_status, device_type, id, last_heartbeat, poi_id, tenant_id,
         update_time
  FROM ods.ods_opr_device_df
  WHERE travel_date = '${bizdate}'                                                -- 只取当日分区
)
INSERT OVERWRITE TABLE dwd.dwd_opr_device_status_log_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  device_chg.id                                                AS device_id,      -- 设备ID
  device_chg.device_no                                         AS device_no,      -- 设备编号
  device_chg.tenant_id                                         AS tenant_id,      -- 租户ID
  device_chg.device_type                                       AS device_type,    -- 设备类型
  device_chg.device_group_id                                   AS device_group_id,  -- 设备分组ID
  device_chg.poi_id                                            AS poi_id,         -- 所属 POI ID
  device_chg.device_status                                     AS before_status,  -- 变更前状态｜待确认：ods_opr_device_df.device_status 昨日快照
  device_chg.device_status                                     AS after_status,   -- 变更后状态｜待确认：ods_opr_device_df.device_status 今日快照
  device_chg.last_heartbeat                                    AS last_heartbeat_time,  -- 最后心跳时间
  device_chg.update_time                                       AS change_time,    -- 状态变更时间
  (UNIX_TIMESTAMP(device_chg.update_time) - UNIX_TIMESTAMP(LAG(device_chg.update_time) OVER (PARTITION BY device_chg.id ORDER BY device_chg.update_time))) / 60 AS status_minute_qty,  -- 前一状态持续时长（分钟）
  CURRENT_TIMESTAMP()                                          AS etl_time        -- ETL 加载时间
FROM device_chg;
