-- dws.dws_ord_tenant_refund_di  商户×SKU 退款日汇总
-- 粒度：travel_date × seller_tenant_id × sku_id × refund_type × initiator_type × refund_reason_desc
-- 来源：dwd_ord_refund_di, dwd_ord_refund_ticket_di
-- 生成方式：Spark SQL / Hive；字段 14 个：直接翻译 5 · 规则翻译 4 · 待确认 5
-- 多来源：每个来源表按粒度键先汇总，UNION ALL 后再合并
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT OVERWRITE TABLE dws.dws_ord_tenant_refund_di PARTITION (travel_date = '${bizdate}')
SELECT
  u.seller_tenant_id,
  u.sku_id,
  u.refund_type,
  u.initiator_type,
  u.refund_reason_desc,
  SUM(u.refund_apply_qty) AS refund_apply_qty,
  SUM(u.refund_success_qty) AS refund_success_qty,
  SUM(u.refund_ticket_qty) AS refund_ticket_qty,
  SUM(u.refund_amt) AS refund_amt,
  SUM(u.refund_process_hour_qty) AS refund_process_hour_qty,
  SUM(u.auto_approve_refund_qty) AS auto_approve_refund_qty,
  SUM(u.refund_reject_qty) AS refund_reject_qty,
  SUM(u.verified_refund_ticket_qty) AS verified_refund_ticket_qty,
  CURRENT_TIMESTAMP() AS etl_time
FROM (
  -- 来源：dwd_ord_refund_di
  SELECT
    seller_tenant_id AS seller_tenant_id,
    CAST(NULL AS BIGINT) AS sku_id,
    refund_type AS refund_type,
    initiator_type AS initiator_type,
    refund_reason_desc AS refund_reason_desc,
    COUNT(refund_no) AS refund_apply_qty,
    COUNT(CASE WHEN refund_status='COMPLETED' THEN refund_no END) AS refund_success_qty,
    NULL AS refund_ticket_qty,
    NULL AS refund_amt,
    NULL AS refund_process_hour_qty,  -- 待确认：sum(hours(complete_time - create_time))
    COUNT(CASE WHEN 1 = 1 THEN refund_no END) AS auto_approve_refund_qty,  -- 待确认：approve_type='AUTO_TIMEOUT'
    COUNT(CASE WHEN refund_status='REJECTED' THEN refund_no END) AS refund_reject_qty,
    NULL AS verified_refund_ticket_qty
  FROM dwd.dwd_ord_refund_di s
  WHERE s.travel_date = '${bizdate}'
  GROUP BY seller_tenant_id, refund_type, initiator_type, refund_reason_desc
  UNION ALL
  -- 来源：dwd_ord_refund_ticket_di
  SELECT
    seller_tenant_id AS seller_tenant_id,
    sku_id AS sku_id,
    refund_type AS refund_type,
    initiator_type AS initiator_type,
    refund_reason_desc AS refund_reason_desc,
    NULL AS refund_apply_qty,
    NULL AS refund_success_qty,
    COUNT(DISTINCT CASE WHEN 1 = 1 THEN ticket_no END) AS refund_ticket_qty,  -- 待确认：of completed refunds
    SUM(CASE WHEN refund_status = 'COMPLETED' THEN refund_amt END) AS refund_amt,
    NULL AS refund_process_hour_qty,
    NULL AS auto_approve_refund_qty,
    NULL AS refund_reject_qty,
    COUNT(CASE WHEN 1 = 1 THEN ticket_no END) AS verified_refund_ticket_qty  -- 待确认：ticket_status_at_refund in ('PARTIALLY_USED','USED')
  FROM dwd.dwd_ord_refund_ticket_di s
  WHERE s.travel_date = '${bizdate}'
  GROUP BY seller_tenant_id, sku_id, refund_type, initiator_type, refund_reason_desc
) u
GROUP BY u.seller_tenant_id, u.sku_id, u.refund_type, u.initiator_type, u.refund_reason_desc;
