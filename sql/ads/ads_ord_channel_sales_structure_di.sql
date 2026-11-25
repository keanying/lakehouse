-- ads.ads_ord_channel_sales_structure_di  渠道销售结构
-- 粒度：travel_date × seller_tenant_id
-- 来源：dws_ord_tenant_sku_channel_trade_di
-- 生成方式：Spark SQL / Hive；字段 29 个：直接翻译 4 · 规则翻译 25 · 待确认 0

INSERT OVERWRITE TABLE ads.ads_ord_channel_sales_structure_di PARTITION (travel_date = '${bizdate}')
SELECT
  x.seller_tenant_id,
  d1.tenant_name AS seller_tenant_name,
  x.mp_pay_amt,
  x.h5_pay_amt,
  x.pc_pay_amt,
  x.offline_pay_amt,
  x.api_pay_amt,
  x.mp_pay_ticket_qty,
  x.h5_pay_ticket_qty,
  x.pc_pay_ticket_qty,
  x.offline_pay_ticket_qty,
  x.api_pay_ticket_qty,
  x.mp_pay_order_qty,
  x.h5_pay_order_qty,
  x.pc_pay_order_qty,
  x.offline_pay_order_qty,
  x.api_pay_order_qty,
  x.mp_channel_pay_share_numerator_amt,
  x.mp_channel_pay_share_denominator_amt,
  x.h5_channel_pay_share_numerator_amt,
  x.h5_channel_pay_share_denominator_amt,
  x.pc_channel_pay_share_numerator_amt,
  x.pc_channel_pay_share_denominator_amt,
  x.offline_channel_pay_share_numerator_amt,
  x.offline_channel_pay_share_denominator_amt,
  x.api_channel_pay_share_numerator_amt,
  x.api_channel_pay_share_denominator_amt,
  x.staff_order_qty,
  x.staff_pay_amt,
  x.etl_time
FROM (
SELECT
  u.seller_tenant_id,
  SUM(u.mp_pay_amt) AS mp_pay_amt,
  SUM(u.h5_pay_amt) AS h5_pay_amt,
  SUM(u.pc_pay_amt) AS pc_pay_amt,
  SUM(u.offline_pay_amt) AS offline_pay_amt,
  SUM(u.api_pay_amt) AS api_pay_amt,
  SUM(u.mp_pay_ticket_qty) AS mp_pay_ticket_qty,
  SUM(u.h5_pay_ticket_qty) AS h5_pay_ticket_qty,
  SUM(u.pc_pay_ticket_qty) AS pc_pay_ticket_qty,
  SUM(u.offline_pay_ticket_qty) AS offline_pay_ticket_qty,
  SUM(u.api_pay_ticket_qty) AS api_pay_ticket_qty,
  SUM(u.mp_pay_order_qty) AS mp_pay_order_qty,
  SUM(u.h5_pay_order_qty) AS h5_pay_order_qty,
  SUM(u.pc_pay_order_qty) AS pc_pay_order_qty,
  SUM(u.offline_pay_order_qty) AS offline_pay_order_qty,
  SUM(u.api_pay_order_qty) AS api_pay_order_qty,
  SUM(u.mp_channel_pay_share_numerator_amt) AS mp_channel_pay_share_numerator_amt,
  SUM(u.mp_channel_pay_share_denominator_amt) AS mp_channel_pay_share_denominator_amt,
  SUM(u.h5_channel_pay_share_numerator_amt) AS h5_channel_pay_share_numerator_amt,
  SUM(u.h5_channel_pay_share_denominator_amt) AS h5_channel_pay_share_denominator_amt,
  SUM(u.pc_channel_pay_share_numerator_amt) AS pc_channel_pay_share_numerator_amt,
  SUM(u.pc_channel_pay_share_denominator_amt) AS pc_channel_pay_share_denominator_amt,
  SUM(u.offline_channel_pay_share_numerator_amt) AS offline_channel_pay_share_numerator_amt,
  SUM(u.offline_channel_pay_share_denominator_amt) AS offline_channel_pay_share_denominator_amt,
  SUM(u.api_channel_pay_share_numerator_amt) AS api_channel_pay_share_numerator_amt,
  SUM(u.api_channel_pay_share_denominator_amt) AS api_channel_pay_share_denominator_amt,
  SUM(u.staff_order_qty) AS staff_order_qty,
  SUM(u.staff_pay_amt) AS staff_pay_amt,
  CURRENT_TIMESTAMP() AS etl_time
FROM (
  -- 来源：dws_ord_tenant_sku_channel_trade_di
  SELECT
    seller_tenant_id AS seller_tenant_id,
    SUM(CASE WHEN ch.channel_type = 'MP' THEN pay_amt END) AS mp_pay_amt,
    SUM(CASE WHEN ch.channel_type = 'H5' THEN pay_amt END) AS h5_pay_amt,
    SUM(CASE WHEN ch.channel_type = 'PC' THEN pay_amt END) AS pc_pay_amt,
    SUM(CASE WHEN ch.channel_type = 'OFFLINE' THEN pay_amt END) AS offline_pay_amt,
    SUM(CASE WHEN ch.channel_type = 'API' THEN pay_amt END) AS api_pay_amt,
    SUM(CASE WHEN ch.channel_type = 'MP' THEN pay_ticket_qty END) AS mp_pay_ticket_qty,
    SUM(CASE WHEN ch.channel_type = 'H5' THEN pay_ticket_qty END) AS h5_pay_ticket_qty,
    SUM(CASE WHEN ch.channel_type = 'PC' THEN pay_ticket_qty END) AS pc_pay_ticket_qty,
    SUM(CASE WHEN ch.channel_type = 'OFFLINE' THEN pay_ticket_qty END) AS offline_pay_ticket_qty,
    SUM(CASE WHEN ch.channel_type = 'API' THEN pay_ticket_qty END) AS api_pay_ticket_qty,
    SUM(CASE WHEN ch.channel_type = 'MP' THEN pay_order_qty END) AS mp_pay_order_qty,
    SUM(CASE WHEN ch.channel_type = 'H5' THEN pay_order_qty END) AS h5_pay_order_qty,
    SUM(CASE WHEN ch.channel_type = 'PC' THEN pay_order_qty END) AS pc_pay_order_qty,
    SUM(CASE WHEN ch.channel_type = 'OFFLINE' THEN pay_order_qty END) AS offline_pay_order_qty,
    SUM(CASE WHEN ch.channel_type = 'API' THEN pay_order_qty END) AS api_pay_order_qty,
    SUM(CASE WHEN ch.channel_type = 'MP' THEN pay_amt END) AS mp_channel_pay_share_numerator_amt,
    SUM(CASE WHEN ch.channel_type = 'MP' THEN pay_amt END) AS mp_channel_pay_share_denominator_amt,
    SUM(CASE WHEN ch.channel_type = 'H5' THEN pay_amt END) AS h5_channel_pay_share_numerator_amt,
    SUM(CASE WHEN ch.channel_type = 'H5' THEN pay_amt END) AS h5_channel_pay_share_denominator_amt,
    SUM(CASE WHEN ch.channel_type = 'PC' THEN pay_amt END) AS pc_channel_pay_share_numerator_amt,
    SUM(CASE WHEN ch.channel_type = 'PC' THEN pay_amt END) AS pc_channel_pay_share_denominator_amt,
    SUM(CASE WHEN ch.channel_type = 'OFFLINE' THEN pay_amt END) AS offline_channel_pay_share_numerator_amt,
    SUM(CASE WHEN ch.channel_type = 'OFFLINE' THEN pay_amt END) AS offline_channel_pay_share_denominator_amt,
    SUM(CASE WHEN ch.channel_type = 'API' THEN pay_amt END) AS api_channel_pay_share_numerator_amt,
    SUM(CASE WHEN ch.channel_type = 'API' THEN pay_amt END) AS api_channel_pay_share_denominator_amt,
    SUM(staff_order_qty) AS staff_order_qty,
    SUM(pay_amt) AS staff_pay_amt
  FROM dws.dws_ord_tenant_sku_channel_trade_di s
  LEFT JOIN dim.dim_trf_channel_df ch ON ch.channel_id = s.channel_id AND ch.travel_date = '${bizdate}'
  WHERE s.travel_date = '${bizdate}'
  GROUP BY seller_tenant_id
) u
GROUP BY u.seller_tenant_id
) x
LEFT JOIN dim.dim_sup_tenant_zip d1 ON d1.tenant_id = x.seller_tenant_id AND d1.travel_date = '${bizdate}' AND d1.end_date = '9999-12-31';
