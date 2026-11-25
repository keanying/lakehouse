-- ads.ads_inv_realtime_stock_rt  实时库存看板（对应 DP09）
-- 粒度：sku_id × pool_no
-- 来源：dws_inv_sku_stock_rt
-- 生成方式：StarRocks 异步物化视图（每分钟刷新）；字段 11 个：直接翻译 5 · 规则翻译 6 · 待确认 0

CREATE MATERIALIZED VIEW IF NOT EXISTS ads.ads_inv_realtime_stock_rt  -- 异步物化视图，StarRocks 定时刷新
REFRESH ASYNC EVERY (INTERVAL 1 MINUTE)
AS
SELECT
  x.travel_date,                                          -- 数据日期
  x.sku_id,                                               -- SKU ID
  x.pool_no,                                              -- 库存池编号
  d1.sku_name AS sku_name,                                -- SKU 名称
  x.stock_available_now_qty,                              -- 当前可用库存
  x.stock_frozen_now_qty,                                 -- 当前预扣库存
  x.stock_sell_through_now_rate,                          -- 当前库存去化率（上座率/入住率）
  x.sellout_pool_now_qty,                                 -- 当前售罄库存池数
  x.prededuct_5m_qty,                                     -- 近5分钟预扣量
  x.prededuct_release_5m_qty,                             -- 近5分钟预扣释放量
  x.update_time                                           -- 最近一次写入时间
FROM (
SELECT
  u.travel_date,                                          -- 数据日期
  u.sku_id,                                               -- SKU ID
  u.pool_no,                                              -- 库存池编号
  SUM(u.stock_available_qty) AS stock_available_now_qty,  -- 当前可用库存
  SUM(u.stock_frozen_qty) AS stock_frozen_now_qty,        -- 当前预扣库存
  SUM(u.stock_sold_qty) * 100 / NULLIF(SUM(u.stock_total_qty), 0) AS stock_sell_through_now_rate,  -- 当前库存去化率（上座率/入住率）
  SUM(u.sellout_pool_qty) AS sellout_pool_now_qty,        -- 当前售罄库存池数
  SUM(u.prededuct_qty) AS prededuct_5m_qty,               -- 近5分钟预扣量
  SUM(u.prededuct_release_qty) AS prededuct_release_5m_qty,  -- 近5分钟预扣释放量
  NOW() AS update_time                                    -- 最近一次写入时间
FROM (
  -- 来源：dws_inv_sku_stock_rt
  SELECT
    s.travel_date AS travel_date,                         -- 数据日期
    s.sku_id AS sku_id,                                   -- SKU ID
    s.pool_no AS pool_no,                                 -- 库存池编号
    SUM(s.stock_available_qty) AS stock_available_qty,
    SUM(s.stock_frozen_qty) AS stock_frozen_qty,
    SUM(s.stock_sold_qty) AS stock_sold_qty,
    SUM(s.stock_total_qty) AS stock_total_qty,
    SUM(s.sellout_pool_qty) AS sellout_pool_qty,
    SUM(CASE WHEN s.window_start_time >= NOW() - INTERVAL 5 MINUTE THEN s.prededuct_qty END) AS prededuct_qty,
    SUM(CASE WHEN s.window_start_time >= NOW() - INTERVAL 5 MINUTE THEN s.prededuct_release_qty END) AS prededuct_release_qty
  FROM dws.dws_inv_sku_stock_rt s                         -- 来源表「SKU 实时库存」
  WHERE s.travel_date = DATE_FORMAT(CURDATE(), '%Y%m%d')  -- 只取今日数据
  GROUP BY s.travel_date, s.sku_id, s.pool_no             -- 按粒度键汇总
) u                                                       -- 各来源合并后的明细
GROUP BY u.travel_date, u.sku_id, u.pool_no               -- 按粒度键汇总
) x                                                       -- 汇总结果，外层再补维度名称
LEFT JOIN dim.dim_prd_sku_zip d1 ON d1.sku_id = x.sku_id AND d1.end_date = '9999-12-31';  -- 关联「SKU维度」，取维度名称
