-- ads.ads_fin_pay_method_di  支付方式结构
-- 粒度：travel_date × tenant_id
-- 来源：dws_fin_tenant_pay_method_di
-- 生成方式：Spark SQL / Hive；字段 23 个：直接翻译 3 · 规则翻译 20 · 待确认 0

INSERT OVERWRITE TABLE ads.ads_fin_pay_method_di PARTITION (travel_date = '${bizdate}')
SELECT
  x.tenant_id,
  d1.tenant_name AS tenant_name,
  x.wechat_inbound_pay_amt,
  x.alipay_inbound_pay_amt,
  x.balance_inbound_pay_amt,
  x.credit_inbound_pay_amt,
  x.offline_inbound_pay_amt,
  x.wechat_pay_record_qty,
  x.alipay_pay_record_qty,
  x.balance_pay_record_qty,
  x.credit_pay_record_qty,
  x.offline_pay_record_qty,
  x.wechat_pay_method_share_numerator_amt,
  x.wechat_pay_method_share_denominator_amt,
  x.alipay_pay_method_share_numerator_amt,
  x.alipay_pay_method_share_denominator_amt,
  x.balance_pay_method_share_numerator_amt,
  x.balance_pay_method_share_denominator_amt,
  x.credit_pay_method_share_numerator_amt,
  x.credit_pay_method_share_denominator_amt,
  x.offline_pay_method_share_numerator_amt,
  x.offline_pay_method_share_denominator_amt,
  x.zero_fee_order_qty,
  x.etl_time
FROM (
SELECT
  u.tenant_id,
  SUM(u.wechat_inbound_pay_amt) AS wechat_inbound_pay_amt,
  SUM(u.alipay_inbound_pay_amt) AS alipay_inbound_pay_amt,
  SUM(u.balance_inbound_pay_amt) AS balance_inbound_pay_amt,
  SUM(u.credit_inbound_pay_amt) AS credit_inbound_pay_amt,
  SUM(u.offline_inbound_pay_amt) AS offline_inbound_pay_amt,
  SUM(u.wechat_pay_record_qty) AS wechat_pay_record_qty,
  SUM(u.alipay_pay_record_qty) AS alipay_pay_record_qty,
  SUM(u.balance_pay_record_qty) AS balance_pay_record_qty,
  SUM(u.credit_pay_record_qty) AS credit_pay_record_qty,
  SUM(u.offline_pay_record_qty) AS offline_pay_record_qty,
  SUM(u.wechat_pay_method_share_numerator_amt) AS wechat_pay_method_share_numerator_amt,
  SUM(u.wechat_pay_method_share_denominator_amt) AS wechat_pay_method_share_denominator_amt,
  SUM(u.alipay_pay_method_share_numerator_amt) AS alipay_pay_method_share_numerator_amt,
  SUM(u.alipay_pay_method_share_denominator_amt) AS alipay_pay_method_share_denominator_amt,
  SUM(u.balance_pay_method_share_numerator_amt) AS balance_pay_method_share_numerator_amt,
  SUM(u.balance_pay_method_share_denominator_amt) AS balance_pay_method_share_denominator_amt,
  SUM(u.credit_pay_method_share_numerator_amt) AS credit_pay_method_share_numerator_amt,
  SUM(u.credit_pay_method_share_denominator_amt) AS credit_pay_method_share_denominator_amt,
  SUM(u.offline_pay_method_share_numerator_amt) AS offline_pay_method_share_numerator_amt,
  SUM(u.offline_pay_method_share_denominator_amt) AS offline_pay_method_share_denominator_amt,
  SUM(u.zero_fee_order_qty) AS zero_fee_order_qty,
  CURRENT_TIMESTAMP() AS etl_time
FROM (
  -- 来源：dws_fin_tenant_pay_method_di
  SELECT
    tenant_id AS tenant_id,
    SUM(CASE WHEN pay_method_type = 'WECHAT' THEN inbound_pay_amt END) AS wechat_inbound_pay_amt,
    SUM(CASE WHEN pay_method_type = 'ALIPAY' THEN inbound_pay_amt END) AS alipay_inbound_pay_amt,
    SUM(CASE WHEN pay_method_type = 'BALANCE' THEN inbound_pay_amt END) AS balance_inbound_pay_amt,
    SUM(CASE WHEN pay_method_type = 'CREDIT' THEN inbound_pay_amt END) AS credit_inbound_pay_amt,
    SUM(CASE WHEN pay_method_type = 'OFFLINE' THEN inbound_pay_amt END) AS offline_inbound_pay_amt,
    SUM(CASE WHEN pay_method_type = 'WECHAT' THEN pay_record_qty END) AS wechat_pay_record_qty,
    SUM(CASE WHEN pay_method_type = 'ALIPAY' THEN pay_record_qty END) AS alipay_pay_record_qty,
    SUM(CASE WHEN pay_method_type = 'BALANCE' THEN pay_record_qty END) AS balance_pay_record_qty,
    SUM(CASE WHEN pay_method_type = 'CREDIT' THEN pay_record_qty END) AS credit_pay_record_qty,
    SUM(CASE WHEN pay_method_type = 'OFFLINE' THEN pay_record_qty END) AS offline_pay_record_qty,
    SUM(CASE WHEN pay_method_type = 'WECHAT' THEN inbound_pay_amt END) AS wechat_pay_method_share_numerator_amt,
    SUM(CASE WHEN pay_method_type = 'WECHAT' THEN inbound_pay_amt END) AS wechat_pay_method_share_denominator_amt,
    SUM(CASE WHEN pay_method_type = 'ALIPAY' THEN inbound_pay_amt END) AS alipay_pay_method_share_numerator_amt,
    SUM(CASE WHEN pay_method_type = 'ALIPAY' THEN inbound_pay_amt END) AS alipay_pay_method_share_denominator_amt,
    SUM(CASE WHEN pay_method_type = 'BALANCE' THEN inbound_pay_amt END) AS balance_pay_method_share_numerator_amt,
    SUM(CASE WHEN pay_method_type = 'BALANCE' THEN inbound_pay_amt END) AS balance_pay_method_share_denominator_amt,
    SUM(CASE WHEN pay_method_type = 'CREDIT' THEN inbound_pay_amt END) AS credit_pay_method_share_numerator_amt,
    SUM(CASE WHEN pay_method_type = 'CREDIT' THEN inbound_pay_amt END) AS credit_pay_method_share_denominator_amt,
    SUM(CASE WHEN pay_method_type = 'OFFLINE' THEN inbound_pay_amt END) AS offline_pay_method_share_numerator_amt,
    SUM(CASE WHEN pay_method_type = 'OFFLINE' THEN inbound_pay_amt END) AS offline_pay_method_share_denominator_amt,
    SUM(zero_fee_order_qty) AS zero_fee_order_qty
  FROM dws.dws_fin_tenant_pay_method_di s
  WHERE s.travel_date = '${bizdate}'
  GROUP BY tenant_id
) u
GROUP BY u.tenant_id
) x
LEFT JOIN dim.dim_sup_tenant_zip d1 ON d1.tenant_id = x.tenant_id AND d1.travel_date = '${bizdate}' AND d1.end_date = '9999-12-31';
