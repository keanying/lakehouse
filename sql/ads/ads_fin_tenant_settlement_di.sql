-- ads.ads_fin_tenant_settlement_di  商户结算对账
-- 粒度：travel_date × tenant_id
-- 来源：dws_fin_account_frozen_di, dws_fin_account_flow_di, dws_fin_tenant_pay_method_di
-- 生成方式：Spark SQL / Hive；字段 22 个：直接翻译 17 · 规则翻译 3 · 待确认 2
-- 多来源：每个来源先按粒度键预聚合，UNION ALL 后再汇总
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

WITH
src_tenant_pay_method AS (                               -- 来源「商户×支付方式 收付款日汇总」按粒度键预聚合
  SELECT
    tenant_id AS tenant_id,                              -- 租户ID
    SUM(inbound_pay_amt) AS inbound_pay_amt,             -- 收款金额（日）
    SUM(outbound_pay_amt) AS outbound_pay_amt,           -- 采购付款金额（日）
    SUM(refund_payment_amt) AS refund_payment_amt,       -- 退款资金金额（日）
    NULL AS freeze_amt,
    NULL AS unfreeze_verify_amt,
    NULL AS unfreeze_refund_amt,
    NULL AS fee_amt,
    NULL AS profit_freeze_amt,
    NULL AS settlement_freeze_amt,
    NULL AS full_freeze_amt,
    NULL AS external_freeze_amt,
    NULL AS external_freeze_numerator_amt,
    NULL AS external_freeze_denominator_amt,
    NULL AS expire_release_amt,
    SUM(invoice_amt) AS invoice_amt,                     -- 开票金额（日）
    SUM(invoice_order_qty) AS invoice_order_qty,         -- 开票订单数（日）
    SUM(invoice_order_qty) AS invoice_numerator_qty,     -- 开票率分子（日）
    SUM(pay_order_group_qty) AS invoice_denominator_qty  -- 开票率分母（日）
  FROM dws.dws_fin_tenant_pay_method_di s                -- 来源表「商户×支付方式 收付款日汇总」
  WHERE s.travel_date = '${bizdate}'                     -- 只取当日分区
  GROUP BY tenant_id                                     -- 按粒度键汇总
),
src_account_frozen AS (                                  -- 来源「账户×冻结类型 冻结日汇总」按粒度键预聚合
  SELECT
    CAST(NULL AS BIGINT) AS tenant_id,
    NULL AS inbound_pay_amt,
    NULL AS outbound_pay_amt,
    NULL AS refund_payment_amt,
    SUM(freeze_amt) AS freeze_amt,                       -- 冻结金额（日）
    SUM(unfreeze_verify_amt) AS unfreeze_verify_amt,     -- 核销解冻金额（日）
    SUM(unfreeze_refund_amt) AS unfreeze_refund_amt,     -- 退款释放金额（日）
    NULL AS fee_amt,
    SUM(CASE WHEN freeze_type = 'PROFIT' THEN freeze_amt END) AS profit_freeze_amt,  -- 利润冻结冻结金额（日）
    SUM(CASE WHEN freeze_type = 'SETTLEMENT' THEN freeze_amt END) AS settlement_freeze_amt,  -- 采购款冻结冻结金额（日）
    SUM(CASE WHEN freeze_type = 'FULL' THEN freeze_amt END) AS full_freeze_amt,  -- 全款冻结冻结金额（日）
    SUM(external_freeze_amt) AS external_freeze_amt,     -- 外部渠道冻结金额（日）
    SUM(external_freeze_amt) AS external_freeze_numerator_amt,  -- 外部冻结占比分子（日）
    SUM(freeze_amt) AS external_freeze_denominator_amt,  -- 外部冻结占比分母（日）
    SUM(expire_release_amt) AS expire_release_amt,       -- 过期兜底释放金额（日）
    NULL AS invoice_amt,
    NULL AS invoice_order_qty,
    NULL AS invoice_numerator_qty,
    NULL AS invoice_denominator_qty
  FROM dws.dws_fin_account_frozen_di s                   -- 来源表「账户×冻结类型 冻结日汇总」
  WHERE s.travel_date = '${bizdate}'                     -- 只取当日分区
),
src_account_flow AS (                                    -- 来源「账户×流水类型 资金日汇总」按粒度键预聚合
  SELECT
    CAST(NULL AS BIGINT) AS tenant_id,
    NULL AS inbound_pay_amt,
    NULL AS outbound_pay_amt,
    NULL AS refund_payment_amt,
    NULL AS freeze_amt,
    NULL AS unfreeze_verify_amt,
    NULL AS unfreeze_refund_amt,
    SUM(fee_amt) AS fee_amt,                             -- 手续费金额（日）
    NULL AS profit_freeze_amt,
    NULL AS settlement_freeze_amt,
    NULL AS full_freeze_amt,
    NULL AS external_freeze_amt,
    NULL AS external_freeze_numerator_amt,
    NULL AS external_freeze_denominator_amt,
    NULL AS expire_release_amt,
    NULL AS invoice_amt,
    NULL AS invoice_order_qty,
    NULL AS invoice_numerator_qty,
    NULL AS invoice_denominator_qty
  FROM dws.dws_fin_account_flow_di s                     -- 来源表「账户×流水类型 资金日汇总」
  WHERE s.travel_date = '${bizdate}'                     -- 只取当日分区
),
all_src AS (                                             -- 各来源字段已对齐，UNION ALL 合并（比多表 FULL JOIN 少 shuffle）
  SELECT * FROM src_tenant_pay_method
  UNION ALL
  SELECT * FROM src_account_frozen
  UNION ALL
  SELECT * FROM src_account_flow
),
merged AS (                                              -- 按粒度键汇总，计算派生指标
  SELECT
    u.tenant_id,                                         -- 租户ID
    SUM(u.inbound_pay_amt) AS inbound_pay_amt,           -- 收款金额（日）
    SUM(u.outbound_pay_amt) AS outbound_pay_amt,         -- 采购付款金额（日）
    SUM(u.refund_payment_amt) AS refund_payment_amt,     -- 退款资金金额（日）
    SUM(u.freeze_amt) AS freeze_amt,                     -- 冻结金额（日）
    SUM(u.unfreeze_verify_amt) AS unfreeze_verify_amt,   -- 核销解冻金额（日）
    SUM(u.unfreeze_refund_amt) AS unfreeze_refund_amt,   -- 退款释放金额（日）
    SUM(u.fee_amt) AS fee_amt,                           -- 手续费金额（日）
    SUM(u.profit_freeze_amt) AS profit_freeze_amt,       -- 利润冻结冻结金额（日）
    SUM(u.settlement_freeze_amt) AS settlement_freeze_amt,  -- 采购款冻结冻结金额（日）
    SUM(u.full_freeze_amt) AS full_freeze_amt,           -- 全款冻结冻结金额（日）
    SUM(u.external_freeze_amt) AS external_freeze_amt,   -- 外部渠道冻结金额（日）
    SUM(u.external_freeze_numerator_amt) AS external_freeze_numerator_amt,  -- 外部冻结占比分子（日）
    SUM(u.external_freeze_denominator_amt) AS external_freeze_denominator_amt,  -- 外部冻结占比分母（日）
    SUM(u.expire_release_amt) AS expire_release_amt,     -- 过期兜底释放金额（日）
    SUM(u.invoice_amt) AS invoice_amt,                   -- 开票金额（日）
    SUM(u.invoice_order_qty) AS invoice_order_qty,       -- 开票订单数（日）
    SUM(u.invoice_numerator_qty) AS invoice_numerator_qty,  -- 开票率分子（日）
    SUM(u.invoice_denominator_qty) AS invoice_denominator_qty,  -- 开票率分母（日）
    CURRENT_TIMESTAMP() AS etl_time                      -- ETL 加载时间
  FROM all_src u
  GROUP BY u.tenant_id                                   -- 按粒度键汇总
),
tenant_cur AS (                                          -- 「租户（商户/供应商/分销商）维度」当前有效版本，只取名称类字段
  SELECT tenant_id, tenant_name
  FROM dim.dim_sup_tenant_zip
  WHERE travel_date = '${bizdate}' AND end_date = '9999-12-31'  -- 取当日分区里的拉链当前有效版本
)
INSERT OVERWRITE TABLE ads.ads_fin_tenant_settlement_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  merged.tenant_id,                                      -- 租户ID
  tenant_cur.tenant_name AS tenant_name,                 -- 租户名称
  merged.inbound_pay_amt,                                -- 收款金额（日）
  merged.outbound_pay_amt,                               -- 采购付款金额（日）
  merged.refund_payment_amt,                             -- 退款资金金额（日）
  merged.freeze_amt,                                     -- 冻结金额（日）
  merged.unfreeze_verify_amt,                            -- 核销解冻金额（日）
  merged.unfreeze_refund_amt,                            -- 退款释放金额（日）
  merged.fee_amt,                                        -- 手续费金额（日）
  merged.profit_freeze_amt,                              -- 利润冻结冻结金额（日）
  merged.settlement_freeze_amt,                          -- 采购款冻结冻结金额（日）
  merged.full_freeze_amt,                                -- 全款冻结冻结金额（日）
  merged.external_freeze_amt,                            -- 外部渠道冻结金额（日）
  merged.external_freeze_numerator_amt,                  -- 外部冻结占比分子（日）
  merged.external_freeze_denominator_amt,                -- 外部冻结占比分母（日）
  merged.expire_release_amt,                             -- 过期兜底释放金额（日）
  merged.invoice_amt,                                    -- 开票金额（日）
  merged.invoice_order_qty,                              -- 开票订单数（日）
  merged.invoice_numerator_qty,                          -- 开票率分子（日）
  merged.invoice_denominator_qty,                        -- 开票率分母（日）
  merged.etl_time                                        -- ETL 加载时间
FROM merged
LEFT JOIN tenant_cur                                     -- 关联「租户（商户/供应商/分销商）维度」，补 tenant_name
  ON tenant_cur.tenant_id = merged.tenant_id;            -- 按 tenant_id 关联
