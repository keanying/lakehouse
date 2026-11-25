-- dim.dim_opr_device_df  设备维度
-- 粒度：1行=1台设备
-- 来源：ods_opr_device_df + ods_opr_device_group_df
-- 生成方式：Spark SQL / Hive；字段 16 个：直接翻译 16 · 规则翻译 0 · 待确认 0

INSERT OVERWRITE TABLE dim.dim_opr_device_df PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  a.id                AS device_id,          -- 设备ID（源表主键 id）
  a.device_no         AS device_no,          -- 设备编号
  a.tenant_id         AS tenant_id,          -- 归属商户ID
  a.device_type       AS device_type,        -- 设备类型
  a.device_name       AS device_name,        -- 设备名称（如"东门闸机#3"）
  a.poi_id            AS poi_id,             -- 绑定POI ID
  a.device_group_id   AS device_group_id,    -- 设备分组ID
  a.capabilities      AS capability_list_desc,  -- 设备能力
  a.device_status     AS device_status,      -- 状态
  a.last_heartbeat    AS last_heartbeat_time,  -- 最后心跳时间
  a.create_time       AS create_time,        -- 创建时间
  a.update_time       AS update_time,        -- 更新时间
  j1.group_no         AS device_group_no,    -- 设备分组编号
  j2.group_name       AS device_group_name,  -- 设备分组名称
  j2.verify_point_id  AS verify_point_id,    -- 绑定核销点ID
  CURRENT_TIMESTAMP() AS etl_time            -- ETL 加载时间
FROM ods.ods_opr_device_df a                 -- 主表「设备」
LEFT JOIN ods.ods_opr_device_group_df j1     -- 关联「设备分组」，取 设备分组编号
  ON j1.id = a.device_group_id               -- 按 device_group_id→id 关联
 AND j1.travel_date = '${bizdate}'           -- 只取当日分区
LEFT JOIN ods.ods_opr_device_group_df j2     -- 关联「设备分组」，取 设备分组名称、绑定核销点ID
  ON j2.poi_id = a.poi_id                    -- 按 poi_id 关联
 AND j2.travel_date = '${bizdate}'           -- 只取当日分区
WHERE a.travel_date = '${bizdate}';          -- 只取当日分区
