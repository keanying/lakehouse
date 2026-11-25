-- ads.ads_sup_platform_overview_di  平台经营大盘
-- 粒度：travel_date
-- 来源：dws_sup_tenant_trade_di, dws_sup_tenant_onboard_di, dws_cus_tenant_growth_di
-- 生成方式：Spark SQL / Hive；字段 14 个：直接翻译 14 · 规则翻译 0 · 待确认 0
-- 多来源：每个来源表按粒度键先汇总，UNION ALL 后再合并

INSERT OVERWRITE TABLE ads.ads_sup_platform_overview_di PARTITION (travel_date = '${bizdate}')
SELECT
  SUM(u.pay_amt) AS pay_amt,
  SUM(u.net_pay_amt) AS net_pay_amt,
  SUM(u.verify_ticket_qty) AS verify_ticket_qty,
  SUM(u.gross_profit_amt) AS gross_profit_amt,
  BITMAP_UNION(u.active_tenant_bitmap) AS active_tenant_bitmap,
  SUM(u.new_tenant_qty) AS new_tenant_qty,
  SUM(u.new_customer_qty) AS new_customer_qty,
  BITMAP_UNION(u.pay_buyer_bitmap) AS pay_buyer_bitmap,
  SUM(u.tenant_cert_apply_qty) AS tenant_cert_apply_qty,
  SUM(u.tenant_cert_pass_qty) AS tenant_cert_pass_qty,
  SUM(u.tenant_cert_pass_numerator_qty) AS tenant_cert_pass_numerator_qty,
  SUM(u.tenant_cert_pass_denominator_qty) AS tenant_cert_pass_denominator_qty,
  BITMAP_UNION(u.sku_sell_numerator_bitmap) AS sku_sell_numerator_bitmap,
  SUM(u.sku_sell_denominator_qty) AS sku_sell_denominator_qty,
  CURRENT_TIMESTAMP() AS etl_time
FROM (
  -- 来源：dws_sup_tenant_trade_di
  SELECT
    SUM(pay_amt) AS pay_amt,
    SUM(net_pay_amt) AS net_pay_amt,
    SUM(verify_ticket_qty) AS verify_ticket_qty,
    SUM(pay_amt) AS gross_profit_amt,
    BITMAP_UNION(pay_amt) AS active_tenant_bitmap,
    NULL AS new_tenant_qty,
    SUM(new_customer_qty) AS new_customer_qty,
    BITMAP_UNION(pay_buyer_bitmap) AS pay_buyer_bitmap,
    NULL AS tenant_cert_apply_qty,
    NULL AS tenant_cert_pass_qty,
    NULL AS tenant_cert_pass_numerator_qty,
    NULL AS tenant_cert_pass_denominator_qty,
    BITMAP_UNION(sold_sku_bitmap) AS sku_sell_numerator_bitmap,
    SUM(on_sale_sku_qty) AS sku_sell_denominator_qty
  FROM dws.dws_sup_tenant_trade_di s
  WHERE s.travel_date = '${bizdate}'
  UNION ALL
  -- 来源：dws_sup_tenant_onboard_di
  SELECT
    NULL AS pay_amt,
    NULL AS net_pay_amt,
    NULL AS verify_ticket_qty,
    NULL AS gross_profit_amt,
    CAST(NULL AS BINARY) AS active_tenant_bitmap,
    SUM(new_tenant_qty) AS new_tenant_qty,
    NULL AS new_customer_qty,
    CAST(NULL AS BINARY) AS pay_buyer_bitmap,
    SUM(tenant_cert_apply_qty) AS tenant_cert_apply_qty,
    SUM(tenant_cert_pass_qty) AS tenant_cert_pass_qty,
    SUM(tenant_cert_pass_qty) AS tenant_cert_pass_numerator_qty,
    SUM(tenant_cert_apply_qty) AS tenant_cert_pass_denominator_qty,
    CAST(NULL AS BINARY) AS sku_sell_numerator_bitmap,
    NULL AS sku_sell_denominator_qty
  FROM dws.dws_sup_tenant_onboard_di s
  WHERE s.travel_date = '${bizdate}'
) u;
