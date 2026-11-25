-- dws.dws_fin_tenant_pay_method_di  商户×支付方式 收付款日汇总
-- 粒度：travel_date × tenant_id × pay_direction_type × pay_method_type × receive_channel_type
-- 来源：dwd_fin_payment_di, dwd_fin_refund_payment_di, dwd_fin_invoice_di
-- 生成方式：Spark SQL / Hive；字段 19 个：直接翻译 4 · 规则翻译 2 · 待确认 13
-- 多来源：每个来源表按粒度键先汇总，UNION ALL 后再合并
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT OVERWRITE TABLE dws.dws_fin_tenant_pay_method_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  u.tenant_id,                                     -- 租户ID
  u.pay_direction_type,                            -- 资金方向
  u.pay_method_type,                               -- 支付方式
  u.receive_channel_type,                          -- 收款渠道
  SUM(u.pay_record_qty) AS pay_record_qty,         -- 支付笔数
  SUM(u.inbound_pay_amt) AS inbound_pay_amt,       -- 收款金额
  SUM(u.outbound_pay_amt) AS outbound_pay_amt,     -- 采购付款金额
  SUM(u.refund_payment_amt) AS refund_payment_amt,  -- 退款资金金额
  SUM(u.zero_fee_order_qty) AS zero_fee_order_qty,  -- 0元单数
  SUM(u.credit_pay_amt) AS credit_pay_amt,         -- 授信支付金额
  SUM(u.invoice_amt) AS invoice_amt,               -- 开票金额
  SUM(u.invoice_order_qty) AS invoice_order_qty,   -- 开票订单数
  SUM(u.pay_order_group_qty) AS pay_order_group_qty,  -- 支付聚合单数
  CURRENT_TIMESTAMP() AS etl_time                  -- ETL 加载时间
FROM (
  -- 来源：dwd_fin_payment_di
  SELECT
    tenant_id AS tenant_id,                        -- 租户ID
    pay_direction_type AS pay_direction_type,      -- 资金方向
    pay_method_type AS pay_method_type,            -- 支付方式
    receive_channel_type AS receive_channel_type,  -- 收款渠道
    COUNT(CASE WHEN pay_status='PAID' THEN payment_no END) AS pay_record_qty,  -- 支付笔数
    NULL AS inbound_pay_amt,                       -- 收款金额｜待确认：sum(amount) where pay_direction='INBOUND' and PAID
    NULL AS outbound_pay_amt,                      -- 采购付款金额｜待确认：sum(amount) where pay_direction='OUTBOUND' and PAID
    NULL AS refund_payment_amt,                    -- 退款资金金额
    COUNT(CASE WHEN 1 = 1 THEN payment_no END) AS zero_fee_order_qty,  -- 0元单数｜待确认：pay_method='ZERO_FEE'
    NULL AS credit_pay_amt,                        -- 授信支付金额｜待确认：sum(amount) where pay_method='CREDIT' and PAID
    NULL AS invoice_amt,                           -- 开票金额
    NULL AS invoice_order_qty,                     -- 开票订单数
    NULL AS pay_order_group_qty                    -- 支付聚合单数
  FROM dwd.dwd_fin_payment_di s                    -- 来源表「支付明细」
  WHERE s.travel_date = '${bizdate}'               -- 只取当日分区
  GROUP BY tenant_id, pay_direction_type, pay_method_type, receive_channel_type  -- 按粒度键汇总
  UNION ALL                                        -- 合并各来源
  -- 来源：dwd_fin_refund_payment_di
  SELECT
    tenant_id AS tenant_id,                        -- 租户ID
    pay_direction_type AS pay_direction_type,      -- 资金方向
    pay_method_type AS pay_method_type,            -- 支付方式
    CAST(NULL AS STRING) AS receive_channel_type,  -- 收款渠道
    NULL AS pay_record_qty,                        -- 支付笔数
    NULL AS inbound_pay_amt,                       -- 收款金额
    NULL AS outbound_pay_amt,                      -- 采购付款金额
    NULL AS refund_payment_amt,                    -- 退款资金金额｜待确认：sum(refund_amount) where status='SUCCESS'
    NULL AS zero_fee_order_qty,                    -- 0元单数
    NULL AS credit_pay_amt,                        -- 授信支付金额
    NULL AS invoice_amt,                           -- 开票金额
    NULL AS invoice_order_qty,                     -- 开票订单数
    NULL AS pay_order_group_qty                    -- 支付聚合单数
  FROM dwd.dwd_fin_refund_payment_di s             -- 来源表「退款资金明细」
  WHERE s.travel_date = '${bizdate}'               -- 只取当日分区
  GROUP BY tenant_id, pay_direction_type, pay_method_type  -- 按粒度键汇总
  UNION ALL                                        -- 合并各来源
  -- 来源：dwd_fin_invoice_di
  SELECT
    tenant_id AS tenant_id,                        -- 租户ID
    CAST(NULL AS STRING) AS pay_direction_type,    -- 资金方向
    CAST(NULL AS STRING) AS pay_method_type,       -- 支付方式
    CAST(NULL AS STRING) AS receive_channel_type,  -- 收款渠道
    NULL AS pay_record_qty,                        -- 支付笔数
    NULL AS inbound_pay_amt,                       -- 收款金额
    NULL AS outbound_pay_amt,                      -- 采购付款金额
    NULL AS refund_payment_amt,                    -- 退款资金金额
    NULL AS zero_fee_order_qty,                    -- 0元单数
    NULL AS credit_pay_amt,                        -- 授信支付金额
    NULL AS invoice_amt,                           -- 开票金额｜待确认：sum(invoice_amount) where INVOICED
    COUNT(DISTINCT CASE WHEN 1 = 1 THEN order_group_no END) AS invoice_order_qty,  -- 开票订单数｜待确认：INVOICED and subject='MERCHANT_TO_VISITOR'
    NULL AS pay_order_group_qty                    -- 支付聚合单数
  FROM dwd.dwd_fin_invoice_di s                    -- 来源表「发票明细」
  WHERE s.travel_date = '${bizdate}'               -- 只取当日分区
  GROUP BY tenant_id                               -- 按粒度键汇总
  UNION ALL                                        -- 合并各来源
  -- 来源：dwd_ord_order_group_di
  SELECT
    tenant_id AS tenant_id,                        -- 租户ID
    CAST(NULL AS STRING) AS pay_direction_type,    -- 资金方向
    CAST(NULL AS STRING) AS pay_method_type,       -- 支付方式
    channel_type AS receive_channel_type,          -- 收款渠道
    NULL AS pay_record_qty,                        -- 支付笔数
    NULL AS inbound_pay_amt,                       -- 收款金额
    NULL AS outbound_pay_amt,                      -- 采购付款金额
    NULL AS refund_payment_amt,                    -- 退款资金金额
    NULL AS zero_fee_order_qty,                    -- 0元单数
    NULL AS credit_pay_amt,                        -- 授信支付金额
    NULL AS invoice_amt,                           -- 开票金额
    NULL AS invoice_order_qty,                     -- 开票订单数
    COUNT(DISTINCT CASE WHEN pay_status='PAID' THEN order_group_no END) AS pay_order_group_qty  -- 支付聚合单数
  FROM dwd.dwd_ord_order_group_di s                -- 来源表「聚合单明细」
  WHERE s.travel_date = '${bizdate}'               -- 只取当日分区
  GROUP BY tenant_id, channel_type                 -- 按粒度键汇总
) u                                                -- 各来源合并后的明细
GROUP BY u.tenant_id, u.pay_direction_type, u.pay_method_type, u.receive_channel_type;  -- 按粒度键汇总
