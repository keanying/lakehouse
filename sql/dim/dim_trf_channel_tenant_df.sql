-- dim.dim_trf_channel_tenant_df  渠道-租户绑定维度
-- 粒度：1行=1条绑定
-- 来源：ods_trf_channel_tenant_binding_df
-- 生成方式：Spark SQL / Hive；字段 15 个：直接翻译 15 · 规则翻译 0 · 待确认 0

INSERT OVERWRITE TABLE dim.dim_trf_channel_tenant_df PARTITION (travel_date = '${bizdate}')
SELECT
  a.id                AS channel_tenant_binding_id,
  a.binding_no        AS binding_no,
  a.channel_id        AS channel_id,
  a.tenant_id         AS tenant_id,
  a.partner_id        AS partner_code,
  a.ota_merchant_id   AS ota_merchant_code,
  a.ota_sub_channel   AS ota_sub_channel_code,
  a.binding_status    AS binding_status,
  a.valid_from        AS valid_start_time,
  a.valid_to          AS valid_end_time,
  a.create_time       AS create_time,
  a.update_time       AS update_time,
  j1.channel_code     AS channel_code,
  j1.channel_type     AS channel_type,
  CURRENT_TIMESTAMP() AS etl_time
FROM ods.ods_trf_channel_tenant_binding_df a
LEFT JOIN dim.dim_trf_channel_df j1
  ON j1.channel_id = a.channel_id
 AND j1.travel_date = '${bizdate}'
WHERE a.travel_date = '${bizdate}';
