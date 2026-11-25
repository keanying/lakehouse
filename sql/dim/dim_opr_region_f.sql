-- dim.dim_opr_region_f  地区维度
-- 粒度：1行=1个末级地区
-- 来源：ods_opr_region_df + ods_opr_country_df
-- 生成方式：Spark SQL / Hive；字段 21 个：直接翻译 14 · 规则翻译 3 · 待确认 4
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT OVERWRITE TABLE dim.dim_opr_region_f
SELECT
  a.id                         AS region_id,
  a.region_code                AS region_code,
  a.parent_id                  AS parent_id,
  a.country_code               AS country_code,
  a.region_level               AS region_level_no,
  a.region_path                AS region_path_desc,
  a.region_status              AS region_status,
  a.sort_order                 AS sort_no,
  a.create_time                AS create_time,
  a.update_time                AS update_time,
  j1.field_value               AS region_name,  -- 待确认：ods_opr_i18n_translation_df.field_value 取 zh-CN
  j1.field_value               AS country_name,
  j2.iso3_code                 AS iso3_code,
  a.parent_id                  AS province_code,  -- 待确认：ods_opr_region_df.parent_id 递归到 region_level=1
  SPLIT(a.region_path, '/')[1] AS province_name,
  a.parent_id                  AS city_code,  -- 待确认：ods_opr_region_df.parent_id 递归到 region_level=2
  SPLIT(a.region_path, '/')[2] AS city_name,
  a.region_code                AS district_code,  -- 待确认：ods_opr_region_df.region_code（region_level=3 时）
  SPLIT(a.region_path, '/')[3] AS district_name,
  a.region_code                AS id_card_prefix_code,
  CURRENT_TIMESTAMP()          AS etl_time
FROM ods.ods_opr_region_df a
LEFT JOIN ods.ods_opr_i18n_translation_df j1
  ON j1.id = a.parent_id
 AND j1.travel_date = '${bizdate}'
LEFT JOIN ods.ods_opr_country_df j2
  ON j2.country_code = a.country_code
 AND j2.travel_date = '${bizdate}'
WHERE a.travel_date = '${bizdate}';
