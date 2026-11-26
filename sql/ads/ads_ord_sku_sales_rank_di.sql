-- ads.ads_ord_sku_sales_rank_di  SKU销售排行
-- 粒度：travel_date × seller_tenant_id × sku_id
-- 来源：dws_ord_tenant_sku_channel_trade_di, dws_ord_tenant_refund_di
-- 生成方式：Spark SQL / Hive；字段 17 个：直接翻译 17 · 规则翻译 0 · 待确认 0
-- 多来源：每个来源先按粒度键预聚合，UNION ALL 后再汇总

WITH
src_tenant_sku_channel_trade AS (                             -- 来源「商户×SKU×渠道 交易日汇总」按粒度键预聚合
  SELECT
    seller_tenant_id AS seller_tenant_id,                     -- 卖家租户ID
    sku_id AS sku_id,                                         -- SKU ID
    SUM(pay_amt) AS pay_amt,                                  -- 支付金额（GMV）（日）
    SUM(pay_ticket_qty) AS pay_ticket_qty,                    -- 支付票数（日）
    SUM(pay_amt) AS net_pay_amt,                              -- 净成交金额（日）
    SUM(pay_amt) AS gross_profit_amt,                         -- 毛利额（日）
    NULL AS refund_ticket_qty,
    SUM(pay_amt) AS avg_ticket_price_numerator_amt,           -- 平均票价分子（日）
    SUM(pay_ticket_qty) AS avg_ticket_price_denominator_qty,  -- 平均票价分母（日）
    SUM(pay_amt) AS gross_profit_numerator_amt,               -- 毛利率分子（日）
    SUM(pay_amt) AS gross_profit_denominator_amt,             -- 毛利率分母（日）
    SUM(pay_order_qty) AS pay_conversion_numerator_qty,       -- 下单支付转化率分子（日）
    SUM(order_qty) AS pay_conversion_denominator_qty,         -- 下单支付转化率分母（日）
    NULL AS refund_numerator_qty,
    SUM(pay_ticket_qty) AS refund_denominator_qty             -- 退票率分母（日）
  FROM dws.dws_ord_tenant_sku_channel_trade_di s              -- 来源表「商户×SKU×渠道 交易日汇总」
  WHERE s.travel_date = '${bizdate}'                          -- 只取当日分区
  GROUP BY seller_tenant_id, sku_id                           -- 按粒度键汇总
),
src_tenant_refund AS (                                        -- 来源「商户×SKU 退款日汇总」按粒度键预聚合
  SELECT
    seller_tenant_id AS seller_tenant_id,                     -- 卖家租户ID
    sku_id AS sku_id,                                         -- SKU ID
    NULL AS pay_amt,
    NULL AS pay_ticket_qty,
    NULL AS net_pay_amt,
    NULL AS gross_profit_amt,
    SUM(refund_ticket_qty) AS refund_ticket_qty,              -- 退款票数（日）
    NULL AS avg_ticket_price_numerator_amt,
    NULL AS avg_ticket_price_denominator_qty,
    NULL AS gross_profit_numerator_amt,
    NULL AS gross_profit_denominator_amt,
    NULL AS pay_conversion_numerator_qty,
    NULL AS pay_conversion_denominator_qty,
    SUM(refund_ticket_qty) AS refund_numerator_qty,           -- 退票率分子（日）
    NULL AS refund_denominator_qty
  FROM dws.dws_ord_tenant_refund_di s                         -- 来源表「商户×SKU 退款日汇总」
  WHERE s.travel_date = '${bizdate}'                          -- 只取当日分区
  GROUP BY seller_tenant_id, sku_id                           -- 按粒度键汇总
),
all_src AS (                                                  -- 各来源字段已对齐，UNION ALL 合并（比多表 FULL JOIN 少 shuffle）
  SELECT * FROM src_tenant_sku_channel_trade
  UNION ALL
  SELECT * FROM src_tenant_refund
),
merged AS (                                                   -- 按粒度键汇总，计算派生指标
  SELECT
    u.seller_tenant_id,                                       -- 卖家租户ID
    u.sku_id,                                                 -- SKU ID
    SUM(u.pay_amt) AS pay_amt,                                -- 支付金额（GMV）（日）
    SUM(u.pay_ticket_qty) AS pay_ticket_qty,                  -- 支付票数（日）
    SUM(u.net_pay_amt) AS net_pay_amt,                        -- 净成交金额（日）
    SUM(u.gross_profit_amt) AS gross_profit_amt,              -- 毛利额（日）
    SUM(u.refund_ticket_qty) AS refund_ticket_qty,            -- 退款票数（日）
    SUM(u.avg_ticket_price_numerator_amt) AS avg_ticket_price_numerator_amt,  -- 平均票价分子（日）
    SUM(u.avg_ticket_price_denominator_qty) AS avg_ticket_price_denominator_qty,  -- 平均票价分母（日）
    SUM(u.gross_profit_numerator_amt) AS gross_profit_numerator_amt,  -- 毛利率分子（日）
    SUM(u.gross_profit_denominator_amt) AS gross_profit_denominator_amt,  -- 毛利率分母（日）
    SUM(u.pay_conversion_numerator_qty) AS pay_conversion_numerator_qty,  -- 下单支付转化率分子（日）
    SUM(u.pay_conversion_denominator_qty) AS pay_conversion_denominator_qty,  -- 下单支付转化率分母（日）
    SUM(u.refund_numerator_qty) AS refund_numerator_qty,      -- 退票率分子（日）
    SUM(u.refund_denominator_qty) AS refund_denominator_qty,  -- 退票率分母（日）
    CURRENT_TIMESTAMP() AS etl_time                           -- ETL 加载时间
  FROM all_src u
  GROUP BY u.seller_tenant_id, u.sku_id                       -- 按粒度键汇总
),
tenant_cur AS (                                               -- 「租户（商户/供应商/分销商）维度」当前有效版本，只取名称类字段
  SELECT tenant_id, tenant_name
  FROM dim.dim_sup_tenant_zip
  WHERE travel_date = '${bizdate}' AND end_date = '9999-12-31'  -- 取当日分区里的拉链当前有效版本
),
sku_cur AS (                                                  -- 「SKU维度」当前有效版本，只取名称类字段
  SELECT sku_id, sku_name
  FROM dim.dim_prd_sku_zip
  WHERE travel_date = '${bizdate}' AND end_date = '9999-12-31'  -- 取当日分区里的拉链当前有效版本
)
INSERT OVERWRITE TABLE ads.ads_ord_sku_sales_rank_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  merged.seller_tenant_id,                                    -- 卖家租户ID
  merged.sku_id,                                              -- SKU ID
  tenant_cur.tenant_name AS seller_tenant_name,               -- 卖家租户名称
  sku_cur.sku_name AS sku_name,                               -- SKU 名称
  merged.pay_amt,                                             -- 支付金额（GMV）（日）
  merged.pay_ticket_qty,                                      -- 支付票数（日）
  merged.net_pay_amt,                                         -- 净成交金额（日）
  merged.gross_profit_amt,                                    -- 毛利额（日）
  merged.refund_ticket_qty,                                   -- 退款票数（日）
  merged.avg_ticket_price_numerator_amt,                      -- 平均票价分子（日）
  merged.avg_ticket_price_denominator_qty,                    -- 平均票价分母（日）
  merged.gross_profit_numerator_amt,                          -- 毛利率分子（日）
  merged.gross_profit_denominator_amt,                        -- 毛利率分母（日）
  merged.pay_conversion_numerator_qty,                        -- 下单支付转化率分子（日）
  merged.pay_conversion_denominator_qty,                      -- 下单支付转化率分母（日）
  merged.refund_numerator_qty,                                -- 退票率分子（日）
  merged.refund_denominator_qty,                              -- 退票率分母（日）
  merged.etl_time                                             -- ETL 加载时间
FROM merged
LEFT JOIN tenant_cur                                          -- 关联「租户（商户/供应商/分销商）维度」，补 seller_tenant_name
  ON tenant_cur.tenant_id = merged.seller_tenant_id           -- 按 seller_tenant_id→tenant_id 关联
LEFT JOIN sku_cur                                             -- 关联「SKU维度」，补 sku_name
  ON sku_cur.sku_id = merged.sku_id;                          -- 按 sku_id 关联
