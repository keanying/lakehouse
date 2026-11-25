-- dim.dim_opr_notify_template_df  通知模板维度
-- 粒度：1行=1个模板
-- 来源：ods_opr_notify_template_df
-- 生成方式：Spark SQL / Hive；字段 11 个：直接翻译 11 · 规则翻译 0 · 待确认 0

INSERT OVERWRITE TABLE dim.dim_opr_notify_template_df PARTITION (travel_date = '${bizdate}')
SELECT
  a.id                AS notify_template_id,
  a.template_no       AS template_no,
  a.template_code     AS template_code,
  a.template_name     AS template_name,
  a.notify_channel    AS notify_channel_type,
  a.scope             AS scope_type,
  a.tenant_id         AS tenant_id,
  a.template_status   AS template_status,
  a.create_time       AS create_time,
  a.update_time       AS update_time,
  CURRENT_TIMESTAMP() AS etl_time
FROM ods.ods_opr_notify_template_df a
WHERE a.travel_date = '${bizdate}';
