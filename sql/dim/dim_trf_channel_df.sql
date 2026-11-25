-- dim.dim_trf_channel_df  渠道/接入端维度
-- 粒度：1行=1个渠道
-- 来源：ods_trf_channel_df + ods_trf_api_key_df
-- 生成方式：Spark SQL / Hive；字段 17 个：直接翻译 16 · 规则翻译 1 · 待确认 0

INSERT OVERWRITE TABLE dim.dim_trf_channel_df PARTITION (travel_date = '${bizdate}')
SELECT
  a.id                        AS channel_id,
  a.channel_code              AS channel_code,
  a.channel_name              AS channel_name,
  a.partner_id                AS partner_code,
  a.partner_name              AS partner_name,
  a.channel_type              AS channel_type,
  a.channel_scope             AS channel_scope_type,
  a.owner_tenant_id           AS owner_tenant_id,
  a.default_operator_staff_id AS default_operator_staff_id,
  a.channel_status            AS channel_status,
  a.valid_from                AS valid_start_time,
  a.valid_to                  AS valid_end_time,
  a.create_time               AS create_time,
  a.update_time               AS update_time,
  COALESCE(j1.v, 0)           AS api_key_qty,
  j2.rate_limit_qps           AS rate_limit_qps_qty,
  CURRENT_TIMESTAMP()         AS etl_time
FROM ods.ods_trf_channel_df a
LEFT JOIN (SELECT channel_id, COUNT(key_no) AS v FROM ods.ods_trf_api_key_df WHERE travel_date = '${bizdate}' GROUP BY channel_id) j1
  ON j1.channel_id = a.id
LEFT JOIN ods.ods_trf_api_key_df j2
  ON j2.channel_id = a.id
 AND j2.travel_date = '${bizdate}'
WHERE a.travel_date = '${bizdate}';
