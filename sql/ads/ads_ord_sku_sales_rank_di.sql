-- ads.ads_ord_sku_sales_rank_di  SKU销售排行
-- 粒度：travel_date × seller_tenant_id × sku_id
-- 来源：dws_ord_tenant_sku_channel_trade_di, dws_ord_tenant_refund_di
-- 生成方式：Spark SQL / Hive；字段 17 个：直接翻译 17 · 规则翻译 0 · 待确认 0
-- 多来源：每个来源表按粒度键先汇总，UNION ALL 后再合并

INSERT OVERWRITE TABLE ads.ads_ord_sku_sales_rank_di PARTITION (travel_date = '${bizdate}')
SELECT
  x.seller_tenant_id,
  x.sku_id,
  d1.tenant_name AS seller_tenant_name,
  d2.sku_name AS sku_name,
  x.pay_amt,
  x.pay_ticket_qty,
  x.net_pay_amt,
  x.gross_profit_amt,
  x.refund_ticket_qty,
  x.avg_ticket_price_numerator_amt,
  x.avg_ticket_price_denominator_qty,
  x.gross_profit_numerator_amt,
  x.gross_profit_denominator_amt,
  x.pay_conversion_numerator_qty,
  x.pay_conversion_denominator_qty,
  x.refund_numerator_qty,
  x.refund_denominator_qty,
  x.etl_time
FROM (
SELECT
  u.seller_tenant_id,
  u.sku_id,
  SUM(u.pay_amt) AS pay_amt,
  SUM(u.pay_ticket_qty) AS pay_ticket_qty,
  SUM(u.net_pay_amt) AS net_pay_amt,
  SUM(u.gross_profit_amt) AS gross_profit_amt,
  SUM(u.refund_ticket_qty) AS refund_ticket_qty,
  SUM(u.avg_ticket_price_numerator_amt) AS avg_ticket_price_numerator_amt,
  SUM(u.avg_ticket_price_denominator_qty) AS avg_ticket_price_denominator_qty,
  SUM(u.gross_profit_numerator_amt) AS gross_profit_numerator_amt,
  SUM(u.gross_profit_denominator_amt) AS gross_profit_denominator_amt,
  SUM(u.pay_conversion_numerator_qty) AS pay_conversion_numerator_qty,
  SUM(u.pay_conversion_denominator_qty) AS pay_conversion_denominator_qty,
  SUM(u.refund_numerator_qty) AS refund_numerator_qty,
  SUM(u.refund_denominator_qty) AS refund_denominator_qty,
  CURRENT_TIMESTAMP() AS etl_time
FROM (
  -- 来源：dws_ord_tenant_sku_channel_trade_di
  SELECT
    seller_tenant_id AS seller_tenant_id,
    sku_id AS sku_id,
    SUM(pay_amt) AS pay_amt,
    SUM(pay_ticket_qty) AS pay_ticket_qty,
    SUM(pay_amt) AS net_pay_amt,
    SUM(pay_amt) AS gross_profit_amt,
    NULL AS refund_ticket_qty,
    SUM(pay_amt) AS avg_ticket_price_numerator_amt,
    SUM(pay_ticket_qty) AS avg_ticket_price_denominator_qty,
    SUM(pay_amt) AS gross_profit_numerator_amt,
    SUM(pay_amt) AS gross_profit_denominator_amt,
    SUM(pay_order_qty) AS pay_conversion_numerator_qty,
    SUM(order_qty) AS pay_conversion_denominator_qty,
    NULL AS refund_numerator_qty,
    SUM(pay_ticket_qty) AS refund_denominator_qty
  FROM dws.dws_ord_tenant_sku_channel_trade_di s
  WHERE s.travel_date = '${bizdate}'
  GROUP BY seller_tenant_id, sku_id
  UNION ALL
  -- 来源：dws_ord_tenant_refund_di
  SELECT
    seller_tenant_id AS seller_tenant_id,
    sku_id AS sku_id,
    NULL AS pay_amt,
    NULL AS pay_ticket_qty,
    NULL AS net_pay_amt,
    NULL AS gross_profit_amt,
    SUM(refund_ticket_qty) AS refund_ticket_qty,
    NULL AS avg_ticket_price_numerator_amt,
    NULL AS avg_ticket_price_denominator_qty,
    NULL AS gross_profit_numerator_amt,
    NULL AS gross_profit_denominator_amt,
    NULL AS pay_conversion_numerator_qty,
    NULL AS pay_conversion_denominator_qty,
    SUM(refund_ticket_qty) AS refund_numerator_qty,
    NULL AS refund_denominator_qty
  FROM dws.dws_ord_tenant_refund_di s
  WHERE s.travel_date = '${bizdate}'
  GROUP BY seller_tenant_id, sku_id
) u
GROUP BY u.seller_tenant_id, u.sku_id
) x
LEFT JOIN dim.dim_sup_tenant_zip d1 ON d1.tenant_id = x.seller_tenant_id AND d1.travel_date = '${bizdate}' AND d1.end_date = '9999-12-31'
LEFT JOIN dim.dim_prd_sku_zip d2 ON d2.sku_id = x.sku_id AND d2.travel_date = '${bizdate}' AND d2.end_date = '9999-12-31';
