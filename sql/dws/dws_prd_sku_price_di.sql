-- dws.dws_prd_sku_price_di  SKU×渠道 价格日汇总
-- 粒度：travel_date × sku_id × price_channel_code
-- 来源：dwd_prd_sku_price_calendar_df, dwd_prd_price_point_log_di, dwd_ord_order_di, dwd_prd_sku_version_di
-- 生成方式：Spark SQL / Hive；字段 11 个：直接翻译 2 · 规则翻译 9 · 待确认 0
-- 多来源：每个来源先按粒度键预聚合，UNION ALL 后再汇总

WITH
src_sku_price_calendar AS (                     -- 来源「SKU每日生效价日历」按粒度键预聚合
  SELECT
    sku_id AS sku_id,                           -- SKU ID
    price_channel_code AS price_channel_code,   -- 价格渠道编码
    MAX(CASE WHEN price_date = '${bizdate_dash}' THEN list_price_amt END) AS list_price_amt,  -- 生效标价｜口径：价格日历中统计日当天生效的挂牌价
    NULL AS price_change_qty,
    NULL AS pay_amt,
    NULL AS pay_ticket_qty,
    NULL AS sku_change_qty
  FROM dwd.dwd_prd_sku_price_calendar_df s      -- 来源表「SKU每日生效价日历」
  WHERE s.travel_date = '${bizdate}'            -- 只取当日分区
  GROUP BY sku_id, price_channel_code           -- 按粒度键汇总
),
src_price_point_log AS (                        -- 来源「价格点变更明细」按粒度键预聚合
  SELECT
    sku_id AS sku_id,                           -- SKU ID
    price_channel_code AS price_channel_code,   -- 价格渠道编码
    NULL AS list_price_amt,
    COUNT(1) AS price_change_qty,               -- 调价次数
    NULL AS pay_amt,
    NULL AS pay_ticket_qty,
    NULL AS sku_change_qty
  FROM dwd.dwd_prd_price_point_log_di s         -- 来源表「价格点变更明细」
  WHERE s.travel_date = '${bizdate}'            -- 只取当日分区
  GROUP BY sku_id, price_channel_code           -- 按粒度键汇总
),
src_order AS (                                  -- 来源「子单明细」按粒度键预聚合
  SELECT
    sku_id AS sku_id,                           -- SKU ID
    CAST(NULL AS STRING) AS price_channel_code,
    NULL AS list_price_amt,
    NULL AS price_change_qty,
    SUM(CASE WHEN pay_time IS NOT NULL THEN unit_price_amt*buy_ticket_qty END) AS pay_amt,  -- 支付金额（GMV）
    SUM(CASE WHEN pay_time IS NOT NULL THEN buy_ticket_qty END) AS pay_ticket_qty,  -- 支付票数
    NULL AS sku_change_qty
  FROM dwd.dwd_ord_order_di s                   -- 来源表「子单明细」
  WHERE s.travel_date = '${bizdate}'            -- 只取当日分区
  GROUP BY sku_id                               -- 按粒度键汇总
),
src_sku_version AS (                            -- 来源「SKU版本变更明细」按粒度键预聚合
  SELECT
    sku_id AS sku_id,                           -- SKU ID
    CAST(NULL AS STRING) AS price_channel_code,
    NULL AS list_price_amt,
    NULL AS price_change_qty,
    NULL AS pay_amt,
    NULL AS pay_ticket_qty,
    COUNT(snapshot_no) AS sku_change_qty        -- SKU属性变更次数
  FROM dwd.dwd_prd_sku_version_di s             -- 来源表「SKU版本变更明细」
  WHERE s.travel_date = '${bizdate}'            -- 只取当日分区
  GROUP BY sku_id                               -- 按粒度键汇总
),
all_src AS (                                    -- 各来源字段已对齐，UNION ALL 合并（比多表 FULL JOIN 少 shuffle）
  SELECT * FROM src_sku_price_calendar
  UNION ALL
  SELECT * FROM src_price_point_log
  UNION ALL
  SELECT * FROM src_order
  UNION ALL
  SELECT * FROM src_sku_version
)
INSERT OVERWRITE TABLE dws.dws_prd_sku_price_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  u.sku_id,                                     -- SKU ID
  u.price_channel_code,                         -- 价格渠道编码
  SUM(u.list_price_amt) AS list_price_amt,      -- 生效标价
  SUM(u.price_change_qty) AS price_change_qty,  -- 调价次数
  SUM(u.pay_amt) / NULLIF(SUM(u.pay_ticket_qty), 0) AS avg_deal_price_amt,  -- 平均成交价
  (SUM(u.pay_amt) / NULLIF(SUM(u.pay_ticket_qty), 0)) * 100 / NULLIF(SUM(u.list_price_amt), 0) AS discount_rate,  -- 成交折扣率
  SUM(u.pay_amt) AS pay_amt,                    -- 支付金额（GMV）
  SUM(u.pay_ticket_qty) AS pay_ticket_qty,      -- 支付票数
  SUM(u.sku_change_qty) AS sku_change_qty,      -- SKU属性变更次数
  CURRENT_TIMESTAMP() AS etl_time               -- ETL 加载时间
FROM all_src u
GROUP BY u.sku_id, u.price_channel_code;        -- 按粒度键汇总
