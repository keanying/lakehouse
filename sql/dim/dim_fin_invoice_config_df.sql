-- dim.dim_fin_invoice_config_df  发票配置维度
-- 粒度：1行=1个发票配置
-- 来源：ods_fin_invoice_config_df
-- 生成方式：Spark SQL / Hive；字段 15 个：直接翻译 15 · 规则翻译 0 · 待确认 0

INSERT OVERWRITE TABLE dim.dim_fin_invoice_config_df PARTITION (travel_date = '${bizdate}')
SELECT
  a.id                AS invoice_config_id,
  a.config_no         AS config_no,
  a.tenant_id         AS tenant_id,
  a.invoice_title     AS invoice_title_name,
  a.tax_no            AS tax_no,
  a.address_phone     AS address_phone_desc,
  a.bank_branch       AS bank_branch_name,
  a.default_content   AS default_content_desc,
  a.invoice_provider  AS invoice_provider_code,
  a.provider_app_id   AS provider_app_code,
  a.provider_terminal AS provider_terminal_code,
  a.config_status     AS config_status,
  a.create_time       AS create_time,
  a.update_time       AS update_time,
  CURRENT_TIMESTAMP() AS etl_time
FROM ods.ods_fin_invoice_config_df a
WHERE a.travel_date = '${bizdate}';
