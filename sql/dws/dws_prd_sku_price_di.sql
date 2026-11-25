-- dws.dws_prd_sku_price_di  SKU×渠道 价格日汇总
-- 粒度：travel_date × sku_id × price_channel_code
-- 来源：dwd_prd_sku_price_calendar_df, dwd_prd_price_point_log_di, dwd_ord_order_di, dwd_prd_sku_version_di
-- 生成方式：Spark SQL / Hive；字段 11 个：直接翻译 2 · 规则翻译 6 · 待确认 3
-- 多来源：每个来源表按粒度键先汇总，UNION ALL 后再合并
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT OVERWRITE TABLE dws.dws_prd_sku_price_di PARTITION (travel_date = '${bizdate}')
SELECT
  u.sku_id,
  u.price_channel_code,
  SUM(u.list_price_amt) AS list_price_amt,
  SUM(u.price_change_qty) AS price_change_qty,
  SUM(u.pay_amt) AS pay_amt,
  SUM(u.pay_ticket_qty) AS pay_ticket_qty,
  SUM(u.sku_change_qty) AS sku_change_qty,
  SUM(u.pay_amt) / NULLIF(SUM(u.pay_ticket_qty), 0) AS avg_deal_price_amt,
  avg_deal_price_amt * 100 / NULLIF(SUM(u.list_price_amt), 0) AS discount_rate,
  CURRENT_TIMESTAMP() AS etl_time
FROM (
  -- 来源：dwd_prd_sku_price_calendar_df
  SELECT
    sku_id AS sku_id,
    price_channel_code AS price_channel_code,
    NULL AS list_price_amt,  -- 待确认：price/100 from 价格日历
    NULL AS price_change_qty,
    NULL AS pay_amt,
    NULL AS pay_ticket_qty,
    NULL AS sku_change_qty
  FROM dwd.dwd_prd_sku_price_calendar_df s
  WHERE s.travel_date = '${bizdate}'
  GROUP BY sku_id, price_channel_code
  UNION ALL
  -- 来源：dwd_prd_price_point_log_di
  SELECT
    sku_id AS sku_id,
    price_channel_code AS price_channel_code,
    NULL AS list_price_amt,
    COUNT(1) AS price_change_qty,
    NULL AS pay_amt,
    NULL AS pay_ticket_qty,
    NULL AS sku_change_qty
  FROM dwd.dwd_prd_price_point_log_di s
  WHERE s.travel_date = '${bizdate}'
  GROUP BY sku_id, price_channel_code
  UNION ALL
  -- 来源：dwd_ord_order_di
  SELECT
    sku_id AS sku_id,
    CAST(NULL AS STRING) AS price_channel_code,
    NULL AS list_price_amt,
    NULL AS price_change_qty,
    SUM(CASE WHEN pay_time IS NOT NULL THEN unit_price_amt*buy_ticket_qty END) AS pay_amt,
    SUM(CASE WHEN pay_time IS NOT NULL THEN buy_ticket_qty END) AS pay_ticket_qty,
    NULL AS sku_change_qty
  FROM dwd.dwd_ord_order_di s
  WHERE s.travel_date = '${bizdate}'
  GROUP BY sku_id
  UNION ALL
  -- 来源：dwd_prd_sku_version_di
  SELECT
    sku_id AS sku_id,
    CAST(NULL AS STRING) AS price_channel_code,
    NULL AS list_price_amt,
    NULL AS price_change_qty,
    NULL AS pay_amt,
    NULL AS pay_ticket_qty,
    COUNT(snapshot_no) AS sku_change_qty
  FROM dwd.dwd_prd_sku_version_di s
  WHERE s.travel_date = '${bizdate}'
  GROUP BY sku_id
) u
GROUP BY u.sku_id, u.price_channel_code;
