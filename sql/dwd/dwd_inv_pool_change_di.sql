-- dwd.dwd_inv_pool_change_di  库存池变动明细
-- 粒度：1行=1次库存池数量变化
-- 来源：ods_inv_inventory_pool_di（binlog 前后镜像）
-- 生成方式：Spark SQL / Hive；字段 20 个：直接翻译 10 · 规则翻译 8 · 待确认 2
-- 流水/状态变更类：保留每条变更记录
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT OVERWRITE TABLE dwd.dwd_inv_pool_change_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  a.id                                                         AS pool_id,        -- 库存池ID（源表主键 id）
  a.pool_no                                                    AS pool_no,        -- 库存池编号
  a.sku_id                                                     AS sku_id,         -- SKU ID
  a.pool_type                                                  AS pool_type,      -- 池类型
  a.pool_status                                                AS pool_status,    -- 池状态
  a.tenant_id                                                  AS tenant_id,      -- 租户ID（分库维度）
  a.create_time                                                AS create_time,    -- 创建时间
  a.update_time                                                AS update_time,    -- 更新时间
  a.frozen_quantity                                            AS change_type,    -- 变动类型｜待确认：ods_inv_inventory_pool_di.frozen_quantity 与 ods_inv_inventory_pool_di.available_quantity 前后变化方向判定
  j1.order_no                                                  AS order_no,       -- 引起变动的子单号｜待确认：ods_inv_inventory_unit_di.order_no 或库存流水关联
  GET_JSON_OBJECT(a.dimension_key, '$.date')                   AS play_date,      -- 库存日期
  GET_JSON_OBJECT(a.dimension_key, '$.roomType')               AS room_type_code,  -- 房型编码（酒店）
  GET_JSON_OBJECT(a.dimension_key, '$.showTime')               AS show_time,      -- 场次时间（演出）
  LAG(a.total_quantity) OVER (PARTITION BY a.id ORDER BY a.binlog_time) AS before_total_qty,  -- 变动前总库存
  a.total_quantity                                             AS after_total_qty,  -- 变动后总库存
  (a.total_quantity) - (LAG(a.total_quantity) OVER (PARTITION BY a.id ORDER BY a.binlog_time)) AS total_change_qty,  -- 总库存变化量
  a.available_quantity - LAG(a.available_quantity) OVER (PARTITION BY a.id ORDER BY a.binlog_time) AS available_change_qty,  -- 可售库存变化量
  a.frozen_quantity - LAG(a.frozen_quantity) OVER (PARTITION BY a.id ORDER BY a.binlog_time) AS frozen_change_qty,  -- 冻结库存变化量
  a.binlog_time                                                AS change_time,    -- 变动时间
  CURRENT_TIMESTAMP()                                          AS etl_time        -- ETL 加载时间
FROM ods.ods_inv_inventory_pool_di a                                              -- 主表「库存池」
LEFT JOIN ods.ods_inv_inventory_unit_di j1                                        -- 关联「UNIT池资源（座位/房间/舱位）」，取 引起变动的子单号
  ON j1.pool_no = a.pool_no                                                       -- 按 pool_no 关联
 AND j1.travel_date = '${bizdate}'                                                -- 只取当日分区
WHERE a.travel_date = '${bizdate}';                                               -- 只取当日分区
