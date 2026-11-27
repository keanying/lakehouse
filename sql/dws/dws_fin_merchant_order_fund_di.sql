-- ================================================================================================
-- dws.dws_fin_merchant_order_fund_di  商户订单资金日汇总
-- 依据：《3.0 通用财务报表 · 需求说明》v1.0（2026-11-24）
-- 业务规则：
--   · 期间值（5.7）：本期收 / 退 / 转实收、本期付 / 退回 / 转实付、履约收入、成本结算，及各口径票数
--   · 粒度 = 全部订单维度；维度无值保持为空（界面显示「—」，4.5）
-- 性能：
--   · 一次扫描当日明细，条件聚合出全部列
-- ================================================================================================

INSERT OVERWRITE TABLE dws.dws_fin_merchant_order_fund_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
    merchant_tenant_id, spu_id, sku_id, channel_type, seller_staff_id, sale_point_code, payer_tenant_id, payer_type, payee_tenant_id, payee_type, sale_unit_price_amt, buy_unit_price_amt, receive_pay_method_type, pay_pay_method_type,
    SUM(IF(report_code = 'ADV_RECEIPT' AND measure_code = 'RECEIVE', event_amt, 0)) AS receive_amt,  -- 本期收
    SUM(IF(report_code = 'ADV_RECEIPT' AND measure_code = 'REFUND', event_amt, 0)) AS refund_amt,  -- 本期退
    SUM(IF(report_code = 'ADV_RECEIPT' AND measure_code = 'TO_REVENUE', event_amt, 0)) AS to_revenue_amt,  -- 转实收
    SUM(IF(report_code = 'ADV_PAYMENT' AND measure_code = 'PAY', event_amt, 0)) AS pay_amt,  -- 本期付
    SUM(IF(report_code = 'ADV_PAYMENT' AND measure_code = 'RETURN', event_amt, 0)) AS return_amt,  -- 本期退回
    SUM(IF(report_code = 'ADV_PAYMENT' AND measure_code = 'TO_COST', event_amt, 0)) AS to_cost_amt,  -- 转实付
    SUM(IF(report_code = 'REVENUE' AND measure_code = 'CONFIRM', event_amt, 0)) AS revenue_amt,  -- 履约收入
    SUM(IF(report_code = 'COST' AND measure_code = 'CONFIRM', event_amt, 0)) AS cost_amt,  -- 成本结算
    SUM(IF(measure_code='RECEIVE', ticket_net_qty, 0)) AS sale_ticket_qty,        -- 售票数
    SUM(IF(measure_code='REFUND', -ticket_net_qty, 0)) AS refund_ticket_qty,      -- 退款票数
    SUM(IF(measure_code='PAY', ticket_net_qty, 0)) AS buy_ticket_qty,             -- 采购票数
    SUM(IF(measure_code='RETURN', -ticket_net_qty, 0)) AS return_ticket_qty,      -- 退回票数
    SUM(IF(report_code='REVENUE', confirm_ticket_qty, 0)) AS revenue_ticket_qty,  -- 确认收入票数
    SUM(IF(report_code='COST', confirm_ticket_qty, 0)) AS cost_ticket_qty,        -- 确认成本票数
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time           -- ETL 加载时间
FROM dwd.dwd_fin_merchant_order_fund_di
WHERE travel_date = '${bizdate}'                                                  -- 只取当日分区
GROUP BY merchant_tenant_id, spu_id, sku_id, channel_type, seller_staff_id, sale_point_code, payer_tenant_id, payer_type, payee_tenant_id, payee_type, sale_unit_price_amt, buy_unit_price_amt, receive_pay_method_type, pay_pay_method_type;  -- 按粒度键汇总
