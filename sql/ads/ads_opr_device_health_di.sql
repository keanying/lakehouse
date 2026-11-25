-- ads.ads_opr_device_health_di  设备健康
-- 粒度：travel_date × tenant_id × device_type
-- 来源：dws_opr_device_di, dws_ord_tenant_sku_verify_di
-- 生成方式：Spark SQL / Hive；字段 12 个：直接翻译 10 · 规则翻译 0 · 待确认 2
-- 多来源：每个来源表按粒度键先汇总，UNION ALL 后再合并
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT OVERWRITE TABLE ads.ads_opr_device_health_di PARTITION (travel_date = '${bizdate}')
SELECT
  x.tenant_id,
  x.device_type,
  d1.tenant_name AS tenant_name,
  x.device_online_numerator_qty,
  x.device_online_denominator_qty,
  x.offline_times_qty,
  x.offline_verify_numerator_qty,
  x.offline_verify_denominator_qty,
  x.offline_conflict_qty,
  x.device_total_qty,
  x.etl_time
FROM (
SELECT
  u.tenant_id,
  u.device_type,
  SUM(u.device_online_numerator_qty) AS device_online_numerator_qty,
  SUM(u.device_online_denominator_qty) AS device_online_denominator_qty,
  SUM(u.offline_times_qty) AS offline_times_qty,
  SUM(u.offline_verify_numerator_qty) AS offline_verify_numerator_qty,
  SUM(u.offline_verify_denominator_qty) AS offline_verify_denominator_qty,
  SUM(u.offline_conflict_qty) AS offline_conflict_qty,
  SUM(u.device_total_qty) AS device_total_qty,
  CURRENT_TIMESTAMP() AS etl_time
FROM (
  -- 来源：dws_opr_device_di
  SELECT
    tenant_id AS tenant_id,
    CAST(NULL AS STRING) AS device_type,
    SUM(online_minute_qty) AS device_online_numerator_qty,
    SUM(online_minute_qty) AS device_online_denominator_qty,
    SUM(offline_times_qty) AS offline_times_qty,
    SUM(offline_verify_qty) AS offline_verify_numerator_qty,
    SUM(verify_entitlement_qty) AS offline_verify_denominator_qty,
    NULL AS offline_conflict_qty,
    SUM(device_total_qty) AS device_total_qty
  FROM dws.dws_opr_device_di s
  WHERE s.travel_date = '${bizdate}'
  GROUP BY tenant_id
  UNION ALL
  -- 来源：dws_ord_tenant_sku_verify_di
  SELECT
    seller_tenant_id AS tenant_id,
    CAST(NULL AS STRING) AS device_type,
    NULL AS device_online_numerator_qty,
    NULL AS device_online_denominator_qty,
    NULL AS offline_times_qty,
    NULL AS offline_verify_numerator_qty,
    NULL AS offline_verify_denominator_qty,
    SUM(offline_conflict_qty) AS offline_conflict_qty,
    NULL AS device_total_qty
  FROM dws.dws_ord_tenant_sku_verify_di s
  WHERE s.travel_date = '${bizdate}'
  GROUP BY seller_tenant_id
) u
GROUP BY u.tenant_id, u.device_type
) x
LEFT JOIN dim.dim_sup_tenant_zip d1 ON d1.tenant_id = x.tenant_id AND d1.travel_date = '${bizdate}' AND d1.end_date = '9999-12-31';
