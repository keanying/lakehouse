-- ads.ads_ord_refund_analysis_di  退款分析
-- 粒度：travel_date × seller_tenant_id × refund_reason_desc
-- 来源：dws_ord_tenant_refund_di, dws_sup_tenant_trade_di
-- 生成方式：Spark SQL / Hive；字段 27 个：直接翻译 18 · 规则翻译 6 · 待确认 3
-- 多来源：每个来源表按粒度键先汇总，UNION ALL 后再合并
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT OVERWRITE TABLE ads.ads_ord_refund_analysis_di PARTITION (travel_date = '${bizdate}')
SELECT
  x.seller_tenant_id,
  x.refund_reason_desc,
  d1.tenant_name AS seller_tenant_name,
  x.refund_apply_qty,
  x.refund_success_qty,
  x.refund_ticket_qty,
  x.refund_amt,
  x.refund_reject_qty,
  x.auto_approve_refund_qty,
  x.verified_refund_ticket_qty,
  x.refund_numerator_qty,
  x.refund_denominator_qty,
  x.refund_amt_numerator_amt,
  x.refund_amt_denominator_amt,
  x.cancel_numerator_qty,
  x.cancel_denominator_qty,
  x.timeout_cancel_numerator_qty,
  x.timeout_cancel_denominator_qty,
  x.visitor_refund_ticket_qty,
  x.merchant_refund_ticket_qty,
  x.ota_refund_ticket_qty,
  x.system_refund_ticket_qty,
  x.visitor_refund_amt,
  x.merchant_refund_amt,
  x.ota_refund_amt,
  x.system_refund_amt,
  x.etl_time
FROM (
SELECT
  u.seller_tenant_id,
  u.refund_reason_desc,
  SUM(u.refund_apply_qty) AS refund_apply_qty,
  SUM(u.refund_success_qty) AS refund_success_qty,
  SUM(u.refund_ticket_qty) AS refund_ticket_qty,
  SUM(u.refund_amt) AS refund_amt,
  SUM(u.refund_reject_qty) AS refund_reject_qty,
  SUM(u.auto_approve_refund_qty) AS auto_approve_refund_qty,
  SUM(u.verified_refund_ticket_qty) AS verified_refund_ticket_qty,
  SUM(u.refund_numerator_qty) AS refund_numerator_qty,
  SUM(u.refund_denominator_qty) AS refund_denominator_qty,
  SUM(u.refund_amt_numerator_amt) AS refund_amt_numerator_amt,
  SUM(u.refund_amt_denominator_amt) AS refund_amt_denominator_amt,
  SUM(u.cancel_numerator_qty) AS cancel_numerator_qty,
  SUM(u.cancel_denominator_qty) AS cancel_denominator_qty,
  SUM(u.timeout_cancel_numerator_qty) AS timeout_cancel_numerator_qty,
  SUM(u.timeout_cancel_denominator_qty) AS timeout_cancel_denominator_qty,
  SUM(u.visitor_refund_ticket_qty) AS visitor_refund_ticket_qty,
  SUM(u.merchant_refund_ticket_qty) AS merchant_refund_ticket_qty,
  SUM(u.ota_refund_ticket_qty) AS ota_refund_ticket_qty,
  SUM(u.system_refund_ticket_qty) AS system_refund_ticket_qty,
  SUM(u.visitor_refund_amt) AS visitor_refund_amt,
  SUM(u.merchant_refund_amt) AS merchant_refund_amt,
  SUM(u.ota_refund_amt) AS ota_refund_amt,
  SUM(u.system_refund_amt) AS system_refund_amt,
  CURRENT_TIMESTAMP() AS etl_time
FROM (
  -- 来源：dws_ord_tenant_refund_di
  SELECT
    seller_tenant_id AS seller_tenant_id,
    refund_reason_desc AS refund_reason_desc,
    SUM(refund_apply_qty) AS refund_apply_qty,
    SUM(refund_success_qty) AS refund_success_qty,
    SUM(refund_ticket_qty) AS refund_ticket_qty,
    SUM(refund_amt) AS refund_amt,
    SUM(refund_reject_qty) AS refund_reject_qty,
    SUM(auto_approve_refund_qty) AS auto_approve_refund_qty,
    SUM(verified_refund_ticket_qty) AS verified_refund_ticket_qty,
    SUM(refund_ticket_qty) AS refund_numerator_qty,
    NULL AS refund_denominator_qty,
    SUM(refund_amt) AS refund_amt_numerator_amt,
    NULL AS refund_amt_denominator_amt,
    NULL AS cancel_numerator_qty,
    NULL AS cancel_denominator_qty,
    NULL AS timeout_cancel_numerator_qty,
    NULL AS timeout_cancel_denominator_qty,
    SUM(CASE WHEN initiator_type = 'VISITOR' THEN refund_ticket_qty END) AS visitor_refund_ticket_qty,
    SUM(CASE WHEN initiator_type = 'MERCHANT' THEN refund_ticket_qty END) AS merchant_refund_ticket_qty,
    SUM(CASE WHEN 1 = 1 THEN refund_ticket_qty END) AS ota_refund_ticket_qty,  -- 待确认：修饰词 退款发起方=OTA发起 在 dws_ord_tenant_refund_di 中找不到对应字段
    SUM(CASE WHEN initiator_type = 'SYSTEM' THEN refund_ticket_qty END) AS system_refund_ticket_qty,
    SUM(CASE WHEN initiator_type = 'VISITOR' THEN refund_amt END) AS visitor_refund_amt,
    SUM(CASE WHEN initiator_type = 'MERCHANT' THEN refund_amt END) AS merchant_refund_amt,
    SUM(CASE WHEN 1 = 1 THEN refund_amt END) AS ota_refund_amt,  -- 待确认：修饰词 退款发起方=OTA发起 在 dws_ord_tenant_refund_di 中找不到对应字段
    SUM(CASE WHEN initiator_type = 'SYSTEM' THEN refund_amt END) AS system_refund_amt
  FROM dws.dws_ord_tenant_refund_di s
  WHERE s.travel_date = '${bizdate}'
  GROUP BY seller_tenant_id, refund_reason_desc
  UNION ALL
  -- 来源：dws_sup_tenant_trade_di
  SELECT
    seller_tenant_id AS seller_tenant_id,
    CAST(NULL AS STRING) AS refund_reason_desc,
    NULL AS refund_apply_qty,
    NULL AS refund_success_qty,
    NULL AS refund_ticket_qty,
    NULL AS refund_amt,
    NULL AS refund_reject_qty,
    NULL AS auto_approve_refund_qty,
    NULL AS verified_refund_ticket_qty,
    NULL AS refund_numerator_qty,
    SUM(pay_ticket_qty) AS refund_denominator_qty,
    NULL AS refund_amt_numerator_amt,
    SUM(pay_amt) AS refund_amt_denominator_amt,
    SUM(order_qty) AS cancel_numerator_qty,
    SUM(order_qty) AS cancel_denominator_qty,
    SUM(order_qty) AS timeout_cancel_numerator_qty,
    SUM(order_qty) AS timeout_cancel_denominator_qty,
    NULL AS visitor_refund_ticket_qty,
    NULL AS merchant_refund_ticket_qty,
    NULL AS ota_refund_ticket_qty,
    NULL AS system_refund_ticket_qty,
    NULL AS visitor_refund_amt,
    NULL AS merchant_refund_amt,
    NULL AS ota_refund_amt,
    NULL AS system_refund_amt
  FROM dws.dws_sup_tenant_trade_di s
  WHERE s.travel_date = '${bizdate}'
  GROUP BY seller_tenant_id
) u
GROUP BY u.seller_tenant_id, u.refund_reason_desc
) x
LEFT JOIN dim.dim_sup_tenant_zip d1 ON d1.tenant_id = x.seller_tenant_id AND d1.travel_date = '${bizdate}' AND d1.end_date = '9999-12-31';
