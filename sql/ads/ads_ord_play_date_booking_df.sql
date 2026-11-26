-- ads.ads_ord_play_date_booking_df  未来游玩日预订看板
-- 粒度：travel_date × sku_id × play_date
-- 来源：dws_ord_sku_play_date_booking_df, dws_inv_sku_stock_df
-- 生成方式：Spark SQL / Hive；字段 10 个：直接翻译 4 · 规则翻译 6 · 待确认 0
-- 多来源：各来源按粒度键预聚合后 UNION ALL 合并，再按公式计算

WITH
src_sku_play_date_booking AS (                           -- 来源「SKU×游玩日 预订存量快照」按粒度键预聚合
  SELECT
    s.sku_id AS sku_id,                                  -- SKU ID
    s.play_date AS play_date,                            -- 游玩日期
    SUM(s.pay_ticket_qty) AS pay_ticket_qty,
    SUM(s.refund_ticket_qty) AS refund_ticket_qty,
    SUM(s.net_pay_ticket_qty) AS net_pay_ticket_qty,
    SUM(s.stock_available_qty) AS stock_available_qty,
    NULL AS stock_sold_qty,
    NULL AS stock_total_qty,
    SUM(s.advance_book_day_qty) AS advance_book_day_qty
  FROM dws.dws_ord_sku_play_date_booking_df s            -- 来源表「SKU×游玩日 预订存量快照」
  WHERE s.travel_date = '${bizdate}'                     -- 只取当日分区
  GROUP BY s.sku_id, s.play_date                         -- 按粒度键汇总
),
src_sku_stock AS (                                       -- 来源「SKU×库存维度 库存日快照」按粒度键预聚合
  SELECT
    s.sku_id AS sku_id,                                  -- SKU ID
    s.play_date AS play_date,                            -- 游玩日期
    NULL AS pay_ticket_qty,
    NULL AS refund_ticket_qty,
    NULL AS net_pay_ticket_qty,
    NULL AS stock_available_qty,
    SUM(s.stock_sold_qty) AS stock_sold_qty,
    SUM(s.stock_total_qty) AS stock_total_qty,
    NULL AS advance_book_day_qty
  FROM dws.dws_inv_sku_stock_df s                        -- 来源表「SKU×库存维度 库存日快照」
  WHERE s.travel_date = '${bizdate}'                     -- 只取当日分区
  GROUP BY s.sku_id, s.play_date                         -- 按粒度键汇总
),
all_src AS (                                             -- 各来源字段已对齐，UNION ALL 合并（比多表 FULL JOIN 少 shuffle）
  SELECT * FROM src_sku_play_date_booking
  UNION ALL
  SELECT * FROM src_sku_stock
),
merged AS (                                              -- 按粒度键汇总，计算派生指标
  SELECT
    u.sku_id,                                            -- SKU ID
    u.play_date,                                         -- 游玩日期
    SUM(u.pay_ticket_qty) AS pay_ticket_td_qty,          -- 截至当日支付票数
    SUM(u.refund_ticket_qty) AS refund_ticket_td_qty,    -- 截至当日退款票数
    SUM(u.net_pay_ticket_qty) AS net_pay_ticket_td_qty,  -- 截至当日净支付票数
    SUM(u.stock_available_qty) AS stock_available_td_qty,  -- 截至当日可用库存
    SUM(u.stock_sold_qty) * 100 / NULLIF(SUM(u.stock_total_qty), 0) AS stock_sell_through_td_rate,  -- 截至当日库存去化率（上座率/入住率）
    SUM(u.advance_book_day_qty) / NULLIF(SUM(u.pay_ticket_qty), 0) AS avg_advance_book_day_td_qty,  -- 截至当日平均提前预订天数
    CURRENT_TIMESTAMP() AS etl_time                      -- ETL 加载时间
  FROM all_src u
  GROUP BY u.sku_id, u.play_date                         -- 按粒度键汇总
),
sku_cur AS (                                             -- 「SKU维度」当前有效版本，只取名称类字段
  SELECT sku_id, sku_name
  FROM dim.dim_prd_sku_zip
  WHERE travel_date = '${bizdate}' AND end_date = '9999-12-31'  -- 取当日分区里的拉链当前有效版本
)
INSERT OVERWRITE TABLE ads.ads_ord_play_date_booking_df PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  merged.sku_id,                                         -- SKU ID
  merged.play_date,                                      -- 游玩日期
  sku_cur.sku_name AS sku_name,                          -- SKU 名称
  merged.pay_ticket_td_qty,                              -- 截至当日支付票数
  merged.refund_ticket_td_qty,                           -- 截至当日退款票数
  merged.net_pay_ticket_td_qty,                          -- 截至当日净支付票数
  merged.stock_available_td_qty,                         -- 截至当日可用库存
  merged.stock_sell_through_td_rate,                     -- 截至当日库存去化率（上座率/入住率）
  merged.avg_advance_book_day_td_qty,                    -- 截至当日平均提前预订天数
  merged.etl_time                                        -- ETL 加载时间
FROM merged
LEFT JOIN sku_cur                                        -- 关联「SKU维度」，补 sku_name
  ON sku_cur.sku_id = merged.sku_id;                     -- 按 sku_id 关联
