-- dws.dws_fin_tenant_pay_method_di  商户×支付方式 收付款日汇总
-- 粒度：travel_date × tenant_id × pay_direction_type × pay_method_type × receive_channel_type
-- 来源：dwd_fin_payment_di, dwd_fin_refund_payment_di, dwd_fin_invoice_di
-- 生成方式：Spark SQL / Hive；字段 19 个：直接翻译 4 · 规则翻译 2 · 待确认 13
-- 多来源：每个来源表按粒度键先汇总，UNION ALL 后再合并
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT OVERWRITE TABLE dws.dws_fin_tenant_pay_method_di PARTITION (travel_date = '${bizdate}')
SELECT
  u.tenant_id,
  u.pay_direction_type,
  u.pay_method_type,
  u.receive_channel_type,
  SUM(u.pay_record_qty) AS pay_record_qty,
  SUM(u.inbound_pay_amt) AS inbound_pay_amt,
  SUM(u.outbound_pay_amt) AS outbound_pay_amt,
  SUM(u.refund_payment_amt) AS refund_payment_amt,
  SUM(u.zero_fee_order_qty) AS zero_fee_order_qty,
  SUM(u.credit_pay_amt) AS credit_pay_amt,
  SUM(u.invoice_amt) AS invoice_amt,
  SUM(u.invoice_order_qty) AS invoice_order_qty,
  SUM(u.pay_order_group_qty) AS pay_order_group_qty,
  CURRENT_TIMESTAMP() AS etl_time
FROM (
  -- 来源：dwd_fin_payment_di
  SELECT
    tenant_id AS tenant_id,
    pay_direction_type AS pay_direction_type,
    pay_method_type AS pay_method_type,
    receive_channel_type AS receive_channel_type,
    COUNT(CASE WHEN pay_status='PAID' THEN payment_no END) AS pay_record_qty,
    NULL AS inbound_pay_amt,  -- 待确认：sum(amount) where pay_direction='INBOUND' and PAID
    NULL AS outbound_pay_amt,  -- 待确认：sum(amount) where pay_direction='OUTBOUND' and PAID
    NULL AS refund_payment_amt,
    COUNT(CASE WHEN 1 = 1 THEN payment_no END) AS zero_fee_order_qty,  -- 待确认：pay_method='ZERO_FEE'
    NULL AS credit_pay_amt,  -- 待确认：sum(amount) where pay_method='CREDIT' and PAID
    NULL AS invoice_amt,
    NULL AS invoice_order_qty,
    NULL AS pay_order_group_qty
  FROM dwd.dwd_fin_payment_di s
  WHERE s.travel_date = '${bizdate}'
  GROUP BY tenant_id, pay_direction_type, pay_method_type, receive_channel_type
  UNION ALL
  -- 来源：dwd_fin_refund_payment_di
  SELECT
    tenant_id AS tenant_id,
    pay_direction_type AS pay_direction_type,
    pay_method_type AS pay_method_type,
    CAST(NULL AS STRING) AS receive_channel_type,
    NULL AS pay_record_qty,
    NULL AS inbound_pay_amt,
    NULL AS outbound_pay_amt,
    NULL AS refund_payment_amt,  -- 待确认：sum(refund_amount) where status='SUCCESS'
    NULL AS zero_fee_order_qty,
    NULL AS credit_pay_amt,
    NULL AS invoice_amt,
    NULL AS invoice_order_qty,
    NULL AS pay_order_group_qty
  FROM dwd.dwd_fin_refund_payment_di s
  WHERE s.travel_date = '${bizdate}'
  GROUP BY tenant_id, pay_direction_type, pay_method_type
  UNION ALL
  -- 来源：dwd_fin_invoice_di
  SELECT
    tenant_id AS tenant_id,
    CAST(NULL AS STRING) AS pay_direction_type,
    CAST(NULL AS STRING) AS pay_method_type,
    CAST(NULL AS STRING) AS receive_channel_type,
    NULL AS pay_record_qty,
    NULL AS inbound_pay_amt,
    NULL AS outbound_pay_amt,
    NULL AS refund_payment_amt,
    NULL AS zero_fee_order_qty,
    NULL AS credit_pay_amt,
    NULL AS invoice_amt,  -- 待确认：sum(invoice_amount) where INVOICED
    COUNT(DISTINCT CASE WHEN 1 = 1 THEN order_group_no END) AS invoice_order_qty,  -- 待确认：INVOICED and subject='MERCHANT_TO_VISITOR'
    NULL AS pay_order_group_qty
  FROM dwd.dwd_fin_invoice_di s
  WHERE s.travel_date = '${bizdate}'
  GROUP BY tenant_id
  UNION ALL
  -- 来源：dwd_ord_order_group_di
  SELECT
    tenant_id AS tenant_id,
    CAST(NULL AS STRING) AS pay_direction_type,
    CAST(NULL AS STRING) AS pay_method_type,
    channel_type AS receive_channel_type,
    NULL AS pay_record_qty,
    NULL AS inbound_pay_amt,
    NULL AS outbound_pay_amt,
    NULL AS refund_payment_amt,
    NULL AS zero_fee_order_qty,
    NULL AS credit_pay_amt,
    NULL AS invoice_amt,
    NULL AS invoice_order_qty,
    COUNT(DISTINCT CASE WHEN pay_status='PAID' THEN order_group_no END) AS pay_order_group_qty
  FROM dwd.dwd_ord_order_group_di s
  WHERE s.travel_date = '${bizdate}'
  GROUP BY tenant_id, channel_type
) u
GROUP BY u.tenant_id, u.pay_direction_type, u.pay_method_type, u.receive_channel_type;
