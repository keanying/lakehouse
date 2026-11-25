-- dim.dim_fin_invoice_config_df  发票配置维度
-- 粒度：1行=1个发票配置
-- 来源：ods_fin_invoice_config_df
-- 生成方式：Spark SQL / Hive；字段 15 个：直接翻译 15 · 规则翻译 0 · 待确认 0

INSERT OVERWRITE TABLE dim.dim_fin_invoice_config_df PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  a.id                AS invoice_config_id,      -- 商户发票配置ID（源表主键 id）
  a.config_no         AS config_no,              -- 配置编号
  a.tenant_id         AS tenant_id,              -- 归属商户ID
  a.invoice_title     AS invoice_title_name,     -- 发票抬头
  a.tax_no            AS tax_no,                 -- 税号
  a.address_phone     AS address_phone_desc,     -- 地址电话
  a.bank_branch       AS bank_branch_name,       -- 开户行及账号
  a.default_content   AS default_content_desc,   -- 默认开票内容
  a.invoice_provider  AS invoice_provider_code,  -- 开票服务商
  a.provider_app_id   AS provider_app_code,      -- 服务商AppID
  a.provider_terminal AS provider_terminal_code,  -- 开票终端号
  a.config_status     AS config_status,          -- 状态
  a.create_time       AS create_time,            -- 创建时间
  a.update_time       AS update_time,            -- 更新时间
  CURRENT_TIMESTAMP() AS etl_time                -- ETL 加载时间
FROM ods.ods_fin_invoice_config_df a             -- 主表「商户发票配置」
WHERE a.travel_date = '${bizdate}';              -- 只取当日分区
