-- dws.dws_ord_tenant_sku_verify_di  商户×SKU×核销点 核销日汇总
-- 粒度：travel_date × seller_tenant_id × sku_id × verify_point_id × verify_type
-- 来源：dwd_ord_verify_di
-- 生成方式：Spark SQL / Hive；字段 13 个：直接翻译 4 · 规则翻译 1 · 待确认 8
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT OVERWRITE TABLE dws.dws_ord_tenant_sku_verify_di PARTITION (travel_date = '${bizdate}')
SELECT
  u.seller_tenant_id,
  u.sku_id,
  u.verify_point_id,
  u.verify_type,
  SUM(u.verify_ticket_qty) AS verify_ticket_qty,
  SUM(u.verify_entitlement_qty) AS verify_entitlement_qty,
  SUM(u.verify_person_qty) AS verify_person_qty,
  SUM(u.verify_fail_qty) AS verify_fail_qty,
  SUM(u.offline_verify_qty) AS offline_verify_qty,
  SUM(u.verify_amt) AS verify_amt,
  SUM(u.duplicate_verify_qty) AS duplicate_verify_qty,
  SUM(u.offline_conflict_qty) AS offline_conflict_qty,
  SUM(u.verify_after_pay_day_qty) AS verify_after_pay_day_qty,
  CURRENT_TIMESTAMP() AS etl_time
FROM (
  -- 来源：dwd_ord_verify_di
  SELECT
    seller_tenant_id AS seller_tenant_id,
    sku_id AS sku_id,
    verify_point_id AS verify_point_id,
    verify_type AS verify_type,
    COUNT(DISTINCT CASE WHEN 1 = 1 THEN ticket_no END) AS verify_ticket_qty,  -- 待确认：verify_result='SUCCESS'
    COUNT(CASE WHEN 1 = 1 THEN verify_no END) AS verify_entitlement_qty,  -- 待确认：verify_result='SUCCESS'
    COUNT(CASE WHEN 1 = 1 THEN verify_no END) AS verify_person_qty,  -- 待确认：SUCCESS（待补放行人数后改 sum(pass_count)）
    COUNT(CASE WHEN 1 = 1 THEN verify_no END) AS verify_fail_qty,  -- 待确认：verify_result in ('FAILED','DUPLICATE')
    COUNT(CASE WHEN verify_type='OFFLINE' and verify_result_type = 'SUCCESS' THEN verify_no END) AS offline_verify_qty,
    NULL AS verify_amt,  -- 待确认：sum(unit_price_amt) of verified tickets（同票只计1次）
    COUNT(CASE WHEN 1 = 1 THEN verify_no END) AS duplicate_verify_qty,  -- 待确认：verify_result='DUPLICATE'
    COUNT(CASE WHEN 1 = 1 THEN verify_no END) AS offline_conflict_qty,  -- 待确认：verify_type='OFFLINE' and verify_result='DUPLICATE'
    NULL AS verify_after_pay_day_qty  -- 待确认：sum(datediff(first_verify_date, pay_date))
  FROM dwd.dwd_ord_verify_di s
  WHERE s.travel_date = '${bizdate}'
  GROUP BY seller_tenant_id, sku_id, verify_point_id, verify_type
) u
GROUP BY u.seller_tenant_id, u.sku_id, u.verify_point_id, u.verify_type;
