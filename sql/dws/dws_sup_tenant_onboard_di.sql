-- dws.dws_sup_tenant_onboard_di  平台×地区×业态 商户入驻日汇总
-- 粒度：travel_date × country_code × region_id × business_type
-- 来源：dim_sup_tenant_zip
-- 生成方式：Spark SQL / Hive；字段 6 个：直接翻译 3 · 规则翻译 3 · 待确认 0
-- 来源先按粒度键预聚合

WITH
src_tenant AS (                                                                   -- 来源「租户（商户/供应商/分销商）维度」按粒度键预聚合
  SELECT
    country_code AS country_code,                                                 -- 国家编码
    region_id AS region_id,                                                       -- 地区ID
    business_type_list_desc AS business_type,                                     -- 业态
    COUNT(CASE WHEN tenant_type='EXTERNAL' THEN tenant_id END) AS new_tenant_qty,  -- 新入驻商户数
    COUNT(CASE WHEN auth_status = 'PENDING_REVIEW'                                -- 提交认证商户数｜口径：今日新开拉链版本认证状态变为审核中（提交认证）
        AND start_date = '${bizdate_dash}'
          AND COALESCE(pv.pv_auth_status, '') <> 'PENDING_REVIEW' THEN tenant_id END) AS tenant_cert_apply_qty,  -- 提交认证商户数
    COUNT(CASE WHEN auth_status = 'CERTIFIED'                                     -- 认证通过商户数｜口径：今日新开拉链版本认证状态变为已认证
        AND start_date = '${bizdate_dash}'
          AND COALESCE(pv.pv_auth_status, '') <> 'CERTIFIED' THEN tenant_id END) AS tenant_cert_pass_qty  -- 认证通过商户数
  FROM dim.dim_sup_tenant_zip s                                                   -- 来源表「租户（商户/供应商/分销商）维度」
  LEFT JOIN (SELECT tenant_id AS pv_key, auth_status AS pv_auth_status FROM dim.dim_sup_tenant_zip
             WHERE travel_date = '${bizdate}'                                     -- 只取当日分区
               AND end_date = '${bizdate_prev_dash}') pv ON pv.pv_key = s.tenant_id
  WHERE s.travel_date = '${bizdate}' AND s.end_date = '9999-12-31'                -- 取当日分区里的拉链当前有效版本
  GROUP BY country_code, region_id, business_type_list_desc                       -- 按粒度键汇总
)
INSERT OVERWRITE TABLE dws.dws_sup_tenant_onboard_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  u.country_code,                                                                 -- 国家编码
  u.region_id,                                                                    -- 地区ID
  u.business_type,                                                                -- 业态
  u.new_tenant_qty,                                                               -- 新入驻商户数
  u.tenant_cert_apply_qty,                                                        -- 提交认证商户数
  u.tenant_cert_pass_qty,                                                         -- 认证通过商户数
  CURRENT_TIMESTAMP() AS etl_time                                                 -- ETL 加载时间
FROM src_tenant u;
