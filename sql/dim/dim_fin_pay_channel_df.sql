-- dim.dim_fin_pay_channel_df  支付渠道维度
-- 粒度：1行=1个支付渠道配置
-- 来源：ods_fin_payment_channel_config_df + ods_fin_merchant_payment_config_df
-- 生成方式：Spark SQL / Hive；字段 13 个：直接翻译 13 · 规则翻译 0 · 待确认 0
-- 每个 WITH 逻辑块只取用到的列并先过滤分区

WITH
payment_channel_config_src AS (                                           -- 主表「支付渠道配置」，只取用到的列
  SELECT app_id, channel_code, channel_name, channel_status, create_time, id, merchant_no, scope,
         tenant_id, update_time
  FROM ods.ods_fin_payment_channel_config_df
  WHERE travel_date = '${bizdate}'                                        -- 只取当日分区
),
merchant_payment_config_src AS (                                          -- 「商户收款配置」当日数据，只取用到的列
  SELECT channel_code, collection_mode, tenant_id
  FROM ods.ods_fin_merchant_payment_config_df
  WHERE travel_date = '${bizdate}'                                        -- 只取当日分区
),
merchant_payment_config_src_2 AS (                                        -- 「商户收款配置」当日数据，只取用到的列
  SELECT channel_code, config_status
  FROM ods.ods_fin_merchant_payment_config_df
  WHERE travel_date = '${bizdate}'                                        -- 只取当日分区
)
INSERT OVERWRITE TABLE dim.dim_fin_pay_channel_df PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  payment_channel_config_src.id               AS pay_channel_id,          -- 支付渠道配置ID（源表主键 id）
  payment_channel_config_src.channel_code     AS channel_code,            -- 渠道代码
  payment_channel_config_src.channel_name     AS channel_name,            -- 渠道名称
  payment_channel_config_src.merchant_no      AS merchant_no,             -- 商户号/子商户号
  payment_channel_config_src.app_id           AS app_code,                -- 应用ID
  payment_channel_config_src.scope            AS scope_type,              -- 配置范围
  payment_channel_config_src.tenant_id        AS tenant_id,               -- 租户ID
  payment_channel_config_src.channel_status   AS channel_status,          -- 状态
  payment_channel_config_src.create_time      AS create_time,             -- 创建时间
  payment_channel_config_src.update_time      AS update_time,             -- 更新时间
  merchant_payment_config_src.collection_mode AS collection_mode_type,    -- 商户收款模式
  merchant_payment_config_src_2.config_status AS merchant_config_status,  -- 商户支付配置状态
  CURRENT_TIMESTAMP()                         AS etl_time                 -- ETL 加载时间
FROM payment_channel_config_src
LEFT JOIN merchant_payment_config_src                                     -- 关联「商户收款配置」，取 商户收款模式
  ON merchant_payment_config_src.tenant_id = payment_channel_config_src.tenant_id AND merchant_payment_config_src.channel_code = payment_channel_config_src.channel_code  -- 按 tenant_id、channel_code 关联
LEFT JOIN merchant_payment_config_src_2                                   -- 关联「商户收款配置」，取 商户支付配置状态
  ON merchant_payment_config_src_2.channel_code = payment_channel_config_src.channel_code;  -- 按 channel_code 关联
