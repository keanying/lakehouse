-- dim.dim_opr_verify_point_df  核销点维度
-- 粒度：1行=1个核销点
-- 来源：ods_opr_verify_point_df
-- 生成方式：Spark SQL / Hive；字段 13 个：直接翻译 12 · 规则翻译 1 · 待确认 0

INSERT OVERWRITE TABLE dim.dim_opr_verify_point_df PARTITION (travel_date = '${bizdate}')
SELECT
  a.id                AS verify_point_id,
  a.verify_point_no   AS verify_point_no,
  a.tenant_id         AS tenant_id,
  a.poi_id            AS poi_id,
  a.point_name        AS verify_point_name,
  a.point_type        AS verify_point_type,
  a.point_status      AS verify_point_status,
  a.allowed_sku_ids   AS allowed_sku_list_desc,
  a.device_group_id   AS device_group_id,
  a.create_time       AS create_time,
  a.update_time       AS update_time,
  COALESCE(j1.v, 0)   AS device_qty,
  CURRENT_TIMESTAMP() AS etl_time
FROM ods.ods_opr_verify_point_df a
LEFT JOIN (SELECT device_group_id, COUNT(id) AS v FROM ods.ods_opr_device_df WHERE travel_date = '${bizdate}' GROUP BY device_group_id) j1
  ON j1.device_group_id = a.device_group_id
WHERE a.travel_date = '${bizdate}';
