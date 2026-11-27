-- ================================================================================================
-- ads.ads_fin_merchant_report_rt  商户财务报表总览（今日实时）
-- 依据：《3.0 通用财务报表 · 需求说明》v1.0（2026-11-24）
-- 业务规则：
--   · 今日段：订单部分取多维汇总今日实时，期初取昨日离线定版期末；余额取实时余额报表
-- 性能：
--   · StarRocks 异步物化视图，1 分钟刷新
-- ================================================================================================
CREATE MATERIALIZED VIEW IF NOT EXISTS ads.ads_fin_merchant_report_rt             -- 异步物化视图，StarRocks 定时刷新
REFRESH ASYNC EVERY (INTERVAL 1 MINUTE)
AS
WITH o AS (
    SELECT merchant_tenant_id,
           SUM(IF(report_code = 'ADV_RECEIPT', close_amt, 0)) AS adv_receipt_close_amt,  -- 期末预收（日快照）
           SUM(IF(report_code = 'ADV_RECEIPT', in_amt, 0))    AS adv_receipt_receive_amt,  -- 本期收（日）
           SUM(IF(report_code = 'ADV_RECEIPT', out_amt, 0))   AS adv_receipt_refund_amt,  -- 本期退（日）
           SUM(IF(report_code = 'ADV_RECEIPT', trans_amt, 0)) AS adv_receipt_to_revenue_amt,  -- 转实收（日）
           SUM(IF(report_code = 'ADV_PAYMENT', close_amt, 0)) AS adv_payment_close_amt,  -- 期末预付（日快照）
           SUM(IF(report_code = 'ADV_PAYMENT', in_amt, 0))    AS adv_payment_pay_amt,  -- 本期付（日）
           SUM(IF(report_code = 'ADV_PAYMENT', out_amt, 0))   AS adv_payment_return_amt,  -- 本期退回（日）
           SUM(IF(report_code = 'ADV_PAYMENT', trans_amt, 0)) AS adv_payment_to_cost_amt,  -- 转实付（日）
           SUM(IF(report_code = 'REVENUE', confirm_amt, 0))   AS revenue_amt,     -- 履约收入（日）
           SUM(IF(report_code = 'COST', confirm_amt, 0))      AS cost_amt,        -- 成本结算（日）
           SUM(IF(report_code = 'ADV_RECEIPT', net_ticket_qty, 0)) AS net_ticket_qty  -- 净票数（日）
    FROM ads.ads_fin_order_report_dim_rt WHERE travel_date = DATE_FORMAT(CURDATE(), '%Y%m%d')
    GROUP BY merchant_tenant_id                                                   -- 按粒度键汇总
),
y AS (                                                                            -- 期初 = 前一日期末
    SELECT merchant_tenant_id, SUM(IF(report_code = 'ADV_RECEIPT', close_amt, 0)) AS adv_receipt_open_amt,
           SUM(IF(report_code = 'ADV_PAYMENT', close_amt, 0)) AS adv_payment_open_amt  -- 期初预付（日快照）
    FROM ads.ads_fin_order_report_dim_di WHERE travel_date = DATE_FORMAT(DATE_SUB(CURDATE(), INTERVAL 1 DAY), '%Y%m%d')
    GROUP BY merchant_tenant_id                                                   -- 按粒度键汇总
),
b AS (
    SELECT merchant_tenant_id, SUM(balance_open_amt) AS balance_open_amt, SUM(balance_in_amt) AS balance_in_amt, SUM(balance_out_amt) AS balance_out_amt,
           SUM(balance_close_amt) AS balance_close_amt, SUM(recharge_amt) AS recharge_amt, SUM(withdraw_amt) AS withdraw_amt,  -- 提现（日）
           SUM(expense_income_amt) AS expense_income_amt, SUM(expense_out_amt) AS expense_out_amt, SUM(unclassified_flow_qty) AS unclassified_flow_qty  -- 待归类流水笔数（日）
    FROM ads.ads_fin_balance_report_rt WHERE travel_date = DATE_FORMAT(CURDATE(), '%Y%m%d')
    GROUP BY merchant_tenant_id                                                   -- 按粒度键汇总
),
k AS (SELECT merchant_tenant_id FROM o UNION SELECT merchant_tenant_id FROM y UNION SELECT merchant_tenant_id FROM b)
SELECT DATE_FORMAT(CURDATE(), '%Y%m%d') AS travel_date,
       k.merchant_tenant_id,                                                      -- 本方商户租户ID
       COALESCE(y.adv_receipt_open_amt, 0) AS adv_receipt_open_amt,               -- 期初预收（日快照）
       COALESCE(o.adv_receipt_receive_amt, 0) AS adv_receipt_receive_amt,         -- 本期收（日）
       COALESCE(o.adv_receipt_refund_amt, 0) AS adv_receipt_refund_amt,           -- 本期退（日）
       COALESCE(o.adv_receipt_to_revenue_amt, 0) AS adv_receipt_to_revenue_amt,   -- 转实收（日）
       COALESCE(o.adv_receipt_close_amt, 0) AS adv_receipt_close_amt,             -- 期末预收（日快照）
       COALESCE(y.adv_payment_open_amt, 0) AS adv_payment_open_amt,               -- 期初预付（日快照）
       COALESCE(o.adv_payment_pay_amt, 0) AS adv_payment_pay_amt,                 -- 本期付（日）
       COALESCE(o.adv_payment_return_amt, 0) AS adv_payment_return_amt,           -- 本期退回（日）
       COALESCE(o.adv_payment_to_cost_amt, 0) AS adv_payment_to_cost_amt,         -- 转实付（日）
       COALESCE(o.adv_payment_close_amt, 0) AS adv_payment_close_amt,             -- 期末预付（日快照）
       COALESCE(o.revenue_amt, 0) AS revenue_amt,                                 -- 履约收入（日）
       COALESCE(o.cost_amt, 0) AS cost_amt,                                       -- 成本结算（日）
       COALESCE(o.net_ticket_qty, 0) AS net_ticket_qty,                           -- 净票数（日）
       COALESCE(b.balance_open_amt, 0) AS balance_open_amt,                       -- 期初余额（日快照）
       COALESCE(b.balance_in_amt, 0) AS balance_in_amt,                           -- 资金流入（日）
       COALESCE(b.balance_out_amt, 0) AS balance_out_amt,                         -- 资金流出（日）
       COALESCE(b.balance_close_amt, 0) AS balance_close_amt,                     -- 期末余额（日快照）
       COALESCE(b.recharge_amt, 0) AS recharge_amt,                               -- 充值（日）
       COALESCE(b.withdraw_amt, 0) AS withdraw_amt,                               -- 提现（日）
       COALESCE(b.expense_income_amt, 0) AS expense_income_amt,                   -- 费用收入（日）
       COALESCE(b.expense_out_amt, 0) AS expense_out_amt,                         -- 费用支出（日）
       COALESCE(b.unclassified_flow_qty, 0) AS unclassified_flow_qty,             -- 待归类流水笔数（日）
       NOW() AS update_time                                                       -- 最近一次刷新时间
FROM k
LEFT JOIN o ON o.merchant_tenant_id = k.merchant_tenant_id
LEFT JOIN y ON y.merchant_tenant_id = k.merchant_tenant_id
LEFT JOIN b ON b.merchant_tenant_id = k.merchant_tenant_id;
