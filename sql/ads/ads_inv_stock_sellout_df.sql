-- ads.ads_inv_stock_sellout_df  库存售罄与上座率
-- 粒度：travel_date × sku_id × play_date
-- 来源：dws_inv_sku_stock_df
-- 生成方式：Spark SQL / Hive；字段 17 个：直接翻译 17 · 规则翻译 0 · 待确认 0
-- 来源先按粒度键预聚合；快照/累计表：增量来源取截至统计日的全部分区

WITH
src_sku_stock AS (                                    -- 来源「SKU×库存维度 库存日快照」按粒度键预聚合
  SELECT
    sku_id AS sku_id,                                 -- SKU ID
    play_date AS play_date,                           -- 游玩日期
    SUM(stock_total_qty) AS stock_total_qty,          -- 库存总量（日快照）
    SUM(stock_available_qty) AS stock_available_qty,  -- 可用库存（日快照）
    SUM(stock_frozen_qty) AS stock_frozen_qty,        -- 预扣库存（日快照）
    SUM(stock_sold_qty) AS stock_sold_qty,            -- 已售库存（日快照）
    SUM(sellout_pool_qty) AS sellout_pool_qty,        -- 售罄库存池数（日快照）
    SUM(stock_sold_qty) AS stock_sell_through_numerator_qty,  -- 库存去化率（上座率/入住率）分子（日）
    SUM(stock_total_qty) AS stock_sell_through_denominator_qty,  -- 库存去化率（上座率/入住率）分母（日）
    SUM(sellout_pool_qty) AS stock_sellout_numerator_qty,  -- 售罄率分子（日）
    SUM(sellout_pool_qty) AS stock_sellout_denominator_qty,  -- 售罄率分母（日）
    SUM(unit_occupied_qty) AS unit_occupied_qty,      -- 已占用座位/房间数（日快照）
    SUM(prededuct_qty) AS prededuct_qty,              -- 预扣量（日）
    SUM(prededuct_release_qty) AS prededuct_release_qty,  -- 预扣释放量（日）
    SUM(prededuct_confirm_qty) AS prededuct_convert_numerator_qty,  -- 预扣转化率分子（日）
    SUM(prededuct_qty) AS prededuct_convert_denominator_qty  -- 预扣转化率分母（日）
  FROM dws.dws_inv_sku_stock_df s                     -- 来源表「SKU×库存维度 库存日快照」
  WHERE s.travel_date = '${bizdate}'                  -- 只取当日分区
  GROUP BY sku_id, play_date                          -- 按粒度键汇总
),
merged AS (                                           -- 按粒度键汇总，计算派生指标
  SELECT
    u.sku_id,                                         -- SKU ID
    u.play_date,                                      -- 游玩日期
    u.stock_total_qty,                                -- 库存总量（日快照）
    u.stock_available_qty,                            -- 可用库存（日快照）
    u.stock_frozen_qty,                               -- 预扣库存（日快照）
    u.stock_sold_qty,                                 -- 已售库存（日快照）
    u.sellout_pool_qty,                               -- 售罄库存池数（日快照）
    u.stock_sell_through_numerator_qty,               -- 库存去化率（上座率/入住率）分子（日）
    u.stock_sell_through_denominator_qty,             -- 库存去化率（上座率/入住率）分母（日）
    u.stock_sellout_numerator_qty,                    -- 售罄率分子（日）
    u.stock_sellout_denominator_qty,                  -- 售罄率分母（日）
    u.unit_occupied_qty,                              -- 已占用座位/房间数（日快照）
    u.prededuct_qty,                                  -- 预扣量（日）
    u.prededuct_release_qty,                          -- 预扣释放量（日）
    u.prededuct_convert_numerator_qty,                -- 预扣转化率分子（日）
    u.prededuct_convert_denominator_qty,              -- 预扣转化率分母（日）
    CURRENT_TIMESTAMP() AS etl_time                   -- ETL 加载时间
  FROM src_sku_stock u
),
sku_cur AS (                                          -- 「SKU维度」当前有效版本，只取名称类字段
  SELECT sku_id, sku_name
  FROM dim.dim_prd_sku_zip
  WHERE travel_date = '${bizdate}' AND end_date = '9999-12-31'  -- 取当日分区里的拉链当前有效版本
)
INSERT OVERWRITE TABLE ads.ads_inv_stock_sellout_df PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  merged.sku_id,                                      -- SKU ID
  merged.play_date,                                   -- 游玩日期
  sku_cur.sku_name AS sku_name,                       -- SKU 名称
  merged.stock_total_qty,                             -- 库存总量（日快照）
  merged.stock_available_qty,                         -- 可用库存（日快照）
  merged.stock_frozen_qty,                            -- 预扣库存（日快照）
  merged.stock_sold_qty,                              -- 已售库存（日快照）
  merged.sellout_pool_qty,                            -- 售罄库存池数（日快照）
  merged.stock_sell_through_numerator_qty,            -- 库存去化率（上座率/入住率）分子（日）
  merged.stock_sell_through_denominator_qty,          -- 库存去化率（上座率/入住率）分母（日）
  merged.stock_sellout_numerator_qty,                 -- 售罄率分子（日）
  merged.stock_sellout_denominator_qty,               -- 售罄率分母（日）
  merged.unit_occupied_qty,                           -- 已占用座位/房间数（日快照）
  merged.prededuct_qty,                               -- 预扣量（日）
  merged.prededuct_release_qty,                       -- 预扣释放量（日）
  merged.prededuct_convert_numerator_qty,             -- 预扣转化率分子（日）
  merged.prededuct_convert_denominator_qty,           -- 预扣转化率分母（日）
  merged.etl_time                                     -- ETL 加载时间
FROM merged
LEFT JOIN sku_cur                                     -- 关联「SKU维度」，补 sku_name
  ON sku_cur.sku_id = merged.sku_id;                  -- 按 sku_id 关联
