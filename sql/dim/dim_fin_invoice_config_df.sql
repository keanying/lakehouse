-- dim.dim_fin_invoice_config_df  发票配置维度
-- 粒度：1行=1个发票配置
-- 来源：ods_fin_invoice_config_df
-- 生成方式：Spark SQL / Hive；字段 15 个：直接翻译 15 · 规则翻译 0 · 待确认 0
-- 每个 WITH 逻辑块只取用到的列并先过滤分区

WITH
invoice_config_src AS (                                           -- 主表「商户发票配置」，只取用到的列
  SELECT address_phone, bank_branch, config_no, config_status, create_time, default_content, id,
         invoice_provider, invoice_title, provider_app_id, provider_terminal, tax_no, tenant_id,
         update_time                                              -- 更新时间
  FROM ods.ods_fin_invoice_config_df
  WHERE travel_date = '${bizdate}'                                -- 只取当日分区
)
INSERT OVERWRITE TABLE dim.dim_fin_invoice_config_df PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  invoice_config_src.id                AS invoice_config_id,      -- 商户发票配置ID（源表主键 id）
  invoice_config_src.config_no         AS config_no,              -- 配置编号
  invoice_config_src.tenant_id         AS tenant_id,              -- 归属商户ID
  invoice_config_src.invoice_title     AS invoice_title_name,     -- 发票抬头
  invoice_config_src.tax_no            AS tax_no,                 -- 税号
  invoice_config_src.address_phone     AS address_phone_desc,     -- 地址电话
  invoice_config_src.bank_branch       AS bank_branch_name,       -- 开户行及账号
  invoice_config_src.default_content   AS default_content_desc,   -- 默认开票内容
  invoice_config_src.invoice_provider  AS invoice_provider_code,  -- 开票服务商
  invoice_config_src.provider_app_id   AS provider_app_code,      -- 服务商AppID
  invoice_config_src.provider_terminal AS provider_terminal_code,  -- 开票终端号
  invoice_config_src.config_status     AS config_status,          -- 状态
  invoice_config_src.create_time       AS create_time,            -- 创建时间
  invoice_config_src.update_time       AS update_time,            -- 更新时间
  CURRENT_TIMESTAMP()                  AS etl_time                -- ETL 加载时间
FROM invoice_config_src;
