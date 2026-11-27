-- ================================================================================================
-- ads.ads_fin_merchant_report_rt  商户财务报表（当日实时）
-- 依据：《3.0 通用财务报表 · 需求说明》v1.0（2026-11-24）
-- 业务规则：
--   · 今日段：期初 = 昨日离线定版期末（ads_fin_merchant_report_di T-1），发生额取实时明细，期末 = 期初 + 发生；应收 / 应付今日段不含还款（还款无明细，日终由授信快照倒推）
--   · 余额报表始终实时（需求 6.3）：期末余额取账户实时可用余额
-- 性能：
--   · StarRocks 异步物化视图，1 分钟刷新；分段拼接：报表服务对历史日期读 ads_fin_merchant_report_di、今日读本表，字段一致
-- ================================================================================================

CREATE MATERIALIZED VIEW ads.ads_fin_merchant_report_rt                           -- 异步物化视图，StarRocks 定时刷新
REFRESH ASYNC EVERY (INTERVAL 1 MINUTE)
AS
WITH d AS (
    SELECT merchant_tenant_id,
           SUM(IF(report_code = 'ADV_RECEIPT' AND measure_code = 'RECEIVE', event_amt, 0))    AS adv_receipt_receive_amt,  -- 本期收（日）
           SUM(IF(report_code = 'ADV_RECEIPT' AND measure_code = 'REFUND', event_amt, 0))     AS adv_receipt_refund_amt,  -- 本期退（日）
           SUM(IF(report_code = 'ADV_RECEIPT' AND measure_code = 'TO_REVENUE', event_amt, 0)) AS adv_receipt_to_revenue_amt,  -- 本期转确认收入（日）
           SUM(IF(report_code = 'ADV_PAYMENT' AND measure_code = 'PAY', event_amt, 0))        AS adv_payment_pay_amt,  -- 本期付（日）
           SUM(IF(report_code = 'ADV_PAYMENT' AND measure_code = 'RETURN', event_amt, 0))     AS adv_payment_return_amt,  -- 本期退回（日）
           SUM(IF(report_code = 'ADV_PAYMENT' AND measure_code = 'TO_COST', event_amt, 0))    AS adv_payment_to_cost_amt,  -- 本期转确认成本（日）
           SUM(IF(report_code = 'REVENUE', event_amt, 0))                                    AS revenue_amt,  -- 确认收入（日）
           SUM(IF(report_code = 'COST', event_amt, 0))                                       AS cost_amt,  -- 确认成本（日）
           SUM(ticket_net_qty)                                                               AS net_ticket_qty,  -- 净票数（日）
           SUM(IF(report_code = 'ADV_RECEIPT', balance_effect_amt, 0))                        AS adv_receipt_chg,
           SUM(IF(report_code = 'ADV_PAYMENT', balance_effect_amt, 0))                        AS adv_payment_chg,
           SUM(IF(report_code = 'AR', event_amt, 0))                                         AS ar_add_amt,  -- 本期应收增加（日）
           SUM(IF(report_code = 'AP', event_amt, 0))                                         AS ap_add_amt,  -- 本期应付增加（日）
           SUM(IF(report_code = 'CREDIT_IN' AND measure_code = 'RECEIVE', event_amt, 0))     AS credit_sale_amt,  -- 授信销售（日）
           SUM(IF(report_code = 'CREDIT_OUT' AND measure_code = 'PAY', event_amt, 0))        AS credit_purchase_amt  -- 授信采购（日）
    FROM dwd.dwd_fin_merchant_order_fund_rt
    WHERE travel_date = DATE_FORMAT(NOW(), '%Y%m%d')
    GROUP BY merchant_tenant_id                                                   -- 按粒度键汇总
),
b AS (
    SELECT subject_id AS merchant_tenant_id,
           SUM(IF(report_code IN ('BALANCE', 'EXPENSE') AND change_amt > 0, change_amt, 0))  AS balance_in_amt,  -- 资金流入（日）
           -SUM(IF(report_code IN ('BALANCE', 'EXPENSE') AND change_amt < 0, change_amt, 0)) AS balance_out_amt,  -- 资金流出（日）
           SUM(IF(flow_type = 'RECHARGE' AND change_amt > 0, change_amt, 0))                 AS recharge_amt,  -- 充值金额（日）
           -SUM(IF(flow_type = 'WITHDRAW' AND change_amt < 0, change_amt, 0))                AS withdraw_amt,  -- 提现金额（日）
           SUM(IF(report_code = 'EXPENSE' AND change_amt > 0, change_amt, 0))                AS expense_income_amt,  -- 费用收入（日）
           -SUM(IF(report_code = 'EXPENSE' AND change_amt < 0, change_amt, 0))               AS expense_out_amt,  -- 费用支出（日）
           SUM(IF(report_code = 'UNCLASSIFIED', 1, 0))                                       AS unclassified_flow_qty  -- 待归类流水笔数（日）
    FROM dwd.dwd_fin_fund_flow_rt
    WHERE travel_date = DATE_FORMAT(NOW(), '%Y%m%d') AND account_type IN ('MERCHANT', 'DISTRIBUTOR')
    GROUP BY subject_id                                                           -- 按粒度键汇总
),
y AS (SELECT * FROM ads.ads_fin_merchant_report_di WHERE travel_date = DATE_FORMAT(DATE_SUB(NOW(), INTERVAL 1 DAY), '%Y%m%d')),
k AS (SELECT merchant_tenant_id FROM d UNION SELECT merchant_tenant_id FROM b UNION SELECT merchant_tenant_id FROM y)
SELECT
    DATE_FORMAT(NOW(), '%Y%m%d')                                                             AS travel_date,  -- 数据日期
    k.merchant_tenant_id,                                                         -- 本方商户租户ID
    COALESCE(y.adv_receipt_close_amt, 0)                                                     AS adv_receipt_open_amt,  -- 期初预收（日快照）
    COALESCE(d.adv_receipt_receive_amt, 0)                                                   AS adv_receipt_receive_amt,  -- 本期收（日）
    COALESCE(d.adv_receipt_refund_amt, 0)                                                    AS adv_receipt_refund_amt,  -- 本期退（日）
    COALESCE(d.adv_receipt_to_revenue_amt, 0)                                                AS adv_receipt_to_revenue_amt,  -- 本期转确认收入（日）
    COALESCE(y.adv_receipt_close_amt, 0) + COALESCE(d.adv_receipt_chg, 0)                    AS adv_receipt_close_amt,  -- 期末预收（日快照）
    COALESCE(y.adv_payment_close_amt, 0)                                                     AS adv_payment_open_amt,  -- 期初预付（日快照）
    COALESCE(d.adv_payment_pay_amt, 0)                                                       AS adv_payment_pay_amt,  -- 本期付（日）
    COALESCE(d.adv_payment_return_amt, 0)                                                    AS adv_payment_return_amt,  -- 本期退回（日）
    COALESCE(d.adv_payment_to_cost_amt, 0)                                                   AS adv_payment_to_cost_amt,  -- 本期转确认成本（日）
    COALESCE(y.adv_payment_close_amt, 0) + COALESCE(d.adv_payment_chg, 0)                    AS adv_payment_close_amt,  -- 期末预付（日快照）
    COALESCE(y.ar_close_amt, 0)                                                              AS ar_open_amt,  -- 期初应收（日快照）
    COALESCE(d.ar_add_amt, 0)                                                                AS ar_add_amt,  -- 本期应收增加（日）
    0                                                                                        AS ar_settle_amt,  -- 本期收回（日）｜还款无明细，日终由快照倒推
    COALESCE(y.ar_close_amt, 0) + COALESCE(d.ar_add_amt, 0)                                  AS ar_close_amt,  -- 期末应收（日快照）｜不含今日还款
    COALESCE(y.ap_close_amt, 0)                                                              AS ap_open_amt,  -- 期初应付（日快照）
    COALESCE(d.ap_add_amt, 0)                                                                AS ap_add_amt,  -- 本期应付增加（日）
    0                                                                                        AS ap_settle_amt,  -- 本期偿还（日）
    COALESCE(y.ap_close_amt, 0) + COALESCE(d.ap_add_amt, 0)                                  AS ap_close_amt,  -- 期末应付（日快照）
    COALESCE(d.credit_sale_amt, 0)                                                           AS credit_sale_amt,  -- 授信销售（日）
    COALESCE(d.credit_purchase_amt, 0)                                                       AS credit_purchase_amt,  -- 授信采购（日）
    COALESCE(d.revenue_amt, 0)                                                               AS revenue_amt,  -- 确认收入（日）
    COALESCE(d.cost_amt, 0)                                                                  AS cost_amt,  -- 确认成本（日）
    COALESCE(d.net_ticket_qty, 0)                                                            AS net_ticket_qty,  -- 净票数（日）
    COALESCE(y.balance_close_amt, 0)                                                         AS balance_open_amt,  -- 期初余额（日快照）
    COALESCE(b.balance_in_amt, 0)                                                            AS balance_in_amt,  -- 资金流入（日）
    COALESCE(b.balance_out_amt, 0)                                                           AS balance_out_amt,  -- 资金流出（日）
    COALESCE(y.balance_close_amt, 0) + COALESCE(b.balance_in_amt, 0) - COALESCE(b.balance_out_amt, 0) AS balance_close_amt,  -- 期末余额（日快照）
    COALESCE(b.recharge_amt, 0)                                                              AS recharge_amt,  -- 充值金额（日）
    COALESCE(b.withdraw_amt, 0)                                                              AS withdraw_amt,  -- 提现金额（日）
    COALESCE(b.expense_income_amt, 0)                                                        AS expense_income_amt,  -- 费用收入（日）
    COALESCE(b.expense_out_amt, 0)                                                           AS expense_out_amt,  -- 费用支出（日）
    COALESCE(b.unclassified_flow_qty, 0)                                                     AS unclassified_flow_qty,  -- 待归类流水笔数（日）
    NOW()                                                                                    AS update_time  -- 最近一次刷新时间
FROM k
LEFT JOIN d ON d.merchant_tenant_id = k.merchant_tenant_id
LEFT JOIN b ON b.merchant_tenant_id = k.merchant_tenant_id
LEFT JOIN y ON y.merchant_tenant_id = k.merchant_tenant_id;
