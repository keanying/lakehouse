-- dim.dim_inv_pool_df  库存池维度
-- 粒度：1行=1个库存池
-- 来源：ods_inv_inventory_pool_di
-- 生成方式：Spark SQL / Hive；字段 13 个：直接翻译 9 · 规则翻译 4 · 待确认 0
-- ODS 增量按主键取最新一条（ROW_NUMBER），剔除删除记录

INSERT OVERWRITE TABLE dim.dim_inv_pool_df PARTITION (travel_date = '${bizdate}')
SELECT
  a.id                                           AS pool_id,
  a.pool_no                                      AS pool_no,
  a.sku_id                                       AS sku_id,
  a.pool_type                                    AS pool_type,
  a.pool_status                                  AS pool_status,
  a.tenant_id                                    AS tenant_id,
  a.create_time                                  AS create_time,
  a.update_time                                  AS update_time,
  GET_JSON_OBJECT(a.dimension_key, '$.date')     AS play_date,
  GET_JSON_OBJECT(a.dimension_key, '$.roomType') AS room_type_code,
  GET_JSON_OBJECT(a.dimension_key, '$.showTime') AS show_time,
  GET_JSON_OBJECT(a.dimension_key, '$.cabin')    AS cabin_code,
  CURRENT_TIMESTAMP()                            AS etl_time
FROM (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY id ORDER BY binlog_time DESC) AS rn
  FROM ods.ods_inv_inventory_pool_di
  WHERE travel_date = '${bizdate}'
) a
WHERE a.rn = 1
  AND a.binlog_op_type <> 'DELETE';
