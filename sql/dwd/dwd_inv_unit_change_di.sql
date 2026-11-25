-- dwd.dwd_inv_unit_change_di  座位/房间锁定释放明细
-- 粒度：1行=1次UNIT资源状态变化
-- 来源：ods_inv_inventory_unit_di（binlog）
-- 生成方式：Spark SQL / Hive；字段 16 个：直接翻译 12 · 规则翻译 4 · 待确认 0
-- 流水/状态变更类：保留每条变更记录

INSERT OVERWRITE TABLE dwd.dwd_inv_unit_change_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  a.id                                                         AS unit_id,        -- UNIT池资源
  a.unit_no                                                    AS unit_no,        -- 资源个体编号（座位号/房号/舱位号）
  a.pool_no                                                    AS pool_no,        -- 归属库存池编号
  a.unit_status                                                AS unit_status,    -- 状态
  a.order_no                                                   AS order_no,       -- 锁定子单号（FROZEN-冻结中
  a.tenant_id                                                  AS tenant_id,      -- 租户ID（分库维度）
  a.create_time                                                AS create_time,    -- 创建时间
  a.update_time                                                AS update_time,    -- 更新时间
  j1.sku_id                                                    AS sku_id,         -- SKU ID
  GET_JSON_OBJECT(a.metadata, '$.seatLevel')                   AS seat_level_code,  -- 座位等级
  GET_JSON_OBJECT(a.metadata, '$.roomType')                    AS room_type_code,  -- 房型编码
  LAG(a.unit_status) OVER (PARTITION BY a.id ORDER BY a.binlog_time) AS before_status,  -- 变更前状态
  a.unit_status                                                AS after_status,   -- 变更后状态
  1                                                            AS unit_change_qty,  -- 变更次数
  a.binlog_time                                                AS change_time,    -- 变更时间
  CURRENT_TIMESTAMP()                                          AS etl_time        -- ETL 加载时间
FROM ods.ods_inv_inventory_unit_di a                                              -- 主表「UNIT池资源（座位/房间/舱位）」
LEFT JOIN dim.dim_inv_pool_df j1                                                  -- 关联「库存池维度」，取 SKU ID
  ON j1.pool_no = a.pool_no                                                       -- 按 pool_no 关联
 AND j1.travel_date = '${bizdate}'                                                -- 只取当日分区
WHERE a.travel_date = '${bizdate}';                                               -- 只取当日分区
