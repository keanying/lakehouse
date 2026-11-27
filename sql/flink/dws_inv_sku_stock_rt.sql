-- dws.dws_inv_sku_stock_rt  SKU 实时库存
-- 粒度：sku_id × pool_no
-- 来源：ods_inv_inventory_pool_rt（CDC，当前库存）+ dwd_inv_pool_change_rt（当日变动）
-- 生成方式：手写（结构不适合按字段自动翻译）；业务规则：
--   · 库存量取库存池 CDC 当前值（Flink 把 CDC 源当作随变更更新的表，聚合结果自动回撤）；与离线同口径：已售 = 总量 − 可售 − 冻结，售罄 = 在售且可售为 0
--   · 预扣 / 回滚释放：当日库存变动的冻结量绝对值
--   · 原自动生成版本对变动类型求和、对变动前总量求和，口径错误，此处重写
-- 性能：
--   · 两路结果按（SKU, 池）常规关联，写 StarRocks 主键模型表

INSERT INTO dws.dws_inv_sku_stock_rt                                              -- 写入 StarRocks 目标表
SELECT
    DATE_FORMAT(CURRENT_TIMESTAMP, 'yyyyMMdd')                          AS travel_date,  -- 数据日期
    p.sku_id,                                                                     -- SKU ID
    p.pool_no,                                                                    -- 库存池编号
    p.total_quantity                                                   AS stock_total_qty,  -- 库存总量
    p.available_quantity                                               AS stock_available_qty,  -- 可用库存
    p.frozen_quantity                                                  AS stock_frozen_qty,  -- 预扣库存
    p.total_quantity - p.available_quantity - p.frozen_quantity        AS stock_sold_qty,  -- 已售库存
    IF(p.pool_status = 'ON_SALE' AND p.available_quantity = 0, 1, 0)   AS sellout_pool_qty,  -- 售罄库存池数
    COALESCE(c.prededuct_qty, 0)                                       AS prededuct_qty,  -- 预扣量
    COALESCE(c.prededuct_release_qty, 0)                               AS prededuct_release_qty,  -- 预扣释放量
    CURRENT_TIMESTAMP                                                  AS update_time  -- 最近一次写入时间
FROM ods_inv_inventory_pool_rt p
LEFT JOIN (
    SELECT pool_no,
           SUM(CASE WHEN change_type = 'PRE_DEDUCT' THEN ABS(frozen_change_qty) END) AS prededuct_qty,  -- 预扣量
           SUM(CASE WHEN change_type = 'ROLLBACK' THEN ABS(frozen_change_qty) END)   AS prededuct_release_qty  -- 预扣释放量
    FROM dwd_inv_pool_change_rt
    WHERE travel_date = DATE_FORMAT(CURRENT_TIMESTAMP, 'yyyyMMdd')
    GROUP BY pool_no                                                              -- 按粒度键汇总
) c ON c.pool_no = p.pool_no
WHERE p.deleted = 0;
