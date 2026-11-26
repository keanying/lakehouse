-- ads.ads_inv_realtime_stock_rt  实时库存看板（对应 DP09）
-- 粒度：sku_id × pool_no
-- 来源：dws_inv_sku_stock_rt
-- 生成方式：StarRocks 异步物化视图（每分钟刷新）；字段 11 个：直接翻译 5 · 规则翻译 6 · 待确认 0
-- 来源按粒度键预聚合后按公式计算

CREATE MATERIALIZED VIEW IF NOT EXISTS ads.ads_inv_realtime_stock_rt  -- 异步物化视图，StarRocks 定时刷新
REFRESH ASYNC EVERY (INTERVAL 1 MINUTE)
AS
WITH
src_sku_stock AS (                               -- 来源「SKU 实时库存」按粒度键预聚合
  SELECT
    s.travel_date AS travel_date,                -- 数据日期
    s.sku_id AS sku_id,                          -- SKU ID
    s.pool_no AS pool_no,                        -- 库存池编号
    SUM(s.stock_available_qty) AS stock_available_qty,
    SUM(s.stock_frozen_qty) AS stock_frozen_qty,
    SUM(s.stock_sold_qty) AS stock_sold_qty,
    SUM(s.stock_total_qty) AS stock_total_qty,
    SUM(s.sellout_pool_qty) AS sellout_pool_qty,
    SUM(CASE WHEN s.window_start_time >= NOW() - INTERVAL 5 MINUTE THEN s.prededuct_qty END) AS prededuct_qty,
    SUM(CASE WHEN s.window_start_time >= NOW() - INTERVAL 5 MINUTE THEN s.prededuct_release_qty END) AS prededuct_release_qty
  FROM dws.dws_inv_sku_stock_rt s                -- 来源表「SKU 实时库存」
  WHERE s.travel_date = DATE_FORMAT(CURDATE(), '%Y%m%d')  -- 只取今日数据
  GROUP BY s.travel_date, s.sku_id, s.pool_no    -- 按粒度键汇总
),
merged AS (                                      -- 按粒度键汇总，计算派生指标
  SELECT
    u.travel_date,                               -- 数据日期
    u.sku_id,                                    -- SKU ID
    u.pool_no,                                   -- 库存池编号
    u.stock_available_qty AS stock_available_now_qty,  -- 当前可用库存
    u.stock_frozen_qty AS stock_frozen_now_qty,  -- 当前预扣库存
    u.stock_sold_qty * 100 / NULLIF(u.stock_total_qty, 0) AS stock_sell_through_now_rate,  -- 当前库存去化率（上座率/入住率）
    u.sellout_pool_qty AS sellout_pool_now_qty,  -- 当前售罄库存池数
    u.prededuct_qty AS prededuct_5m_qty,         -- 近5分钟预扣量
    u.prededuct_release_qty AS prededuct_release_5m_qty,  -- 近5分钟预扣释放量
    NOW() AS update_time                         -- 最近一次写入时间
  FROM src_sku_stock u
),
sku_cur AS (                                     -- 「SKU维度」当前有效版本，只取名称类字段
  SELECT sku_id, sku_name
  FROM dim.dim_prd_sku_zip
  WHERE end_date = '9999-12-31'                  -- 只取拉链当前有效版本
)
SELECT
  merged.travel_date,                            -- 数据日期
  merged.sku_id,                                 -- SKU ID
  merged.pool_no,                                -- 库存池编号
  sku_cur.sku_name AS sku_name,                  -- SKU 名称
  merged.stock_available_now_qty,                -- 当前可用库存
  merged.stock_frozen_now_qty,                   -- 当前预扣库存
  merged.stock_sell_through_now_rate,            -- 当前库存去化率（上座率/入住率）
  merged.sellout_pool_now_qty,                   -- 当前售罄库存池数
  merged.prededuct_5m_qty,                       -- 近5分钟预扣量
  merged.prededuct_release_5m_qty,               -- 近5分钟预扣释放量
  merged.update_time                             -- 最近一次写入时间
FROM merged
LEFT JOIN sku_cur                                -- 关联「SKU维度」，补 sku_name
  ON sku_cur.sku_id = merged.sku_id;             -- 按 sku_id 关联
