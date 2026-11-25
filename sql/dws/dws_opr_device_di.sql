-- dws.dws_opr_device_di  设备日汇总
-- 粒度：travel_date × tenant_id × device_id
-- 来源：dwd_opr_device_status_log_di, dwd_ord_verify_di
-- 生成方式：Spark SQL / Hive；字段 7 个：直接翻译 2 · 规则翻译 3 · 待确认 2
-- 多来源：每个来源表按粒度键先汇总，UNION ALL 后再合并
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT OVERWRITE TABLE dws.dws_opr_device_di PARTITION (travel_date = '${bizdate}')
SELECT
  u.tenant_id,
  u.device_id,
  SUM(u.online_minute_qty) AS online_minute_qty,
  SUM(u.offline_times_qty) AS offline_times_qty,
  SUM(u.verify_entitlement_qty) AS verify_entitlement_qty,
  SUM(u.device_total_qty) AS device_total_qty,
  SUM(u.offline_verify_qty) AS offline_verify_qty,
  CURRENT_TIMESTAMP() AS etl_time
FROM (
  -- 来源：dwd_opr_device_status_log_di
  SELECT
    tenant_id AS tenant_id,
    device_id AS device_id,
    NULL AS online_minute_qty,  -- 待确认：sum(状态区间分钟) where ACTIVE
    COUNT(CASE WHEN after_status='OFFLINE' THEN 1 END) AS offline_times_qty,
    NULL AS verify_entitlement_qty,
    NULL AS device_total_qty,
    NULL AS offline_verify_qty
  FROM dwd.dwd_opr_device_status_log_di s
  WHERE s.travel_date = '${bizdate}'
  GROUP BY tenant_id, device_id
  UNION ALL
  -- 来源：dwd_ord_verify_di
  SELECT
    tenant_id AS tenant_id,
    device_id AS device_id,
    NULL AS online_minute_qty,
    NULL AS offline_times_qty,
    COUNT(CASE WHEN 1 = 1 THEN verify_no END) AS verify_entitlement_qty,  -- 待确认：verify_result='SUCCESS'
    NULL AS device_total_qty,
    COUNT(CASE WHEN verify_type='OFFLINE' and verify_result_type = 'SUCCESS' THEN verify_no END) AS offline_verify_qty
  FROM dwd.dwd_ord_verify_di s
  WHERE s.travel_date = '${bizdate}'
  GROUP BY tenant_id, device_id
  UNION ALL
  -- 来源：dim_opr_device_df
  SELECT
    tenant_id AS tenant_id,
    device_id AS device_id,
    NULL AS online_minute_qty,
    NULL AS offline_times_qty,
    NULL AS verify_entitlement_qty,
    COUNT(device_id) AS device_total_qty,
    NULL AS offline_verify_qty
  FROM dim.dim_opr_device_df s
  WHERE s.travel_date = '${bizdate}'
  GROUP BY tenant_id, device_id
) u
GROUP BY u.tenant_id, u.device_id;
