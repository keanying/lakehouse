-- ads.ads_prd_price_discount_di  价格与折扣分析
-- 粒度：travel_date × sku_id × price_channel_code
-- 来源：dws_prd_sku_price_di
-- 生成方式：Spark SQL / Hive；字段 10 个：直接翻译 10 · 规则翻译 0 · 待确认 0

INSERT OVERWRITE TABLE ads.ads_prd_price_discount_di PARTITION (travel_date = '${bizdate}')
SELECT
  x.sku_id,
  x.price_channel_code,
  d1.sku_name AS sku_name,
  x.list_price_amt,
  x.avg_deal_price_numerator_amt,
  x.avg_deal_price_denominator_qty,
  x.discount_numerator_amt,
  x.discount_denominator_amt,
  x.price_change_qty,
  x.sku_change_qty,
  x.etl_time
FROM (
SELECT
  u.sku_id,
  u.price_channel_code,
  SUM(u.list_price_amt) AS list_price_amt,
  SUM(u.avg_deal_price_numerator_amt) AS avg_deal_price_numerator_amt,
  SUM(u.avg_deal_price_denominator_qty) AS avg_deal_price_denominator_qty,
  SUM(u.discount_numerator_amt) AS discount_numerator_amt,
  SUM(u.discount_denominator_amt) AS discount_denominator_amt,
  SUM(u.price_change_qty) AS price_change_qty,
  SUM(u.sku_change_qty) AS sku_change_qty,
  CURRENT_TIMESTAMP() AS etl_time
FROM (
  -- 来源：dws_prd_sku_price_di
  SELECT
    sku_id AS sku_id,
    price_channel_code AS price_channel_code,
    SUM(list_price_amt) AS list_price_amt,
    SUM(pay_amt) AS avg_deal_price_numerator_amt,
    SUM(pay_ticket_qty) AS avg_deal_price_denominator_qty,
    SUM(avg_deal_price_amt) AS discount_numerator_amt,
    SUM(list_price_amt) AS discount_denominator_amt,
    SUM(price_change_qty) AS price_change_qty,
    SUM(sku_change_qty) AS sku_change_qty
  FROM dws.dws_prd_sku_price_di s
  WHERE s.travel_date = '${bizdate}'
  GROUP BY sku_id, price_channel_code
) u
GROUP BY u.sku_id, u.price_channel_code
) x
LEFT JOIN dim.dim_prd_sku_zip d1 ON d1.sku_id = x.sku_id AND d1.travel_date = '${bizdate}' AND d1.end_date = '9999-12-31';
