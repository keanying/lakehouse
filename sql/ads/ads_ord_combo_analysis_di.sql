-- ads.ads_ord_combo_analysis_di  套票分析（主子单/跨商户/部分退）
-- 粒度：travel_date × combo_sku_id × sub_sku_id
-- 来源：dws_ord_combo_sku_trade_di
-- 生成方式：Spark SQL / Hive；字段 12 个：直接翻译 12 · 规则翻译 0 · 待确认 0
-- 来源先按粒度键预聚合

WITH
src_combo_sku_trade AS (                      -- 来源「套票×子项 交易日汇总」按粒度键预聚合
  SELECT
    combo_sku_id AS combo_sku_id,             -- 套票主 SKU ID
    sub_sku_id AS sub_sku_id,                 -- 套票子项 SKU ID
    SUM(combo_order_qty) AS combo_order_qty,  -- 套票主单数（日）
    SUM(pay_amt) AS pay_amt,                  -- 支付金额（GMV）（日）
    SUM(pay_ticket_qty) AS pay_ticket_qty,    -- 支付票数（日）
    SUM(verify_ticket_qty) AS verify_ticket_qty,  -- 核销票数（日）
    SUM(refund_ticket_qty) AS refund_ticket_qty,  -- 退款票数（日）
    SUM(refund_amt) AS refund_amt,            -- 退款金额（日）
    SUM(refund_ticket_qty) AS combo_refund_numerator_qty,  -- 套票部分退率分子（日）
    SUM(refund_ticket_qty) AS combo_refund_denominator_qty  -- 套票部分退率分母（日）
  FROM dws.dws_ord_combo_sku_trade_di s       -- 来源表「套票×子项 交易日汇总」
  WHERE s.travel_date = '${bizdate}'          -- 只取当日分区
  GROUP BY combo_sku_id, sub_sku_id           -- 按粒度键汇总
),
merged AS (                                   -- 按粒度键汇总，计算派生指标
  SELECT
    u.combo_sku_id,                           -- 套票主 SKU ID
    u.sub_sku_id,                             -- 套票子项 SKU ID
    u.combo_order_qty,                        -- 套票主单数（日）
    u.pay_amt,                                -- 支付金额（GMV）（日）
    u.pay_ticket_qty,                         -- 支付票数（日）
    u.verify_ticket_qty,                      -- 核销票数（日）
    u.refund_ticket_qty,                      -- 退款票数（日）
    u.refund_amt,                             -- 退款金额（日）
    u.combo_refund_numerator_qty,             -- 套票部分退率分子（日）
    u.combo_refund_denominator_qty,           -- 套票部分退率分母（日）
    CURRENT_TIMESTAMP() AS etl_time           -- ETL 加载时间
  FROM src_combo_sku_trade u
),
sku_cur AS (                                  -- 「SKU维度」当前有效版本，只取名称类字段
  SELECT sku_id, sku_name
  FROM dim.dim_prd_sku_zip
  WHERE travel_date = '${bizdate}' AND end_date = '9999-12-31'  -- 取当日分区里的拉链当前有效版本
),
sku_cur_2 AS (                                -- 「SKU维度」当前有效版本，只取名称类字段
  SELECT sku_id, sku_name
  FROM dim.dim_prd_sku_zip
  WHERE travel_date = '${bizdate}' AND end_date = '9999-12-31'  -- 取当日分区里的拉链当前有效版本
)
INSERT OVERWRITE TABLE ads.ads_ord_combo_analysis_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  merged.combo_sku_id,                        -- 套票主 SKU ID
  merged.sub_sku_id,                          -- 套票子项 SKU ID
  sku_cur.sku_name AS combo_sku_name,         -- 套票名称
  sku_cur_2.sku_name AS sub_sku_name,         -- 子项 SKU 名称
  merged.combo_order_qty,                     -- 套票主单数（日）
  merged.pay_amt,                             -- 支付金额（GMV）（日）
  merged.pay_ticket_qty,                      -- 支付票数（日）
  merged.verify_ticket_qty,                   -- 核销票数（日）
  merged.refund_ticket_qty,                   -- 退款票数（日）
  merged.refund_amt,                          -- 退款金额（日）
  merged.combo_refund_numerator_qty,          -- 套票部分退率分子（日）
  merged.combo_refund_denominator_qty,        -- 套票部分退率分母（日）
  merged.etl_time                             -- ETL 加载时间
FROM merged
LEFT JOIN sku_cur                             -- 关联「SKU维度」，补 combo_sku_name
  ON sku_cur.sku_id = merged.combo_sku_id     -- 按 combo_sku_id→sku_id 关联
LEFT JOIN sku_cur_2                           -- 关联「SKU维度」，补 sub_sku_name
  ON sku_cur_2.sku_id = merged.sub_sku_id;    -- 按 sub_sku_id→sku_id 关联
