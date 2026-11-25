-- ads.ads_ord_trade_efficiency_di  交易时效分析
-- 粒度：travel_date × seller_tenant_id × sku_id
-- 来源：dws_ord_tenant_sku_channel_trade_di, dws_ord_tenant_refund_di, dws_ord_tenant_sku_verify_di
-- 生成方式：Spark SQL / Hive；字段 13 个：直接翻译 13 · 规则翻译 0 · 待确认 0
-- 多来源：每个来源表按粒度键先汇总，UNION ALL 后再合并

INSERT OVERWRITE TABLE ads.ads_ord_trade_efficiency_di PARTITION (travel_date = '${bizdate}')
SELECT
  x.seller_tenant_id,
  x.sku_id,
  d1.tenant_name AS seller_tenant_name,
  d2.sku_name AS sku_name,
  x.avg_pay_minute_numerator_qty,
  x.avg_pay_minute_denominator_qty,
  x.avg_refund_process_hour_numerator_qty,
  x.avg_refund_process_hour_denominator_qty,
  x.avg_verify_after_pay_day_numerator_qty,
  x.avg_verify_after_pay_day_denominator_qty,
  x.avg_advance_book_day_numerator_qty,
  x.avg_advance_book_day_denominator_qty,
  x.timeout_cancel_order_qty,
  x.etl_time
FROM (
SELECT
  u.seller_tenant_id,
  u.sku_id,
  SUM(u.avg_pay_minute_numerator_qty) AS avg_pay_minute_numerator_qty,
  SUM(u.avg_pay_minute_denominator_qty) AS avg_pay_minute_denominator_qty,
  SUM(u.avg_refund_process_hour_numerator_qty) AS avg_refund_process_hour_numerator_qty,
  SUM(u.avg_refund_process_hour_denominator_qty) AS avg_refund_process_hour_denominator_qty,
  SUM(u.avg_verify_after_pay_day_numerator_qty) AS avg_verify_after_pay_day_numerator_qty,
  SUM(u.avg_verify_after_pay_day_denominator_qty) AS avg_verify_after_pay_day_denominator_qty,
  SUM(u.avg_advance_book_day_numerator_qty) AS avg_advance_book_day_numerator_qty,
  SUM(u.avg_advance_book_day_denominator_qty) AS avg_advance_book_day_denominator_qty,
  SUM(u.timeout_cancel_order_qty) AS timeout_cancel_order_qty,
  CURRENT_TIMESTAMP() AS etl_time
FROM (
  -- 来源：dws_ord_tenant_sku_channel_trade_di
  SELECT
    seller_tenant_id AS seller_tenant_id,
    sku_id AS sku_id,
    SUM(pay_minute_qty) AS avg_pay_minute_numerator_qty,
    SUM(pay_order_qty) AS avg_pay_minute_denominator_qty,
    NULL AS avg_refund_process_hour_numerator_qty,
    NULL AS avg_refund_process_hour_denominator_qty,
    NULL AS avg_verify_after_pay_day_numerator_qty,
    NULL AS avg_verify_after_pay_day_denominator_qty,
    SUM(advance_book_day_qty) AS avg_advance_book_day_numerator_qty,
    SUM(pay_ticket_qty) AS avg_advance_book_day_denominator_qty,
    SUM(timeout_cancel_order_qty) AS timeout_cancel_order_qty
  FROM dws.dws_ord_tenant_sku_channel_trade_di s
  WHERE s.travel_date = '${bizdate}'
  GROUP BY seller_tenant_id, sku_id
  UNION ALL
  -- 来源：dws_ord_tenant_refund_di
  SELECT
    seller_tenant_id AS seller_tenant_id,
    sku_id AS sku_id,
    NULL AS avg_pay_minute_numerator_qty,
    NULL AS avg_pay_minute_denominator_qty,
    SUM(refund_process_hour_qty) AS avg_refund_process_hour_numerator_qty,
    SUM(refund_success_qty) AS avg_refund_process_hour_denominator_qty,
    NULL AS avg_verify_after_pay_day_numerator_qty,
    NULL AS avg_verify_after_pay_day_denominator_qty,
    NULL AS avg_advance_book_day_numerator_qty,
    NULL AS avg_advance_book_day_denominator_qty,
    NULL AS timeout_cancel_order_qty
  FROM dws.dws_ord_tenant_refund_di s
  WHERE s.travel_date = '${bizdate}'
  GROUP BY seller_tenant_id, sku_id
  UNION ALL
  -- 来源：dws_ord_tenant_sku_verify_di
  SELECT
    seller_tenant_id AS seller_tenant_id,
    sku_id AS sku_id,
    NULL AS avg_pay_minute_numerator_qty,
    NULL AS avg_pay_minute_denominator_qty,
    NULL AS avg_refund_process_hour_numerator_qty,
    NULL AS avg_refund_process_hour_denominator_qty,
    SUM(verify_after_pay_day_qty) AS avg_verify_after_pay_day_numerator_qty,
    SUM(verify_ticket_qty) AS avg_verify_after_pay_day_denominator_qty,
    NULL AS avg_advance_book_day_numerator_qty,
    NULL AS avg_advance_book_day_denominator_qty,
    NULL AS timeout_cancel_order_qty
  FROM dws.dws_ord_tenant_sku_verify_di s
  WHERE s.travel_date = '${bizdate}'
  GROUP BY seller_tenant_id, sku_id
) u
GROUP BY u.seller_tenant_id, u.sku_id
) x
LEFT JOIN dim.dim_sup_tenant_zip d1 ON d1.tenant_id = x.seller_tenant_id AND d1.travel_date = '${bizdate}' AND d1.end_date = '9999-12-31'
LEFT JOIN dim.dim_prd_sku_zip d2 ON d2.sku_id = x.sku_id AND d2.travel_date = '${bizdate}' AND d2.end_date = '9999-12-31';
