-- dim.dim_inv_pool_df  库存池维度
-- 粒度：1行=1个库存池
-- 来源：ods_inv_inventory_pool_di
-- 生成方式：Spark SQL / Hive；字段 13 个：直接翻译 9 · 规则翻译 4 · 待确认 0
-- ODS 增量按主键取最新一条（ROW_NUMBER），剔除删除记录

INSERT OVERWRITE TABLE dim.dim_inv_pool_df PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  a.id                                           AS pool_id,         -- 库存池ID（源表主键 id）
  a.pool_no                                      AS pool_no,         -- 库存池编号
  a.sku_id                                       AS sku_id,          -- SKU ID
  a.pool_type                                    AS pool_type,       -- 池类型
  a.pool_status                                  AS pool_status,     -- 池状态
  a.tenant_id                                    AS tenant_id,       -- 租户ID（分库维度）
  a.create_time                                  AS create_time,     -- 创建时间
  a.update_time                                  AS update_time,     -- 更新时间
  GET_JSON_OBJECT(a.dimension_key, '$.date')     AS play_date,       -- 库存日期
  GET_JSON_OBJECT(a.dimension_key, '$.roomType') AS room_type_code,  -- 房型编码
  GET_JSON_OBJECT(a.dimension_key, '$.showTime') AS show_time,       -- 场次时间
  GET_JSON_OBJECT(a.dimension_key, '$.cabin')    AS cabin_code,      -- 舱位编码
  CURRENT_TIMESTAMP()                            AS etl_time         -- ETL 加载时间
FROM (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY id ORDER BY binlog_time DESC) AS rn  -- 同一主键多次变更，按 binlog 时间倒序编号
  FROM ods.ods_inv_inventory_pool_di
  WHERE travel_date = '${bizdate}'                                   -- 只取当日分区
) a                                                                  -- 主表当日增量，按主键取最新一条
WHERE a.rn = 1                                                       -- 只保留每个主键的最新一条
  AND a.binlog_op_type <> 'DELETE';                                  -- 剔除源库已删除的记录
