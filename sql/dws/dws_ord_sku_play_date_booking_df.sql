-- dws.dws_ord_sku_play_date_booking_df  SKU×游玩日 预订存量快照
-- 粒度：travel_date（快照日）× sku_id × play_date × time_slot_code
-- 来源：dwd_ord_order_di, dwd_ord_refund_ticket_di, dwd_ord_verify_di, dwd_inv_pool_snapshot_df
-- 生成方式：Spark SQL / Hive；字段 12 个：直接翻译 3 · 规则翻译 2 · 待确认 7
-- 多来源：每个来源先按粒度键预聚合，UNION ALL 后再汇总；快照/累计表：增量来源取截至统计日的全部分区
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

WITH
src_order AS (                                        -- 来源「子单明细」按粒度键预聚合
  SELECT
    sku_id AS sku_id,                                 -- SKU ID
    play_date AS play_date,                           -- 游玩日期
    time_slot_code AS time_slot_code,                 -- 游玩时段
    SUM(CASE WHEN pay_time IS NOT NULL THEN buy_ticket_qty END) AS pay_ticket_qty,  -- 支付票数
    NULL AS refund_ticket_qty,
    NULL AS verify_ticket_qty,
    NULL AS advance_book_day_qty,                     -- 待确认：sum(datediff(play_date, pay_date) * buy_ticket_qty)
    NULL AS stock_available_qty
  FROM dwd.dwd_ord_order_di s                         -- 来源表「子单明细」
  WHERE s.travel_date <= '${bizdate}'                 -- 累计口径：取截至统计日的全部分区
  GROUP BY sku_id, play_date, time_slot_code          -- 按粒度键汇总
),
src_refund_ticket AS (                                -- 来源「退款票明细」按粒度键预聚合
  SELECT
    sku_id AS sku_id,                                 -- SKU ID
    play_date AS play_date,                           -- 游玩日期
    CAST(NULL AS STRING) AS time_slot_code,
    NULL AS pay_ticket_qty,
    COUNT(DISTINCT CASE WHEN 1 = 1 THEN ticket_no END) AS refund_ticket_qty,  -- 退款票数｜待确认：of completed refunds
    NULL AS verify_ticket_qty,
    NULL AS advance_book_day_qty,
    NULL AS stock_available_qty
  FROM dwd.dwd_ord_refund_ticket_di s                 -- 来源表「退款票明细」
  WHERE s.travel_date <= '${bizdate}'                 -- 累计口径：取截至统计日的全部分区
  GROUP BY sku_id, play_date                          -- 按粒度键汇总
),
src_verify AS (                                       -- 来源「核销明细（权益级）」按粒度键预聚合
  SELECT
    sku_id AS sku_id,                                 -- SKU ID
    play_date AS play_date,                           -- 游玩日期
    CAST(NULL AS STRING) AS time_slot_code,
    NULL AS pay_ticket_qty,
    NULL AS refund_ticket_qty,
    COUNT(DISTINCT CASE WHEN 1 = 1 THEN ticket_no END) AS verify_ticket_qty,  -- 核销票数｜待确认：verify_result='SUCCESS'
    NULL AS advance_book_day_qty,
    NULL AS stock_available_qty
  FROM dwd.dwd_ord_verify_di s                        -- 来源表「核销明细（权益级）」
  WHERE s.travel_date <= '${bizdate}'                 -- 累计口径：取截至统计日的全部分区
  GROUP BY sku_id, play_date                          -- 按粒度键汇总
),
src_pool_snapshot AS (                                -- 来源「库存池日快照」按粒度键预聚合
  SELECT
    sku_id AS sku_id,                                 -- SKU ID
    play_date AS play_date,                           -- 游玩日期
    CAST(NULL AS STRING) AS time_slot_code,
    NULL AS pay_ticket_qty,
    NULL AS refund_ticket_qty,
    NULL AS verify_ticket_qty,
    NULL AS advance_book_day_qty,
    NULL AS stock_available_qty                       -- 待确认：sum(available_quantity)
  FROM dwd.dwd_inv_pool_snapshot_df s                 -- 来源表「库存池日快照」
  WHERE s.travel_date = '${bizdate}'                  -- 只取当日分区
  GROUP BY sku_id, play_date                          -- 按粒度键汇总
),
all_src AS (                                          -- 各来源字段已对齐，UNION ALL 合并（比多表 FULL JOIN 少 shuffle）
  SELECT * FROM src_order
  UNION ALL
  SELECT * FROM src_refund_ticket
  UNION ALL
  SELECT * FROM src_verify
  UNION ALL
  SELECT * FROM src_pool_snapshot
)
INSERT OVERWRITE TABLE dws.dws_ord_sku_play_date_booking_df PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  u.sku_id,                                           -- SKU ID
  u.play_date,                                        -- 游玩日期
  u.time_slot_code,                                   -- 游玩时段
  SUM(u.pay_ticket_qty) AS pay_ticket_qty,            -- 支付票数
  SUM(u.refund_ticket_qty) AS refund_ticket_qty,      -- 退款票数
  SUM(u.pay_ticket_qty) - SUM(u.refund_ticket_qty) AS net_pay_ticket_qty,  -- 净支付票数
  SUM(u.verify_ticket_qty) AS verify_ticket_qty,      -- 核销票数
  SUM(u.advance_book_day_qty) AS advance_book_day_qty,  -- 提前预订天数合计
  SUM(u.stock_available_qty) AS stock_available_qty,  -- 可用库存
  CURRENT_TIMESTAMP() AS etl_time                     -- ETL 加载时间
FROM all_src u
GROUP BY u.sku_id, u.play_date, u.time_slot_code;     -- 按粒度键汇总
