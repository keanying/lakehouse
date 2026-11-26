-- dws.dws_inv_sku_stock_df  SKU×库存维度 库存日快照
-- 粒度：travel_date × sku_id × pool_no × play_date × room_type_code/show_time
-- 来源：dwd_inv_pool_snapshot_df, dwd_inv_pool_change_di, dwd_inv_unit_change_di
-- 生成方式：Spark SQL / Hive；字段 19 个：直接翻译 5 · 规则翻译 2 · 待确认 12
-- 多来源：每个来源先按粒度键预聚合，UNION ALL 后再汇总；快照/累计表：增量来源取截至统计日的全部分区
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

WITH
src_pool_snapshot AS (                                -- 来源「库存池日快照」按粒度键预聚合
  SELECT
    sku_id AS sku_id,                                 -- SKU ID
    pool_no AS pool_no,                               -- 库存池编号
    play_date AS play_date,                           -- 游玩日期
    room_type_code AS room_type_code,                 -- 房型编码
    show_time AS show_time,                           -- 场次时间
    NULL AS stock_total_qty,                          -- 待确认：sum(total_quantity)
    NULL AS stock_available_qty,                      -- 待确认：sum(available_quantity)
    NULL AS stock_frozen_qty,                         -- 待确认：sum(frozen_quantity)
    NULL AS stock_sold_qty,                           -- 待确认：sum(total - available - frozen)
    COUNT(CASE WHEN 1 = 1 THEN pool_no END) AS sellout_pool_qty,  -- 售罄库存池数｜待确认：available=0 and status='ON_SALE'
    NULL AS unit_occupied_qty,
    NULL AS unit_total_qty,
    NULL AS prededuct_qty,
    NULL AS prededuct_confirm_qty,
    NULL AS prededuct_release_qty
  FROM dwd.dwd_inv_pool_snapshot_df s                 -- 来源表「库存池日快照」
  WHERE s.travel_date = '${bizdate}'                  -- 只取当日分区
  GROUP BY sku_id, pool_no, play_date, room_type_code, show_time  -- 按粒度键汇总
),
src_unit_change AS (                                  -- 来源「座位/房间锁定释放明细」按粒度键预聚合
  SELECT
    sku_id AS sku_id,                                 -- SKU ID
    pool_no AS pool_no,                               -- 库存池编号
    CAST(NULL AS STRING) AS play_date,
    room_type_code AS room_type_code,                 -- 房型编码
    CAST(NULL AS STRING) AS show_time,
    NULL AS stock_total_qty,
    NULL AS stock_available_qty,
    NULL AS stock_frozen_qty,
    NULL AS stock_sold_qty,
    NULL AS sellout_pool_qty,
    COUNT(CASE WHEN 1 = 1 THEN unit_no END) AS unit_occupied_qty,  -- 已占用座位/房间数｜待确认：status='OCCUPIED'
    NULL AS unit_total_qty,
    NULL AS prededuct_qty,
    NULL AS prededuct_confirm_qty,
    NULL AS prededuct_release_qty
  FROM dwd.dwd_inv_unit_change_di s                   -- 来源表「座位/房间锁定释放明细」
  WHERE s.travel_date <= '${bizdate}'                 -- 累计口径：取截至统计日的全部分区
  GROUP BY sku_id, pool_no, room_type_code            -- 按粒度键汇总
),
src_unit AS (                                         -- 来源「座位/房间/舱位维度」按粒度键预聚合
  SELECT
    sku_id AS sku_id,                                 -- SKU ID
    pool_no AS pool_no,                               -- 库存池编号
    CAST(NULL AS STRING) AS play_date,
    room_type_code AS room_type_code,                 -- 房型编码
    CAST(NULL AS STRING) AS show_time,
    NULL AS stock_total_qty,
    NULL AS stock_available_qty,
    NULL AS stock_frozen_qty,
    NULL AS stock_sold_qty,
    NULL AS sellout_pool_qty,
    NULL AS unit_occupied_qty,
    COUNT(unit_no) AS unit_total_qty,                 -- 座位/房间总数
    NULL AS prededuct_qty,
    NULL AS prededuct_confirm_qty,
    NULL AS prededuct_release_qty
  FROM dim.dim_inv_unit_df s                          -- 来源表「座位/房间/舱位维度」
  WHERE s.travel_date = '${bizdate}'                  -- 只取当日分区
  GROUP BY sku_id, pool_no, room_type_code            -- 按粒度键汇总
),
src_pool_change AS (                                  -- 来源「库存池变动明细」按粒度键预聚合
  SELECT
    sku_id AS sku_id,                                 -- SKU ID
    pool_no AS pool_no,                               -- 库存池编号
    play_date AS play_date,                           -- 游玩日期
    room_type_code AS room_type_code,                 -- 房型编码
    show_time AS show_time,                           -- 场次时间
    NULL AS stock_total_qty,
    NULL AS stock_available_qty,
    NULL AS stock_frozen_qty,
    NULL AS stock_sold_qty,
    NULL AS sellout_pool_qty,
    NULL AS unit_occupied_qty,
    NULL AS unit_total_qty,
    SUM(CASE WHEN change_type='PRE_DEDUCT' THEN frozen_change_qty END) AS prededuct_qty,  -- 预扣量
    NULL AS prededuct_confirm_qty,                    -- 待确认：sum(qty) where change_type='CONFIRM'
    NULL AS prededuct_release_qty                     -- 待确认：sum(qty) where change_type='ROLLBACK' and 来源为预扣
  FROM dwd.dwd_inv_pool_change_di s                   -- 来源表「库存池变动明细」
  WHERE s.travel_date <= '${bizdate}'                 -- 累计口径：取截至统计日的全部分区
  GROUP BY sku_id, pool_no, play_date, room_type_code, show_time  -- 按粒度键汇总
),
all_src AS (                                          -- 各来源字段已对齐，UNION ALL 合并（比多表 FULL JOIN 少 shuffle）
  SELECT * FROM src_pool_snapshot
  UNION ALL
  SELECT * FROM src_unit_change
  UNION ALL
  SELECT * FROM src_unit
  UNION ALL
  SELECT * FROM src_pool_change
)
INSERT OVERWRITE TABLE dws.dws_inv_sku_stock_df PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  u.sku_id,                                           -- SKU ID
  u.pool_no,                                          -- 库存池编号
  u.play_date,                                        -- 游玩日期
  u.room_type_code,                                   -- 房型编码
  u.show_time,                                        -- 场次时间
  SUM(u.stock_total_qty) AS stock_total_qty,          -- 库存总量
  SUM(u.stock_available_qty) AS stock_available_qty,  -- 可用库存
  SUM(u.stock_frozen_qty) AS stock_frozen_qty,        -- 预扣库存
  SUM(u.stock_sold_qty) AS stock_sold_qty,            -- 已售库存
  SUM(u.sellout_pool_qty) AS sellout_pool_qty,        -- 售罄库存池数
  SUM(u.unit_occupied_qty) AS unit_occupied_qty,      -- 已占用座位/房间数
  SUM(u.unit_total_qty) AS unit_total_qty,            -- 座位/房间总数
  SUM(u.prededuct_qty) AS prededuct_qty,              -- 预扣量
  SUM(u.prededuct_confirm_qty) AS prededuct_confirm_qty,  -- 预扣确认量
  SUM(u.prededuct_release_qty) AS prededuct_release_qty,  -- 预扣释放量
  CURRENT_TIMESTAMP() AS etl_time                     -- ETL 加载时间
FROM all_src u
GROUP BY u.sku_id, u.pool_no, u.play_date, u.room_type_code, u.show_time;  -- 按粒度键汇总
