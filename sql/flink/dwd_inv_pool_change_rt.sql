-- dwd.dwd_inv_pool_change_rt  实时库存变动
-- 粒度：1行=1次库存池数量变化
-- 来源：ods_inv_inventory_pool_rt + ods_inv_inventory_unit_rt
-- 生成方式：Flink SQL（CDC 源表 → StarRocks 主键模型表；维表 Lookup Join）；字段 21 个：直接翻译 10 · 规则翻译 9 · 待确认 2
-- 源表 ods.*_rt 为 Flink CDC 表（含 proc_time AS PROCTIME()），目标表在 StarRocks catalog 中
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT INTO dwd.dwd_inv_pool_change_rt                                            -- 写入 StarRocks 目标表
SELECT
  DATE_FORMAT(a.binlog_time, 'yyyyMMdd')                       AS travel_date,    -- 数据日期
  a.id                                                         AS pool_id,        -- 库存池ID（源表主键 id）
  a.binlog_time                                                AS change_time,    -- 变动时间
  a.pool_no                                                    AS pool_no,        -- 库存池编号
  a.sku_id                                                     AS sku_id,         -- SKU ID
  a.pool_type                                                  AS pool_type,      -- 池类型
  a.pool_status                                                AS pool_status,    -- 池状态
  a.tenant_id                                                  AS tenant_id,      -- 租户ID（分库维度）
  a.create_time                                                AS create_time,    -- 创建时间
  a.update_time                                                AS update_time,    -- 更新时间
  a.frozen_quantity                                            AS change_type,    -- 变动类型｜待确认：ods_inv_inventory_pool_rt.frozen_quantity 与 ods_inv_inventory_pool_rt.available_quantity 前后变化方向判定
  j1.order_no                                                  AS order_no,       -- 引起变动的子单号｜待确认：ods_inv_inventory_unit_rt.order_no 或库存流水关联
  GET_JSON_OBJECT(a.dimension_key, '$.date')                   AS play_date,      -- 库存日期
  GET_JSON_OBJECT(a.dimension_key, '$.roomType')               AS room_type_code,  -- 房型编码（酒店）
  GET_JSON_OBJECT(a.dimension_key, '$.showTime')               AS show_time,      -- 场次时间（演出）
  LAG(a.total_quantity) OVER (PARTITION BY a.id ORDER BY a.binlog_time) AS before_total_qty,  -- 变动前总库存
  a.total_quantity                                             AS after_total_qty,  -- 变动后总库存
  (a.total_quantity) - (LAG(a.total_quantity) OVER (PARTITION BY a.id ORDER BY a.binlog_time)) AS total_change_qty,  -- 总库存变化量
  a.available_quantity - LAG(a.available_quantity) OVER (PARTITION BY a.id ORDER BY a.binlog_time) AS available_change_qty,  -- 可售库存变化量
  a.frozen_quantity - LAG(a.frozen_quantity) OVER (PARTITION BY a.id ORDER BY a.binlog_time) AS frozen_change_qty,  -- 冻结库存变化量
  CURRENT_TIMESTAMP                                            AS event_time      -- 事件时间（binlog 时间）
FROM ods.ods_inv_inventory_pool_rt a                                              -- 主表「库存池 binlog 流」
LEFT JOIN ods.ods_inv_inventory_unit_rt j1                                        -- 关联「座位/房间 binlog 流」，取 引起变动的子单号
  ON j1.pool_no = a.pool_no;                                                      -- 按 pool_no 关联
