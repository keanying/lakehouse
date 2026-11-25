-- ads.ads_ord_play_date_booking_df  未来游玩日预订看板
-- 粒度：travel_date × sku_id × play_date
-- 来源：dws_ord_sku_play_date_booking_df, dws_inv_sku_stock_df
-- 生成方式：Spark SQL / Hive；字段 10 个：直接翻译 4 · 规则翻译 6 · 待确认 0
-- 多来源：各来源按粒度键汇总后 UNION ALL 合并，再按公式计算

INSERT OVERWRITE TABLE ads.ads_ord_play_date_booking_df PARTITION (travel_date = '${bizdate}')
SELECT
  x.sku_id,
  x.play_date,
  d1.sku_name AS sku_name,
  x.pay_ticket_td_qty,
  x.refund_ticket_td_qty,
  x.net_pay_ticket_td_qty,
  x.stock_available_td_qty,
  x.stock_sell_through_td_rate,
  x.avg_advance_book_day_td_qty,
  x.etl_time
FROM (
SELECT
  u.sku_id,
  u.play_date,
  SUM(u.pay_ticket_qty) AS pay_ticket_td_qty,
  SUM(u.refund_ticket_qty) AS refund_ticket_td_qty,
  SUM(u.net_pay_ticket_qty) AS net_pay_ticket_td_qty,
  SUM(u.stock_available_qty) AS stock_available_td_qty,
  SUM(u.stock_sold_qty) * 100 / NULLIF(SUM(u.stock_total_qty), 0) AS stock_sell_through_td_rate,
  SUM(u.advance_book_day_qty) / NULLIF(SUM(u.pay_ticket_qty), 0) AS avg_advance_book_day_td_qty,
  CURRENT_TIMESTAMP() AS etl_time
FROM (
  -- 来源：dws_ord_sku_play_date_booking_df
  SELECT
    s.sku_id AS sku_id,
    s.play_date AS play_date,
    SUM(s.pay_ticket_qty) AS pay_ticket_qty,
    SUM(s.refund_ticket_qty) AS refund_ticket_qty,
    SUM(s.net_pay_ticket_qty) AS net_pay_ticket_qty,
    SUM(s.stock_available_qty) AS stock_available_qty,
    NULL AS stock_sold_qty,
    NULL AS stock_total_qty,
    SUM(s.advance_book_day_qty) AS advance_book_day_qty
  FROM dws.dws_ord_sku_play_date_booking_df s
  WHERE s.travel_date = '${bizdate}'
  GROUP BY s.sku_id, s.play_date
  UNION ALL
  -- 来源：dws_inv_sku_stock_df
  SELECT
    s.sku_id AS sku_id,
    s.play_date AS play_date,
    NULL AS pay_ticket_qty,
    NULL AS refund_ticket_qty,
    NULL AS net_pay_ticket_qty,
    NULL AS stock_available_qty,
    SUM(s.stock_sold_qty) AS stock_sold_qty,
    SUM(s.stock_total_qty) AS stock_total_qty,
    NULL AS advance_book_day_qty
  FROM dws.dws_inv_sku_stock_df s
  WHERE s.travel_date = '${bizdate}'
  GROUP BY s.sku_id, s.play_date
) u
GROUP BY u.sku_id, u.play_date
) x
LEFT JOIN dim.dim_prd_sku_zip d1 ON d1.sku_id = x.sku_id AND d1.travel_date = '${bizdate}' AND d1.end_date = '9999-12-31';
