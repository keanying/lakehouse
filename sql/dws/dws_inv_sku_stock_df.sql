-- dws.dws_inv_sku_stock_df  SKU×库存维度 库存日快照
-- 粒度：travel_date × sku_id × pool_no × play_date × room_type_code/show_time
-- 来源：dwd_inv_pool_snapshot_df, dwd_inv_pool_change_di, dwd_inv_unit_change_di
-- 生成方式：Spark SQL / Hive；字段 19 个：直接翻译 5 · 规则翻译 2 · 待确认 12
-- 多来源：每个来源表按粒度键先汇总，UNION ALL 后再合并；快照/累计表：增量来源取截至统计日的全部分区
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT OVERWRITE TABLE dws.dws_inv_sku_stock_df PARTITION (travel_date = '${bizdate}')
SELECT
  u.sku_id,
  u.pool_no,
  u.play_date,
  u.room_type_code,
  u.show_time,
  SUM(u.stock_total_qty) AS stock_total_qty,
  SUM(u.stock_available_qty) AS stock_available_qty,
  SUM(u.stock_frozen_qty) AS stock_frozen_qty,
  SUM(u.stock_sold_qty) AS stock_sold_qty,
  SUM(u.sellout_pool_qty) AS sellout_pool_qty,
  SUM(u.unit_occupied_qty) AS unit_occupied_qty,
  SUM(u.unit_total_qty) AS unit_total_qty,
  SUM(u.prededuct_qty) AS prededuct_qty,
  SUM(u.prededuct_confirm_qty) AS prededuct_confirm_qty,
  SUM(u.prededuct_release_qty) AS prededuct_release_qty,
  CURRENT_TIMESTAMP() AS etl_time
FROM (
  -- 来源：dwd_inv_pool_snapshot_df
  SELECT
    sku_id AS sku_id,
    pool_no AS pool_no,
    play_date AS play_date,
    room_type_code AS room_type_code,
    show_time AS show_time,
    NULL AS stock_total_qty,  -- 待确认：sum(total_quantity)
    NULL AS stock_available_qty,  -- 待确认：sum(available_quantity)
    NULL AS stock_frozen_qty,  -- 待确认：sum(frozen_quantity)
    NULL AS stock_sold_qty,  -- 待确认：sum(total - available - frozen)
    COUNT(CASE WHEN 1 = 1 THEN pool_no END) AS sellout_pool_qty,  -- 待确认：available=0 and status='ON_SALE'
    NULL AS unit_occupied_qty,
    NULL AS unit_total_qty,
    NULL AS prededuct_qty,
    NULL AS prededuct_confirm_qty,
    NULL AS prededuct_release_qty
  FROM dwd.dwd_inv_pool_snapshot_df s
  WHERE s.travel_date = '${bizdate}'
  GROUP BY sku_id, pool_no, play_date, room_type_code, show_time
  UNION ALL
  -- 来源：dwd_inv_unit_change_di
  SELECT
    sku_id AS sku_id,
    pool_no AS pool_no,
    CAST(NULL AS STRING) AS play_date,
    room_type_code AS room_type_code,
    CAST(NULL AS STRING) AS show_time,
    NULL AS stock_total_qty,
    NULL AS stock_available_qty,
    NULL AS stock_frozen_qty,
    NULL AS stock_sold_qty,
    NULL AS sellout_pool_qty,
    COUNT(CASE WHEN 1 = 1 THEN unit_no END) AS unit_occupied_qty,  -- 待确认：status='OCCUPIED'
    NULL AS unit_total_qty,
    NULL AS prededuct_qty,
    NULL AS prededuct_confirm_qty,
    NULL AS prededuct_release_qty
  FROM dwd.dwd_inv_unit_change_di s
  WHERE s.travel_date <= '${bizdate}'
  GROUP BY sku_id, pool_no, room_type_code
  UNION ALL
  -- 来源：dim_inv_unit_df
  SELECT
    sku_id AS sku_id,
    pool_no AS pool_no,
    CAST(NULL AS STRING) AS play_date,
    room_type_code AS room_type_code,
    CAST(NULL AS STRING) AS show_time,
    NULL AS stock_total_qty,
    NULL AS stock_available_qty,
    NULL AS stock_frozen_qty,
    NULL AS stock_sold_qty,
    NULL AS sellout_pool_qty,
    NULL AS unit_occupied_qty,
    COUNT(unit_no) AS unit_total_qty,
    NULL AS prededuct_qty,
    NULL AS prededuct_confirm_qty,
    NULL AS prededuct_release_qty
  FROM dim.dim_inv_unit_df s
  WHERE s.travel_date = '${bizdate}'
  GROUP BY sku_id, pool_no, room_type_code
  UNION ALL
  -- 来源：dwd_inv_pool_change_di
  SELECT
    sku_id AS sku_id,
    pool_no AS pool_no,
    play_date AS play_date,
    room_type_code AS room_type_code,
    show_time AS show_time,
    NULL AS stock_total_qty,
    NULL AS stock_available_qty,
    NULL AS stock_frozen_qty,
    NULL AS stock_sold_qty,
    NULL AS sellout_pool_qty,
    NULL AS unit_occupied_qty,
    NULL AS unit_total_qty,
    SUM(CASE WHEN change_type='PRE_DEDUCT' THEN frozen_change_qty END) AS prededuct_qty,
    NULL AS prededuct_confirm_qty,  -- 待确认：sum(qty) where change_type='CONFIRM'
    NULL AS prededuct_release_qty  -- 待确认：sum(qty) where change_type='ROLLBACK' and 来源为预扣
  FROM dwd.dwd_inv_pool_change_di s
  WHERE s.travel_date <= '${bizdate}'
  GROUP BY sku_id, pool_no, play_date, room_type_code, show_time
) u
GROUP BY u.sku_id, u.pool_no, u.play_date, u.room_type_code, u.show_time;
