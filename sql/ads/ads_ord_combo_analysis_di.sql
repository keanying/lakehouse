-- ads.ads_ord_combo_analysis_di  套票分析（主子单/跨商户/部分退）
-- 粒度：travel_date × combo_sku_id × sub_sku_id
-- 来源：dws_ord_combo_sku_trade_di
-- 生成方式：Spark SQL / Hive；字段 12 个：直接翻译 12 · 规则翻译 0 · 待确认 0

INSERT OVERWRITE TABLE ads.ads_ord_combo_analysis_di PARTITION (travel_date = '${bizdate}')
SELECT
  x.combo_sku_id,
  x.sub_sku_id,
  d1.sku_name AS combo_sku_name,
  d2.sku_name AS sub_sku_name,
  x.combo_order_qty,
  x.pay_amt,
  x.pay_ticket_qty,
  x.verify_ticket_qty,
  x.refund_ticket_qty,
  x.refund_amt,
  x.combo_refund_numerator_qty,
  x.combo_refund_denominator_qty,
  x.etl_time
FROM (
SELECT
  u.combo_sku_id,
  u.sub_sku_id,
  SUM(u.combo_order_qty) AS combo_order_qty,
  SUM(u.pay_amt) AS pay_amt,
  SUM(u.pay_ticket_qty) AS pay_ticket_qty,
  SUM(u.verify_ticket_qty) AS verify_ticket_qty,
  SUM(u.refund_ticket_qty) AS refund_ticket_qty,
  SUM(u.refund_amt) AS refund_amt,
  SUM(u.combo_refund_numerator_qty) AS combo_refund_numerator_qty,
  SUM(u.combo_refund_denominator_qty) AS combo_refund_denominator_qty,
  CURRENT_TIMESTAMP() AS etl_time
FROM (
  -- 来源：dws_ord_combo_sku_trade_di
  SELECT
    combo_sku_id AS combo_sku_id,
    sub_sku_id AS sub_sku_id,
    SUM(combo_order_qty) AS combo_order_qty,
    SUM(pay_amt) AS pay_amt,
    SUM(pay_ticket_qty) AS pay_ticket_qty,
    SUM(verify_ticket_qty) AS verify_ticket_qty,
    SUM(refund_ticket_qty) AS refund_ticket_qty,
    SUM(refund_amt) AS refund_amt,
    SUM(refund_ticket_qty) AS combo_refund_numerator_qty,
    SUM(refund_ticket_qty) AS combo_refund_denominator_qty
  FROM dws.dws_ord_combo_sku_trade_di s
  WHERE s.travel_date = '${bizdate}'
  GROUP BY combo_sku_id, sub_sku_id
) u
GROUP BY u.combo_sku_id, u.sub_sku_id
) x
LEFT JOIN dim.dim_prd_sku_zip d1 ON d1.sku_id = x.combo_sku_id AND d1.travel_date = '${bizdate}' AND d1.end_date = '9999-12-31'
LEFT JOIN dim.dim_prd_sku_zip d2 ON d2.sku_id = x.sub_sku_id AND d2.travel_date = '${bizdate}' AND d2.end_date = '9999-12-31';
