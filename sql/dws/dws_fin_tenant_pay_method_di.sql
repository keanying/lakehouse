-- dws.dws_fin_tenant_pay_method_di  商户×支付方式 收付款日汇总
-- 粒度：travel_date × tenant_id × pay_direction_type × pay_method_type × receive_channel_type
-- 来源：dwd_fin_payment_di, dwd_fin_refund_payment_di, dwd_fin_invoice_di
-- 生成方式：Spark SQL / Hive；字段 19 个：直接翻译 4 · 规则翻译 15 · 待确认 0
-- 多来源：每个来源先按粒度键预聚合，UNION ALL 后再汇总

WITH
src_payment AS (                                                                  -- 来源「支付明细」按粒度键预聚合
  SELECT
    tenant_id AS tenant_id,                                                       -- 租户ID
    pay_direction_type AS pay_direction_type,                                     -- 资金方向
    pay_method_type AS pay_method_type,                                           -- 支付方式
    receive_channel_type AS receive_channel_type,                                 -- 收款渠道
    COUNT(CASE WHEN pay_status='PAID' THEN payment_no END) AS pay_record_qty,     -- 支付笔数
    SUM(CASE WHEN pay_direction_type='INBOUND' and pay_status = 'PAID' THEN pay_amt END) AS inbound_pay_amt,  -- 收款金额
    SUM(CASE WHEN pay_direction_type='OUTBOUND' and pay_status = 'PAID' THEN pay_amt END) AS outbound_pay_amt,  -- 采购付款金额
    NULL AS refund_payment_amt,
    COUNT(CASE WHEN pay_method_type='ZERO_FEE' THEN payment_no END) AS zero_fee_order_qty,  -- 0元单数
    SUM(CASE WHEN pay_method_type='CREDIT' and pay_status = 'PAID' THEN pay_amt END) AS credit_pay_amt,  -- 授信支付金额
    NULL AS invoice_amt,
    NULL AS invoice_order_qty,
    NULL AS pay_order_group_qty
  FROM dwd.dwd_fin_payment_di s                                                   -- 来源表「支付明细」
  WHERE s.travel_date = '${bizdate}'                                              -- 只取当日分区
  GROUP BY tenant_id, pay_direction_type, pay_method_type, receive_channel_type   -- 按粒度键汇总
),
src_refund_payment AS (                                                           -- 来源「退款资金明细」按粒度键预聚合
  SELECT
    tenant_id AS tenant_id,                                                       -- 租户ID
    pay_direction_type AS pay_direction_type,                                     -- 资金方向
    pay_method_type AS pay_method_type,                                           -- 支付方式
    CAST(NULL AS STRING) AS receive_channel_type,
    NULL AS pay_record_qty,
    NULL AS inbound_pay_amt,
    NULL AS outbound_pay_amt,
    SUM(CASE WHEN refund_detail_status = 'SUCCESS' THEN refund_amt END) AS refund_payment_amt,  -- 退款资金金额｜口径：退款明细成功
    NULL AS zero_fee_order_qty,
    NULL AS credit_pay_amt,
    NULL AS invoice_amt,
    NULL AS invoice_order_qty,
    NULL AS pay_order_group_qty
  FROM dwd.dwd_fin_refund_payment_di s                                            -- 来源表「退款资金明细」
  WHERE s.travel_date = '${bizdate}'                                              -- 只取当日分区
  GROUP BY tenant_id, pay_direction_type, pay_method_type                         -- 按粒度键汇总
),
src_invoice AS (                                                                  -- 来源「发票明细」按粒度键预聚合
  SELECT
    tenant_id AS tenant_id,                                                       -- 租户ID
    CAST(NULL AS STRING) AS pay_direction_type,
    CAST(NULL AS STRING) AS pay_method_type,
    CAST(NULL AS STRING) AS receive_channel_type,
    NULL AS pay_record_qty,
    NULL AS inbound_pay_amt,
    NULL AS outbound_pay_amt,
    NULL AS refund_payment_amt,
    NULL AS zero_fee_order_qty,
    NULL AS credit_pay_amt,
    SUM(CASE WHEN invoice_status = 'INVOICED' THEN invoice_amt END) AS invoice_amt,  -- 开票金额
    COUNT(DISTINCT CASE WHEN invoice_status = 'INVOICED' AND invoice_subject_type = 'MERCHANT_TO_VISITOR' THEN order_group_no END) AS invoice_order_qty,  -- 开票订单数｜口径：已开票、商户给游客开票
    NULL AS pay_order_group_qty
  FROM dwd.dwd_fin_invoice_di s                                                   -- 来源表「发票明细」
  WHERE s.travel_date = '${bizdate}'                                              -- 只取当日分区
  GROUP BY tenant_id                                                              -- 按粒度键汇总
),
src_order_group AS (                                                              -- 来源「聚合单明细」按粒度键预聚合
  SELECT
    tenant_id AS tenant_id,                                                       -- 租户ID
    CAST(NULL AS STRING) AS pay_direction_type,
    CAST(NULL AS STRING) AS pay_method_type,
    channel_type AS receive_channel_type,                                         -- 收款渠道
    NULL AS pay_record_qty,
    NULL AS inbound_pay_amt,
    NULL AS outbound_pay_amt,
    NULL AS refund_payment_amt,
    NULL AS zero_fee_order_qty,
    NULL AS credit_pay_amt,
    NULL AS invoice_amt,
    NULL AS invoice_order_qty,
    COUNT(DISTINCT CASE WHEN pay_status='PAID' THEN order_group_no END) AS pay_order_group_qty  -- 支付聚合单数
  FROM dwd.dwd_ord_order_group_di s                                               -- 来源表「聚合单明细」
  WHERE s.travel_date = '${bizdate}'                                              -- 只取当日分区
  GROUP BY tenant_id, channel_type                                                -- 按粒度键汇总
),
all_src AS (                                                                      -- 各来源字段已对齐，UNION ALL 合并（比多表 FULL JOIN 少 shuffle）
  SELECT * FROM src_payment
  UNION ALL
  SELECT * FROM src_refund_payment
  UNION ALL
  SELECT * FROM src_invoice
  UNION ALL
  SELECT * FROM src_order_group
)
INSERT OVERWRITE TABLE dws.dws_fin_tenant_pay_method_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  u.tenant_id,                                                                    -- 租户ID
  u.pay_direction_type,                                                           -- 资金方向
  u.pay_method_type,                                                              -- 支付方式
  u.receive_channel_type,                                                         -- 收款渠道
  SUM(u.pay_record_qty) AS pay_record_qty,                                        -- 支付笔数
  SUM(u.inbound_pay_amt) AS inbound_pay_amt,                                      -- 收款金额
  SUM(u.outbound_pay_amt) AS outbound_pay_amt,                                    -- 采购付款金额
  SUM(u.refund_payment_amt) AS refund_payment_amt,                                -- 退款资金金额
  SUM(u.zero_fee_order_qty) AS zero_fee_order_qty,                                -- 0元单数
  SUM(u.credit_pay_amt) AS credit_pay_amt,                                        -- 授信支付金额
  SUM(u.invoice_amt) AS invoice_amt,                                              -- 开票金额
  SUM(u.invoice_order_qty) AS invoice_order_qty,                                  -- 开票订单数
  SUM(u.pay_order_group_qty) AS pay_order_group_qty,                              -- 支付聚合单数
  CURRENT_TIMESTAMP() AS etl_time                                                 -- ETL 加载时间
FROM all_src u
GROUP BY u.tenant_id, u.pay_direction_type, u.pay_method_type, u.receive_channel_type;  -- 按粒度键汇总
