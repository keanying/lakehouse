-- dwd.dwd_inv_pool_change_di  库存池变动明细
-- 粒度：1行=1次库存池数量变化
-- 来源：ods_inv_inventory_pool_di（binlog 前后镜像）
-- 生成方式：Spark SQL / Hive；字段 20 个：直接翻译 10 · 规则翻译 10 · 待确认 0
-- 流水/状态变更类：保留每条变更记录；每个 WITH 逻辑块只取用到的列并先过滤分区

WITH
inventory_pool_chg AS (                                                           -- 主表「库存池」：保留每条变更记录，只取用到的列
  SELECT available_quantity, binlog_time, create_time, dimension_key, frozen_quantity, id, pool_no,
         pool_status, pool_type, sku_id, tenant_id, total_quantity, update_time
  FROM ods.ods_inv_inventory_pool_di
  WHERE travel_date = '${bizdate}'                                                -- 只取当日分区
),
inventory_unit_rn AS (                                                            -- 「UNIT池资源（座位/房间/舱位）」当日增量，同一主键按 binlog 时间倒序编号
  SELECT id, order_no, pool_no, binlog_op_type,
         ROW_NUMBER() OVER (PARTITION BY id ORDER BY binlog_time DESC) AS rn      -- 同一主键多次变更，按 binlog 时间倒序编号
  FROM ods.ods_inv_inventory_unit_di
  WHERE travel_date = '${bizdate}'                                                -- 只取当日分区
),
inventory_unit_latest AS (                                                        -- 「UNIT池资源（座位/房间/舱位）」每个主键只保留最新一条，剔除已删除记录
  SELECT id, order_no, pool_no
  FROM inventory_unit_rn
  WHERE rn = 1
    AND binlog_op_type <> 'DELETE'                                                -- 剔除源库已删除的记录
)
INSERT OVERWRITE TABLE dwd.dwd_inv_pool_change_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  inventory_pool_chg.id                                        AS pool_id,        -- 库存池ID（源表主键 id）
  inventory_pool_chg.pool_no                                   AS pool_no,        -- 库存池编号
  inventory_pool_chg.sku_id                                    AS sku_id,         -- SKU ID
  inventory_pool_chg.pool_type                                 AS pool_type,      -- 池类型
  inventory_pool_chg.pool_status                               AS pool_status,    -- 池状态
  inventory_pool_chg.tenant_id                                 AS tenant_id,      -- 租户ID（分库维度）
  inventory_pool_chg.create_time                               AS create_time,    -- 创建时间
  inventory_pool_chg.update_time                               AS update_time,    -- 更新时间
  CASE WHEN (inventory_pool_chg.frozen_quantity - LAG(inventory_pool_chg.frozen_quantity) OVER (PARTITION BY inventory_pool_chg.id ORDER BY inventory_pool_chg.binlog_time)) > 0 AND (inventory_pool_chg.available_quantity - LAG(inventory_pool_chg.available_quantity) OVER (PARTITION BY inventory_pool_chg.id ORDER BY inventory_pool_chg.binlog_time)) < 0 THEN 'PRE_DEDUCT' WHEN (inventory_pool_chg.frozen_quantity - LAG(inventory_pool_chg.frozen_quantity) OVER (PARTITION BY inventory_pool_chg.id ORDER BY inventory_pool_chg.binlog_time)) < 0 AND (inventory_pool_chg.available_quantity - LAG(inventory_pool_chg.available_quantity) OVER (PARTITION BY inventory_pool_chg.id ORDER BY inventory_pool_chg.binlog_time)) > 0 THEN 'ROLLBACK' WHEN (inventory_pool_chg.frozen_quantity - LAG(inventory_pool_chg.frozen_quantity) OVER (PARTITION BY inventory_pool_chg.id ORDER BY inventory_pool_chg.binlog_time)) < 0 AND COALESCE((inventory_pool_chg.available_quantity - LAG(inventory_pool_chg.available_quantity) OVER (PARTITION BY inventory_pool_chg.id ORDER BY inventory_pool_chg.binlog_time)), 0) = 0 THEN 'CONFIRM' ELSE 'ADJUST' END AS change_type,  -- 变动类型｜口径：冻结增、可售减 = 预扣；冻结减、可售增 = 回滚；冻结减、可售不变 = 确认（转已售）；其余 = 人工调整
  CAST(NULL AS STRING) AS order_no,  -- 引起变动的子单号｜口径：源端缺口：库存池变更没有记录引起变动的订单（数量型库存池无法回溯），已登记待确认事项
  GET_JSON_OBJECT(inventory_pool_chg.dimension_key, '$.date')  AS play_date,      -- 库存日期
  GET_JSON_OBJECT(inventory_pool_chg.dimension_key, '$.roomType') AS room_type_code,  -- 房型编码（酒店）
  GET_JSON_OBJECT(inventory_pool_chg.dimension_key, '$.showTime') AS show_time,   -- 场次时间（演出）
  LAG(inventory_pool_chg.total_quantity) OVER (PARTITION BY inventory_pool_chg.id ORDER BY inventory_pool_chg.binlog_time) AS before_total_qty,  -- 变动前总库存
  inventory_pool_chg.total_quantity                            AS after_total_qty,  -- 变动后总库存
  (inventory_pool_chg.total_quantity) - (LAG(inventory_pool_chg.total_quantity) OVER (PARTITION BY inventory_pool_chg.id ORDER BY inventory_pool_chg.binlog_time)) AS total_change_qty,  -- 总库存变化量
  inventory_pool_chg.available_quantity - LAG(inventory_pool_chg.available_quantity) OVER (PARTITION BY inventory_pool_chg.id ORDER BY inventory_pool_chg.binlog_time) AS available_change_qty,  -- 可售库存变化量
  inventory_pool_chg.frozen_quantity - LAG(inventory_pool_chg.frozen_quantity) OVER (PARTITION BY inventory_pool_chg.id ORDER BY inventory_pool_chg.binlog_time) AS frozen_change_qty,  -- 冻结库存变化量
  inventory_pool_chg.binlog_time                               AS change_time,    -- 变动时间
  CURRENT_TIMESTAMP()                                          AS etl_time        -- ETL 加载时间
FROM inventory_pool_chg

  ;
