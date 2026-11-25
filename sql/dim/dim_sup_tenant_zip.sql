-- dim.dim_sup_tenant_zip  租户（商户/供应商/分销商）维度
-- 粒度：1行=1个租户×1个有效区间
-- 来源：ods_sup_tenant_df + ods_sup_tenant_config_df + ods_opr_package_subscription_di
-- 生成方式：Spark SQL / Hive（拉链表）；字段 22 个：直接翻译 19 · 规则翻译 2 · 待确认 1
-- 拉链：比对今日源数据与昨日拉链的行哈希，变化的旧版本闭链、新版本开链；源为全量快照，消失的主键闭链
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

WITH src AS (                       -- 今日最新状态
  SELECT
    a.id AS tenant_id,
    a.tenant_no AS tenant_no,
    a.tenant_name AS tenant_name,
    a.tenant_type AS tenant_type,
    a.contact_phone AS contact_phone_no,
    a.country_code AS country_code,
    a.region_id AS region_id,
    a.region_path AS region_path_desc,
    a.business_types AS business_type_list_desc,
    a.auth_status AS auth_status,
    a.register_source AS register_source_code,
    a.tenant_status AS tenant_status,
    a.create_time AS create_time,
    a.update_time AS update_time,
    j1.country_name AS country_name,
    j2.province_name AS province_name,
    j2.city_name AS city_name,
    j3.v AS currency_code,
    j4.v AS locale_code,
    j5.package_id AS package_id,  -- 待确认：ods_opr_package_subscription_di.package_id 取生效中最新一笔
    j5.expire_at AS package_expire_time
  FROM ods.ods_sup_tenant_df a
  LEFT JOIN dim.dim_opr_region_f j1
    ON j1.country_code = a.country_code
  LEFT JOIN dim.dim_opr_region_f j2
    ON j2.region_id = a.region_id
  LEFT JOIN (SELECT tenant_id, MAX(config_value) AS v FROM ods.ods_sup_tenant_config_df WHERE travel_date = '${bizdate}' AND config_key = 'CURRENCY' GROUP BY tenant_id) j3
    ON j3.tenant_id = a.id
  LEFT JOIN (SELECT tenant_id, MAX(config_value) AS v FROM ods.ods_sup_tenant_config_df WHERE travel_date = '${bizdate}' AND config_key = 'LOCALE' GROUP BY tenant_id) j4
    ON j4.tenant_id = a.id
  LEFT JOIN ods.ods_opr_package_subscription_di j5
    ON j5.tenant_id = a.id
   AND j5.travel_date = '${bizdate}'
  WHERE a.travel_date = '${bizdate}'
),
src_h AS (SELECT s.*, MD5(CONCAT_WS('|', CAST(tenant_no AS STRING), CAST(tenant_name AS STRING), CAST(tenant_type AS STRING), CAST(contact_phone_no AS STRING), CAST(country_code AS STRING), CAST(region_id AS STRING), CAST(region_path_desc AS STRING), CAST(business_type_list_desc AS STRING), CAST(auth_status AS STRING), CAST(register_source_code AS STRING), CAST(tenant_status AS STRING), CAST(create_time AS STRING), CAST(update_time AS STRING), CAST(country_name AS STRING), CAST(province_name AS STRING), CAST(city_name AS STRING), CAST(currency_code AS STRING), CAST(locale_code AS STRING), CAST(package_id AS STRING), CAST(package_expire_time AS STRING))) AS row_hash FROM src s),
his AS (                               -- 昨日拉链
  SELECT h.*, MD5(CONCAT_WS('|', CAST(h.tenant_no AS STRING), CAST(h.tenant_name AS STRING), CAST(h.tenant_type AS STRING), CAST(h.contact_phone_no AS STRING), CAST(h.country_code AS STRING), CAST(h.region_id AS STRING), CAST(h.region_path_desc AS STRING), CAST(h.business_type_list_desc AS STRING), CAST(h.auth_status AS STRING), CAST(h.register_source_code AS STRING), CAST(h.tenant_status AS STRING), CAST(h.create_time AS STRING), CAST(h.update_time AS STRING), CAST(h.country_name AS STRING), CAST(h.province_name AS STRING), CAST(h.city_name AS STRING), CAST(h.currency_code AS STRING), CAST(h.locale_code AS STRING), CAST(h.package_id AS STRING), CAST(h.package_expire_time AS STRING))) AS row_hash
  FROM dim.dim_sup_tenant_zip h
  WHERE h.travel_date = '${bizdate_prev}'
)
INSERT OVERWRITE TABLE dim.dim_sup_tenant_zip PARTITION (travel_date = '${bizdate}')
-- ① 历史记录：当前有效版本若有变化或已删除则闭链（结束日 = 昨天）
SELECT h.tenant_id, h.tenant_no, h.tenant_name, h.tenant_type, h.contact_phone_no, h.country_code, h.region_id, h.region_path_desc, h.business_type_list_desc, h.auth_status, h.register_source_code, h.tenant_status, h.create_time, h.update_time, h.country_name, h.province_name, h.city_name, h.currency_code, h.locale_code, h.package_id, h.package_expire_time,
  h.start_date,
  CASE WHEN h.end_date = '9999-12-31' AND (s.row_hash IS NULL OR s.row_hash <> h.row_hash)
       THEN '${bizdate_prev_dash}' ELSE h.end_date END AS end_date,
  CURRENT_TIMESTAMP() AS etl_time
FROM his h
LEFT JOIN src_h s ON s.tenant_id = h.tenant_id
UNION ALL
-- ② 新增或变化的记录开新链（开始日 = 今天，结束日 = 9999-12-31）
SELECT s.tenant_id, s.tenant_no, s.tenant_name, s.tenant_type, s.contact_phone_no, s.country_code, s.region_id, s.region_path_desc, s.business_type_list_desc, s.auth_status, s.register_source_code, s.tenant_status, s.create_time, s.update_time, s.country_name, s.province_name, s.city_name, s.currency_code, s.locale_code, s.package_id, s.package_expire_time,
  '${bizdate_dash}' AS start_date,
  '9999-12-31' AS end_date,
  CURRENT_TIMESTAMP() AS etl_time
FROM src_h s
LEFT JOIN his h ON h.tenant_id = s.tenant_id AND h.end_date = '9999-12-31'
WHERE h.tenant_id IS NULL OR h.row_hash <> s.row_hash;
