-- dim.dim_opr_device_df  设备维度
-- 粒度：1行=1台设备
-- 来源：ods_opr_device_df + ods_opr_device_group_df
-- 生成方式：Spark SQL / Hive；字段 16 个：直接翻译 16 · 规则翻译 0 · 待确认 0
-- 每个 WITH 逻辑块只取用到的列并先过滤分区

WITH
device_src AS (                                           -- 主表「设备」，只取用到的列
  SELECT capabilities, create_time, device_group_id, device_name, device_no, device_status, device_type,
         id, last_heartbeat, poi_id, tenant_id, update_time
  FROM ods.ods_opr_device_df
  WHERE travel_date = '${bizdate}'                        -- 只取当日分区
),
device_group_src AS (                                     -- 「设备分组」当日数据，只取用到的列
  SELECT group_name, group_no, id, verify_point_id
  FROM ods.ods_opr_device_group_df
  WHERE travel_date = '${bizdate}'                        -- 只取当日分区
)
INSERT OVERWRITE TABLE dim.dim_opr_device_df PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  device_src.id                    AS device_id,          -- 设备ID（源表主键 id）
  device_src.device_no             AS device_no,          -- 设备编号
  device_src.tenant_id             AS tenant_id,          -- 归属商户ID
  device_src.device_type           AS device_type,        -- 设备类型
  device_src.device_name           AS device_name,        -- 设备名称（如"东门闸机#3"）
  device_src.poi_id                AS poi_id,             -- 绑定POI ID
  device_src.device_group_id       AS device_group_id,    -- 设备分组ID
  device_src.capabilities          AS capability_list_desc,  -- 设备能力
  device_src.device_status         AS device_status,      -- 状态
  device_src.last_heartbeat        AS last_heartbeat_time,  -- 最后心跳时间
  device_src.create_time           AS create_time,        -- 创建时间
  device_src.update_time           AS update_time,        -- 更新时间
  device_group_src.group_no        AS device_group_no,    -- 设备分组编号
  device_group_src.group_name      AS device_group_name,  -- 设备分组名称
  device_group_src.verify_point_id AS verify_point_id,    -- 绑定核销点ID
  CURRENT_TIMESTAMP()              AS etl_time            -- ETL 加载时间
FROM device_src
LEFT JOIN device_group_src                                -- 关联「设备分组」，取 设备分组编号、设备分组名称、绑定核销点ID
  ON device_group_src.id = device_src.device_group_id;    -- 按 device_group_id→id 关联
