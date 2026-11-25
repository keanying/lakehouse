-- dim.dim_fin_pay_channel_df  支付渠道维度
-- 粒度：1行=1个支付渠道配置
-- 来源：ods_fin_payment_channel_config_df + ods_fin_merchant_payment_config_df
-- 生成方式：Spark SQL / Hive；字段 13 个：直接翻译 13 · 规则翻译 0 · 待确认 0

INSERT OVERWRITE TABLE dim.dim_fin_pay_channel_df PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  a.id                AS pay_channel_id,             -- 支付渠道配置ID（源表主键 id）
  a.channel_code      AS channel_code,               -- 渠道代码
  a.channel_name      AS channel_name,               -- 渠道名称
  a.merchant_no       AS merchant_no,                -- 商户号/子商户号
  a.app_id            AS app_code,                   -- 应用ID
  a.scope             AS scope_type,                 -- 配置范围
  a.tenant_id         AS tenant_id,                  -- 租户ID
  a.channel_status    AS channel_status,             -- 状态
  a.create_time       AS create_time,                -- 创建时间
  a.update_time       AS update_time,                -- 更新时间
  j1.collection_mode  AS collection_mode_type,       -- 商户收款模式
  j2.config_status    AS merchant_config_status,     -- 商户支付配置状态
  CURRENT_TIMESTAMP() AS etl_time                    -- ETL 加载时间
FROM ods.ods_fin_payment_channel_config_df a         -- 主表「支付渠道配置」
LEFT JOIN ods.ods_fin_merchant_payment_config_df j1  -- 关联「商户收款配置」，取 商户收款模式
  ON j1.tenant_id = a.tenant_id AND j1.channel_code = a.channel_code  -- 按 tenant_id、channel_code 关联
 AND j1.travel_date = '${bizdate}'                   -- 只取当日分区
LEFT JOIN ods.ods_fin_merchant_payment_config_df j2  -- 关联「商户收款配置」，取 商户支付配置状态
  ON j2.merchant_no = a.merchant_no                  -- 按 merchant_no 关联
 AND j2.travel_date = '${bizdate}'                   -- 只取当日分区
WHERE a.travel_date = '${bizdate}';                  -- 只取当日分区
