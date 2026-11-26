-- ads.ads_prd_price_discount_di  价格与折扣分析
-- 粒度：travel_date × sku_id × price_channel_code
-- 来源：dws_prd_sku_price_di
-- 生成方式：Spark SQL / Hive；字段 10 个：直接翻译 10 · 规则翻译 0 · 待确认 0
-- 来源先按粒度键预聚合

WITH
src_sku_price AS (                                 -- 来源「SKU×渠道 价格日汇总」按粒度键预聚合
  SELECT
    sku_id AS sku_id,                              -- SKU ID
    price_channel_code AS price_channel_code,      -- 价格渠道编码
    SUM(list_price_amt) AS list_price_amt,         -- 生效标价（日）
    SUM(pay_amt) AS avg_deal_price_numerator_amt,  -- 平均成交价分子（日）
    SUM(pay_ticket_qty) AS avg_deal_price_denominator_qty,  -- 平均成交价分母（日）
    SUM(avg_deal_price_amt) AS discount_numerator_amt,  -- 成交折扣率分子（日）
    SUM(list_price_amt) AS discount_denominator_amt,  -- 成交折扣率分母（日）
    SUM(price_change_qty) AS price_change_qty,     -- 调价次数（日）
    SUM(sku_change_qty) AS sku_change_qty          -- SKU属性变更次数（日）
  FROM dws.dws_prd_sku_price_di s                  -- 来源表「SKU×渠道 价格日汇总」
  WHERE s.travel_date = '${bizdate}'               -- 只取当日分区
  GROUP BY sku_id, price_channel_code              -- 按粒度键汇总
),
merged AS (                                        -- 按粒度键汇总，计算派生指标
  SELECT
    u.sku_id,                                      -- SKU ID
    u.price_channel_code,                          -- 价格渠道编码
    u.list_price_amt,                              -- 生效标价（日）
    u.avg_deal_price_numerator_amt,                -- 平均成交价分子（日）
    u.avg_deal_price_denominator_qty,              -- 平均成交价分母（日）
    u.discount_numerator_amt,                      -- 成交折扣率分子（日）
    u.discount_denominator_amt,                    -- 成交折扣率分母（日）
    u.price_change_qty,                            -- 调价次数（日）
    u.sku_change_qty,                              -- SKU属性变更次数（日）
    CURRENT_TIMESTAMP() AS etl_time                -- ETL 加载时间
  FROM src_sku_price u
),
sku_cur AS (                                       -- 「SKU维度」当前有效版本，只取名称类字段
  SELECT sku_id, sku_name
  FROM dim.dim_prd_sku_zip
  WHERE travel_date = '${bizdate}' AND end_date = '9999-12-31'  -- 取当日分区里的拉链当前有效版本
)
INSERT OVERWRITE TABLE ads.ads_prd_price_discount_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  merged.sku_id,                                   -- SKU ID
  merged.price_channel_code,                       -- 价格渠道编码
  sku_cur.sku_name AS sku_name,                    -- SKU 名称
  merged.list_price_amt,                           -- 生效标价（日）
  merged.avg_deal_price_numerator_amt,             -- 平均成交价分子（日）
  merged.avg_deal_price_denominator_qty,           -- 平均成交价分母（日）
  merged.discount_numerator_amt,                   -- 成交折扣率分子（日）
  merged.discount_denominator_amt,                 -- 成交折扣率分母（日）
  merged.price_change_qty,                         -- 调价次数（日）
  merged.sku_change_qty,                           -- SKU属性变更次数（日）
  merged.etl_time                                  -- ETL 加载时间
FROM merged
LEFT JOIN sku_cur                                  -- 关联「SKU维度」，补 sku_name
  ON sku_cur.sku_id = merged.sku_id;               -- 按 sku_id 关联
