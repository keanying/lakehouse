-- ads.ads_ord_trade_efficiency_di  交易时效分析
-- 粒度：travel_date × seller_tenant_id × sku_id
-- 来源：dws_ord_tenant_sku_channel_trade_di, dws_ord_tenant_refund_di, dws_ord_tenant_sku_verify_di
-- 生成方式：Spark SQL / Hive；字段 13 个：直接翻译 13 · 规则翻译 0 · 待确认 0
-- 多来源：每个来源表按粒度键先汇总，UNION ALL 后再合并

INSERT OVERWRITE TABLE ads.ads_ord_trade_efficiency_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  x.seller_tenant_id,                                                       -- 卖家租户ID
  x.sku_id,                                                                 -- SKU ID
  d1.tenant_name AS seller_tenant_name,                                     -- 卖家租户名称
  d2.sku_name AS sku_name,                                                  -- SKU 名称
  x.avg_pay_minute_numerator_qty,                                           -- 平均支付时长分子（日）
  x.avg_pay_minute_denominator_qty,                                         -- 平均支付时长分母（日）
  x.avg_refund_process_hour_numerator_qty,                                  -- 平均退款处理时长分子（日）
  x.avg_refund_process_hour_denominator_qty,                                -- 平均退款处理时长分母（日）
  x.avg_verify_after_pay_day_numerator_qty,                                 -- 平均支付到核销天数分子（日）
  x.avg_verify_after_pay_day_denominator_qty,                               -- 平均支付到核销天数分母（日）
  x.avg_advance_book_day_numerator_qty,                                     -- 平均提前预订天数分子（日）
  x.avg_advance_book_day_denominator_qty,                                   -- 平均提前预订天数分母（日）
  x.timeout_cancel_order_qty,                                               -- 超时取消子单数（日）
  x.etl_time                                                                -- ETL 加载时间
FROM (
SELECT
  u.seller_tenant_id,                                                       -- 卖家租户ID
  u.sku_id,                                                                 -- SKU ID
  SUM(u.avg_pay_minute_numerator_qty) AS avg_pay_minute_numerator_qty,      -- 平均支付时长分子（日）
  SUM(u.avg_pay_minute_denominator_qty) AS avg_pay_minute_denominator_qty,  -- 平均支付时长分母（日）
  SUM(u.avg_refund_process_hour_numerator_qty) AS avg_refund_process_hour_numerator_qty,  -- 平均退款处理时长分子（日）
  SUM(u.avg_refund_process_hour_denominator_qty) AS avg_refund_process_hour_denominator_qty,  -- 平均退款处理时长分母（日）
  SUM(u.avg_verify_after_pay_day_numerator_qty) AS avg_verify_after_pay_day_numerator_qty,  -- 平均支付到核销天数分子（日）
  SUM(u.avg_verify_after_pay_day_denominator_qty) AS avg_verify_after_pay_day_denominator_qty,  -- 平均支付到核销天数分母（日）
  SUM(u.avg_advance_book_day_numerator_qty) AS avg_advance_book_day_numerator_qty,  -- 平均提前预订天数分子（日）
  SUM(u.avg_advance_book_day_denominator_qty) AS avg_advance_book_day_denominator_qty,  -- 平均提前预订天数分母（日）
  SUM(u.timeout_cancel_order_qty) AS timeout_cancel_order_qty,              -- 超时取消子单数（日）
  CURRENT_TIMESTAMP() AS etl_time                                           -- ETL 加载时间
FROM (
  -- 来源：dws_ord_tenant_sku_channel_trade_di
  SELECT
    seller_tenant_id AS seller_tenant_id,                                   -- 卖家租户ID
    sku_id AS sku_id,                                                       -- SKU ID
    SUM(pay_minute_qty) AS avg_pay_minute_numerator_qty,                    -- 平均支付时长分子（日）
    SUM(pay_order_qty) AS avg_pay_minute_denominator_qty,                   -- 平均支付时长分母（日）
    NULL AS avg_refund_process_hour_numerator_qty,                          -- 平均退款处理时长分子（日）
    NULL AS avg_refund_process_hour_denominator_qty,                        -- 平均退款处理时长分母（日）
    NULL AS avg_verify_after_pay_day_numerator_qty,                         -- 平均支付到核销天数分子（日）
    NULL AS avg_verify_after_pay_day_denominator_qty,                       -- 平均支付到核销天数分母（日）
    SUM(advance_book_day_qty) AS avg_advance_book_day_numerator_qty,        -- 平均提前预订天数分子（日）
    SUM(pay_ticket_qty) AS avg_advance_book_day_denominator_qty,            -- 平均提前预订天数分母（日）
    SUM(timeout_cancel_order_qty) AS timeout_cancel_order_qty               -- 超时取消子单数（日）
  FROM dws.dws_ord_tenant_sku_channel_trade_di s                            -- 来源表「商户×SKU×渠道 交易日汇总」
  WHERE s.travel_date = '${bizdate}'                                        -- 只取当日分区
  GROUP BY seller_tenant_id, sku_id                                         -- 按粒度键汇总
  UNION ALL                                                                 -- 合并各来源
  -- 来源：dws_ord_tenant_refund_di
  SELECT
    seller_tenant_id AS seller_tenant_id,                                   -- 卖家租户ID
    sku_id AS sku_id,                                                       -- SKU ID
    NULL AS avg_pay_minute_numerator_qty,                                   -- 平均支付时长分子（日）
    NULL AS avg_pay_minute_denominator_qty,                                 -- 平均支付时长分母（日）
    SUM(refund_process_hour_qty) AS avg_refund_process_hour_numerator_qty,  -- 平均退款处理时长分子（日）
    SUM(refund_success_qty) AS avg_refund_process_hour_denominator_qty,     -- 平均退款处理时长分母（日）
    NULL AS avg_verify_after_pay_day_numerator_qty,                         -- 平均支付到核销天数分子（日）
    NULL AS avg_verify_after_pay_day_denominator_qty,                       -- 平均支付到核销天数分母（日）
    NULL AS avg_advance_book_day_numerator_qty,                             -- 平均提前预订天数分子（日）
    NULL AS avg_advance_book_day_denominator_qty,                           -- 平均提前预订天数分母（日）
    NULL AS timeout_cancel_order_qty                                        -- 超时取消子单数（日）
  FROM dws.dws_ord_tenant_refund_di s                                       -- 来源表「商户×SKU 退款日汇总」
  WHERE s.travel_date = '${bizdate}'                                        -- 只取当日分区
  GROUP BY seller_tenant_id, sku_id                                         -- 按粒度键汇总
  UNION ALL                                                                 -- 合并各来源
  -- 来源：dws_ord_tenant_sku_verify_di
  SELECT
    seller_tenant_id AS seller_tenant_id,                                   -- 卖家租户ID
    sku_id AS sku_id,                                                       -- SKU ID
    NULL AS avg_pay_minute_numerator_qty,                                   -- 平均支付时长分子（日）
    NULL AS avg_pay_minute_denominator_qty,                                 -- 平均支付时长分母（日）
    NULL AS avg_refund_process_hour_numerator_qty,                          -- 平均退款处理时长分子（日）
    NULL AS avg_refund_process_hour_denominator_qty,                        -- 平均退款处理时长分母（日）
    SUM(verify_after_pay_day_qty) AS avg_verify_after_pay_day_numerator_qty,  -- 平均支付到核销天数分子（日）
    SUM(verify_ticket_qty) AS avg_verify_after_pay_day_denominator_qty,     -- 平均支付到核销天数分母（日）
    NULL AS avg_advance_book_day_numerator_qty,                             -- 平均提前预订天数分子（日）
    NULL AS avg_advance_book_day_denominator_qty,                           -- 平均提前预订天数分母（日）
    NULL AS timeout_cancel_order_qty                                        -- 超时取消子单数（日）
  FROM dws.dws_ord_tenant_sku_verify_di s                                   -- 来源表「商户×SKU×核销点 核销日汇总」
  WHERE s.travel_date = '${bizdate}'                                        -- 只取当日分区
  GROUP BY seller_tenant_id, sku_id                                         -- 按粒度键汇总
) u                                                                         -- 各来源合并后的明细
GROUP BY u.seller_tenant_id, u.sku_id                                       -- 按粒度键汇总
) x                                                                         -- 汇总结果，外层再补维度名称
LEFT JOIN dim.dim_sup_tenant_zip d1 ON d1.tenant_id = x.seller_tenant_id AND d1.travel_date = '${bizdate}' AND d1.end_date = '9999-12-31'  -- 关联「租户（商户/供应商/分销商）维度」，取维度名称
LEFT JOIN dim.dim_prd_sku_zip d2 ON d2.sku_id = x.sku_id AND d2.travel_date = '${bizdate}' AND d2.end_date = '9999-12-31';  -- 关联「SKU维度」，取维度名称
