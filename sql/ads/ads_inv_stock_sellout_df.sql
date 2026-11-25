-- ads.ads_inv_stock_sellout_df  库存售罄与上座率
-- 粒度：travel_date × sku_id × play_date
-- 来源：dws_inv_sku_stock_df
-- 生成方式：Spark SQL / Hive；字段 17 个：直接翻译 17 · 规则翻译 0 · 待确认 0
-- 快照/累计表：增量来源取截至统计日的全部分区

INSERT OVERWRITE TABLE ads.ads_inv_stock_sellout_df PARTITION (travel_date = '${bizdate}')
SELECT
  x.sku_id,
  x.play_date,
  d1.sku_name AS sku_name,
  x.stock_total_qty,
  x.stock_available_qty,
  x.stock_frozen_qty,
  x.stock_sold_qty,
  x.sellout_pool_qty,
  x.stock_sell_through_numerator_qty,
  x.stock_sell_through_denominator_qty,
  x.stock_sellout_numerator_qty,
  x.stock_sellout_denominator_qty,
  x.unit_occupied_qty,
  x.prededuct_qty,
  x.prededuct_release_qty,
  x.prededuct_convert_numerator_qty,
  x.prededuct_convert_denominator_qty,
  x.etl_time
FROM (
SELECT
  u.sku_id,
  u.play_date,
  SUM(u.stock_total_qty) AS stock_total_qty,
  SUM(u.stock_available_qty) AS stock_available_qty,
  SUM(u.stock_frozen_qty) AS stock_frozen_qty,
  SUM(u.stock_sold_qty) AS stock_sold_qty,
  SUM(u.sellout_pool_qty) AS sellout_pool_qty,
  SUM(u.stock_sell_through_numerator_qty) AS stock_sell_through_numerator_qty,
  SUM(u.stock_sell_through_denominator_qty) AS stock_sell_through_denominator_qty,
  SUM(u.stock_sellout_numerator_qty) AS stock_sellout_numerator_qty,
  SUM(u.stock_sellout_denominator_qty) AS stock_sellout_denominator_qty,
  SUM(u.unit_occupied_qty) AS unit_occupied_qty,
  SUM(u.prededuct_qty) AS prededuct_qty,
  SUM(u.prededuct_release_qty) AS prededuct_release_qty,
  SUM(u.prededuct_convert_numerator_qty) AS prededuct_convert_numerator_qty,
  SUM(u.prededuct_convert_denominator_qty) AS prededuct_convert_denominator_qty,
  CURRENT_TIMESTAMP() AS etl_time
FROM (
  -- 来源：dws_inv_sku_stock_df
  SELECT
    sku_id AS sku_id,
    play_date AS play_date,
    SUM(stock_total_qty) AS stock_total_qty,
    SUM(stock_available_qty) AS stock_available_qty,
    SUM(stock_frozen_qty) AS stock_frozen_qty,
    SUM(stock_sold_qty) AS stock_sold_qty,
    SUM(sellout_pool_qty) AS sellout_pool_qty,
    SUM(stock_sold_qty) AS stock_sell_through_numerator_qty,
    SUM(stock_total_qty) AS stock_sell_through_denominator_qty,
    SUM(sellout_pool_qty) AS stock_sellout_numerator_qty,
    SUM(sellout_pool_qty) AS stock_sellout_denominator_qty,
    SUM(unit_occupied_qty) AS unit_occupied_qty,
    SUM(prededuct_qty) AS prededuct_qty,
    SUM(prededuct_release_qty) AS prededuct_release_qty,
    SUM(prededuct_confirm_qty) AS prededuct_convert_numerator_qty,
    SUM(prededuct_qty) AS prededuct_convert_denominator_qty
  FROM dws.dws_inv_sku_stock_df s
  WHERE s.travel_date = '${bizdate}'
  GROUP BY sku_id, play_date
) u
GROUP BY u.sku_id, u.play_date
) x
LEFT JOIN dim.dim_prd_sku_zip d1 ON d1.sku_id = x.sku_id AND d1.travel_date = '${bizdate}' AND d1.end_date = '9999-12-31';
