-- ads.ads_ord_trade_efficiency_di  交易时效分析
-- 粒度：travel_date × seller_tenant_id × sku_id
-- 来源：dws_ord_tenant_sku_channel_trade_di, dws_ord_tenant_refund_di, dws_ord_tenant_sku_verify_di
-- 生成方式：Spark SQL / Hive；字段 13 个：直接翻译 13 · 规则翻译 0 · 待确认 0
-- 多来源：每个来源先按粒度键预聚合，UNION ALL 后再汇总

WITH
src_tenant_sku_channel_trade AS (                                           -- 来源「商户×SKU×渠道 交易日汇总」按粒度键预聚合
  SELECT
    seller_tenant_id AS seller_tenant_id,                                   -- 卖家租户ID
    sku_id AS sku_id,                                                       -- SKU ID
    SUM(pay_minute_qty) AS avg_pay_minute_numerator_qty,                    -- 平均支付时长分子（日）
    SUM(pay_order_qty) AS avg_pay_minute_denominator_qty,                   -- 平均支付时长分母（日）
    NULL AS avg_refund_process_hour_numerator_qty,
    NULL AS avg_refund_process_hour_denominator_qty,
    NULL AS avg_verify_after_pay_day_numerator_qty,
    NULL AS avg_verify_after_pay_day_denominator_qty,
    SUM(advance_book_day_qty) AS avg_advance_book_day_numerator_qty,        -- 平均提前预订天数分子（日）
    SUM(pay_ticket_qty) AS avg_advance_book_day_denominator_qty,            -- 平均提前预订天数分母（日）
    SUM(timeout_cancel_order_qty) AS timeout_cancel_order_qty               -- 超时取消子单数（日）
  FROM dws.dws_ord_tenant_sku_channel_trade_di s                            -- 来源表「商户×SKU×渠道 交易日汇总」
  WHERE s.travel_date = '${bizdate}'                                        -- 只取当日分区
  GROUP BY seller_tenant_id, sku_id                                         -- 按粒度键汇总
),
src_tenant_refund AS (                                                      -- 来源「商户×SKU 退款日汇总」按粒度键预聚合
  SELECT
    seller_tenant_id AS seller_tenant_id,                                   -- 卖家租户ID
    sku_id AS sku_id,                                                       -- SKU ID
    NULL AS avg_pay_minute_numerator_qty,
    NULL AS avg_pay_minute_denominator_qty,
    SUM(refund_process_hour_qty) AS avg_refund_process_hour_numerator_qty,  -- 平均退款处理时长分子（日）
    SUM(refund_success_qty) AS avg_refund_process_hour_denominator_qty,     -- 平均退款处理时长分母（日）
    NULL AS avg_verify_after_pay_day_numerator_qty,
    NULL AS avg_verify_after_pay_day_denominator_qty,
    NULL AS avg_advance_book_day_numerator_qty,
    NULL AS avg_advance_book_day_denominator_qty,
    NULL AS timeout_cancel_order_qty
  FROM dws.dws_ord_tenant_refund_di s                                       -- 来源表「商户×SKU 退款日汇总」
  WHERE s.travel_date = '${bizdate}'                                        -- 只取当日分区
  GROUP BY seller_tenant_id, sku_id                                         -- 按粒度键汇总
),
src_tenant_sku_verify AS (                                                  -- 来源「商户×SKU×核销点 核销日汇总」按粒度键预聚合
  SELECT
    seller_tenant_id AS seller_tenant_id,                                   -- 卖家租户ID
    sku_id AS sku_id,                                                       -- SKU ID
    NULL AS avg_pay_minute_numerator_qty,
    NULL AS avg_pay_minute_denominator_qty,
    NULL AS avg_refund_process_hour_numerator_qty,
    NULL AS avg_refund_process_hour_denominator_qty,
    SUM(verify_after_pay_day_qty) AS avg_verify_after_pay_day_numerator_qty,  -- 平均支付到核销天数分子（日）
    SUM(verify_ticket_qty) AS avg_verify_after_pay_day_denominator_qty,     -- 平均支付到核销天数分母（日）
    NULL AS avg_advance_book_day_numerator_qty,
    NULL AS avg_advance_book_day_denominator_qty,
    NULL AS timeout_cancel_order_qty
  FROM dws.dws_ord_tenant_sku_verify_di s                                   -- 来源表「商户×SKU×核销点 核销日汇总」
  WHERE s.travel_date = '${bizdate}'                                        -- 只取当日分区
  GROUP BY seller_tenant_id, sku_id                                         -- 按粒度键汇总
),
all_src AS (                                                                -- 各来源字段已对齐，UNION ALL 合并（比多表 FULL JOIN 少 shuffle）
  SELECT * FROM src_tenant_sku_channel_trade
  UNION ALL
  SELECT * FROM src_tenant_refund
  UNION ALL
  SELECT * FROM src_tenant_sku_verify
),
merged AS (                                                                 -- 按粒度键汇总，计算派生指标
  SELECT
    u.seller_tenant_id,                                                     -- 卖家租户ID
    u.sku_id,                                                               -- SKU ID
    SUM(u.avg_pay_minute_numerator_qty) AS avg_pay_minute_numerator_qty,    -- 平均支付时长分子（日）
    SUM(u.avg_pay_minute_denominator_qty) AS avg_pay_minute_denominator_qty,  -- 平均支付时长分母（日）
    SUM(u.avg_refund_process_hour_numerator_qty) AS avg_refund_process_hour_numerator_qty,  -- 平均退款处理时长分子（日）
    SUM(u.avg_refund_process_hour_denominator_qty) AS avg_refund_process_hour_denominator_qty,  -- 平均退款处理时长分母（日）
    SUM(u.avg_verify_after_pay_day_numerator_qty) AS avg_verify_after_pay_day_numerator_qty,  -- 平均支付到核销天数分子（日）
    SUM(u.avg_verify_after_pay_day_denominator_qty) AS avg_verify_after_pay_day_denominator_qty,  -- 平均支付到核销天数分母（日）
    SUM(u.avg_advance_book_day_numerator_qty) AS avg_advance_book_day_numerator_qty,  -- 平均提前预订天数分子（日）
    SUM(u.avg_advance_book_day_denominator_qty) AS avg_advance_book_day_denominator_qty,  -- 平均提前预订天数分母（日）
    SUM(u.timeout_cancel_order_qty) AS timeout_cancel_order_qty,            -- 超时取消子单数（日）
    CURRENT_TIMESTAMP() AS etl_time                                         -- ETL 加载时间
  FROM all_src u
  GROUP BY u.seller_tenant_id, u.sku_id                                     -- 按粒度键汇总
),
tenant_cur AS (                                                             -- 「租户（商户/供应商/分销商）维度」当前有效版本，只取名称类字段
  SELECT tenant_id, tenant_name
  FROM dim.dim_sup_tenant_zip
  WHERE travel_date = '${bizdate}' AND end_date = '9999-12-31'              -- 取当日分区里的拉链当前有效版本
),
sku_cur AS (                                                                -- 「SKU维度」当前有效版本，只取名称类字段
  SELECT sku_id, sku_name
  FROM dim.dim_prd_sku_zip
  WHERE travel_date = '${bizdate}' AND end_date = '9999-12-31'              -- 取当日分区里的拉链当前有效版本
)
INSERT OVERWRITE TABLE ads.ads_ord_trade_efficiency_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  merged.seller_tenant_id,                                                  -- 卖家租户ID
  merged.sku_id,                                                            -- SKU ID
  tenant_cur.tenant_name AS seller_tenant_name,                             -- 卖家租户名称
  sku_cur.sku_name AS sku_name,                                             -- SKU 名称
  merged.avg_pay_minute_numerator_qty,                                      -- 平均支付时长分子（日）
  merged.avg_pay_minute_denominator_qty,                                    -- 平均支付时长分母（日）
  merged.avg_refund_process_hour_numerator_qty,                             -- 平均退款处理时长分子（日）
  merged.avg_refund_process_hour_denominator_qty,                           -- 平均退款处理时长分母（日）
  merged.avg_verify_after_pay_day_numerator_qty,                            -- 平均支付到核销天数分子（日）
  merged.avg_verify_after_pay_day_denominator_qty,                          -- 平均支付到核销天数分母（日）
  merged.avg_advance_book_day_numerator_qty,                                -- 平均提前预订天数分子（日）
  merged.avg_advance_book_day_denominator_qty,                              -- 平均提前预订天数分母（日）
  merged.timeout_cancel_order_qty,                                          -- 超时取消子单数（日）
  merged.etl_time                                                           -- ETL 加载时间
FROM merged
LEFT JOIN tenant_cur                                                        -- 关联「租户（商户/供应商/分销商）维度」，补 seller_tenant_name
  ON tenant_cur.tenant_id = merged.seller_tenant_id                         -- 按 seller_tenant_id→tenant_id 关联
LEFT JOIN sku_cur                                                           -- 关联「SKU维度」，补 sku_name
  ON sku_cur.sku_id = merged.sku_id;                                        -- 按 sku_id 关联
