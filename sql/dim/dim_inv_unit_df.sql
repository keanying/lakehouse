-- dim.dim_inv_unit_df  座位/房间/舱位维度
-- 粒度：1行=1个UNIT资源
-- 来源：ods_inv_inventory_unit_di
-- 生成方式：Spark SQL / Hive；字段 11 个：直接翻译 9 · 规则翻译 2 · 待确认 0
-- ODS 增量按主键取最新一条（ROW_NUMBER），剔除删除记录

INSERT OVERWRITE TABLE dim.dim_inv_unit_df PARTITION (travel_date = '${bizdate}')
SELECT
  a.id                                       AS unit_id,
  a.unit_no                                  AS unit_no,
  a.pool_no                                  AS pool_no,
  a.unit_status                              AS unit_status,
  a.tenant_id                                AS tenant_id,
  a.create_time                              AS create_time,
  a.update_time                              AS update_time,
  j1.sku_id                                  AS sku_id,
  GET_JSON_OBJECT(a.metadata, '$.seatLevel') AS seat_level_code,
  GET_JSON_OBJECT(a.metadata, '$.roomType')  AS room_type_code,
  CURRENT_TIMESTAMP()                        AS etl_time
FROM (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY id ORDER BY binlog_time DESC) AS rn
  FROM ods.ods_inv_inventory_unit_di
  WHERE travel_date = '${bizdate}'
) a
LEFT JOIN ods.ods_inv_inventory_pool_di j1
  ON j1.pool_no = a.pool_no
 AND j1.travel_date = '${bizdate}'
WHERE a.rn = 1
  AND a.binlog_op_type <> 'DELETE';
