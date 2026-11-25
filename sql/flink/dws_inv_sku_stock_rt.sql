-- dws.dws_inv_sku_stock_rt  SKU 实时库存
-- 粒度：sku_id × pool_no
-- 来源：dwd_inv_pool_change_rt
-- 生成方式：Flink SQL（1 分钟滚动窗口聚合 → StarRocks 主键模型表）；字段 10 个：直接翻译 3 · 规则翻译 1 · 待确认 6
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT INTO dws.dws_inv_sku_stock_rt
SELECT
  u.window_start_time,
  u.window_end_time,
  u.travel_date,
  u.sku_id,
  u.pool_no,
  SUM(u.stock_total_qty) AS stock_total_qty,
  SUM(u.stock_available_qty) AS stock_available_qty,
  SUM(u.stock_frozen_qty) AS stock_frozen_qty,
  SUM(u.stock_sold_qty) AS stock_sold_qty,
  SUM(u.sellout_pool_qty) AS sellout_pool_qty,
  SUM(u.prededuct_qty) AS prededuct_qty,
  SUM(u.prededuct_release_qty) AS prededuct_release_qty,
  CURRENT_TIMESTAMP AS update_time
FROM (
  -- 来源：dwd_inv_pool_change_rt
  SELECT
    window_start AS window_start_time,
    window_end AS window_end_time,
    travel_date AS travel_date,
    sku_id AS sku_id,
    pool_no AS pool_no,
    NULL AS stock_total_qty,  -- 待确认：sum(total_quantity)（与离线同一口径 A073）
    NULL AS stock_available_qty,  -- 待确认：sum(available_quantity)（与离线同一口径 A074）
    NULL AS stock_frozen_qty,  -- 待确认：sum(frozen_quantity)（与离线同一口径 A075）
    NULL AS stock_sold_qty,  -- 待确认：sum(total - available - frozen)（与离线同一口径 A076）
    COUNT(CASE WHEN 1 = 1 THEN pool_no END) AS sellout_pool_qty,  -- 待确认：available=0 and status='ON_SALE'
    SUM(CASE WHEN change_type='PRE_DEDUCT' THEN frozen_change_qty END) AS prededuct_qty,
    NULL AS prededuct_release_qty  -- 待确认：sum(qty) where change_type='ROLLBACK' and 来源为预扣（与离线同一口径 A137）
  FROM TABLE(TUMBLE(TABLE dwd.dwd_inv_pool_change_rt, DESCRIPTOR(event_time), INTERVAL '1' MINUTE)) s
  GROUP BY window_start, window_end, travel_date, sku_id, pool_no
) u
GROUP BY u.window_start_time, u.window_end_time, u.travel_date, u.sku_id, u.pool_no;
