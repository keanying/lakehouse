-- ads.ads_ord_combo_analysis_di  套票分析（主子单/跨商户/部分退）
-- 粒度：travel_date × combo_sku_id × sub_sku_id
-- 来源：dws_ord_combo_sku_trade_di
-- 生成方式：Spark SQL / Hive；字段 12 个：直接翻译 12 · 规则翻译 0 · 待确认 0

INSERT OVERWRITE TABLE ads.ads_ord_combo_analysis_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  x.combo_sku_id,                                          -- 套票主 SKU ID
  x.sub_sku_id,                                            -- 套票子项 SKU ID
  d1.sku_name AS combo_sku_name,                           -- 套票名称
  d2.sku_name AS sub_sku_name,                             -- 子项 SKU 名称
  x.combo_order_qty,                                       -- 套票主单数（日）
  x.pay_amt,                                               -- 支付金额（GMV）（日）
  x.pay_ticket_qty,                                        -- 支付票数（日）
  x.verify_ticket_qty,                                     -- 核销票数（日）
  x.refund_ticket_qty,                                     -- 退款票数（日）
  x.refund_amt,                                            -- 退款金额（日）
  x.combo_refund_numerator_qty,                            -- 套票部分退率分子（日）
  x.combo_refund_denominator_qty,                          -- 套票部分退率分母（日）
  x.etl_time                                               -- ETL 加载时间
FROM (
SELECT
  u.combo_sku_id,                                          -- 套票主 SKU ID
  u.sub_sku_id,                                            -- 套票子项 SKU ID
  SUM(u.combo_order_qty) AS combo_order_qty,               -- 套票主单数（日）
  SUM(u.pay_amt) AS pay_amt,                               -- 支付金额（GMV）（日）
  SUM(u.pay_ticket_qty) AS pay_ticket_qty,                 -- 支付票数（日）
  SUM(u.verify_ticket_qty) AS verify_ticket_qty,           -- 核销票数（日）
  SUM(u.refund_ticket_qty) AS refund_ticket_qty,           -- 退款票数（日）
  SUM(u.refund_amt) AS refund_amt,                         -- 退款金额（日）
  SUM(u.combo_refund_numerator_qty) AS combo_refund_numerator_qty,  -- 套票部分退率分子（日）
  SUM(u.combo_refund_denominator_qty) AS combo_refund_denominator_qty,  -- 套票部分退率分母（日）
  CURRENT_TIMESTAMP() AS etl_time                          -- ETL 加载时间
FROM (
  -- 来源：dws_ord_combo_sku_trade_di
  SELECT
    combo_sku_id AS combo_sku_id,                          -- 套票主 SKU ID
    sub_sku_id AS sub_sku_id,                              -- 套票子项 SKU ID
    SUM(combo_order_qty) AS combo_order_qty,               -- 套票主单数（日）
    SUM(pay_amt) AS pay_amt,                               -- 支付金额（GMV）（日）
    SUM(pay_ticket_qty) AS pay_ticket_qty,                 -- 支付票数（日）
    SUM(verify_ticket_qty) AS verify_ticket_qty,           -- 核销票数（日）
    SUM(refund_ticket_qty) AS refund_ticket_qty,           -- 退款票数（日）
    SUM(refund_amt) AS refund_amt,                         -- 退款金额（日）
    SUM(refund_ticket_qty) AS combo_refund_numerator_qty,  -- 套票部分退率分子（日）
    SUM(refund_ticket_qty) AS combo_refund_denominator_qty  -- 套票部分退率分母（日）
  FROM dws.dws_ord_combo_sku_trade_di s                    -- 来源表「套票×子项 交易日汇总」
  WHERE s.travel_date = '${bizdate}'                       -- 只取当日分区
  GROUP BY combo_sku_id, sub_sku_id                        -- 按粒度键汇总
) u                                                        -- 各来源合并后的明细
GROUP BY u.combo_sku_id, u.sub_sku_id                      -- 按粒度键汇总
) x                                                        -- 汇总结果，外层再补维度名称
LEFT JOIN dim.dim_prd_sku_zip d1 ON d1.sku_id = x.combo_sku_id AND d1.travel_date = '${bizdate}' AND d1.end_date = '9999-12-31'  -- 关联「SKU维度」，取维度名称
LEFT JOIN dim.dim_prd_sku_zip d2 ON d2.sku_id = x.sub_sku_id AND d2.travel_date = '${bizdate}' AND d2.end_date = '9999-12-31';  -- 关联「SKU维度」，取维度名称
