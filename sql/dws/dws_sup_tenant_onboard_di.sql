-- dws.dws_sup_tenant_onboard_di  平台×地区×业态 商户入驻日汇总
-- 粒度：travel_date × country_code × region_id × business_type
-- 来源：dim_sup_tenant_zip
-- 生成方式：Spark SQL / Hive；字段 6 个：直接翻译 3 · 规则翻译 1 · 待确认 2
-- 来源先按粒度键预聚合
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

WITH
src_tenant AS (                                                          -- 来源「租户（商户/供应商/分销商）维度」按粒度键预聚合
  SELECT
    country_code AS country_code,                                        -- 国家编码
    region_id AS region_id,                                              -- 地区ID
    business_type_list_desc AS business_type,                            -- 业态
    COUNT(CASE WHEN tenant_type='EXTERNAL' THEN tenant_id END) AS new_tenant_qty,  -- 新入驻商户数
    COUNT(CASE WHEN 1 = 1 THEN tenant_id END) AS tenant_cert_apply_qty,  -- 提交认证商户数｜待确认：auth_status 变为 PENDING_REVIEW
    COUNT(CASE WHEN 1 = 1 THEN tenant_id END) AS tenant_cert_pass_qty    -- 认证通过商户数｜待确认：auth_status 变为 CERTIFIED
  FROM dim.dim_sup_tenant_zip s                                          -- 来源表「租户（商户/供应商/分销商）维度」
  WHERE s.travel_date = '${bizdate}' AND s.end_date = '9999-12-31'       -- 取当日分区里的拉链当前有效版本
  GROUP BY country_code, region_id, business_type_list_desc              -- 按粒度键汇总
)
INSERT OVERWRITE TABLE dws.dws_sup_tenant_onboard_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  u.country_code,                                                        -- 国家编码
  u.region_id,                                                           -- 地区ID
  u.business_type,                                                       -- 业态
  u.new_tenant_qty,                                                      -- 新入驻商户数
  u.tenant_cert_apply_qty,                                               -- 提交认证商户数
  u.tenant_cert_pass_qty,                                                -- 认证通过商户数
  CURRENT_TIMESTAMP() AS etl_time                                        -- ETL 加载时间
FROM src_tenant u;
