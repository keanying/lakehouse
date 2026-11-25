-- dwd.dwd_inv_pool_change_di  库存池变动明细
-- 粒度：1行=1次库存池数量变化
-- 来源：ods_inv_inventory_pool_di（binlog 前后镜像）
-- 生成方式：Spark SQL / Hive；字段 20 个：直接翻译 10 · 规则翻译 8 · 待确认 2
-- 流水/状态变更类：保留每条变更记录
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT OVERWRITE TABLE dwd.dwd_inv_pool_change_di PARTITION (travel_date = '${bizdate}')
SELECT
  a.id                                                         AS pool_id,
  a.pool_no                                                    AS pool_no,
  a.sku_id                                                     AS sku_id,
  a.pool_type                                                  AS pool_type,
  a.pool_status                                                AS pool_status,
  a.tenant_id                                                  AS tenant_id,
  a.create_time                                                AS create_time,
  a.update_time                                                AS update_time,
  a.frozen_quantity                                            AS change_type,  -- 待确认：ods_inv_inventory_pool_di.frozen_quantity 与 ods_inv_inventory_pool_di.available_quantity 前后变化方向判定
  j1.order_no                                                  AS order_no,  -- 待确认：ods_inv_inventory_unit_di.order_no 或库存流水关联
  GET_JSON_OBJECT(a.dimension_key, '$.date')                   AS play_date,
  GET_JSON_OBJECT(a.dimension_key, '$.roomType')               AS room_type_code,
  GET_JSON_OBJECT(a.dimension_key, '$.showTime')               AS show_time,
  LAG(a.total_quantity) OVER (PARTITION BY a.id ORDER BY a.binlog_time) AS before_total_qty,
  a.total_quantity                                             AS after_total_qty,
  (a.total_quantity) - (LAG(a.total_quantity) OVER (PARTITION BY a.id ORDER BY a.binlog_time)) AS total_change_qty,
  a.available_quantity - LAG(a.available_quantity) OVER (PARTITION BY a.id ORDER BY a.binlog_time) AS available_change_qty,
  a.frozen_quantity - LAG(a.frozen_quantity) OVER (PARTITION BY a.id ORDER BY a.binlog_time) AS frozen_change_qty,
  a.binlog_time                                                AS change_time,
  CURRENT_TIMESTAMP()                                          AS etl_time
FROM ods.ods_inv_inventory_pool_di a
LEFT JOIN ods.ods_inv_inventory_unit_di j1
  ON j1.pool_no = a.pool_no
 AND j1.travel_date = '${bizdate}'
WHERE a.travel_date = '${bizdate}';
