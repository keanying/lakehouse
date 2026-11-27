-- ================================================================================================
-- ads.ads_fin_merchant_report_di  商户财务报表总览（日）
-- 依据：《3.0 通用财务报表 · 需求说明》v1.0（2026-11-24）
-- 业务规则：
--   · 五张基础报表的商户级总数 = 多维汇总 / 余额报表按商户相加（明细加总 = 汇总，7.3）
--   · 派生指标（未结转差额、毛利、净利）不落表，查询时由本表字段计算（原则 5）
-- 性能：
--   · 三个来源各按商户预聚合后关联
-- ================================================================================================
WITH o AS (
    SELECT merchant_tenant_id,                                                    -- 本方商户租户ID
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
    FROM ads.ads_fin_order_report_dim_di WHERE travel_date = '${bizdate}'
    GROUP BY merchant_tenant_id                                                   -- 按粒度键汇总
),
y AS (                                                                            -- 期初 = 前一日期末
    SELECT merchant_tenant_id, SUM(IF(report_code = 'ADV_RECEIPT', close_amt, 0)) AS adv_receipt_open_amt,  -- 期初预收（日快照）
           SUM(IF(report_code = 'ADV_PAYMENT', close_amt, 0)) AS adv_payment_open_amt  -- 期初预付（日快照）
    FROM ads.ads_fin_order_report_dim_di WHERE travel_date = DATE_FORMAT(DATE_SUB(TO_DATE('${bizdate}', 'yyyyMMdd'), 1), 'yyyyMMdd')
    GROUP BY merchant_tenant_id                                                   -- 按粒度键汇总
),
b AS (
    SELECT merchant_tenant_id,                                                    -- 本方商户租户ID
           SUM(balance_open_amt) AS balance_open_amt,                             -- 期初余额（日快照）
           SUM(balance_in_amt) AS balance_in_amt,                                 -- 资金流入（日）
           SUM(balance_out_amt) AS balance_out_amt,                               -- 资金流出（日）
           SUM(balance_close_amt) AS balance_close_amt,                           -- 期末余额（日快照）
           SUM(recharge_amt) AS recharge_amt,                                     -- 充值（日）
           SUM(withdraw_amt) AS withdraw_amt,                                     -- 提现（日）
           SUM(expense_income_amt) AS expense_income_amt,                         -- 费用收入（日）
           SUM(expense_out_amt) AS expense_out_amt,                               -- 费用支出（日）
           SUM(unclassified_flow_qty) AS unclassified_flow_qty                    -- 待归类流水笔数（日）
    FROM ads.ads_fin_balance_report_di WHERE travel_date = '${bizdate}'
    GROUP BY merchant_tenant_id                                                   -- 按粒度键汇总
),
k AS (SELECT merchant_tenant_id FROM o UNION SELECT merchant_tenant_id FROM y UNION SELECT merchant_tenant_id FROM b)
INSERT OVERWRITE TABLE ads.ads_fin_merchant_report_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT k.merchant_tenant_id,                                                      -- 本方商户租户ID
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
       DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time        -- ETL 加载时间
FROM k
LEFT JOIN o ON o.merchant_tenant_id = k.merchant_tenant_id
LEFT JOIN y ON y.merchant_tenant_id = k.merchant_tenant_id
LEFT JOIN b ON b.merchant_tenant_id = k.merchant_tenant_id;
