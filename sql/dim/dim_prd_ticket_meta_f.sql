-- dim.dim_prd_ticket_meta_f  票属性元数据码表
-- 粒度：1行=1个票属性
-- 来源：ods_prd_ticket_meta_df
-- 生成方式：Spark SQL / Hive；字段 15 个：直接翻译 15 · 规则翻译 0 · 待确认 0

INSERT OVERWRITE TABLE dim.dim_prd_ticket_meta_f
SELECT
  a.id                AS ticket_meta_id,
  a.attribute_code    AS attribute_code,
  a.attribute_name    AS attribute_name,
  a.value_type        AS value_type,
  a.default_value     AS default_value_desc,
  a.scope             AS applicable_business_list_desc,
  a.impacts           AS impact_list_desc,
  a.conflicts         AS conflict_list_desc,
  a.depends_on        AS depend_list_desc,
  a.enabled_when      AS enabled_when_desc,
  a.disabled_when     AS disabled_when_desc,
  a.attribute_status  AS attribute_status,
  a.create_time       AS create_time,
  a.update_time       AS update_time,
  CURRENT_TIMESTAMP() AS etl_time
FROM ods.ods_prd_ticket_meta_df a
WHERE a.travel_date = '${bizdate}';
