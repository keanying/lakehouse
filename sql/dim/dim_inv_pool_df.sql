-- dim.dim_inv_pool_df  库存池维度
-- 粒度：1行=1个库存池
-- 来源：ods_inv_inventory_pool_di
-- 生成方式：Spark SQL / Hive；字段 13 个：直接翻译 9 · 规则翻译 4 · 待确认 0
-- 主表增量先去重再关联；每个 WITH 逻辑块只取用到的列并先过滤分区

WITH
inventory_pool_rn AS (                                                            -- 「库存池」当日增量，同一主键按 binlog 时间倒序编号
  SELECT create_time, dimension_key, id, pool_no, pool_status, pool_type, sku_id, tenant_id, update_time,
         binlog_op_type,
         ROW_NUMBER() OVER (PARTITION BY id ORDER BY binlog_time DESC) AS rn      -- 去重序号（1 = 最新）
  FROM ods.ods_inv_inventory_pool_di
  WHERE travel_date = '${bizdate}'                                                -- 只取当日分区
),
inventory_pool_latest AS (                                                        -- 「库存池」每个主键只保留最新一条，剔除已删除记录
  SELECT create_time, dimension_key, id, pool_no, pool_status, pool_type, sku_id, tenant_id, update_time
  FROM inventory_pool_rn
  WHERE rn = 1
    AND binlog_op_type <> 'DELETE'                                                -- 剔除源库已删除的记录
)
INSERT OVERWRITE TABLE dim.dim_inv_pool_df PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  inventory_pool_latest.id                                     AS pool_id,        -- 库存池ID（源表主键 id）
  inventory_pool_latest.pool_no                                AS pool_no,        -- 库存池编号
  inventory_pool_latest.sku_id                                 AS sku_id,         -- SKU ID
  inventory_pool_latest.pool_type                              AS pool_type,      -- 池类型
  inventory_pool_latest.pool_status                            AS pool_status,    -- 池状态
  inventory_pool_latest.tenant_id                              AS tenant_id,      -- 租户ID（分库维度）
  inventory_pool_latest.create_time                            AS create_time,    -- 创建时间
  inventory_pool_latest.update_time                            AS update_time,    -- 更新时间
  GET_JSON_OBJECT(inventory_pool_latest.dimension_key, '$.date') AS play_date,    -- 库存日期
  GET_JSON_OBJECT(inventory_pool_latest.dimension_key, '$.roomType') AS room_type_code,  -- 房型编码
  GET_JSON_OBJECT(inventory_pool_latest.dimension_key, '$.showTime') AS show_time,  -- 场次时间
  GET_JSON_OBJECT(inventory_pool_latest.dimension_key, '$.cabin') AS cabin_code,  -- 舱位编码
  CURRENT_TIMESTAMP()                                          AS etl_time        -- ETL 加载时间
FROM inventory_pool_latest;
