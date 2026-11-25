-- dws.dws_ord_tenant_sku_trade_rt  商户×SKU 分钟级交易
-- 粒度：seller_tenant_id × sku_id × channel_id × operator_type × 窗口
-- 来源：dwd_ord_order_rt + dwd_fin_payment_rt + dwd_ord_refund_rt
-- 生成方式：Flink SQL（1 分钟滚动窗口聚合 → StarRocks 主键模型表）；字段 19 个：直接翻译 5 · 规则翻译 6 · 待确认 8
-- 多来源：每个来源表按粒度键先汇总，UNION ALL 后再合并
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT INTO dws.dws_ord_tenant_sku_trade_rt
SELECT
  u.travel_date,
  u.window_start_time,
  u.window_end_time,
  u.seller_tenant_id,
  u.sku_id,
  u.channel_id,
  u.operator_type,
  SUM(u.pay_amt) AS pay_amt,
  SUM(u.pay_order_qty) AS pay_order_qty,
  SUM(u.pay_ticket_qty) AS pay_ticket_qty,
  SUM(u.pay_buyer_qty) AS pay_buyer_qty,
  SUM(u.refund_amt) AS refund_amt,
  SUM(u.refund_ticket_qty) AS refund_ticket_qty,
  SUM(u.order_qty) AS order_qty,
  SUM(u.order_ticket_qty) AS order_ticket_qty,
  SUM(u.order_amt) AS order_amt,
  SUM(u.cancel_order_qty) AS cancel_order_qty,
  SUM(u.staff_order_qty) AS staff_order_qty,
  SUM(u.staff_pay_amt) AS staff_pay_amt,
  CURRENT_TIMESTAMP AS update_time
FROM (
  -- 来源：dwd_ord_order_rt
  SELECT
    window_start AS window_start_time,
    window_end AS window_end_time,
    travel_date AS travel_date,
    seller_tenant_id AS seller_tenant_id,
    sku_id AS sku_id,
    channel_id AS channel_id,
    operator_type AS operator_type,
    SUM(CASE WHEN pay_time IS NOT NULL THEN unit_price_amt*buy_ticket_qty END) AS pay_amt,
    COUNT(DISTINCT CASE WHEN 1 = 1 THEN order_no END) AS pay_order_qty,  -- 待确认：after_status='PAID'
    SUM(CASE WHEN pay_time IS NOT NULL THEN buy_ticket_qty END) AS pay_ticket_qty,
    COUNT(DISTINCT CASE WHEN 1 = 1 THEN buyer_customer_id END) AS pay_buyer_qty,  -- 待确认：buyer_customer_id>0 and kind='REAL'
    NULL AS refund_amt,
    NULL AS refund_ticket_qty,
    COUNT(DISTINCT CASE WHEN 1 = 1 THEN order_no END) AS order_qty,  -- 待确认：combo 子项除外
    SUM(buy_ticket_qty) AS order_ticket_qty,
    SUM(unit_price_amt*buy_ticket_qty) AS order_amt,
    COUNT(DISTINCT CASE WHEN 1 = 1 THEN order_no END) AS cancel_order_qty,  -- 待确认：after_status='CANCELLED'
    COUNT(CASE WHEN operator_type='TENANT_STAFF' THEN order_no END) AS staff_order_qty,
    NULL AS staff_pay_amt  -- 待确认：sum(pay_amt) where operator_type='TENANT_STAFF'（与离线同一口径 A043）
  FROM TABLE(TUMBLE(TABLE dwd.dwd_ord_order_rt, DESCRIPTOR(event_time), INTERVAL '1' MINUTE)) s
  GROUP BY window_start, window_end, travel_date, seller_tenant_id, sku_id, channel_id, operator_type
  UNION ALL
  -- 来源：dwd_ord_refund_rt
  SELECT
    window_start AS window_start_time,
    window_end AS window_end_time,
    travel_date AS travel_date,
    seller_tenant_id AS seller_tenant_id,
    CAST(NULL AS BIGINT) AS sku_id,
    channel_id AS channel_id,
    CAST(NULL AS STRING) AS operator_type,
    NULL AS pay_amt,
    NULL AS pay_order_qty,
    NULL AS pay_ticket_qty,
    NULL AS pay_buyer_qty,
    SUM(CASE WHEN refund_status = 'COMPLETED' THEN refund_amt END) AS refund_amt,
    NULL AS refund_ticket_qty,  -- 待确认：count(distinct ticket_no) of completed refunds（与离线同一口径 A024）
    NULL AS order_qty,
    NULL AS order_ticket_qty,
    NULL AS order_amt,
    NULL AS cancel_order_qty,
    NULL AS staff_order_qty,
    NULL AS staff_pay_amt
  FROM TABLE(TUMBLE(TABLE dwd.dwd_ord_refund_rt, DESCRIPTOR(event_time), INTERVAL '1' MINUTE)) s
  GROUP BY window_start, window_end, travel_date, seller_tenant_id, channel_id
) u
GROUP BY u.window_start_time, u.window_end_time, u.travel_date, u.seller_tenant_id, u.sku_id, u.channel_id, u.operator_type;
