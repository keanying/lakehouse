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
  CASE                                                                            -- 变动类型｜口径：冻结增、可售减 = 预扣；冻结减、可售增 = 回滚；冻结减、可售不变 = 确认（转已售）；其余 = 人工调整
      WHEN (inventory_pool_chg.frozen_quantity - LAG(inventory_pool_chg.frozen_quantity)
          OVER (PARTITION BY inventory_pool_chg.id ORDER BY inventory_pool_chg.binlog_time)) > 0
              AND (inventory_pool_chg.available_quantity
                  - LAG(inventory_pool_chg.available_quantity)
                      OVER (PARTITION BY inventory_pool_chg.id ORDER BY inventory_pool_chg.binlog_time)) < 0 THEN 'PRE_DEDUCT'
      WHEN (inventory_pool_chg.frozen_quantity - LAG(inventory_pool_chg.frozen_quantity)
          OVER (PARTITION BY inventory_pool_chg.id ORDER BY inventory_pool_chg.binlog_time)) < 0
              AND (inventory_pool_chg.available_quantity
                  - LAG(inventory_pool_chg.available_quantity)
                      OVER (PARTITION BY inventory_pool_chg.id ORDER BY inventory_pool_chg.binlog_time)) > 0 THEN 'ROLLBACK'
      WHEN (inventory_pool_chg.frozen_quantity - LAG(inventory_pool_chg.frozen_quantity)
          OVER (PARTITION BY inventory_pool_chg.id ORDER BY inventory_pool_chg.binlog_time)) < 0
              AND COALESCE((inventory_pool_chg.available_quantity
                  - LAG(inventory_pool_chg.available_quantity) OVER (PARTITION BY inventory_pool_chg.id ORDER BY inventory_pool_chg.binlog_time)),
          0) = 0 THEN 'CONFIRM'
      ELSE 'ADJUST'
  END AS change_type,                                                             -- 变动类型
  u.order_no AS order_no,                                                         -- 引起变动的子单号｜口径：UNIT 池（座位 / 房间）：同一事务内资源个体被锁定的子单号（与池变更 binlog 时间一致）；COUNTING 池源表不记录订单，为空
  GET_JSON_OBJECT(inventory_pool_chg.dimension_key, '$.date')  AS play_date,      -- 库存日期
  GET_JSON_OBJECT(inventory_pool_chg.dimension_key, '$.roomType') AS room_type_code,  -- 房型编码（酒店）
  GET_JSON_OBJECT(inventory_pool_chg.dimension_key, '$.showTime') AS show_time,   -- 场次时间（演出）
  LAG(inventory_pool_chg.total_quantity) OVER (PARTITION BY inventory_pool_chg.id ORDER BY inventory_pool_chg.binlog_time) AS before_total_qty,  -- 变动前总库存
  inventory_pool_chg.total_quantity                            AS after_total_qty,  -- 变动后总库存
  (inventory_pool_chg.total_quantity) - (LAG(inventory_pool_chg.total_quantity)   -- 总库存变化量
      OVER (PARTITION BY inventory_pool_chg.id ORDER BY inventory_pool_chg.binlog_time)) AS total_change_qty,  -- 总库存变化量
  inventory_pool_chg.available_quantity - LAG(inventory_pool_chg.available_quantity)  -- 可售库存变化量
      OVER (PARTITION BY inventory_pool_chg.id ORDER BY inventory_pool_chg.binlog_time) AS available_change_qty,  -- 可售库存变化量
  inventory_pool_chg.frozen_quantity - LAG(inventory_pool_chg.frozen_quantity)    -- 冻结库存变化量
      OVER (PARTITION BY inventory_pool_chg.id ORDER BY inventory_pool_chg.binlog_time) AS frozen_change_qty,  -- 冻结库存变化量
  inventory_pool_chg.binlog_time                               AS change_time,    -- 变动时间
  CURRENT_TIMESTAMP()                                          AS etl_time        -- ETL 加载时间
FROM inventory_pool_chg
LEFT JOIN (SELECT pool_no, binlog_time, MAX(order_no) AS order_no FROM ods.ods_inv_inventory_unit_di  -- 关联「UNIT池资源（座位/房间/舱位）」，取 引起变动的子单号
           WHERE travel_date = '${bizdate}' AND order_no <> '' GROUP BY pool_no, binlog_time) u  -- 只取当日分区，并按条件过滤｜UNIT 池资源个体：同一事务锁定 / 释放的子单号
  ON u.pool_no = inventory_pool_chg.pool_no AND u.binlog_time = inventory_pool_chg.binlog_time  -- 按 pool_no、binlog_time 关联｜按池号 + 事务时间对齐，一次变更一行不放大  -- 按 pool_no 关联;
