-- dim.dim_opr_device_df  设备维度
-- 粒度：1行=1台设备
-- 来源：ods_opr_device_df + ods_opr_device_group_df
-- 生成方式：Spark SQL / Hive；字段 16 个：直接翻译 16 · 规则翻译 0 · 待确认 0

INSERT OVERWRITE TABLE dim.dim_opr_device_df PARTITION (travel_date = '${bizdate}')
SELECT
  a.id                AS device_id,
  a.device_no         AS device_no,
  a.tenant_id         AS tenant_id,
  a.device_type       AS device_type,
  a.device_name       AS device_name,
  a.poi_id            AS poi_id,
  a.device_group_id   AS device_group_id,
  a.capabilities      AS capability_list_desc,
  a.device_status     AS device_status,
  a.last_heartbeat    AS last_heartbeat_time,
  a.create_time       AS create_time,
  a.update_time       AS update_time,
  j1.group_no         AS device_group_no,
  j2.group_name       AS device_group_name,
  j2.verify_point_id  AS verify_point_id,
  CURRENT_TIMESTAMP() AS etl_time
FROM ods.ods_opr_device_df a
LEFT JOIN ods.ods_opr_device_group_df j1
  ON j1.id = a.device_group_id
 AND j1.travel_date = '${bizdate}'
LEFT JOIN ods.ods_opr_device_group_df j2
  ON j2.poi_id = a.poi_id
 AND j2.travel_date = '${bizdate}'
WHERE a.travel_date = '${bizdate}';
