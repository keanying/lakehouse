-- dim.dim_opr_app_df  应用维度
-- 粒度：1行=1个应用
-- 来源：ods_opr_app_definition_df
-- 生成方式：Spark SQL / Hive；字段 9 个：直接翻译 9 · 规则翻译 0 · 待确认 0

INSERT OVERWRITE TABLE dim.dim_opr_app_df PARTITION (travel_date = '${bizdate}')
SELECT
  a.id                AS app_id,
  a.app_no            AS app_no,
  a.app_name          AS app_name,
  a.app_code          AS app_code,
  a.app_type          AS app_type,
  a.app_status        AS app_status,
  a.create_time       AS create_time,
  a.update_time       AS update_time,
  CURRENT_TIMESTAMP() AS etl_time
FROM ods.ods_opr_app_definition_df a
WHERE a.travel_date = '${bizdate}';
