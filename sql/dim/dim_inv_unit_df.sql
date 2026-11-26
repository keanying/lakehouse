-- dim.dim_inv_unit_df  座位/房间/舱位维度
-- 粒度：1行=1个UNIT资源
-- 来源：ods_inv_inventory_unit_di
-- 生成方式：Spark SQL / Hive；字段 11 个：直接翻译 9 · 规则翻译 2 · 待确认 0
-- 主表增量先去重再关联；每个 WITH 逻辑块只取用到的列并先过滤分区

WITH
inventory_unit_rn AS (                                                          -- 「UNIT池资源（座位/房间/舱位）」当日增量，同一主键按 binlog 时间倒序编号
  SELECT create_time, id, metadata, pool_no, tenant_id, unit_no, unit_status, update_time, binlog_op_type,
         ROW_NUMBER() OVER (PARTITION BY id ORDER BY binlog_time DESC) AS rn    -- 同一主键多次变更，按 binlog 时间倒序编号
  FROM ods.ods_inv_inventory_unit_di
  WHERE travel_date = '${bizdate}'                                              -- 只取当日分区
),
inventory_unit_latest AS (                                                      -- 「UNIT池资源（座位/房间/舱位）」每个主键只保留最新一条，剔除已删除记录
  SELECT create_time, id, metadata, pool_no, tenant_id, unit_no, unit_status, update_time
  FROM inventory_unit_rn
  WHERE rn = 1
    AND binlog_op_type <> 'DELETE'                                              -- 剔除源库已删除的记录
),
inventory_pool_rn AS (                                                          -- 「库存池」当日增量，同一主键按 binlog 时间倒序编号
  SELECT id, pool_no, sku_id, binlog_op_type,
         ROW_NUMBER() OVER (PARTITION BY id ORDER BY binlog_time DESC) AS rn    -- 同一主键多次变更，按 binlog 时间倒序编号
  FROM ods.ods_inv_inventory_pool_di
  WHERE travel_date = '${bizdate}'                                              -- 只取当日分区
),
inventory_pool_latest AS (                                                      -- 「库存池」每个主键只保留最新一条，剔除已删除记录
  SELECT id, pool_no, sku_id
  FROM inventory_pool_rn
  WHERE rn = 1
    AND binlog_op_type <> 'DELETE'                                              -- 剔除源库已删除的记录
)
INSERT OVERWRITE TABLE dim.dim_inv_unit_df PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  inventory_unit_latest.id                                     AS unit_id,      -- UNIT池资源
  inventory_unit_latest.unit_no                                AS unit_no,      -- 资源个体编号（座位号/房号/舱位号）
  inventory_unit_latest.pool_no                                AS pool_no,      -- 归属库存池编号
  inventory_unit_latest.unit_status                            AS unit_status,  -- 状态
  inventory_unit_latest.tenant_id                              AS tenant_id,    -- 租户ID（分库维度）
  inventory_unit_latest.create_time                            AS create_time,  -- 创建时间
  inventory_unit_latest.update_time                            AS update_time,  -- 更新时间
  inventory_pool_latest.sku_id                                 AS sku_id,       -- SKU ID
  GET_JSON_OBJECT(inventory_unit_latest.metadata, '$.seatLevel') AS seat_level_code,  -- 座位等级
  GET_JSON_OBJECT(inventory_unit_latest.metadata, '$.roomType') AS room_type_code,  -- 房型编码
  CURRENT_TIMESTAMP()                                          AS etl_time      -- ETL 加载时间
FROM inventory_unit_latest
LEFT JOIN inventory_pool_latest                                                 -- 关联「库存池」，取 SKU ID
  ON inventory_pool_latest.pool_no = inventory_unit_latest.pool_no;             -- 按 pool_no 关联
