-- dwd.dwd_inv_unit_change_di  座位/房间锁定释放明细
-- 粒度：1行=1次UNIT资源状态变化
-- 来源：ods_inv_inventory_unit_di（binlog）
-- 生成方式：Spark SQL / Hive；字段 16 个：直接翻译 12 · 规则翻译 4 · 待确认 0
-- 流水/状态变更类：保留每条变更记录

INSERT OVERWRITE TABLE dwd.dwd_inv_unit_change_di PARTITION (travel_date = '${bizdate}')
SELECT
  a.id                                                         AS unit_id,
  a.unit_no                                                    AS unit_no,
  a.pool_no                                                    AS pool_no,
  a.unit_status                                                AS unit_status,
  a.order_no                                                   AS order_no,
  a.tenant_id                                                  AS tenant_id,
  a.create_time                                                AS create_time,
  a.update_time                                                AS update_time,
  j1.sku_id                                                    AS sku_id,
  GET_JSON_OBJECT(a.metadata, '$.seatLevel')                   AS seat_level_code,
  GET_JSON_OBJECT(a.metadata, '$.roomType')                    AS room_type_code,
  LAG(a.unit_status) OVER (PARTITION BY a.id ORDER BY a.binlog_time) AS before_status,
  a.unit_status                                                AS after_status,
  1                                                            AS unit_change_qty,
  a.binlog_time                                                AS change_time,
  CURRENT_TIMESTAMP()                                          AS etl_time
FROM ods.ods_inv_inventory_unit_di a
LEFT JOIN dim.dim_inv_pool_df j1
  ON j1.pool_no = a.pool_no
 AND j1.travel_date = '${bizdate}'
WHERE a.travel_date = '${bizdate}';
