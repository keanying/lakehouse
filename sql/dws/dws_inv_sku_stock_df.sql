-- dws.dws_inv_sku_stock_df  SKU 库存日快照
-- 粒度：travel_date × sku_id × pool_no × play_date × room_type_code/show_time
-- 来源：dwd_inv_pool_snapshot_df + dim_inv_unit_df + dwd_inv_pool_change_di
-- 生成方式：手写（结构不适合按字段自动翻译）；业务规则：
--   · 一行 = 一个库存池（池编号唯一确定 SKU、游玩日、房型、场次），库存量取池日快照
--   · 已售 = 总量 − 可售 − 冻结；售罄 = 在售且可售为 0
--   · 座位 / 房间：从资源个体维表按池统计总数与已占用数（快照）
--   · 预扣 / 确认 / 回滚：当日库存池变动，取冻结量变化的绝对值
-- 性能：
--   · 三个来源都按池编号预聚合后左关联池快照

WITH pool AS (
    SELECT pool_no,                                                               -- 库存池编号
           sku_id,                                                                -- SKU ID
           play_date,                                                             -- 游玩日期
           room_type_code,                                                        -- 房型编码
           show_time,                                                             -- 场次时间
           total_qty,
           available_qty,
           frozen_qty,
           sold_qty,
           pool_status
    FROM dwd.dwd_inv_pool_snapshot_df WHERE travel_date = '${bizdate}'
),
unit AS (
    SELECT pool_no,                                                               -- 库存池编号
           COUNT(unit_no) AS unit_total_qty,                                      -- 座位/房间总数
           COUNT(CASE WHEN unit_status = 'OCCUPIED' THEN unit_no END) AS unit_occupied_qty  -- 已占用座位/房间数
    FROM dim.dim_inv_unit_df WHERE travel_date = '${bizdate}'
    GROUP BY pool_no                                                              -- 按粒度键汇总
),
chg AS (
    SELECT pool_no,                                                               -- 库存池编号
           SUM(CASE WHEN change_type = 'PRE_DEDUCT' THEN ABS(frozen_change_qty) END) AS prededuct_qty,  -- 预扣量
           SUM(CASE WHEN change_type = 'CONFIRM' THEN ABS(frozen_change_qty) END)    AS prededuct_confirm_qty,  -- 预扣确认量
           SUM(CASE WHEN change_type = 'ROLLBACK' THEN ABS(frozen_change_qty) END)   AS prededuct_release_qty  -- 预扣释放量
    FROM dwd.dwd_inv_pool_change_di WHERE travel_date = '${bizdate}'
    GROUP BY pool_no                                                              -- 按粒度键汇总
)
INSERT OVERWRITE TABLE dws.dws_inv_sku_stock_df PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
    p.sku_id, p.pool_no, p.play_date, p.room_type_code, p.show_time,
    p.total_qty                                                       AS stock_total_qty,  -- 库存总量
    p.available_qty                                                   AS stock_available_qty,  -- 可用库存
    p.frozen_qty                                                      AS stock_frozen_qty,  -- 预扣库存
    p.total_qty - p.available_qty - p.frozen_qty                      AS stock_sold_qty,  -- 已售库存
    IF(p.pool_status = 'ON_SALE' AND p.available_qty = 0, 1, 0)       AS sellout_pool_qty,  -- 售罄库存池数
    COALESCE(u.unit_occupied_qty, 0)                                  AS unit_occupied_qty,  -- 已占用座位/房间数
    COALESCE(u.unit_total_qty, 0)                                     AS unit_total_qty,  -- 座位/房间总数
    COALESCE(c.prededuct_qty, 0)                                      AS prededuct_qty,  -- 预扣量
    COALESCE(c.prededuct_confirm_qty, 0)                              AS prededuct_confirm_qty,  -- 预扣确认量
    COALESCE(c.prededuct_release_qty, 0)                              AS prededuct_release_qty,  -- 预扣释放量
    CURRENT_TIMESTAMP() AS etl_time                                               -- ETL 加载时间
FROM pool p
LEFT JOIN unit u ON u.pool_no = p.pool_no
LEFT JOIN chg c ON c.pool_no = p.pool_no;
