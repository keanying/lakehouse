-- dim.dim_fin_pay_channel_df  支付渠道维度
-- 粒度：1行=1个支付渠道配置
-- 来源：ods_fin_payment_channel_config_df + ods_fin_merchant_payment_config_df
-- 生成方式：Spark SQL / Hive；字段 13 个：直接翻译 13 · 规则翻译 0 · 待确认 0

INSERT OVERWRITE TABLE dim.dim_fin_pay_channel_df PARTITION (travel_date = '${bizdate}')
SELECT
  a.id                AS pay_channel_id,
  a.channel_code      AS channel_code,
  a.channel_name      AS channel_name,
  a.merchant_no       AS merchant_no,
  a.app_id            AS app_code,
  a.scope             AS scope_type,
  a.tenant_id         AS tenant_id,
  a.channel_status    AS channel_status,
  a.create_time       AS create_time,
  a.update_time       AS update_time,
  j1.collection_mode  AS collection_mode_type,
  j2.config_status    AS merchant_config_status,
  CURRENT_TIMESTAMP() AS etl_time
FROM ods.ods_fin_payment_channel_config_df a
LEFT JOIN ods.ods_fin_merchant_payment_config_df j1
  ON j1.tenant_id = a.tenant_id AND j1.channel_code = a.channel_code
 AND j1.travel_date = '${bizdate}'
LEFT JOIN ods.ods_fin_merchant_payment_config_df j2
  ON j2.channel_code = a.channel_code
 AND j2.travel_date = '${bizdate}'
WHERE a.travel_date = '${bizdate}';
