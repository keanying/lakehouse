-- ads.ads_ord_tenant_trade_overview_di  商户经营概览
-- 粒度：travel_date × seller_tenant_id
-- 来源：dws_sup_tenant_trade_di
-- 生成方式：Spark SQL / Hive；字段 24 个：直接翻译 24 · 规则翻译 0 · 待确认 0

INSERT OVERWRITE TABLE ads.ads_ord_tenant_trade_overview_di PARTITION (travel_date = '${bizdate}')
SELECT
  x.seller_tenant_id,
  d1.tenant_name AS seller_tenant_name,
  x.pay_amt,
  x.net_pay_amt,
  x.pay_order_qty,
  x.pay_ticket_qty,
  x.pay_buyer_bitmap,
  x.verify_ticket_qty,
  x.verify_amt,
  x.refund_amt,
  x.cost_amt,
  x.gross_profit_amt,
  x.per_customer_numerator_amt,
  x.per_customer_denominator_bitmap,
  x.avg_ticket_price_numerator_amt,
  x.avg_ticket_price_denominator_qty,
  x.verify_numerator_qty,
  x.verify_denominator_qty,
  x.refund_numerator_qty,
  x.refund_denominator_qty,
  x.gross_profit_numerator_amt,
  x.gross_profit_denominator_amt,
  x.pay_conversion_numerator_qty,
  x.pay_conversion_denominator_qty,
  x.etl_time
FROM (
SELECT
  u.seller_tenant_id,
  SUM(u.pay_amt) AS pay_amt,
  SUM(u.net_pay_amt) AS net_pay_amt,
  SUM(u.pay_order_qty) AS pay_order_qty,
  SUM(u.pay_ticket_qty) AS pay_ticket_qty,
  BITMAP_UNION(u.pay_buyer_bitmap) AS pay_buyer_bitmap,
  SUM(u.verify_ticket_qty) AS verify_ticket_qty,
  SUM(u.verify_amt) AS verify_amt,
  SUM(u.refund_amt) AS refund_amt,
  SUM(u.cost_amt) AS cost_amt,
  SUM(u.gross_profit_amt) AS gross_profit_amt,
  SUM(u.per_customer_numerator_amt) AS per_customer_numerator_amt,
  BITMAP_UNION(u.per_customer_denominator_bitmap) AS per_customer_denominator_bitmap,
  SUM(u.avg_ticket_price_numerator_amt) AS avg_ticket_price_numerator_amt,
  SUM(u.avg_ticket_price_denominator_qty) AS avg_ticket_price_denominator_qty,
  SUM(u.verify_numerator_qty) AS verify_numerator_qty,
  SUM(u.verify_denominator_qty) AS verify_denominator_qty,
  SUM(u.refund_numerator_qty) AS refund_numerator_qty,
  SUM(u.refund_denominator_qty) AS refund_denominator_qty,
  SUM(u.gross_profit_numerator_amt) AS gross_profit_numerator_amt,
  SUM(u.gross_profit_denominator_amt) AS gross_profit_denominator_amt,
  SUM(u.pay_conversion_numerator_qty) AS pay_conversion_numerator_qty,
  SUM(u.pay_conversion_denominator_qty) AS pay_conversion_denominator_qty,
  CURRENT_TIMESTAMP() AS etl_time
FROM (
  -- 来源：dws_sup_tenant_trade_di
  SELECT
    seller_tenant_id AS seller_tenant_id,
    SUM(pay_amt) AS pay_amt,
    SUM(net_pay_amt) AS net_pay_amt,
    SUM(pay_order_qty) AS pay_order_qty,
    SUM(pay_ticket_qty) AS pay_ticket_qty,
    BITMAP_UNION(pay_buyer_bitmap) AS pay_buyer_bitmap,
    SUM(verify_ticket_qty) AS verify_ticket_qty,
    SUM(verify_amt) AS verify_amt,
    SUM(refund_amt) AS refund_amt,
    SUM(cost_amt) AS cost_amt,
    SUM(pay_amt) AS gross_profit_amt,
    SUM(pay_amt) AS per_customer_numerator_amt,
    BITMAP_UNION(pay_buyer_bitmap) AS per_customer_denominator_bitmap,
    SUM(pay_amt) AS avg_ticket_price_numerator_amt,
    SUM(pay_ticket_qty) AS avg_ticket_price_denominator_qty,
    SUM(verify_ticket_qty) AS verify_numerator_qty,
    SUM(pay_ticket_qty) AS verify_denominator_qty,
    SUM(refund_ticket_qty) AS refund_numerator_qty,
    SUM(pay_ticket_qty) AS refund_denominator_qty,
    SUM(pay_amt) AS gross_profit_numerator_amt,
    SUM(pay_amt) AS gross_profit_denominator_amt,
    SUM(pay_order_qty) AS pay_conversion_numerator_qty,
    SUM(order_qty) AS pay_conversion_denominator_qty
  FROM dws.dws_sup_tenant_trade_di s
  WHERE s.travel_date = '${bizdate}'
  GROUP BY seller_tenant_id
) u
GROUP BY u.seller_tenant_id
) x
LEFT JOIN dim.dim_sup_tenant_zip d1 ON d1.tenant_id = x.seller_tenant_id AND d1.travel_date = '${bizdate}' AND d1.end_date = '9999-12-31';
