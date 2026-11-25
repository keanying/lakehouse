-- ads.ads_sup_staff_performance_di  员工/窗口业绩
-- 粒度：travel_date × tenant_id × staff_id
-- 来源：dws_sup_staff_operate_di
-- 生成方式：Spark SQL / Hive；字段 8 个：直接翻译 8 · 规则翻译 0 · 待确认 0

INSERT OVERWRITE TABLE ads.ads_sup_staff_performance_di PARTITION (travel_date = '${bizdate}')
SELECT
  x.tenant_id,
  x.staff_id,
  d1.tenant_name AS tenant_name,
  d2.staff_name AS staff_name,
  x.staff_order_qty,
  x.staff_pay_amt,
  x.staff_verify_qty,
  x.staff_refund_qty,
  x.etl_time
FROM (
SELECT
  u.tenant_id,
  u.staff_id,
  SUM(u.staff_order_qty) AS staff_order_qty,
  SUM(u.staff_pay_amt) AS staff_pay_amt,
  SUM(u.staff_verify_qty) AS staff_verify_qty,
  SUM(u.staff_refund_qty) AS staff_refund_qty,
  CURRENT_TIMESTAMP() AS etl_time
FROM (
  -- 来源：dws_sup_staff_operate_di
  SELECT
    tenant_id AS tenant_id,
    staff_id AS staff_id,
    SUM(staff_order_qty) AS staff_order_qty,
    SUM(staff_pay_amt) AS staff_pay_amt,
    SUM(staff_verify_qty) AS staff_verify_qty,
    SUM(staff_refund_qty) AS staff_refund_qty
  FROM dws.dws_sup_staff_operate_di s
  WHERE s.travel_date = '${bizdate}'
  GROUP BY tenant_id, staff_id
) u
GROUP BY u.tenant_id, u.staff_id
) x
LEFT JOIN dim.dim_sup_tenant_zip d1 ON d1.tenant_id = x.tenant_id AND d1.travel_date = '${bizdate}' AND d1.end_date = '9999-12-31'
LEFT JOIN dim.dim_sup_staff_zip d2 ON d2.staff_id = x.staff_id AND d2.travel_date = '${bizdate}' AND d2.end_date = '9999-12-31';
