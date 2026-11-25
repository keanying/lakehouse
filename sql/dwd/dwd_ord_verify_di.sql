-- dwd.dwd_ord_verify_di  核销明细（权益级）
-- 粒度：1行=1次核销（verify_no）
-- 来源：ods_ord_verify_record_di + dwd_ord_entitlement_di + dwd_ord_ticket_di
-- 生成方式：Spark SQL / Hive；字段 28 个：直接翻译 24 · 规则翻译 3 · 待确认 1
-- 流水/状态变更类：保留每条变更记录
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT OVERWRITE TABLE dwd.dwd_ord_verify_di PARTITION (travel_date = '${bizdate}')
SELECT
  a.id                                                         AS verify_id,
  a.verify_no                                                  AS verify_no,
  a.ticket_no                                                  AS ticket_no,
  a.entitlement_no                                             AS entitlement_no,
  a.verify_point_id                                            AS verify_point_id,
  a.operator_id                                                AS operator_id,
  a.device_id                                                  AS device_id,
  a.verify_type                                                AS verify_type,
  a.offline_timestamp                                          AS offline_device_time,
  a.verify_result                                              AS verify_result_type,
  a.tenant_id                                                  AS tenant_id,
  a.create_time                                                AS create_time,
  a.update_time                                                AS update_time,
  j1.order_no                                                  AS order_no,
  j1.seller_tenant_id                                          AS seller_tenant_id,
  j1.sku_id                                                    AS sku_id,
  j1.spu_id                                                    AS spu_id,
  j1.play_date                                                 AS play_date,
  j2.entitlement_type                                          AS entitlement_type,
  j3.verify_point_type                                         AS verify_point_type,
  j4.device_type                                               AS device_type,
  a.create_time                                                AS verify_time,
  HOUR(a.create_time)                                          AS verify_hour_no,
  NULL                                                         AS verify_person_qty,  -- 待确认：dwd_ord_entitlement_binding_di 按 ticket_no+entitlement_no 计人数，开放模式记 1
  1                                                            AS verify_qty,
  j1.unit_price_amt / NULLIF(j2.max_qty, 0)                    AS verify_amt,
  CASE WHEN a.verify_result='DUPLICATE' AND a.verify_type ='OFFLINE' THEN 1 ELSE 0 END AS offline_conflict_type,
  CURRENT_TIMESTAMP()                                          AS etl_time
FROM ods.ods_ord_verify_record_di a
LEFT JOIN dwd.dwd_ord_ticket_di j1
  ON j1.ticket_no = a.ticket_no
 AND j1.travel_date = '${bizdate}'
LEFT JOIN dwd.dwd_ord_entitlement_di j2
  ON j2.entitlement_no = a.entitlement_no
 AND j2.travel_date = '${bizdate}'
LEFT JOIN dim.dim_opr_verify_point_df j3
  ON j3.verify_point_id = a.verify_point_id
 AND j3.travel_date = '${bizdate}'
LEFT JOIN dim.dim_opr_device_df j4
  ON j4.device_id = a.device_id
 AND j4.travel_date = '${bizdate}'
WHERE a.travel_date = '${bizdate}';
