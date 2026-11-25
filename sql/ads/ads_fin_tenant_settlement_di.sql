-- ads.ads_fin_tenant_settlement_di  商户结算对账
-- 粒度：travel_date × tenant_id
-- 来源：dws_fin_account_frozen_di, dws_fin_account_flow_di, dws_fin_tenant_pay_method_di
-- 生成方式：Spark SQL / Hive；字段 22 个：直接翻译 17 · 规则翻译 3 · 待确认 2
-- 多来源：每个来源表按粒度键先汇总，UNION ALL 后再合并
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT OVERWRITE TABLE ads.ads_fin_tenant_settlement_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  x.tenant_id,                                        -- 租户ID
  d1.tenant_name AS tenant_name,                      -- 租户名称
  x.inbound_pay_amt,                                  -- 收款金额（日）
  x.outbound_pay_amt,                                 -- 采购付款金额（日）
  x.refund_payment_amt,                               -- 退款资金金额（日）
  x.freeze_amt,                                       -- 冻结金额（日）
  x.unfreeze_verify_amt,                              -- 核销解冻金额（日）
  x.unfreeze_refund_amt,                              -- 退款释放金额（日）
  x.fee_amt,                                          -- 手续费金额（日）
  x.profit_freeze_amt,                                -- 利润冻结冻结金额（日）
  x.settlement_freeze_amt,                            -- 采购款冻结冻结金额（日）
  x.full_freeze_amt,                                  -- 全款冻结冻结金额（日）
  x.external_freeze_amt,                              -- 外部渠道冻结金额（日）
  x.external_freeze_numerator_amt,                    -- 外部冻结占比分子（日）
  x.external_freeze_denominator_amt,                  -- 外部冻结占比分母（日）
  x.expire_release_amt,                               -- 过期兜底释放金额（日）
  x.invoice_amt,                                      -- 开票金额（日）
  x.invoice_order_qty,                                -- 开票订单数（日）
  x.invoice_numerator_qty,                            -- 开票率分子（日）
  x.invoice_denominator_qty,                          -- 开票率分母（日）
  x.etl_time                                          -- ETL 加载时间
FROM (
SELECT
  u.tenant_id,                                        -- 租户ID
  SUM(u.inbound_pay_amt) AS inbound_pay_amt,          -- 收款金额（日）
  SUM(u.outbound_pay_amt) AS outbound_pay_amt,        -- 采购付款金额（日）
  SUM(u.refund_payment_amt) AS refund_payment_amt,    -- 退款资金金额（日）
  SUM(u.freeze_amt) AS freeze_amt,                    -- 冻结金额（日）
  SUM(u.unfreeze_verify_amt) AS unfreeze_verify_amt,  -- 核销解冻金额（日）
  SUM(u.unfreeze_refund_amt) AS unfreeze_refund_amt,  -- 退款释放金额（日）
  SUM(u.fee_amt) AS fee_amt,                          -- 手续费金额（日）
  SUM(u.profit_freeze_amt) AS profit_freeze_amt,      -- 利润冻结冻结金额（日）
  SUM(u.settlement_freeze_amt) AS settlement_freeze_amt,  -- 采购款冻结冻结金额（日）
  SUM(u.full_freeze_amt) AS full_freeze_amt,          -- 全款冻结冻结金额（日）
  SUM(u.external_freeze_amt) AS external_freeze_amt,  -- 外部渠道冻结金额（日）
  SUM(u.external_freeze_numerator_amt) AS external_freeze_numerator_amt,  -- 外部冻结占比分子（日）
  SUM(u.external_freeze_denominator_amt) AS external_freeze_denominator_amt,  -- 外部冻结占比分母（日）
  SUM(u.expire_release_amt) AS expire_release_amt,    -- 过期兜底释放金额（日）
  SUM(u.invoice_amt) AS invoice_amt,                  -- 开票金额（日）
  SUM(u.invoice_order_qty) AS invoice_order_qty,      -- 开票订单数（日）
  SUM(u.invoice_numerator_qty) AS invoice_numerator_qty,  -- 开票率分子（日）
  SUM(u.invoice_denominator_qty) AS invoice_denominator_qty,  -- 开票率分母（日）
  CURRENT_TIMESTAMP() AS etl_time                     -- ETL 加载时间
FROM (
  -- 来源：dws_fin_tenant_pay_method_di
  SELECT
    tenant_id AS tenant_id,                           -- 租户ID
    SUM(inbound_pay_amt) AS inbound_pay_amt,          -- 收款金额（日）
    SUM(outbound_pay_amt) AS outbound_pay_amt,        -- 采购付款金额（日）
    SUM(refund_payment_amt) AS refund_payment_amt,    -- 退款资金金额（日）
    NULL AS freeze_amt,                               -- 冻结金额（日）
    NULL AS unfreeze_verify_amt,                      -- 核销解冻金额（日）
    NULL AS unfreeze_refund_amt,                      -- 退款释放金额（日）
    NULL AS fee_amt,                                  -- 手续费金额（日）
    NULL AS profit_freeze_amt,                        -- 利润冻结冻结金额（日）
    NULL AS settlement_freeze_amt,                    -- 采购款冻结冻结金额（日）
    NULL AS full_freeze_amt,                          -- 全款冻结冻结金额（日）
    NULL AS external_freeze_amt,                      -- 外部渠道冻结金额（日）
    NULL AS external_freeze_numerator_amt,            -- 外部冻结占比分子（日）
    NULL AS external_freeze_denominator_amt,          -- 外部冻结占比分母（日）
    NULL AS expire_release_amt,                       -- 过期兜底释放金额（日）
    SUM(invoice_amt) AS invoice_amt,                  -- 开票金额（日）
    SUM(invoice_order_qty) AS invoice_order_qty,      -- 开票订单数（日）
    SUM(invoice_order_qty) AS invoice_numerator_qty,  -- 开票率分子（日）
    SUM(pay_order_group_qty) AS invoice_denominator_qty  -- 开票率分母（日）
  FROM dws.dws_fin_tenant_pay_method_di s             -- 来源表「商户×支付方式 收付款日汇总」
  WHERE s.travel_date = '${bizdate}'                  -- 只取当日分区
  GROUP BY tenant_id                                  -- 按粒度键汇总
  UNION ALL                                           -- 合并各来源
  -- 来源：dws_fin_account_frozen_di
  SELECT
    CAST(NULL AS BIGINT) AS tenant_id,                -- 租户ID
    NULL AS inbound_pay_amt,                          -- 收款金额（日）
    NULL AS outbound_pay_amt,                         -- 采购付款金额（日）
    NULL AS refund_payment_amt,                       -- 退款资金金额（日）
    SUM(freeze_amt) AS freeze_amt,                    -- 冻结金额（日）
    SUM(unfreeze_verify_amt) AS unfreeze_verify_amt,  -- 核销解冻金额（日）
    SUM(unfreeze_refund_amt) AS unfreeze_refund_amt,  -- 退款释放金额（日）
    NULL AS fee_amt,                                  -- 手续费金额（日）
    SUM(CASE WHEN freeze_type = 'PROFIT' THEN freeze_amt END) AS profit_freeze_amt,  -- 利润冻结冻结金额（日）
    SUM(CASE WHEN freeze_type = 'SETTLEMENT' THEN freeze_amt END) AS settlement_freeze_amt,  -- 采购款冻结冻结金额（日）
    SUM(CASE WHEN freeze_type = 'FULL' THEN freeze_amt END) AS full_freeze_amt,  -- 全款冻结冻结金额（日）
    SUM(external_freeze_amt) AS external_freeze_amt,  -- 外部渠道冻结金额（日）
    SUM(external_freeze_amt) AS external_freeze_numerator_amt,  -- 外部冻结占比分子（日）
    SUM(freeze_amt) AS external_freeze_denominator_amt,  -- 外部冻结占比分母（日）
    SUM(expire_release_amt) AS expire_release_amt,    -- 过期兜底释放金额（日）
    NULL AS invoice_amt,                              -- 开票金额（日）
    NULL AS invoice_order_qty,                        -- 开票订单数（日）
    NULL AS invoice_numerator_qty,                    -- 开票率分子（日）
    NULL AS invoice_denominator_qty                   -- 开票率分母（日）
  FROM dws.dws_fin_account_frozen_di s                -- 来源表「账户×冻结类型 冻结日汇总」
  WHERE s.travel_date = '${bizdate}'                  -- 只取当日分区
  UNION ALL                                           -- 合并各来源
  -- 来源：dws_fin_account_flow_di
  SELECT
    CAST(NULL AS BIGINT) AS tenant_id,                -- 租户ID
    NULL AS inbound_pay_amt,                          -- 收款金额（日）
    NULL AS outbound_pay_amt,                         -- 采购付款金额（日）
    NULL AS refund_payment_amt,                       -- 退款资金金额（日）
    NULL AS freeze_amt,                               -- 冻结金额（日）
    NULL AS unfreeze_verify_amt,                      -- 核销解冻金额（日）
    NULL AS unfreeze_refund_amt,                      -- 退款释放金额（日）
    SUM(fee_amt) AS fee_amt,                          -- 手续费金额（日）
    NULL AS profit_freeze_amt,                        -- 利润冻结冻结金额（日）
    NULL AS settlement_freeze_amt,                    -- 采购款冻结冻结金额（日）
    NULL AS full_freeze_amt,                          -- 全款冻结冻结金额（日）
    NULL AS external_freeze_amt,                      -- 外部渠道冻结金额（日）
    NULL AS external_freeze_numerator_amt,            -- 外部冻结占比分子（日）
    NULL AS external_freeze_denominator_amt,          -- 外部冻结占比分母（日）
    NULL AS expire_release_amt,                       -- 过期兜底释放金额（日）
    NULL AS invoice_amt,                              -- 开票金额（日）
    NULL AS invoice_order_qty,                        -- 开票订单数（日）
    NULL AS invoice_numerator_qty,                    -- 开票率分子（日）
    NULL AS invoice_denominator_qty                   -- 开票率分母（日）
  FROM dws.dws_fin_account_flow_di s                  -- 来源表「账户×流水类型 资金日汇总」
  WHERE s.travel_date = '${bizdate}'                  -- 只取当日分区
) u                                                   -- 各来源合并后的明细
GROUP BY u.tenant_id                                  -- 按粒度键汇总
) x                                                   -- 汇总结果，外层再补维度名称
LEFT JOIN dim.dim_sup_tenant_zip d1 ON d1.tenant_id = x.tenant_id AND d1.travel_date = '${bizdate}' AND d1.end_date = '9999-12-31';  -- 关联「租户（商户/供应商/分销商）维度」，取维度名称
