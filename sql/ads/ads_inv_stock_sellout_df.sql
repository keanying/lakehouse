-- ads.ads_inv_stock_sellout_df  库存售罄与上座率
-- 粒度：travel_date × sku_id × play_date
-- 来源：dws_inv_sku_stock_df
-- 生成方式：Spark SQL / Hive；字段 17 个：直接翻译 17 · 规则翻译 0 · 待确认 0
-- 快照/累计表：增量来源取截至统计日的全部分区

INSERT OVERWRITE TABLE ads.ads_inv_stock_sellout_df PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  x.sku_id,                                                         -- SKU ID
  x.play_date,                                                      -- 游玩日期
  d1.sku_name AS sku_name,                                          -- SKU 名称
  x.stock_total_qty,                                                -- 库存总量（日快照）
  x.stock_available_qty,                                            -- 可用库存（日快照）
  x.stock_frozen_qty,                                               -- 预扣库存（日快照）
  x.stock_sold_qty,                                                 -- 已售库存（日快照）
  x.sellout_pool_qty,                                               -- 售罄库存池数（日快照）
  x.stock_sell_through_numerator_qty,                               -- 库存去化率（上座率/入住率）分子（日）
  x.stock_sell_through_denominator_qty,                             -- 库存去化率（上座率/入住率）分母（日）
  x.stock_sellout_numerator_qty,                                    -- 售罄率分子（日）
  x.stock_sellout_denominator_qty,                                  -- 售罄率分母（日）
  x.unit_occupied_qty,                                              -- 已占用座位/房间数（日快照）
  x.prededuct_qty,                                                  -- 预扣量（日）
  x.prededuct_release_qty,                                          -- 预扣释放量（日）
  x.prededuct_convert_numerator_qty,                                -- 预扣转化率分子（日）
  x.prededuct_convert_denominator_qty,                              -- 预扣转化率分母（日）
  x.etl_time                                                        -- ETL 加载时间
FROM (
SELECT
  u.sku_id,                                                         -- SKU ID
  u.play_date,                                                      -- 游玩日期
  SUM(u.stock_total_qty) AS stock_total_qty,                        -- 库存总量（日快照）
  SUM(u.stock_available_qty) AS stock_available_qty,                -- 可用库存（日快照）
  SUM(u.stock_frozen_qty) AS stock_frozen_qty,                      -- 预扣库存（日快照）
  SUM(u.stock_sold_qty) AS stock_sold_qty,                          -- 已售库存（日快照）
  SUM(u.sellout_pool_qty) AS sellout_pool_qty,                      -- 售罄库存池数（日快照）
  SUM(u.stock_sell_through_numerator_qty) AS stock_sell_through_numerator_qty,  -- 库存去化率（上座率/入住率）分子（日）
  SUM(u.stock_sell_through_denominator_qty) AS stock_sell_through_denominator_qty,  -- 库存去化率（上座率/入住率）分母（日）
  SUM(u.stock_sellout_numerator_qty) AS stock_sellout_numerator_qty,  -- 售罄率分子（日）
  SUM(u.stock_sellout_denominator_qty) AS stock_sellout_denominator_qty,  -- 售罄率分母（日）
  SUM(u.unit_occupied_qty) AS unit_occupied_qty,                    -- 已占用座位/房间数（日快照）
  SUM(u.prededuct_qty) AS prededuct_qty,                            -- 预扣量（日）
  SUM(u.prededuct_release_qty) AS prededuct_release_qty,            -- 预扣释放量（日）
  SUM(u.prededuct_convert_numerator_qty) AS prededuct_convert_numerator_qty,  -- 预扣转化率分子（日）
  SUM(u.prededuct_convert_denominator_qty) AS prededuct_convert_denominator_qty,  -- 预扣转化率分母（日）
  CURRENT_TIMESTAMP() AS etl_time                                   -- ETL 加载时间
FROM (
  -- 来源：dws_inv_sku_stock_df
  SELECT
    sku_id AS sku_id,                                               -- SKU ID
    play_date AS play_date,                                         -- 游玩日期
    SUM(stock_total_qty) AS stock_total_qty,                        -- 库存总量（日快照）
    SUM(stock_available_qty) AS stock_available_qty,                -- 可用库存（日快照）
    SUM(stock_frozen_qty) AS stock_frozen_qty,                      -- 预扣库存（日快照）
    SUM(stock_sold_qty) AS stock_sold_qty,                          -- 已售库存（日快照）
    SUM(sellout_pool_qty) AS sellout_pool_qty,                      -- 售罄库存池数（日快照）
    SUM(stock_sold_qty) AS stock_sell_through_numerator_qty,        -- 库存去化率（上座率/入住率）分子（日）
    SUM(stock_total_qty) AS stock_sell_through_denominator_qty,     -- 库存去化率（上座率/入住率）分母（日）
    SUM(sellout_pool_qty) AS stock_sellout_numerator_qty,           -- 售罄率分子（日）
    SUM(sellout_pool_qty) AS stock_sellout_denominator_qty,         -- 售罄率分母（日）
    SUM(unit_occupied_qty) AS unit_occupied_qty,                    -- 已占用座位/房间数（日快照）
    SUM(prededuct_qty) AS prededuct_qty,                            -- 预扣量（日）
    SUM(prededuct_release_qty) AS prededuct_release_qty,            -- 预扣释放量（日）
    SUM(prededuct_confirm_qty) AS prededuct_convert_numerator_qty,  -- 预扣转化率分子（日）
    SUM(prededuct_qty) AS prededuct_convert_denominator_qty         -- 预扣转化率分母（日）
  FROM dws.dws_inv_sku_stock_df s                                   -- 来源表「SKU×库存维度 库存日快照」
  WHERE s.travel_date = '${bizdate}'                                -- 只取当日分区
  GROUP BY sku_id, play_date                                        -- 按粒度键汇总
) u                                                                 -- 各来源合并后的明细
GROUP BY u.sku_id, u.play_date                                      -- 按粒度键汇总
) x                                                                 -- 汇总结果，外层再补维度名称
LEFT JOIN dim.dim_prd_sku_zip d1 ON d1.sku_id = x.sku_id AND d1.travel_date = '${bizdate}' AND d1.end_date = '9999-12-31';  -- 关联「SKU维度」，取维度名称
