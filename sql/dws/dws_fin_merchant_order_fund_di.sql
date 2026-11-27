-- ================================================================================================
-- dws.dws_fin_merchant_order_fund_di  商户订单资金日汇总
-- 依据：《3.0 通用财务报表 · 需求说明》v1.0（2026-11-24）
-- 业务规则：
--   · 期间值（需求 5.7）：本期收 / 退 / 转、付 / 退回 / 转、确认收入 / 成本，按报表常用维度汇总
-- 性能：
--   · 一次扫描当日明细，条件聚合出全部列
-- ================================================================================================

INSERT OVERWRITE TABLE dws.dws_fin_merchant_order_fund_di PARTITION (travel_date = '${bizdate}')
SELECT
    merchant_tenant_id, COALESCE(spu_id, 0) AS spu_id, COALESCE(sku_id, 0) AS sku_id, COALESCE(channel_id, 0) AS channel_id, COALESCE(seller_staff_id, 0) AS seller_staff_id, COALESCE(payer_tenant_id, 0) AS payer_tenant_id, COALESCE(payee_tenant_id, 0) AS payee_tenant_id, COALESCE(receive_pay_method_type, '') AS receive_pay_method_type, COALESCE(pay_pay_method_type, '') AS pay_pay_method_type,
    SUM(IF(report_code = 'ADV_RECEIPT' AND measure_code = 'RECEIVE', event_amt, 0)) AS receive_amt,
    SUM(IF(report_code = 'ADV_RECEIPT' AND measure_code = 'REFUND', event_amt, 0)) AS refund_amt,
    SUM(IF(report_code = 'ADV_RECEIPT' AND measure_code = 'TO_REVENUE', event_amt, 0)) AS to_revenue_amt,
    SUM(IF(report_code = 'ADV_PAYMENT' AND measure_code = 'PAY', event_amt, 0)) AS pay_amt,
    SUM(IF(report_code = 'ADV_PAYMENT' AND measure_code = 'RETURN', event_amt, 0)) AS return_amt,
    SUM(IF(report_code = 'ADV_PAYMENT' AND measure_code = 'TO_COST', event_amt, 0)) AS to_cost_amt,
    SUM(IF(report_code = 'REVENUE' AND measure_code = 'CONFIRM', event_amt, 0)) AS revenue_amt,
    SUM(IF(report_code = 'COST' AND measure_code = 'CONFIRM', event_amt, 0)) AS cost_amt,
    SUM(IF(report_code = 'AR' AND measure_code = 'ADD', event_amt, 0)) AS ar_add_amt,
    SUM(IF(report_code = 'AP' AND measure_code = 'ADD', event_amt, 0)) AS ap_add_amt,
    SUM(IF(report_code = 'CREDIT_IN' AND measure_code = 'RECEIVE', event_amt, 0)) AS credit_sale_amt,
    SUM(IF(report_code = 'CREDIT_OUT' AND measure_code = 'PAY', event_amt, 0)) AS credit_purchase_amt,
    SUM(IF(measure_code = 'RECEIVE', ticket_net_qty, 0))            AS sale_ticket_qty,
    -SUM(IF(measure_code = 'REFUND', ticket_net_qty, 0))            AS refund_ticket_qty,
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time
FROM dwd.dwd_fin_merchant_order_fund_di
WHERE travel_date = '${bizdate}'
GROUP BY merchant_tenant_id, COALESCE(spu_id, 0), COALESCE(sku_id, 0), COALESCE(channel_id, 0), COALESCE(seller_staff_id, 0), COALESCE(payer_tenant_id, 0), COALESCE(payee_tenant_id, 0), COALESCE(receive_pay_method_type, ''), COALESCE(pay_pay_method_type, '');
