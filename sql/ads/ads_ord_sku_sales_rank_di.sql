-- ads.ads_ord_sku_sales_rank_di  SKU销售排行
-- 粒度：travel_date × seller_tenant_id × sku_id
-- 来源：dws_ord_tenant_sku_channel_trade_di, dws_ord_tenant_refund_di
-- 生成方式：Spark SQL / Hive；字段 17 个：直接翻译 17 · 规则翻译 0 · 待确认 0
-- 多来源：每个来源表按粒度键先汇总，UNION ALL 后再合并

INSERT OVERWRITE TABLE ads.ads_ord_sku_sales_rank_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  x.seller_tenant_id,                                    -- 卖家租户ID
  x.sku_id,                                              -- SKU ID
  d1.tenant_name AS seller_tenant_name,                  -- 卖家租户名称
  d2.sku_name AS sku_name,                               -- SKU 名称
  x.pay_amt,                                             -- 支付金额（GMV）（日）
  x.pay_ticket_qty,                                      -- 支付票数（日）
  x.net_pay_amt,                                         -- 净成交金额（日）
  x.gross_profit_amt,                                    -- 毛利额（日）
  x.refund_ticket_qty,                                   -- 退款票数（日）
  x.avg_ticket_price_numerator_amt,                      -- 平均票价分子（日）
  x.avg_ticket_price_denominator_qty,                    -- 平均票价分母（日）
  x.gross_profit_numerator_amt,                          -- 毛利率分子（日）
  x.gross_profit_denominator_amt,                        -- 毛利率分母（日）
  x.pay_conversion_numerator_qty,                        -- 下单支付转化率分子（日）
  x.pay_conversion_denominator_qty,                      -- 下单支付转化率分母（日）
  x.refund_numerator_qty,                                -- 退票率分子（日）
  x.refund_denominator_qty,                              -- 退票率分母（日）
  x.etl_time                                             -- ETL 加载时间
FROM (
SELECT
  u.seller_tenant_id,                                    -- 卖家租户ID
  u.sku_id,                                              -- SKU ID
  SUM(u.pay_amt) AS pay_amt,                             -- 支付金额（GMV）（日）
  SUM(u.pay_ticket_qty) AS pay_ticket_qty,               -- 支付票数（日）
  SUM(u.net_pay_amt) AS net_pay_amt,                     -- 净成交金额（日）
  SUM(u.gross_profit_amt) AS gross_profit_amt,           -- 毛利额（日）
  SUM(u.refund_ticket_qty) AS refund_ticket_qty,         -- 退款票数（日）
  SUM(u.avg_ticket_price_numerator_amt) AS avg_ticket_price_numerator_amt,  -- 平均票价分子（日）
  SUM(u.avg_ticket_price_denominator_qty) AS avg_ticket_price_denominator_qty,  -- 平均票价分母（日）
  SUM(u.gross_profit_numerator_amt) AS gross_profit_numerator_amt,  -- 毛利率分子（日）
  SUM(u.gross_profit_denominator_amt) AS gross_profit_denominator_amt,  -- 毛利率分母（日）
  SUM(u.pay_conversion_numerator_qty) AS pay_conversion_numerator_qty,  -- 下单支付转化率分子（日）
  SUM(u.pay_conversion_denominator_qty) AS pay_conversion_denominator_qty,  -- 下单支付转化率分母（日）
  SUM(u.refund_numerator_qty) AS refund_numerator_qty,   -- 退票率分子（日）
  SUM(u.refund_denominator_qty) AS refund_denominator_qty,  -- 退票率分母（日）
  CURRENT_TIMESTAMP() AS etl_time                        -- ETL 加载时间
FROM (
  -- 来源：dws_ord_tenant_sku_channel_trade_di
  SELECT
    seller_tenant_id AS seller_tenant_id,                -- 卖家租户ID
    sku_id AS sku_id,                                    -- SKU ID
    SUM(pay_amt) AS pay_amt,                             -- 支付金额（GMV）（日）
    SUM(pay_ticket_qty) AS pay_ticket_qty,               -- 支付票数（日）
    SUM(pay_amt) AS net_pay_amt,                         -- 净成交金额（日）
    SUM(pay_amt) AS gross_profit_amt,                    -- 毛利额（日）
    NULL AS refund_ticket_qty,                           -- 退款票数（日）
    SUM(pay_amt) AS avg_ticket_price_numerator_amt,      -- 平均票价分子（日）
    SUM(pay_ticket_qty) AS avg_ticket_price_denominator_qty,  -- 平均票价分母（日）
    SUM(pay_amt) AS gross_profit_numerator_amt,          -- 毛利率分子（日）
    SUM(pay_amt) AS gross_profit_denominator_amt,        -- 毛利率分母（日）
    SUM(pay_order_qty) AS pay_conversion_numerator_qty,  -- 下单支付转化率分子（日）
    SUM(order_qty) AS pay_conversion_denominator_qty,    -- 下单支付转化率分母（日）
    NULL AS refund_numerator_qty,                        -- 退票率分子（日）
    SUM(pay_ticket_qty) AS refund_denominator_qty        -- 退票率分母（日）
  FROM dws.dws_ord_tenant_sku_channel_trade_di s         -- 来源表「商户×SKU×渠道 交易日汇总」
  WHERE s.travel_date = '${bizdate}'                     -- 只取当日分区
  GROUP BY seller_tenant_id, sku_id                      -- 按粒度键汇总
  UNION ALL                                              -- 合并各来源
  -- 来源：dws_ord_tenant_refund_di
  SELECT
    seller_tenant_id AS seller_tenant_id,                -- 卖家租户ID
    sku_id AS sku_id,                                    -- SKU ID
    NULL AS pay_amt,                                     -- 支付金额（GMV）（日）
    NULL AS pay_ticket_qty,                              -- 支付票数（日）
    NULL AS net_pay_amt,                                 -- 净成交金额（日）
    NULL AS gross_profit_amt,                            -- 毛利额（日）
    SUM(refund_ticket_qty) AS refund_ticket_qty,         -- 退款票数（日）
    NULL AS avg_ticket_price_numerator_amt,              -- 平均票价分子（日）
    NULL AS avg_ticket_price_denominator_qty,            -- 平均票价分母（日）
    NULL AS gross_profit_numerator_amt,                  -- 毛利率分子（日）
    NULL AS gross_profit_denominator_amt,                -- 毛利率分母（日）
    NULL AS pay_conversion_numerator_qty,                -- 下单支付转化率分子（日）
    NULL AS pay_conversion_denominator_qty,              -- 下单支付转化率分母（日）
    SUM(refund_ticket_qty) AS refund_numerator_qty,      -- 退票率分子（日）
    NULL AS refund_denominator_qty                       -- 退票率分母（日）
  FROM dws.dws_ord_tenant_refund_di s                    -- 来源表「商户×SKU 退款日汇总」
  WHERE s.travel_date = '${bizdate}'                     -- 只取当日分区
  GROUP BY seller_tenant_id, sku_id                      -- 按粒度键汇总
) u                                                      -- 各来源合并后的明细
GROUP BY u.seller_tenant_id, u.sku_id                    -- 按粒度键汇总
) x                                                      -- 汇总结果，外层再补维度名称
LEFT JOIN dim.dim_sup_tenant_zip d1 ON d1.tenant_id = x.seller_tenant_id AND d1.travel_date = '${bizdate}' AND d1.end_date = '9999-12-31'  -- 关联「租户（商户/供应商/分销商）维度」，取维度名称
LEFT JOIN dim.dim_prd_sku_zip d2 ON d2.sku_id = x.sku_id AND d2.travel_date = '${bizdate}' AND d2.end_date = '9999-12-31';  -- 关联「SKU维度」，取维度名称
