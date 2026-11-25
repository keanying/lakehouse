-- ads.ads_prd_price_discount_di  价格与折扣分析
-- 粒度：travel_date × sku_id × price_channel_code
-- 来源：dws_prd_sku_price_di
-- 生成方式：Spark SQL / Hive；字段 10 个：直接翻译 10 · 规则翻译 0 · 待确认 0

INSERT OVERWRITE TABLE ads.ads_prd_price_discount_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  x.sku_id,                                                 -- SKU ID
  x.price_channel_code,                                     -- 价格渠道编码
  d1.sku_name AS sku_name,                                  -- SKU 名称
  x.list_price_amt,                                         -- 生效标价（日）
  x.avg_deal_price_numerator_amt,                           -- 平均成交价分子（日）
  x.avg_deal_price_denominator_qty,                         -- 平均成交价分母（日）
  x.discount_numerator_amt,                                 -- 成交折扣率分子（日）
  x.discount_denominator_amt,                               -- 成交折扣率分母（日）
  x.price_change_qty,                                       -- 调价次数（日）
  x.sku_change_qty,                                         -- SKU属性变更次数（日）
  x.etl_time                                                -- ETL 加载时间
FROM (
SELECT
  u.sku_id,                                                 -- SKU ID
  u.price_channel_code,                                     -- 价格渠道编码
  SUM(u.list_price_amt) AS list_price_amt,                  -- 生效标价（日）
  SUM(u.avg_deal_price_numerator_amt) AS avg_deal_price_numerator_amt,  -- 平均成交价分子（日）
  SUM(u.avg_deal_price_denominator_qty) AS avg_deal_price_denominator_qty,  -- 平均成交价分母（日）
  SUM(u.discount_numerator_amt) AS discount_numerator_amt,  -- 成交折扣率分子（日）
  SUM(u.discount_denominator_amt) AS discount_denominator_amt,  -- 成交折扣率分母（日）
  SUM(u.price_change_qty) AS price_change_qty,              -- 调价次数（日）
  SUM(u.sku_change_qty) AS sku_change_qty,                  -- SKU属性变更次数（日）
  CURRENT_TIMESTAMP() AS etl_time                           -- ETL 加载时间
FROM (
  -- 来源：dws_prd_sku_price_di
  SELECT
    sku_id AS sku_id,                                       -- SKU ID
    price_channel_code AS price_channel_code,               -- 价格渠道编码
    SUM(list_price_amt) AS list_price_amt,                  -- 生效标价（日）
    SUM(pay_amt) AS avg_deal_price_numerator_amt,           -- 平均成交价分子（日）
    SUM(pay_ticket_qty) AS avg_deal_price_denominator_qty,  -- 平均成交价分母（日）
    SUM(avg_deal_price_amt) AS discount_numerator_amt,      -- 成交折扣率分子（日）
    SUM(list_price_amt) AS discount_denominator_amt,        -- 成交折扣率分母（日）
    SUM(price_change_qty) AS price_change_qty,              -- 调价次数（日）
    SUM(sku_change_qty) AS sku_change_qty                   -- SKU属性变更次数（日）
  FROM dws.dws_prd_sku_price_di s                           -- 来源表「SKU×渠道 价格日汇总」
  WHERE s.travel_date = '${bizdate}'                        -- 只取当日分区
  GROUP BY sku_id, price_channel_code                       -- 按粒度键汇总
) u                                                         -- 各来源合并后的明细
GROUP BY u.sku_id, u.price_channel_code                     -- 按粒度键汇总
) x                                                         -- 汇总结果，外层再补维度名称
LEFT JOIN dim.dim_prd_sku_zip d1 ON d1.sku_id = x.sku_id AND d1.travel_date = '${bizdate}' AND d1.end_date = '9999-12-31';  -- 关联「SKU维度」，取维度名称
