-- ads.ads_inv_realtime_stock_rt  实时库存看板（对应 DP09）
-- 粒度：sku_id × pool_no
-- 来源：dws_inv_sku_stock_rt
-- 生成方式：StarRocks 异步物化视图（每分钟刷新）；字段 11 个：直接翻译 5 · 规则翻译 6 · 待确认 0
-- 来源按粒度键预聚合后按公式计算

CREATE MATERIALIZED VIEW IF NOT EXISTS ads.ads_inv_realtime_stock_rt  -- 异步物化视图，StarRocks 定时刷新
REFRESH ASYNC EVERY (INTERVAL 1 MINUTE)
AS
WITH
src_sku_stock AS (                                       -- 来源「SKU 实时库存」按粒度键预聚合
  SELECT
    s.travel_date AS travel_date,                        -- 数据日期
    s.sku_id AS sku_id,                                  -- SKU ID
    s.pool_no AS pool_no,                                -- 库存池编号
    SUM(s.stock_available_qty) AS stock_available_qty,   -- 可用库存
    SUM(s.stock_frozen_qty) AS stock_frozen_qty,         -- 预扣库存
    SUM(s.stock_sold_qty) AS stock_sold_qty,             -- 已售库存
    SUM(s.stock_total_qty) AS stock_total_qty,           -- 库存总量
    SUM(s.sellout_pool_qty) AS sellout_pool_qty          -- 售罄库存池数
  FROM dws.dws_inv_sku_stock_rt s                        -- 来源表「SKU 实时库存」
  WHERE s.travel_date = DATE_FORMAT(CURDATE(), '%Y%m%d')  -- 只取今日数据
  GROUP BY s.travel_date, s.sku_id, s.pool_no            -- 按粒度键汇总
),
merged AS (                                              -- 按粒度键汇总，计算派生指标
  SELECT
    u.travel_date,                                       -- 数据日期
    u.sku_id,                                            -- SKU ID
    u.pool_no,                                           -- 库存池编号
    u.stock_available_qty AS stock_available_now_qty,    -- 当前可用库存
    u.stock_frozen_qty AS stock_frozen_now_qty,          -- 当前预扣库存
    u.stock_sold_qty * 100 / NULLIF(u.stock_total_qty, 0) AS stock_sell_through_now_rate,  -- 当前库存去化率（上座率/入住率）
    u.sellout_pool_qty AS sellout_pool_now_qty,          -- 当前售罄库存池数
    COALESCE(c.c_prededuct_qty, 0) AS prededuct_5m_qty,  -- 近5分钟预扣量｜口径：近 5 分钟预扣变动的冻结量（实时库存变动明细）
    COALESCE(c.c_release_qty, 0) AS prededuct_release_5m_qty,  -- 近5分钟预扣释放量｜口径：近 5 分钟回滚释放的冻结量
    NOW() AS update_time                                 -- 最近一次写入时间
  FROM src_sku_stock u
    LEFT JOIN (SELECT sku_id AS c_sku_id, pool_no AS c_pool_no,
                      SUM(CASE WHEN change_type = 'PRE_DEDUCT' THEN ABS(frozen_change_qty) END) AS c_prededuct_qty,  -- 预扣量（关联子查询列）
                      SUM(CASE WHEN change_type = 'ROLLBACK' THEN ABS(frozen_change_qty) END) AS c_release_qty
               FROM dwd.dwd_inv_pool_change_rt
               WHERE change_time >= DATE_SUB(NOW(), INTERVAL 5 MINUTE)
               GROUP BY sku_id, pool_no) c ON c.c_sku_id = u.sku_id AND c.c_pool_no = u.pool_no  -- 按粒度键汇总｜近 5 分钟库存变动
),
sku_cur AS (                                             -- 「SKU维度」当前有效版本，只取名称类字段
  SELECT sku_id, sku_name
  FROM dim.dim_prd_sku_zip
  WHERE end_date = '9999-12-31'                          -- 只取拉链当前有效版本
)
SELECT
  merged.travel_date,                                    -- 数据日期
  merged.sku_id,                                         -- SKU ID
  merged.pool_no,                                        -- 库存池编号
  sku_cur.sku_name AS sku_name,                          -- SKU 名称
  merged.stock_available_now_qty,                        -- 当前可用库存
  merged.stock_frozen_now_qty,                           -- 当前预扣库存
  merged.stock_sell_through_now_rate,                    -- 当前库存去化率（上座率/入住率）
  merged.sellout_pool_now_qty,                           -- 当前售罄库存池数
  merged.prededuct_5m_qty,                               -- 近5分钟预扣量
  merged.prededuct_release_5m_qty,                       -- 近5分钟预扣释放量
  merged.update_time                                     -- 最近一次写入时间
FROM merged
LEFT JOIN sku_cur                                        -- 关联「SKU维度」，补 sku_name
  ON sku_cur.sku_id = merged.sku_id;                     -- 按 sku_id 关联
