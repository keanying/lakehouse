-- ads.ads_cus_tourist_portrait_di  游客客源画像
-- 粒度：travel_date × seller_tenant_id × origin_province_code × age_band_code × gender_type
-- 来源：dws_cus_tourist_origin_di
-- 生成方式：Spark SQL / Hive；字段 14 个：直接翻译 14 · 规则翻译 0 · 待确认 0

INSERT OVERWRITE TABLE ads.ads_cus_tourist_portrait_di PARTITION (travel_date = '${bizdate}')
SELECT
  x.seller_tenant_id,
  x.origin_province_code,
  x.age_band_code,
  x.gender_type,
  d1.tenant_name AS seller_tenant_name,
  d2.province_name AS origin_province_name,
  x.tourist_qty,
  x.verify_person_qty,
  x.tourist_origin_share_numerator_qty,
  x.tourist_origin_share_denominator_qty,
  x.realname_numerator_qty,
  x.realname_denominator_qty,
  x.person_link_numerator_qty,
  x.person_link_denominator_qty,
  x.etl_time
FROM (
SELECT
  u.seller_tenant_id,
  u.origin_province_code,
  u.age_band_code,
  u.gender_type,
  SUM(u.tourist_qty) AS tourist_qty,
  SUM(u.verify_person_qty) AS verify_person_qty,
  SUM(u.tourist_origin_share_numerator_qty) AS tourist_origin_share_numerator_qty,
  SUM(u.tourist_origin_share_denominator_qty) AS tourist_origin_share_denominator_qty,
  SUM(u.realname_numerator_qty) AS realname_numerator_qty,
  SUM(u.realname_denominator_qty) AS realname_denominator_qty,
  SUM(u.person_link_numerator_qty) AS person_link_numerator_qty,
  SUM(u.person_link_denominator_qty) AS person_link_denominator_qty,
  CURRENT_TIMESTAMP() AS etl_time
FROM (
  -- 来源：dws_cus_tourist_origin_di
  SELECT
    seller_tenant_id AS seller_tenant_id,
    origin_province_code AS origin_province_code,
    age_band_code AS age_band_code,
    gender_type AS gender_type,
    SUM(tourist_qty) AS tourist_qty,
    SUM(verify_person_qty) AS verify_person_qty,
    SUM(tourist_qty) AS tourist_origin_share_numerator_qty,
    SUM(tourist_qty) AS tourist_origin_share_denominator_qty,
    SUM(realname_ticket_qty) AS realname_numerator_qty,
    SUM(issue_ticket_qty) AS realname_denominator_qty,
    SUM(person_linked_qty) AS person_link_numerator_qty,
    SUM(tourist_qty) AS person_link_denominator_qty
  FROM dws.dws_cus_tourist_origin_di s
  WHERE s.travel_date = '${bizdate}'
  GROUP BY seller_tenant_id, origin_province_code, age_band_code, gender_type
) u
GROUP BY u.seller_tenant_id, u.origin_province_code, u.age_band_code, u.gender_type
) x
LEFT JOIN dim.dim_sup_tenant_zip d1 ON d1.tenant_id = x.seller_tenant_id AND d1.travel_date = '${bizdate}' AND d1.end_date = '9999-12-31'
LEFT JOIN dim.dim_opr_region_f d2 ON d2.region_id = x.origin_province_code;
