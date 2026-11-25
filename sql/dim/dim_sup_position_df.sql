-- dim.dim_sup_position_df  岗位维度
-- 粒度：1行=1个岗位
-- 来源：ods_sup_tenant_position_df
-- 生成方式：Spark SQL / Hive；字段 9 个：直接翻译 9 · 规则翻译 0 · 待确认 0

INSERT OVERWRITE TABLE dim.dim_sup_position_df PARTITION (travel_date = '${bizdate}')
SELECT
  a.id                AS position_id,
  a.position_no       AS position_no,
  a.tenant_id         AS tenant_id,
  a.position_name     AS position_name,
  a.position_code     AS position_code,
  a.position_status   AS position_status,
  a.create_time       AS create_time,
  a.update_time       AS update_time,
  CURRENT_TIMESTAMP() AS etl_time
FROM ods.ods_sup_tenant_position_df a
WHERE a.travel_date = '${bizdate}';
