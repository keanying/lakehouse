-- dws.dws_sup_staff_operate_di  员工操作日汇总（窗口/导游/核销员）
-- 粒度：travel_date × tenant_id × staff_id
-- 来源：dwd_ord_order_group_di, dwd_ord_verify_di, dwd_ord_refund_di
-- 生成方式：Spark SQL / Hive；字段 7 个：直接翻译 2 · 规则翻译 1 · 待确认 4
-- 多来源：每个来源表按粒度键先汇总，UNION ALL 后再合并
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT OVERWRITE TABLE dws.dws_sup_staff_operate_di PARTITION (travel_date = '${bizdate}')
SELECT
  u.tenant_id,
  u.staff_id,
  SUM(u.staff_order_qty) AS staff_order_qty,
  SUM(u.staff_pay_amt) AS staff_pay_amt,
  SUM(u.staff_verify_qty) AS staff_verify_qty,
  SUM(u.staff_refund_qty) AS staff_refund_qty,
  CURRENT_TIMESTAMP() AS etl_time
FROM (
  -- 来源：dwd_ord_order_di
  SELECT
    tenant_id AS tenant_id,
    CAST(NULL AS BIGINT) AS staff_id,
    COUNT(CASE WHEN operator_type='TENANT_STAFF' THEN order_no END) AS staff_order_qty,
    NULL AS staff_pay_amt,  -- 待确认：sum(pay_amt) where operator_type='TENANT_STAFF'
    NULL AS staff_verify_qty,
    NULL AS staff_refund_qty
  FROM dwd.dwd_ord_order_di s
  WHERE s.travel_date = '${bizdate}'
  GROUP BY tenant_id
  UNION ALL
  -- 来源：dwd_ord_verify_di
  SELECT
    tenant_id AS tenant_id,
    operator_id AS staff_id,
    NULL AS staff_order_qty,
    NULL AS staff_pay_amt,
    COUNT(CASE WHEN 1 = 1 THEN verify_no END) AS staff_verify_qty,  -- 待确认：group by operator_id
    NULL AS staff_refund_qty
  FROM dwd.dwd_ord_verify_di s
  WHERE s.travel_date = '${bizdate}'
  GROUP BY tenant_id, operator_id
  UNION ALL
  -- 来源：dwd_ord_refund_di
  SELECT
    tenant_id AS tenant_id,
    approver_id AS staff_id,
    NULL AS staff_order_qty,
    NULL AS staff_pay_amt,
    NULL AS staff_verify_qty,
    COUNT(CASE WHEN 1 = 1 THEN refund_no END) AS staff_refund_qty  -- 待确认：group by initiator_id
  FROM dwd.dwd_ord_refund_di s
  WHERE s.travel_date = '${bizdate}'
  GROUP BY tenant_id, approver_id
) u
GROUP BY u.tenant_id, u.staff_id;
