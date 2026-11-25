-- dws.dws_cus_tourist_origin_di  游客客源画像日汇总
-- 粒度：travel_date × seller_tenant_id × sku_id × origin_province_code × origin_city_code × age_band_code × gender_type
-- 来源：dwd_ord_ticket_person_di, dwd_ord_verify_di, dwd_ord_ticket_di
-- 生成方式：Spark SQL / Hive；字段 19 个：直接翻译 6 · 规则翻译 4 · 待确认 9
-- 多来源：每个来源表按粒度键先汇总，UNION ALL 后再合并
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT OVERWRITE TABLE dws.dws_cus_tourist_origin_di PARTITION (travel_date = '${bizdate}')
SELECT
  u.seller_tenant_id,
  u.sku_id,
  u.origin_province_code,
  u.origin_city_code,
  u.age_band_code,
  u.gender_type,
  SUM(u.tourist_qty) AS tourist_qty,
  SUM(u.verify_person_qty) AS verify_person_qty,
  SUM(u.person_linked_qty) AS person_linked_qty,
  SUM(u.realname_ticket_qty) AS realname_ticket_qty,
  SUM(u.issue_ticket_qty) AS issue_ticket_qty,
  CURRENT_TIMESTAMP() AS etl_time
FROM (
  -- 来源：dwd_ord_ticket_person_di
  SELECT
    seller_tenant_id AS seller_tenant_id,
    sku_id AS sku_id,
    origin_province_code AS origin_province_code,
    origin_city_code AS origin_city_code,
    age_band_code AS age_band_code,
    gender_type AS gender_type,
    COUNT(ticket_no||person_id) AS tourist_qty,
    NULL AS verify_person_qty,
    COUNT(CASE WHEN global_customer_id>0 THEN 1 END) AS person_linked_qty,
    COUNT(CASE WHEN person_qty>0 THEN ticket_no END) AS realname_ticket_qty,
    NULL AS issue_ticket_qty
  FROM dwd.dwd_ord_ticket_person_di s
  WHERE s.travel_date = '${bizdate}'
  GROUP BY seller_tenant_id, sku_id, origin_province_code, origin_city_code, age_band_code, gender_type
  UNION ALL
  -- 来源：dwd_ord_verify_di
  SELECT
    seller_tenant_id AS seller_tenant_id,
    sku_id AS sku_id,
    CAST(NULL AS STRING) AS origin_province_code,
    CAST(NULL AS STRING) AS origin_city_code,
    CAST(NULL AS STRING) AS age_band_code,
    CAST(NULL AS STRING) AS gender_type,
    NULL AS tourist_qty,
    COUNT(CASE WHEN 1 = 1 THEN verify_no END) AS verify_person_qty,  -- 待确认：SUCCESS（待补放行人数后改 sum(pass_count)）
    NULL AS person_linked_qty,
    NULL AS realname_ticket_qty,
    NULL AS issue_ticket_qty
  FROM dwd.dwd_ord_verify_di s
  WHERE s.travel_date = '${bizdate}'
  GROUP BY seller_tenant_id, sku_id
  UNION ALL
  -- 来源：dwd_ord_ticket_di
  SELECT
    seller_tenant_id AS seller_tenant_id,
    sku_id AS sku_id,
    CAST(NULL AS STRING) AS origin_province_code,
    CAST(NULL AS STRING) AS origin_city_code,
    CAST(NULL AS STRING) AS age_band_code,
    CAST(NULL AS STRING) AS gender_type,
    NULL AS tourist_qty,
    NULL AS verify_person_qty,
    NULL AS person_linked_qty,
    NULL AS realname_ticket_qty,
    COUNT(ticket_no) AS issue_ticket_qty
  FROM dwd.dwd_ord_ticket_di s
  WHERE s.travel_date = '${bizdate}'
  GROUP BY seller_tenant_id, sku_id
) u
GROUP BY u.seller_tenant_id, u.sku_id, u.origin_province_code, u.origin_city_code, u.age_band_code, u.gender_type;
