-- dws.dws_ord_tenant_sku_channel_trade_di  商户×SKU×渠道 交易日汇总
-- 粒度：travel_date × seller_tenant_id × sku_id × channel_id × app_ref_code × operator_type
-- 来源：dwd_ord_order_di, dwd_ord_order_status_log_di, dwd_ord_order_group_di
-- 生成方式：Spark SQL / Hive；字段 27 个：直接翻译 5 · 规则翻译 10 · 待确认 12
-- 多来源：每个来源表按粒度键先汇总，UNION ALL 后再合并
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT OVERWRITE TABLE dws.dws_ord_tenant_sku_channel_trade_di PARTITION (travel_date = '${bizdate}')
SELECT
  u.seller_tenant_id,
  u.sku_id,
  u.channel_id,
  u.app_ref_code,
  u.operator_type,
  SUM(u.order_group_qty) AS order_group_qty,
  SUM(u.order_qty) AS order_qty,
  SUM(u.order_ticket_qty) AS order_ticket_qty,
  SUM(u.order_amt) AS order_amt,
  SUM(u.pay_order_qty) AS pay_order_qty,
  SUM(u.pay_ticket_qty) AS pay_ticket_qty,
  SUM(u.pay_amt) AS pay_amt,
  SUM(u.pay_buyer_qty) AS pay_buyer_qty,
  BITMAP_UNION(u.pay_buyer_bitmap) AS pay_buyer_bitmap,
  SUM(u.cancel_order_qty) AS cancel_order_qty,
  SUM(u.cancel_amt) AS cancel_amt,
  SUM(u.staff_order_qty) AS staff_order_qty,
  SUM(u.combo_order_qty) AS combo_order_qty,
  SUM(u.pay_order_group_qty) AS pay_order_group_qty,
  SUM(u.cost_amt) AS cost_amt,
  SUM(u.pay_minute_qty) AS pay_minute_qty,
  SUM(u.timeout_cancel_order_qty) AS timeout_cancel_order_qty,
  SUM(u.advance_book_day_qty) AS advance_book_day_qty,
  CURRENT_TIMESTAMP() AS etl_time
FROM (
  -- 来源：dwd_ord_order_group_di
  SELECT
    seller_tenant_id AS seller_tenant_id,
    CAST(NULL AS BIGINT) AS sku_id,
    channel_id AS channel_id,
    app_ref_code AS app_ref_code,
    operator_type AS operator_type,
    COUNT(DISTINCT order_group_no) AS order_group_qty,
    NULL AS order_qty,
    NULL AS order_ticket_qty,
    NULL AS order_amt,
    NULL AS pay_order_qty,
    NULL AS pay_ticket_qty,
    NULL AS pay_amt,
    NULL AS pay_buyer_qty,
    CAST(NULL AS BINARY) AS pay_buyer_bitmap,
    NULL AS cancel_order_qty,
    NULL AS cancel_amt,
    NULL AS staff_order_qty,
    NULL AS combo_order_qty,
    COUNT(DISTINCT CASE WHEN pay_status='PAID' THEN order_group_no END) AS pay_order_group_qty,
    NULL AS cost_amt,
    NULL AS pay_minute_qty,
    NULL AS timeout_cancel_order_qty,
    NULL AS advance_book_day_qty
  FROM dwd.dwd_ord_order_group_di s
  WHERE s.travel_date = '${bizdate}'
  GROUP BY seller_tenant_id, channel_id, app_ref_code, operator_type
  UNION ALL
  -- 来源：dwd_ord_order_di
  SELECT
    seller_tenant_id AS seller_tenant_id,
    sku_id AS sku_id,
    channel_id AS channel_id,
    app_ref_code AS app_ref_code,
    operator_type AS operator_type,
    NULL AS order_group_qty,
    COUNT(DISTINCT CASE WHEN 1 = 1 THEN order_no END) AS order_qty,  -- 待确认：combo 子项除外
    SUM(buy_ticket_qty) AS order_ticket_qty,
    SUM(unit_price_amt*buy_ticket_qty) AS order_amt,
    NULL AS pay_order_qty,
    SUM(CASE WHEN pay_time IS NOT NULL THEN buy_ticket_qty END) AS pay_ticket_qty,
    SUM(CASE WHEN pay_time IS NOT NULL THEN unit_price_amt*buy_ticket_qty END) AS pay_amt,
    COUNT(DISTINCT CASE WHEN 1 = 1 THEN buyer_customer_id END) AS pay_buyer_qty,  -- 待确认：buyer_customer_id>0 and kind='REAL'
    BITMAP_UNION(TO_BITMAP(CASE WHEN 1 = 1 THEN buyer_customer_id END)) AS pay_buyer_bitmap,  -- 待确认：buyer_customer_id>0 and kind='REAL'
    NULL AS cancel_order_qty,
    SUM(CASE WHEN 1 = 1 THEN order_amt END) AS cancel_amt,  -- 待确认：of cancelled orders
    COUNT(CASE WHEN operator_type='TENANT_STAFF' THEN order_no END) AS staff_order_qty,
    COUNT(CASE WHEN 1 = 1 THEN order_no END) AS combo_order_qty,  -- 待确认：combo_flag=1
    NULL AS pay_order_group_qty,
    SUM(CASE WHEN pay_time IS NOT NULL THEN cost_price_amt * buy_ticket_qty END) AS cost_amt,
    NULL AS pay_minute_qty,
    NULL AS timeout_cancel_order_qty,
    NULL AS advance_book_day_qty  -- 待确认：sum(datediff(play_date, pay_date) * buy_ticket_qty)
  FROM dwd.dwd_ord_order_di s
  WHERE s.travel_date = '${bizdate}'
  GROUP BY seller_tenant_id, sku_id, channel_id, app_ref_code, operator_type
  UNION ALL
  -- 来源：dwd_ord_order_status_log_di
  SELECT
    seller_tenant_id AS seller_tenant_id,
    sku_id AS sku_id,
    CAST(NULL AS BIGINT) AS channel_id,
    CAST(NULL AS STRING) AS app_ref_code,
    CAST(NULL AS STRING) AS operator_type,
    NULL AS order_group_qty,
    NULL AS order_qty,
    NULL AS order_ticket_qty,
    NULL AS order_amt,
    COUNT(DISTINCT CASE WHEN after_status='PAID' THEN order_no END) AS pay_order_qty,
    NULL AS pay_ticket_qty,
    NULL AS pay_amt,
    NULL AS pay_buyer_qty,
    CAST(NULL AS BINARY) AS pay_buyer_bitmap,
    COUNT(DISTINCT CASE WHEN after_status='CANCELLED' THEN order_no END) AS cancel_order_qty,
    NULL AS cancel_amt,
    NULL AS staff_order_qty,
    NULL AS combo_order_qty,
    NULL AS pay_order_group_qty,
    NULL AS cost_amt,
    NULL AS pay_minute_qty,  -- 待确认：sum(minutes(pay_time - create_time))
    COUNT(CASE WHEN 1 = 1 THEN order_no END) AS timeout_cancel_order_qty,  -- 待确认：after_status='CANCELLED' and reason='PAY_TIMEOUT'
    NULL AS advance_book_day_qty
  FROM dwd.dwd_ord_order_status_log_di s
  WHERE s.travel_date = '${bizdate}'
  GROUP BY seller_tenant_id, sku_id
) u
GROUP BY u.seller_tenant_id, u.sku_id, u.channel_id, u.app_ref_code, u.operator_type;
