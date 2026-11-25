-- dim.dim_prd_sku_attr_df  SKU票属性维度
-- 粒度：1行=1个SKU×1个票属性
-- 来源：ods_prd_sku_meta_value_df + ods_prd_ticket_meta_df, dim_prd_ticket_meta_f
-- 生成方式：Spark SQL / Hive；字段 11 个：直接翻译 11 · 规则翻译 0 · 待确认 0

INSERT OVERWRITE TABLE dim.dim_prd_sku_attr_df PARTITION (travel_date = '${bizdate}')
SELECT
  a.id                AS sku_attr_id,
  a.sku_id            AS sku_id,
  a.attribute_code    AS attribute_code,
  a.attribute_value   AS attribute_value_code,
  a.tenant_id         AS tenant_id,
  a.create_time       AS create_time,
  a.update_time       AS update_time,
  j1.attribute_name   AS attribute_name,
  j1.value_type       AS value_type,
  j2.dict_name        AS attribute_value_name,
  CURRENT_TIMESTAMP() AS etl_time
FROM ods.ods_prd_sku_meta_value_df a
LEFT JOIN ods.ods_prd_ticket_meta_df j1
  ON j1.attribute_code = a.attribute_code
 AND j1.travel_date = '${bizdate}'
LEFT JOIN dim.dim_opr_dict_f j2
  ON j2.tenant_id = a.tenant_id
WHERE a.travel_date = '${bizdate}';
