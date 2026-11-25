-- dim.dim_inv_unit_df  座位/房间/舱位维度
-- 粒度：1行=1个UNIT资源
-- 来源：ods_inv_inventory_unit_di
-- 生成方式：Spark SQL / Hive；字段 11 个：直接翻译 9 · 规则翻译 2 · 待确认 0
-- ODS 增量按主键取最新一条（ROW_NUMBER），剔除删除记录

INSERT OVERWRITE TABLE dim.dim_inv_unit_df PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  a.id                                       AS unit_id,          -- UNIT池资源
  a.unit_no                                  AS unit_no,          -- 资源个体编号（座位号/房号/舱位号）
  a.pool_no                                  AS pool_no,          -- 归属库存池编号
  a.unit_status                              AS unit_status,      -- 状态
  a.tenant_id                                AS tenant_id,        -- 租户ID（分库维度）
  a.create_time                              AS create_time,      -- 创建时间
  a.update_time                              AS update_time,      -- 更新时间
  j1.sku_id                                  AS sku_id,           -- SKU ID
  GET_JSON_OBJECT(a.metadata, '$.seatLevel') AS seat_level_code,  -- 座位等级
  GET_JSON_OBJECT(a.metadata, '$.roomType')  AS room_type_code,   -- 房型编码
  CURRENT_TIMESTAMP()                        AS etl_time          -- ETL 加载时间
FROM (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY id ORDER BY binlog_time DESC) AS rn  -- 同一主键多次变更，按 binlog 时间倒序编号
  FROM ods.ods_inv_inventory_unit_di
  WHERE travel_date = '${bizdate}'                                -- 只取当日分区
) a                                                               -- 主表当日增量，按主键取最新一条
LEFT JOIN ods.ods_inv_inventory_pool_di j1                        -- 关联「库存池」，取 SKU ID
  ON j1.pool_no = a.pool_no                                       -- 按 pool_no 关联
 AND j1.travel_date = '${bizdate}'                                -- 只取当日分区
WHERE a.rn = 1                                                    -- 只保留每个主键的最新一条
  AND a.binlog_op_type <> 'DELETE';                               -- 剔除源库已删除的记录
