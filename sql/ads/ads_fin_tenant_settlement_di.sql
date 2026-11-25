-- ads.ads_fin_tenant_settlement_di  商户结算对账
-- 粒度：travel_date × tenant_id
-- 来源：dws_fin_account_frozen_di, dws_fin_account_flow_di, dws_fin_tenant_pay_method_di
-- 生成方式：Spark SQL / Hive；字段 22 个：直接翻译 17 · 规则翻译 3 · 待确认 2
-- 多来源：每个来源表按粒度键先汇总，UNION ALL 后再合并
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT OVERWRITE TABLE ads.ads_fin_tenant_settlement_di PARTITION (travel_date = '${bizdate}')
SELECT
  x.tenant_id,
  d1.tenant_name AS tenant_name,
  x.inbound_pay_amt,
  x.outbound_pay_amt,
  x.refund_payment_amt,
  x.freeze_amt,
  x.unfreeze_verify_amt,
  x.unfreeze_refund_amt,
  x.fee_amt,
  x.profit_freeze_amt,
  x.settlement_freeze_amt,
  x.full_freeze_amt,
  x.external_freeze_amt,
  x.external_freeze_numerator_amt,
  x.external_freeze_denominator_amt,
  x.expire_release_amt,
  x.invoice_amt,
  x.invoice_order_qty,
  x.invoice_numerator_qty,
  x.invoice_denominator_qty,
  x.etl_time
FROM (
SELECT
  u.tenant_id,
  SUM(u.inbound_pay_amt) AS inbound_pay_amt,
  SUM(u.outbound_pay_amt) AS outbound_pay_amt,
  SUM(u.refund_payment_amt) AS refund_payment_amt,
  SUM(u.freeze_amt) AS freeze_amt,
  SUM(u.unfreeze_verify_amt) AS unfreeze_verify_amt,
  SUM(u.unfreeze_refund_amt) AS unfreeze_refund_amt,
  SUM(u.fee_amt) AS fee_amt,
  SUM(u.profit_freeze_amt) AS profit_freeze_amt,
  SUM(u.settlement_freeze_amt) AS settlement_freeze_amt,
  SUM(u.full_freeze_amt) AS full_freeze_amt,
  SUM(u.external_freeze_amt) AS external_freeze_amt,
  SUM(u.external_freeze_numerator_amt) AS external_freeze_numerator_amt,
  SUM(u.external_freeze_denominator_amt) AS external_freeze_denominator_amt,
  SUM(u.expire_release_amt) AS expire_release_amt,
  SUM(u.invoice_amt) AS invoice_amt,
  SUM(u.invoice_order_qty) AS invoice_order_qty,
  SUM(u.invoice_numerator_qty) AS invoice_numerator_qty,
  SUM(u.invoice_denominator_qty) AS invoice_denominator_qty,
  CURRENT_TIMESTAMP() AS etl_time
FROM (
  -- 来源：dws_fin_tenant_pay_method_di
  SELECT
    tenant_id AS tenant_id,
    SUM(inbound_pay_amt) AS inbound_pay_amt,
    SUM(outbound_pay_amt) AS outbound_pay_amt,
    SUM(refund_payment_amt) AS refund_payment_amt,
    NULL AS freeze_amt,
    NULL AS unfreeze_verify_amt,
    NULL AS unfreeze_refund_amt,
    NULL AS fee_amt,
    NULL AS profit_freeze_amt,
    NULL AS settlement_freeze_amt,
    NULL AS full_freeze_amt,
    NULL AS external_freeze_amt,
    NULL AS external_freeze_numerator_amt,
    NULL AS external_freeze_denominator_amt,
    NULL AS expire_release_amt,
    SUM(invoice_amt) AS invoice_amt,
    SUM(invoice_order_qty) AS invoice_order_qty,
    SUM(invoice_order_qty) AS invoice_numerator_qty,
    SUM(pay_order_group_qty) AS invoice_denominator_qty
  FROM dws.dws_fin_tenant_pay_method_di s
  WHERE s.travel_date = '${bizdate}'
  GROUP BY tenant_id
  UNION ALL
  -- 来源：dws_fin_account_frozen_di
  SELECT
    CAST(NULL AS BIGINT) AS tenant_id,
    NULL AS inbound_pay_amt,
    NULL AS outbound_pay_amt,
    NULL AS refund_payment_amt,
    SUM(freeze_amt) AS freeze_amt,
    SUM(unfreeze_verify_amt) AS unfreeze_verify_amt,
    SUM(unfreeze_refund_amt) AS unfreeze_refund_amt,
    NULL AS fee_amt,
    SUM(CASE WHEN freeze_type = 'PROFIT' THEN freeze_amt END) AS profit_freeze_amt,
    SUM(CASE WHEN freeze_type = 'SETTLEMENT' THEN freeze_amt END) AS settlement_freeze_amt,
    SUM(CASE WHEN freeze_type = 'FULL' THEN freeze_amt END) AS full_freeze_amt,
    SUM(external_freeze_amt) AS external_freeze_amt,
    SUM(external_freeze_amt) AS external_freeze_numerator_amt,
    SUM(freeze_amt) AS external_freeze_denominator_amt,
    SUM(expire_release_amt) AS expire_release_amt,
    NULL AS invoice_amt,
    NULL AS invoice_order_qty,
    NULL AS invoice_numerator_qty,
    NULL AS invoice_denominator_qty
  FROM dws.dws_fin_account_frozen_di s
  WHERE s.travel_date = '${bizdate}'
  UNION ALL
  -- 来源：dws_fin_account_flow_di
  SELECT
    CAST(NULL AS BIGINT) AS tenant_id,
    NULL AS inbound_pay_amt,
    NULL AS outbound_pay_amt,
    NULL AS refund_payment_amt,
    NULL AS freeze_amt,
    NULL AS unfreeze_verify_amt,
    NULL AS unfreeze_refund_amt,
    SUM(fee_amt) AS fee_amt,
    NULL AS profit_freeze_amt,
    NULL AS settlement_freeze_amt,
    NULL AS full_freeze_amt,
    NULL AS external_freeze_amt,
    NULL AS external_freeze_numerator_amt,
    NULL AS external_freeze_denominator_amt,
    NULL AS expire_release_amt,
    NULL AS invoice_amt,
    NULL AS invoice_order_qty,
    NULL AS invoice_numerator_qty,
    NULL AS invoice_denominator_qty
  FROM dws.dws_fin_account_flow_di s
  WHERE s.travel_date = '${bizdate}'
) u
GROUP BY u.tenant_id
) x
LEFT JOIN dim.dim_sup_tenant_zip d1 ON d1.tenant_id = x.tenant_id AND d1.travel_date = '${bizdate}' AND d1.end_date = '9999-12-31';
