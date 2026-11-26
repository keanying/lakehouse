-- dwd.dwd_inv_unit_change_di  座位/房间锁定释放明细
-- 粒度：1行=1次UNIT资源状态变化
-- 来源：ods_inv_inventory_unit_di（binlog）
-- 生成方式：Spark SQL / Hive；字段 16 个：直接翻译 12 · 规则翻译 4 · 待确认 0
-- 流水/状态变更类：保留每条变更记录；每个 WITH 逻辑块只取用到的列并先过滤分区；小维表广播关联

WITH
inventory_unit_chg AS (                                                           -- 主表「UNIT池资源（座位/房间/舱位）」：保留每条变更记录，只取用到的列
  SELECT binlog_time, create_time, id, metadata, order_no, pool_no, tenant_id, unit_no, unit_status,
         update_time                                                              -- 更新时间
  FROM ods.ods_inv_inventory_unit_di
  WHERE travel_date = '${bizdate}'                                                -- 只取当日分区
),
pool_dim AS (                                                                     -- 「库存池维度」当日数据，只取用到的列
  SELECT pool_no, sku_id
  FROM dim.dim_inv_pool_df
  WHERE travel_date = '${bizdate}'                                                -- 只取当日分区
)
INSERT OVERWRITE TABLE dwd.dwd_inv_unit_change_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT  /*+ BROADCAST(pool_dim) */
  inventory_unit_chg.id                                        AS unit_id,        -- UNIT池资源
  inventory_unit_chg.unit_no                                   AS unit_no,        -- 资源个体编号（座位号/房号/舱位号）
  inventory_unit_chg.pool_no                                   AS pool_no,        -- 归属库存池编号
  inventory_unit_chg.unit_status                               AS unit_status,    -- 状态
  inventory_unit_chg.order_no                                  AS order_no,       -- 锁定子单号（FROZEN-冻结中
  inventory_unit_chg.tenant_id                                 AS tenant_id,      -- 租户ID（分库维度）
  inventory_unit_chg.create_time                               AS create_time,    -- 创建时间
  inventory_unit_chg.update_time                               AS update_time,    -- 更新时间
  pool_dim.sku_id                                              AS sku_id,         -- SKU ID
  GET_JSON_OBJECT(inventory_unit_chg.metadata, '$.seatLevel')  AS seat_level_code,  -- 座位等级
  GET_JSON_OBJECT(inventory_unit_chg.metadata, '$.roomType')   AS room_type_code,  -- 房型编码
  LAG(inventory_unit_chg.unit_status) OVER (PARTITION BY inventory_unit_chg.id ORDER BY inventory_unit_chg.binlog_time) AS before_status,  -- 变更前状态
  inventory_unit_chg.unit_status                               AS after_status,   -- 变更后状态
  1                                                            AS unit_change_qty,  -- 变更次数
  inventory_unit_chg.binlog_time                               AS change_time,    -- 变更时间
  CURRENT_TIMESTAMP()                                          AS etl_time        -- ETL 加载时间
FROM inventory_unit_chg
LEFT JOIN pool_dim                                                                -- 关联「库存池维度」，取 SKU ID
  ON pool_dim.pool_no = inventory_unit_chg.pool_no;                               -- 按 pool_no 关联
