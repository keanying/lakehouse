-- ads.ads_ord_tenant_trade_overview_di  商户经营概览
-- 粒度：travel_date × seller_tenant_id
-- 来源：dws_sup_tenant_trade_di
-- 生成方式：Spark SQL / Hive；字段 24 个：直接翻译 23 · 规则翻译 1 · 待确认 0
-- 来源先按粒度键预聚合

WITH
src_tenant_trade AS (                               -- 来源「商户经营日汇总」按粒度键预聚合
  SELECT
    seller_tenant_id AS seller_tenant_id,           -- 卖家租户ID
    SUM(pay_amt) AS pay_amt,                        -- 支付金额（GMV）（日）
    SUM(net_pay_amt) AS net_pay_amt,                -- 净成交金额（日）
    SUM(pay_order_qty) AS pay_order_qty,            -- 支付子单数（日）
    SUM(pay_ticket_qty) AS pay_ticket_qty,          -- 支付票数（日）
    BITMAP_UNION(pay_buyer_bitmap) AS pay_buyer_bitmap,  -- 支付买家数去重位图（日）
    SUM(verify_ticket_qty) AS verify_ticket_qty,    -- 核销票数（日）
    SUM(verify_amt) AS verify_amt,                  -- 核销金额（日）
    SUM(refund_amt) AS refund_amt,                  -- 退款金额（日）
    SUM(cost_amt) AS cost_amt,                      -- 成本金额（日）
    SUM(pay_amt) - SUM(cost_amt) AS gross_profit_amt,  -- 毛利额（日）
    SUM(pay_amt) AS per_customer_numerator_amt,     -- 客单价分子（日）
    BITMAP_UNION(pay_buyer_bitmap) AS per_customer_denominator_bitmap,  -- 客单价分母（日）
    SUM(pay_amt) AS avg_ticket_price_numerator_amt,  -- 平均票价分子（日）
    SUM(pay_ticket_qty) AS avg_ticket_price_denominator_qty,  -- 平均票价分母（日）
    SUM(verify_ticket_qty) AS verify_numerator_qty,  -- 核销率分子（日）
    SUM(pay_ticket_qty) AS verify_denominator_qty,  -- 核销率分母（日）
    SUM(refund_ticket_qty) AS refund_numerator_qty,  -- 退票率分子（日）
    SUM(pay_ticket_qty) AS refund_denominator_qty,  -- 退票率分母（日）
    SUM(pay_amt) AS gross_profit_numerator_amt,     -- 毛利率分子（日）
    SUM(pay_amt) AS gross_profit_denominator_amt,   -- 毛利率分母（日）
    SUM(pay_order_qty) AS pay_conversion_numerator_qty,  -- 下单支付转化率分子（日）
    SUM(order_qty) AS pay_conversion_denominator_qty  -- 下单支付转化率分母（日）
  FROM dws.dws_sup_tenant_trade_di s                -- 来源表「商户经营日汇总」
  WHERE s.travel_date = '${bizdate}'                -- 只取当日分区
  GROUP BY seller_tenant_id                         -- 按粒度键汇总
),
merged AS (                                         -- 按粒度键汇总，计算派生指标
  SELECT
    u.seller_tenant_id,                             -- 卖家租户ID
    u.pay_amt,                                      -- 支付金额（GMV）（日）
    u.net_pay_amt,                                  -- 净成交金额（日）
    u.pay_order_qty,                                -- 支付子单数（日）
    u.pay_ticket_qty,                               -- 支付票数（日）
    u.pay_buyer_bitmap,                             -- 支付买家数去重位图（日）
    u.verify_ticket_qty,                            -- 核销票数（日）
    u.verify_amt,                                   -- 核销金额（日）
    u.refund_amt,                                   -- 退款金额（日）
    u.cost_amt,                                     -- 成本金额（日）
    u.gross_profit_amt,                             -- 毛利额（日）
    u.per_customer_numerator_amt,                   -- 客单价分子（日）
    u.per_customer_denominator_bitmap,              -- 客单价分母（日）
    u.avg_ticket_price_numerator_amt,               -- 平均票价分子（日）
    u.avg_ticket_price_denominator_qty,             -- 平均票价分母（日）
    u.verify_numerator_qty,                         -- 核销率分子（日）
    u.verify_denominator_qty,                       -- 核销率分母（日）
    u.refund_numerator_qty,                         -- 退票率分子（日）
    u.refund_denominator_qty,                       -- 退票率分母（日）
    u.gross_profit_numerator_amt,                   -- 毛利率分子（日）
    u.gross_profit_denominator_amt,                 -- 毛利率分母（日）
    u.pay_conversion_numerator_qty,                 -- 下单支付转化率分子（日）
    u.pay_conversion_denominator_qty,               -- 下单支付转化率分母（日）
    CURRENT_TIMESTAMP() AS etl_time                 -- ETL 加载时间
  FROM src_tenant_trade u
),
tenant_cur AS (                                     -- 「租户（商户/供应商/分销商）维度」当前有效版本，只取名称类字段
  SELECT tenant_id, tenant_name
  FROM dim.dim_sup_tenant_zip
  WHERE travel_date = '${bizdate}' AND end_date = '9999-12-31'  -- 取当日分区里的拉链当前有效版本
)
INSERT OVERWRITE TABLE ads.ads_ord_tenant_trade_overview_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  merged.seller_tenant_id,                          -- 卖家租户ID
  tenant_cur.tenant_name AS seller_tenant_name,     -- 卖家租户名称
  merged.pay_amt,                                   -- 支付金额（GMV）（日）
  merged.net_pay_amt,                               -- 净成交金额（日）
  merged.pay_order_qty,                             -- 支付子单数（日）
  merged.pay_ticket_qty,                            -- 支付票数（日）
  merged.pay_buyer_bitmap,                          -- 支付买家数去重位图（日）
  merged.verify_ticket_qty,                         -- 核销票数（日）
  merged.verify_amt,                                -- 核销金额（日）
  merged.refund_amt,                                -- 退款金额（日）
  merged.cost_amt,                                  -- 成本金额（日）
  merged.gross_profit_amt,                          -- 毛利额（日）
  merged.per_customer_numerator_amt,                -- 客单价分子（日）
  merged.per_customer_denominator_bitmap,           -- 客单价分母（日）
  merged.avg_ticket_price_numerator_amt,            -- 平均票价分子（日）
  merged.avg_ticket_price_denominator_qty,          -- 平均票价分母（日）
  merged.verify_numerator_qty,                      -- 核销率分子（日）
  merged.verify_denominator_qty,                    -- 核销率分母（日）
  merged.refund_numerator_qty,                      -- 退票率分子（日）
  merged.refund_denominator_qty,                    -- 退票率分母（日）
  merged.gross_profit_numerator_amt,                -- 毛利率分子（日）
  merged.gross_profit_denominator_amt,              -- 毛利率分母（日）
  merged.pay_conversion_numerator_qty,              -- 下单支付转化率分子（日）
  merged.pay_conversion_denominator_qty,            -- 下单支付转化率分母（日）
  merged.etl_time                                   -- ETL 加载时间
FROM merged
LEFT JOIN tenant_cur                                -- 关联「租户（商户/供应商/分销商）维度」，补 seller_tenant_name
  ON tenant_cur.tenant_id = merged.seller_tenant_id;  -- 按 seller_tenant_id→tenant_id 关联
