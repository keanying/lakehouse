-- dws.dws_sup_tenant_onboard_di  平台×地区×业态 商户入驻日汇总
-- 粒度：travel_date × country_code × region_id × business_type
-- 来源：dim_sup_tenant_zip
-- 生成方式：Spark SQL / Hive；字段 6 个：直接翻译 3 · 规则翻译 1 · 待确认 2
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT OVERWRITE TABLE dws.dws_sup_tenant_onboard_di PARTITION (travel_date = '${bizdate}')
SELECT
  u.country_code,
  u.region_id,
  u.business_type,
  SUM(u.new_tenant_qty) AS new_tenant_qty,
  SUM(u.tenant_cert_apply_qty) AS tenant_cert_apply_qty,
  SUM(u.tenant_cert_pass_qty) AS tenant_cert_pass_qty,
  CURRENT_TIMESTAMP() AS etl_time
FROM (
  -- 来源：dim_sup_tenant_zip
  SELECT
    country_code AS country_code,
    region_id AS region_id,
    business_type_list_desc AS business_type,
    COUNT(CASE WHEN tenant_type='EXTERNAL' THEN tenant_id END) AS new_tenant_qty,
    COUNT(CASE WHEN 1 = 1 THEN tenant_id END) AS tenant_cert_apply_qty,  -- 待确认：auth_status 变为 PENDING_REVIEW
    COUNT(CASE WHEN 1 = 1 THEN tenant_id END) AS tenant_cert_pass_qty  -- 待确认：auth_status 变为 CERTIFIED
  FROM dim.dim_sup_tenant_zip s
  WHERE s.travel_date = '${bizdate}' AND s.end_date = '9999-12-31'
  GROUP BY country_code, region_id, business_type_list_desc
) u
GROUP BY u.country_code, u.region_id, u.business_type;
