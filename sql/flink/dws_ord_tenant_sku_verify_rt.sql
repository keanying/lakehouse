-- dws.dws_ord_tenant_sku_verify_rt  商户×SKU 实时核销
-- 粒度：seller_tenant_id × sku_id × 窗口
-- 来源：dwd_ord_verify_rt
-- 生成方式：Flink SQL（1 分钟滚动窗口聚合 → StarRocks 主键模型表）；字段 7 个：直接翻译 3 · 规则翻译 0 · 待确认 4
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT INTO dws.dws_ord_tenant_sku_verify_rt
SELECT
  u.travel_date,
  u.window_start_time,
  u.window_end_time,
  u.seller_tenant_id,
  u.sku_id,
  SUM(u.verify_ticket_qty) AS verify_ticket_qty,
  SUM(u.verify_amt) AS verify_amt,
  SUM(u.verify_entitlement_qty) AS verify_entitlement_qty,
  SUM(u.verify_fail_qty) AS verify_fail_qty,
  CURRENT_TIMESTAMP AS update_time
FROM (
  -- 来源：dwd_ord_verify_rt
  SELECT
    window_start AS window_start_time,
    window_end AS window_end_time,
    travel_date AS travel_date,
    seller_tenant_id AS seller_tenant_id,
    sku_id AS sku_id,
    COUNT(DISTINCT CASE WHEN 1 = 1 THEN ticket_no END) AS verify_ticket_qty,  -- 待确认：verify_result='SUCCESS'
    NULL AS verify_amt,  -- 待确认：sum(unit_price_amt) of verified tickets（同票只计1次）（与离线同一口径 A021）
    COUNT(CASE WHEN 1 = 1 THEN verify_no END) AS verify_entitlement_qty,  -- 待确认：verify_result='SUCCESS'
    COUNT(CASE WHEN 1 = 1 THEN verify_no END) AS verify_fail_qty  -- 待确认：verify_result in ('FAILED','DUPLICATE')
  FROM TABLE(TUMBLE(TABLE dwd.dwd_ord_verify_rt, DESCRIPTOR(event_time), INTERVAL '1' MINUTE)) s
  GROUP BY window_start, window_end, travel_date, seller_tenant_id, sku_id
) u
GROUP BY u.window_start_time, u.window_end_time, u.travel_date, u.seller_tenant_id, u.sku_id;
