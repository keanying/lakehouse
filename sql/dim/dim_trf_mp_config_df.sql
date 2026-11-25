-- dim.dim_trf_mp_config_df  小程序配置维度
-- 粒度：1行=1个小程序
-- 来源：ods_trf_tenant_mp_config_df
-- 生成方式：Spark SQL / Hive；字段 10 个：直接翻译 10 · 规则翻译 0 · 待确认 0

INSERT OVERWRITE TABLE dim.dim_trf_mp_config_df PARTITION (travel_date = '${bizdate}')
SELECT
  a.id                AS mp_config_id,
  a.tenant_id         AS tenant_id,
  a.mp_type           AS mp_type,
  a.app_id            AS app_code,
  a.mch_id            AS mch_code,
  a.remark            AS remark_desc,
  a.config_status     AS config_status,
  a.create_time       AS create_time,
  a.update_time       AS update_time,
  CURRENT_TIMESTAMP() AS etl_time
FROM ods.ods_trf_tenant_mp_config_df a
WHERE a.travel_date = '${bizdate}';
