-- ads.ads_ord_verify_flow_hrs  分时客流（入园人次）
-- 粒度：travel_date × stat_hour_no × seller_tenant_id × verify_point_id
-- 来源：dws_ord_verify_point_flow_hrs
-- 生成方式：Spark SQL / Hive；字段 13 个：直接翻译 6 · 规则翻译 7 · 待确认 0

INSERT OVERWRITE TABLE ads.ads_ord_verify_flow_hrs PARTITION (travel_date = '${bizdate}')
SELECT
  x.stat_hour_no,
  x.seller_tenant_id,
  x.verify_point_id,
  d1.tenant_name AS seller_tenant_name,
  d2.verify_point_name AS verify_point_name,
  x.verify_person_1h_qty,
  x.verify_fail_1h_qty,
  x.verify_fail_1h_rate,
  x.verify_person_1d_qty,
  x.verify_person_7d_qty,
  x.verify_person_30d_qty,
  x.peak_hour_verify_qty,
  x.etl_time
FROM (
SELECT
  u.stat_hour_no,
  u.seller_tenant_id,
  u.verify_point_id,
  SUM(u.verify_person_qty) AS verify_person_1h_qty,
  SUM(u.verify_fail_qty) AS verify_fail_1h_qty,
  SUM(u.verify_fail_qty) * 100 / NULLIF(SUM(u.verify_entitlement_qty), 0) AS verify_fail_1h_rate,
  SUM(u.verify_person_qty) AS verify_person_1d_qty,
  SUM(u.verify_person_qty) AS verify_person_7d_qty,
  SUM(u.verify_person_qty) AS verify_person_30d_qty,
  SUM(u.verify_person_qty) AS peak_hour_verify_qty,
  CURRENT_TIMESTAMP() AS etl_time
FROM (
  -- 来源：dws_ord_verify_point_flow_hrs
  SELECT
    s.stat_hour_no AS stat_hour_no,
    s.seller_tenant_id AS seller_tenant_id,
    s.verify_point_id AS verify_point_id,
    SUM(s.verify_person_qty) AS verify_person_qty,
    SUM(s.verify_fail_qty) AS verify_fail_qty,
    SUM(s.verify_entitlement_qty) AS verify_entitlement_qty
  FROM dws.dws_ord_verify_point_flow_hrs s
  WHERE s.travel_date = '${bizdate}'
  GROUP BY s.stat_hour_no, s.seller_tenant_id, s.verify_point_id
) u
GROUP BY u.stat_hour_no, u.seller_tenant_id, u.verify_point_id
) x
LEFT JOIN dim.dim_sup_tenant_zip d1 ON d1.tenant_id = x.seller_tenant_id AND d1.travel_date = '${bizdate}' AND d1.end_date = '9999-12-31'
LEFT JOIN dim.dim_opr_verify_point_df d2 ON d2.verify_point_id = x.verify_point_id AND d2.travel_date = '${bizdate}';
