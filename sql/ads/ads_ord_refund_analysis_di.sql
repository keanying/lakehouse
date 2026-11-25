-- ads.ads_ord_refund_analysis_di  退款分析
-- 粒度：travel_date × seller_tenant_id × refund_reason_desc
-- 来源：dws_ord_tenant_refund_di, dws_sup_tenant_trade_di
-- 生成方式：Spark SQL / Hive；字段 27 个：直接翻译 18 · 规则翻译 6 · 待确认 3
-- 多来源：每个来源表按粒度键先汇总，UNION ALL 后再合并
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT OVERWRITE TABLE ads.ads_ord_refund_analysis_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  x.seller_tenant_id,                                           -- 卖家租户ID
  x.refund_reason_desc,                                         -- 退款原因
  d1.tenant_name AS seller_tenant_name,                         -- 卖家租户名称
  x.refund_apply_qty,                                           -- 退款申请单数（日）
  x.refund_success_qty,                                         -- 退款完成单数（日）
  x.refund_ticket_qty,                                          -- 退款票数（日）
  x.refund_amt,                                                 -- 退款金额（日）
  x.refund_reject_qty,                                          -- 退款驳回单数（日）
  x.auto_approve_refund_qty,                                    -- 超时自动通过退款单数（日）
  x.verified_refund_ticket_qty,                                 -- 核销后退款票数（日）
  x.refund_numerator_qty,                                       -- 退票率分子（日）
  x.refund_denominator_qty,                                     -- 退票率分母（日）
  x.refund_amt_numerator_amt,                                   -- 退款金额率分子（日）
  x.refund_amt_denominator_amt,                                 -- 退款金额率分母（日）
  x.cancel_numerator_qty,                                       -- 取消率分子（日）
  x.cancel_denominator_qty,                                     -- 取消率分母（日）
  x.timeout_cancel_numerator_qty,                               -- 超时取消率分子（日）
  x.timeout_cancel_denominator_qty,                             -- 超时取消率分母（日）
  x.visitor_refund_ticket_qty,                                  -- 游客发起退款票数（日）
  x.merchant_refund_ticket_qty,                                 -- 商户发起退款票数（日）
  x.ota_refund_ticket_qty,                                      -- OTA发起退款票数（日）
  x.system_refund_ticket_qty,                                   -- 系统发起退款票数（日）
  x.visitor_refund_amt,                                         -- 游客发起退款金额（日）
  x.merchant_refund_amt,                                        -- 商户发起退款金额（日）
  x.ota_refund_amt,                                             -- OTA发起退款金额（日）
  x.system_refund_amt,                                          -- 系统发起退款金额（日）
  x.etl_time                                                    -- ETL 加载时间
FROM (
SELECT
  u.seller_tenant_id,                                           -- 卖家租户ID
  u.refund_reason_desc,                                         -- 退款原因
  SUM(u.refund_apply_qty) AS refund_apply_qty,                  -- 退款申请单数（日）
  SUM(u.refund_success_qty) AS refund_success_qty,              -- 退款完成单数（日）
  SUM(u.refund_ticket_qty) AS refund_ticket_qty,                -- 退款票数（日）
  SUM(u.refund_amt) AS refund_amt,                              -- 退款金额（日）
  SUM(u.refund_reject_qty) AS refund_reject_qty,                -- 退款驳回单数（日）
  SUM(u.auto_approve_refund_qty) AS auto_approve_refund_qty,    -- 超时自动通过退款单数（日）
  SUM(u.verified_refund_ticket_qty) AS verified_refund_ticket_qty,  -- 核销后退款票数（日）
  SUM(u.refund_numerator_qty) AS refund_numerator_qty,          -- 退票率分子（日）
  SUM(u.refund_denominator_qty) AS refund_denominator_qty,      -- 退票率分母（日）
  SUM(u.refund_amt_numerator_amt) AS refund_amt_numerator_amt,  -- 退款金额率分子（日）
  SUM(u.refund_amt_denominator_amt) AS refund_amt_denominator_amt,  -- 退款金额率分母（日）
  SUM(u.cancel_numerator_qty) AS cancel_numerator_qty,          -- 取消率分子（日）
  SUM(u.cancel_denominator_qty) AS cancel_denominator_qty,      -- 取消率分母（日）
  SUM(u.timeout_cancel_numerator_qty) AS timeout_cancel_numerator_qty,  -- 超时取消率分子（日）
  SUM(u.timeout_cancel_denominator_qty) AS timeout_cancel_denominator_qty,  -- 超时取消率分母（日）
  SUM(u.visitor_refund_ticket_qty) AS visitor_refund_ticket_qty,  -- 游客发起退款票数（日）
  SUM(u.merchant_refund_ticket_qty) AS merchant_refund_ticket_qty,  -- 商户发起退款票数（日）
  SUM(u.ota_refund_ticket_qty) AS ota_refund_ticket_qty,        -- OTA发起退款票数（日）
  SUM(u.system_refund_ticket_qty) AS system_refund_ticket_qty,  -- 系统发起退款票数（日）
  SUM(u.visitor_refund_amt) AS visitor_refund_amt,              -- 游客发起退款金额（日）
  SUM(u.merchant_refund_amt) AS merchant_refund_amt,            -- 商户发起退款金额（日）
  SUM(u.ota_refund_amt) AS ota_refund_amt,                      -- OTA发起退款金额（日）
  SUM(u.system_refund_amt) AS system_refund_amt,                -- 系统发起退款金额（日）
  CURRENT_TIMESTAMP() AS etl_time                               -- ETL 加载时间
FROM (
  -- 来源：dws_ord_tenant_refund_di
  SELECT
    seller_tenant_id AS seller_tenant_id,                       -- 卖家租户ID
    refund_reason_desc AS refund_reason_desc,                   -- 退款原因
    SUM(refund_apply_qty) AS refund_apply_qty,                  -- 退款申请单数（日）
    SUM(refund_success_qty) AS refund_success_qty,              -- 退款完成单数（日）
    SUM(refund_ticket_qty) AS refund_ticket_qty,                -- 退款票数（日）
    SUM(refund_amt) AS refund_amt,                              -- 退款金额（日）
    SUM(refund_reject_qty) AS refund_reject_qty,                -- 退款驳回单数（日）
    SUM(auto_approve_refund_qty) AS auto_approve_refund_qty,    -- 超时自动通过退款单数（日）
    SUM(verified_refund_ticket_qty) AS verified_refund_ticket_qty,  -- 核销后退款票数（日）
    SUM(refund_ticket_qty) AS refund_numerator_qty,             -- 退票率分子（日）
    NULL AS refund_denominator_qty,                             -- 退票率分母（日）
    SUM(refund_amt) AS refund_amt_numerator_amt,                -- 退款金额率分子（日）
    NULL AS refund_amt_denominator_amt,                         -- 退款金额率分母（日）
    NULL AS cancel_numerator_qty,                               -- 取消率分子（日）
    NULL AS cancel_denominator_qty,                             -- 取消率分母（日）
    NULL AS timeout_cancel_numerator_qty,                       -- 超时取消率分子（日）
    NULL AS timeout_cancel_denominator_qty,                     -- 超时取消率分母（日）
    SUM(CASE WHEN initiator_type = 'VISITOR' THEN refund_ticket_qty END) AS visitor_refund_ticket_qty,  -- 游客发起退款票数（日）
    SUM(CASE WHEN initiator_type = 'MERCHANT' THEN refund_ticket_qty END) AS merchant_refund_ticket_qty,  -- 商户发起退款票数（日）
    SUM(CASE WHEN 1 = 1 THEN refund_ticket_qty END) AS ota_refund_ticket_qty,  -- OTA发起退款票数（日）｜待确认：修饰词 退款发起方=OTA发起 在 dws_ord_tenant_refund_di 中找不到对应字段
    SUM(CASE WHEN initiator_type = 'SYSTEM' THEN refund_ticket_qty END) AS system_refund_ticket_qty,  -- 系统发起退款票数（日）
    SUM(CASE WHEN initiator_type = 'VISITOR' THEN refund_amt END) AS visitor_refund_amt,  -- 游客发起退款金额（日）
    SUM(CASE WHEN initiator_type = 'MERCHANT' THEN refund_amt END) AS merchant_refund_amt,  -- 商户发起退款金额（日）
    SUM(CASE WHEN 1 = 1 THEN refund_amt END) AS ota_refund_amt,  -- OTA发起退款金额（日）｜待确认：修饰词 退款发起方=OTA发起 在 dws_ord_tenant_refund_di 中找不到对应字段
    SUM(CASE WHEN initiator_type = 'SYSTEM' THEN refund_amt END) AS system_refund_amt  -- 系统发起退款金额（日）
  FROM dws.dws_ord_tenant_refund_di s                           -- 来源表「商户×SKU 退款日汇总」
  WHERE s.travel_date = '${bizdate}'                            -- 只取当日分区
  GROUP BY seller_tenant_id, refund_reason_desc                 -- 按粒度键汇总
  UNION ALL                                                     -- 合并各来源
  -- 来源：dws_sup_tenant_trade_di
  SELECT
    seller_tenant_id AS seller_tenant_id,                       -- 卖家租户ID
    CAST(NULL AS STRING) AS refund_reason_desc,                 -- 退款原因
    NULL AS refund_apply_qty,                                   -- 退款申请单数（日）
    NULL AS refund_success_qty,                                 -- 退款完成单数（日）
    NULL AS refund_ticket_qty,                                  -- 退款票数（日）
    NULL AS refund_amt,                                         -- 退款金额（日）
    NULL AS refund_reject_qty,                                  -- 退款驳回单数（日）
    NULL AS auto_approve_refund_qty,                            -- 超时自动通过退款单数（日）
    NULL AS verified_refund_ticket_qty,                         -- 核销后退款票数（日）
    NULL AS refund_numerator_qty,                               -- 退票率分子（日）
    SUM(pay_ticket_qty) AS refund_denominator_qty,              -- 退票率分母（日）
    NULL AS refund_amt_numerator_amt,                           -- 退款金额率分子（日）
    SUM(pay_amt) AS refund_amt_denominator_amt,                 -- 退款金额率分母（日）
    SUM(order_qty) AS cancel_numerator_qty,                     -- 取消率分子（日）
    SUM(order_qty) AS cancel_denominator_qty,                   -- 取消率分母（日）
    SUM(order_qty) AS timeout_cancel_numerator_qty,             -- 超时取消率分子（日）
    SUM(order_qty) AS timeout_cancel_denominator_qty,           -- 超时取消率分母（日）
    NULL AS visitor_refund_ticket_qty,                          -- 游客发起退款票数（日）
    NULL AS merchant_refund_ticket_qty,                         -- 商户发起退款票数（日）
    NULL AS ota_refund_ticket_qty,                              -- OTA发起退款票数（日）
    NULL AS system_refund_ticket_qty,                           -- 系统发起退款票数（日）
    NULL AS visitor_refund_amt,                                 -- 游客发起退款金额（日）
    NULL AS merchant_refund_amt,                                -- 商户发起退款金额（日）
    NULL AS ota_refund_amt,                                     -- OTA发起退款金额（日）
    NULL AS system_refund_amt                                   -- 系统发起退款金额（日）
  FROM dws.dws_sup_tenant_trade_di s                            -- 来源表「商户经营日汇总」
  WHERE s.travel_date = '${bizdate}'                            -- 只取当日分区
  GROUP BY seller_tenant_id                                     -- 按粒度键汇总
) u                                                             -- 各来源合并后的明细
GROUP BY u.seller_tenant_id, u.refund_reason_desc               -- 按粒度键汇总
) x                                                             -- 汇总结果，外层再补维度名称
LEFT JOIN dim.dim_sup_tenant_zip d1 ON d1.tenant_id = x.seller_tenant_id AND d1.travel_date = '${bizdate}' AND d1.end_date = '9999-12-31';  -- 关联「租户（商户/供应商/分销商）维度」，取维度名称
