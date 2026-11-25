-- dws.dws_sup_tenant_trade_di  商户经营日汇总
-- 粒度：travel_date × seller_tenant_id
-- 来源：dws_ord_tenant_sku_channel_trade_di, dws_ord_tenant_sku_verify_di, dws_ord_tenant_refund_di, dwd_cus_customer_register_di, dws_cus_customer_lifetime_df
-- 生成方式：Spark SQL / Hive；字段 21 个：直接翻译 2 · 规则翻译 17 · 待确认 2
-- 多来源：每个来源表按粒度键先汇总，UNION ALL 后再合并
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT OVERWRITE TABLE dws.dws_sup_tenant_trade_di PARTITION (travel_date = '${bizdate}')
SELECT
  u.seller_tenant_id,
  SUM(u.pay_order_qty) AS pay_order_qty,
  SUM(u.pay_ticket_qty) AS pay_ticket_qty,
  SUM(u.pay_amt) AS pay_amt,
  SUM(u.refund_amt) AS refund_amt,
  SUM(u.pay_amt) - SUM(u.refund_amt) AS net_pay_amt,
  SUM(u.verify_ticket_qty) AS verify_ticket_qty,
  SUM(u.verify_amt) AS verify_amt,
  BITMAP_COUNT(BITMAP_UNION(u.pay_buyer_bitmap)) AS pay_buyer_qty,
  BITMAP_UNION(u.pay_buyer_bitmap) AS pay_buyer_bitmap,
  SUM(u.new_customer_qty) AS new_customer_qty,
  SUM(u.on_sale_sku_qty) AS on_sale_sku_qty,
  SUM(u.cost_amt) AS cost_amt,
  SUM(u.sold_sku_qty) AS sold_sku_qty,
  BITMAP_UNION(u.sold_sku_bitmap) AS sold_sku_bitmap,
  SUM(u.first_pay_customer_qty) AS first_pay_customer_qty,
  SUM(u.pay_order_group_qty) AS pay_order_group_qty,
  SUM(u.refund_ticket_qty) AS refund_ticket_qty,
  SUM(u.order_qty) AS order_qty,
  SUM(u.pay_order_qty) * 100 / NULLIF(SUM(u.order_qty), 0) AS pay_conversion_rate,
  CURRENT_TIMESTAMP() AS etl_time
FROM (
  -- 来源：dws_ord_tenant_sku_channel_trade_di
  SELECT
    seller_tenant_id AS seller_tenant_id,
    SUM(pay_order_qty) AS pay_order_qty,
    SUM(pay_ticket_qty) AS pay_ticket_qty,
    SUM(pay_amt) AS pay_amt,
    NULL AS refund_amt,
    NULL AS verify_ticket_qty,
    NULL AS verify_amt,
    BITMAP_UNION(pay_buyer_bitmap) AS pay_buyer_bitmap,
    NULL AS new_customer_qty,
    NULL AS on_sale_sku_qty,
    SUM(cost_amt) AS cost_amt,
    COUNT(DISTINCT CASE WHEN pay_amt>0 THEN sku_id END) AS sold_sku_qty,
    BITMAP_UNION(TO_BITMAP(CASE WHEN pay_amt>0 THEN sku_id END)) AS sold_sku_bitmap,
    NULL AS first_pay_customer_qty,
    SUM(pay_order_group_qty) AS pay_order_group_qty,
    NULL AS refund_ticket_qty,
    SUM(order_qty) AS order_qty
  FROM dws.dws_ord_tenant_sku_channel_trade_di s
  WHERE s.travel_date = '${bizdate}'
  GROUP BY seller_tenant_id
  UNION ALL
  -- 来源：dws_ord_tenant_refund_di
  SELECT
    seller_tenant_id AS seller_tenant_id,
    NULL AS pay_order_qty,
    NULL AS pay_ticket_qty,
    NULL AS pay_amt,
    SUM(refund_amt) AS refund_amt,
    NULL AS verify_ticket_qty,
    NULL AS verify_amt,
    CAST(NULL AS BINARY) AS pay_buyer_bitmap,
    NULL AS new_customer_qty,
    NULL AS on_sale_sku_qty,
    NULL AS cost_amt,
    NULL AS sold_sku_qty,
    CAST(NULL AS BINARY) AS sold_sku_bitmap,
    NULL AS first_pay_customer_qty,
    NULL AS pay_order_group_qty,
    SUM(refund_ticket_qty) AS refund_ticket_qty,
    NULL AS order_qty
  FROM dws.dws_ord_tenant_refund_di s
  WHERE s.travel_date = '${bizdate}'
  GROUP BY seller_tenant_id
  UNION ALL
  -- 来源：dws_ord_tenant_sku_verify_di
  SELECT
    seller_tenant_id AS seller_tenant_id,
    NULL AS pay_order_qty,
    NULL AS pay_ticket_qty,
    NULL AS pay_amt,
    NULL AS refund_amt,
    SUM(verify_ticket_qty) AS verify_ticket_qty,
    SUM(verify_amt) AS verify_amt,
    CAST(NULL AS BINARY) AS pay_buyer_bitmap,
    NULL AS new_customer_qty,
    NULL AS on_sale_sku_qty,
    NULL AS cost_amt,
    NULL AS sold_sku_qty,
    CAST(NULL AS BINARY) AS sold_sku_bitmap,
    NULL AS first_pay_customer_qty,
    NULL AS pay_order_group_qty,
    NULL AS refund_ticket_qty,
    NULL AS order_qty
  FROM dws.dws_ord_tenant_sku_verify_di s
  WHERE s.travel_date = '${bizdate}'
  GROUP BY seller_tenant_id
  UNION ALL
  -- 来源：dwd_cus_customer_register_di
  SELECT
    CAST(NULL AS BIGINT) AS seller_tenant_id,
    NULL AS pay_order_qty,
    NULL AS pay_ticket_qty,
    NULL AS pay_amt,
    NULL AS refund_amt,
    NULL AS verify_ticket_qty,
    NULL AS verify_amt,
    CAST(NULL AS BINARY) AS pay_buyer_bitmap,
    COUNT(CASE WHEN 1 = 1 THEN customer_id END) AS new_customer_qty,  -- 待确认：kind='REAL'
    NULL AS on_sale_sku_qty,
    NULL AS cost_amt,
    NULL AS sold_sku_qty,
    CAST(NULL AS BINARY) AS sold_sku_bitmap,
    NULL AS first_pay_customer_qty,
    NULL AS pay_order_group_qty,
    NULL AS refund_ticket_qty,
    NULL AS order_qty
  FROM dwd.dwd_cus_customer_register_di s
  WHERE s.travel_date = '${bizdate}'
  UNION ALL
  -- 来源：dim_prd_sku_zip
  SELECT
    tenant_id AS seller_tenant_id,
    NULL AS pay_order_qty,
    NULL AS pay_ticket_qty,
    NULL AS pay_amt,
    NULL AS refund_amt,
    NULL AS verify_ticket_qty,
    NULL AS verify_amt,
    CAST(NULL AS BINARY) AS pay_buyer_bitmap,
    NULL AS new_customer_qty,
    COUNT(CASE WHEN sku_status='PUBLISHED' THEN sku_id END) AS on_sale_sku_qty,
    NULL AS cost_amt,
    NULL AS sold_sku_qty,
    CAST(NULL AS BINARY) AS sold_sku_bitmap,
    NULL AS first_pay_customer_qty,
    NULL AS pay_order_group_qty,
    NULL AS refund_ticket_qty,
    NULL AS order_qty
  FROM dim.dim_prd_sku_zip s
  WHERE s.travel_date = '${bizdate}' AND s.end_date = '9999-12-31'
  GROUP BY tenant_id
  UNION ALL
  -- 来源：dws_cus_customer_lifetime_df
  SELECT
    seller_tenant_id AS seller_tenant_id,
    NULL AS pay_order_qty,
    NULL AS pay_ticket_qty,
    NULL AS pay_amt,
    NULL AS refund_amt,
    NULL AS verify_ticket_qty,
    NULL AS verify_amt,
    CAST(NULL AS BINARY) AS pay_buyer_bitmap,
    NULL AS new_customer_qty,
    NULL AS on_sale_sku_qty,
    NULL AS cost_amt,
    NULL AS sold_sku_qty,
    CAST(NULL AS BINARY) AS sold_sku_bitmap,
    COUNT(CASE WHEN DATE_FORMAT(first_pay_date, 'yyyyMMdd') = '${bizdate}' THEN buyer_customer_id END) AS first_pay_customer_qty,
    NULL AS pay_order_group_qty,
    NULL AS refund_ticket_qty,
    NULL AS order_qty
  FROM dws.dws_cus_customer_lifetime_df s
  WHERE s.travel_date = '${bizdate}'
  GROUP BY seller_tenant_id
) u
GROUP BY u.seller_tenant_id;
