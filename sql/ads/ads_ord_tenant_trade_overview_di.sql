-- ads.ads_ord_tenant_trade_overview_di  商户经营概览
-- 粒度：travel_date × seller_tenant_id
-- 来源：dws_sup_tenant_trade_di
-- 生成方式：Spark SQL / Hive；字段 24 个：直接翻译 24 · 规则翻译 0 · 待确认 0

INSERT OVERWRITE TABLE ads.ads_ord_tenant_trade_overview_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  x.seller_tenant_id,                                         -- 卖家租户ID
  d1.tenant_name AS seller_tenant_name,                       -- 卖家租户名称
  x.pay_amt,                                                  -- 支付金额（GMV）（日）
  x.net_pay_amt,                                              -- 净成交金额（日）
  x.pay_order_qty,                                            -- 支付子单数（日）
  x.pay_ticket_qty,                                           -- 支付票数（日）
  x.pay_buyer_bitmap,                                         -- 支付买家数去重位图（日）
  x.verify_ticket_qty,                                        -- 核销票数（日）
  x.verify_amt,                                               -- 核销金额（日）
  x.refund_amt,                                               -- 退款金额（日）
  x.cost_amt,                                                 -- 成本金额（日）
  x.gross_profit_amt,                                         -- 毛利额（日）
  x.per_customer_numerator_amt,                               -- 客单价分子（日）
  x.per_customer_denominator_bitmap,                          -- 客单价分母（日）
  x.avg_ticket_price_numerator_amt,                           -- 平均票价分子（日）
  x.avg_ticket_price_denominator_qty,                         -- 平均票价分母（日）
  x.verify_numerator_qty,                                     -- 核销率分子（日）
  x.verify_denominator_qty,                                   -- 核销率分母（日）
  x.refund_numerator_qty,                                     -- 退票率分子（日）
  x.refund_denominator_qty,                                   -- 退票率分母（日）
  x.gross_profit_numerator_amt,                               -- 毛利率分子（日）
  x.gross_profit_denominator_amt,                             -- 毛利率分母（日）
  x.pay_conversion_numerator_qty,                             -- 下单支付转化率分子（日）
  x.pay_conversion_denominator_qty,                           -- 下单支付转化率分母（日）
  x.etl_time                                                  -- ETL 加载时间
FROM (
SELECT
  u.seller_tenant_id,                                         -- 卖家租户ID
  SUM(u.pay_amt) AS pay_amt,                                  -- 支付金额（GMV）（日）
  SUM(u.net_pay_amt) AS net_pay_amt,                          -- 净成交金额（日）
  SUM(u.pay_order_qty) AS pay_order_qty,                      -- 支付子单数（日）
  SUM(u.pay_ticket_qty) AS pay_ticket_qty,                    -- 支付票数（日）
  BITMAP_UNION(u.pay_buyer_bitmap) AS pay_buyer_bitmap,       -- 支付买家数去重位图（日）
  SUM(u.verify_ticket_qty) AS verify_ticket_qty,              -- 核销票数（日）
  SUM(u.verify_amt) AS verify_amt,                            -- 核销金额（日）
  SUM(u.refund_amt) AS refund_amt,                            -- 退款金额（日）
  SUM(u.cost_amt) AS cost_amt,                                -- 成本金额（日）
  SUM(u.gross_profit_amt) AS gross_profit_amt,                -- 毛利额（日）
  SUM(u.per_customer_numerator_amt) AS per_customer_numerator_amt,  -- 客单价分子（日）
  BITMAP_UNION(u.per_customer_denominator_bitmap) AS per_customer_denominator_bitmap,  -- 客单价分母（日）
  SUM(u.avg_ticket_price_numerator_amt) AS avg_ticket_price_numerator_amt,  -- 平均票价分子（日）
  SUM(u.avg_ticket_price_denominator_qty) AS avg_ticket_price_denominator_qty,  -- 平均票价分母（日）
  SUM(u.verify_numerator_qty) AS verify_numerator_qty,        -- 核销率分子（日）
  SUM(u.verify_denominator_qty) AS verify_denominator_qty,    -- 核销率分母（日）
  SUM(u.refund_numerator_qty) AS refund_numerator_qty,        -- 退票率分子（日）
  SUM(u.refund_denominator_qty) AS refund_denominator_qty,    -- 退票率分母（日）
  SUM(u.gross_profit_numerator_amt) AS gross_profit_numerator_amt,  -- 毛利率分子（日）
  SUM(u.gross_profit_denominator_amt) AS gross_profit_denominator_amt,  -- 毛利率分母（日）
  SUM(u.pay_conversion_numerator_qty) AS pay_conversion_numerator_qty,  -- 下单支付转化率分子（日）
  SUM(u.pay_conversion_denominator_qty) AS pay_conversion_denominator_qty,  -- 下单支付转化率分母（日）
  CURRENT_TIMESTAMP() AS etl_time                             -- ETL 加载时间
FROM (
  -- 来源：dws_sup_tenant_trade_di
  SELECT
    seller_tenant_id AS seller_tenant_id,                     -- 卖家租户ID
    SUM(pay_amt) AS pay_amt,                                  -- 支付金额（GMV）（日）
    SUM(net_pay_amt) AS net_pay_amt,                          -- 净成交金额（日）
    SUM(pay_order_qty) AS pay_order_qty,                      -- 支付子单数（日）
    SUM(pay_ticket_qty) AS pay_ticket_qty,                    -- 支付票数（日）
    BITMAP_UNION(pay_buyer_bitmap) AS pay_buyer_bitmap,       -- 支付买家数去重位图（日）
    SUM(verify_ticket_qty) AS verify_ticket_qty,              -- 核销票数（日）
    SUM(verify_amt) AS verify_amt,                            -- 核销金额（日）
    SUM(refund_amt) AS refund_amt,                            -- 退款金额（日）
    SUM(cost_amt) AS cost_amt,                                -- 成本金额（日）
    SUM(pay_amt) AS gross_profit_amt,                         -- 毛利额（日）
    SUM(pay_amt) AS per_customer_numerator_amt,               -- 客单价分子（日）
    BITMAP_UNION(pay_buyer_bitmap) AS per_customer_denominator_bitmap,  -- 客单价分母（日）
    SUM(pay_amt) AS avg_ticket_price_numerator_amt,           -- 平均票价分子（日）
    SUM(pay_ticket_qty) AS avg_ticket_price_denominator_qty,  -- 平均票价分母（日）
    SUM(verify_ticket_qty) AS verify_numerator_qty,           -- 核销率分子（日）
    SUM(pay_ticket_qty) AS verify_denominator_qty,            -- 核销率分母（日）
    SUM(refund_ticket_qty) AS refund_numerator_qty,           -- 退票率分子（日）
    SUM(pay_ticket_qty) AS refund_denominator_qty,            -- 退票率分母（日）
    SUM(pay_amt) AS gross_profit_numerator_amt,               -- 毛利率分子（日）
    SUM(pay_amt) AS gross_profit_denominator_amt,             -- 毛利率分母（日）
    SUM(pay_order_qty) AS pay_conversion_numerator_qty,       -- 下单支付转化率分子（日）
    SUM(order_qty) AS pay_conversion_denominator_qty          -- 下单支付转化率分母（日）
  FROM dws.dws_sup_tenant_trade_di s                          -- 来源表「商户经营日汇总」
  WHERE s.travel_date = '${bizdate}'                          -- 只取当日分区
  GROUP BY seller_tenant_id                                   -- 按粒度键汇总
) u                                                           -- 各来源合并后的明细
GROUP BY u.seller_tenant_id                                   -- 按粒度键汇总
) x                                                           -- 汇总结果，外层再补维度名称
LEFT JOIN dim.dim_sup_tenant_zip d1 ON d1.tenant_id = x.seller_tenant_id AND d1.travel_date = '${bizdate}' AND d1.end_date = '9999-12-31';  -- 关联「租户（商户/供应商/分销商）维度」，取维度名称
