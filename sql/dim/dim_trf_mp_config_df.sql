-- dim.dim_trf_mp_config_df  小程序配置维度
-- 粒度：1行=1个小程序
-- 来源：ods_trf_tenant_mp_config_df
-- 生成方式：Spark SQL / Hive；字段 10 个：直接翻译 10 · 规则翻译 0 · 待确认 0
-- 每个 WITH 逻辑块只取用到的列并先过滤分区

WITH
tenant_mp_config_src AS (                               -- 主表「租户小程序配置」，只取用到的列
  SELECT app_id, config_status, create_time, id, mch_id, mp_type, remark, tenant_id, update_time
  FROM ods.ods_trf_tenant_mp_config_df
  WHERE travel_date = '${bizdate}'                      -- 只取当日分区
)
INSERT OVERWRITE TABLE dim.dim_trf_mp_config_df PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  tenant_mp_config_src.id            AS mp_config_id,   -- 租户小程序配置ID（源表主键 id）
  tenant_mp_config_src.tenant_id     AS tenant_id,      -- 归属租户ID
  tenant_mp_config_src.mp_type       AS mp_type,        -- 小程序类型
  tenant_mp_config_src.app_id        AS app_code,       -- 小程序 appId（微信/支付宝/抖音）
  tenant_mp_config_src.mch_id        AS mch_code,       -- 微信支付商户号（可能共用）
  tenant_mp_config_src.remark        AS remark_desc,    -- 备注
  tenant_mp_config_src.config_status AS config_status,  -- 状态
  tenant_mp_config_src.create_time   AS create_time,    -- 创建时间
  tenant_mp_config_src.update_time   AS update_time,    -- 更新时间
  CURRENT_TIMESTAMP()                AS etl_time        -- ETL 加载时间
FROM tenant_mp_config_src;
