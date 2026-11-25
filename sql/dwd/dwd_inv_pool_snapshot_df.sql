-- dwd.dwd_inv_pool_snapshot_df  库存池日快照
-- 粒度：1行=1个库存池×1日
-- 来源：ods_inv_inventory_pool_di
-- 生成方式：Spark SQL / Hive；字段 18 个：直接翻译 13 · 规则翻译 5 · 待确认 0
-- ODS 增量按主键取最新一条（ROW_NUMBER），剔除删除记录

INSERT OVERWRITE TABLE dwd.dwd_inv_pool_snapshot_df PARTITION (travel_date = '${bizdate}')
SELECT
  a.id                                                         AS pool_id,
  a.pool_no                                                    AS pool_no,
  a.sku_id                                                     AS sku_id,
  a.pool_type                                                  AS pool_type,
  a.total_quantity                                             AS total_qty,
  a.available_quantity                                         AS available_qty,
  a.frozen_quantity                                            AS frozen_qty,
  a.pool_status                                                AS pool_status,
  a.tenant_id                                                  AS tenant_id,
  a.create_time                                                AS create_time,
  a.update_time                                                AS update_time,
  GET_JSON_OBJECT(a.dimension_key, '$.date')                   AS play_date,
  GET_JSON_OBJECT(a.dimension_key, '$.roomType')               AS room_type_code,
  GET_JSON_OBJECT(a.dimension_key, '$.showTime')               AS show_time,
  j1.shared_pool_no                                            AS shared_pool_no,
  (a.total_quantity) - (a.available_quantity) - (a.frozen_quantity) AS sold_qty,
  (a.available_quantity) = 0                                   AS sellout_type,
  CURRENT_TIMESTAMP()                                          AS etl_time
FROM (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY id ORDER BY binlog_time DESC) AS rn
  FROM ods.ods_inv_inventory_pool_di
  WHERE travel_date = '${bizdate}'
) a
LEFT JOIN dim.dim_inv_shared_pool_df j1
  ON j1.source_pool_no = a.pool_no
 AND j1.travel_date = '${bizdate}'
WHERE a.rn = 1
  AND a.binlog_op_type <> 'DELETE';
