-- ================================================================================================
-- ads.ads_fin_merchant_report_di  商户财务报表（日）
-- 依据：《3.0 通用财务报表 · 需求说明》v1.0（2026-11-24）
-- 业务规则：
--   · 基础报表日值：预收 / 预付期初期末取在途快照，应收 / 应付取授信快照，余额取账户快照（时点值）；其余为当日发生额
--   · 余额只统计「仅余额 / 费用」归属的流水，冻结与退款释放不进（需求第八章第 7 条说明）
--   · 派生指标（未结转差额、毛利、净利）不落表，查询时由本表字段计算（需求核心原则 5）
-- 性能：
--   · 各来源先按商户预聚合，UNION ALL 后汇总，不做明细级关联
-- ================================================================================================

WITH x AS (
    -- 在途快照：预收 / 预付 期初（T-1）、期末（T）
    SELECT merchant_tenant_id AS merchant_tenant_id,
           SUM(IF(report_code = 'ADV_RECEIPT' AND travel_date <> '${bizdate}', unsettled_amt, 0)) AS adv_receipt_open_amt,  -- 期初预收（日快照）
           0 AS adv_receipt_receive_amt,                       -- 本期收（日）
           0 AS adv_receipt_refund_amt,                        -- 本期退（日）
           0 AS adv_receipt_to_revenue_amt,                    -- 本期转确认收入（日）
           SUM(IF(report_code = 'ADV_RECEIPT' AND travel_date = '${bizdate}', unsettled_amt, 0)) AS adv_receipt_close_amt,  -- 期末预收（日快照）
           SUM(IF(report_code = 'ADV_PAYMENT' AND travel_date <> '${bizdate}', unsettled_amt, 0)) AS adv_payment_open_amt,  -- 期初预付（日快照）
           0 AS adv_payment_pay_amt,                           -- 本期付（日）
           0 AS adv_payment_return_amt,                        -- 本期退回（日）
           0 AS adv_payment_to_cost_amt,                       -- 本期转确认成本（日）
           SUM(IF(report_code = 'ADV_PAYMENT' AND travel_date = '${bizdate}', unsettled_amt, 0)) AS adv_payment_close_amt,  -- 期末预付（日快照）
           0 AS ar_open_amt,                                   -- 期初应收（日快照）
           0 AS ar_add_amt,                                    -- 本期应收增加（日）
           0 AS ar_settle_amt,                                 -- 本期收回（日）
           0 AS ar_close_amt,                                  -- 期末应收（日快照）
           0 AS ap_open_amt,                                   -- 期初应付（日快照）
           0 AS ap_add_amt,                                    -- 本期应付增加（日）
           0 AS ap_settle_amt,                                 -- 本期偿还（日）
           0 AS ap_close_amt,                                  -- 期末应付（日快照）
           0 AS credit_sale_amt,                               -- 授信销售（日）
           0 AS credit_purchase_amt,                           -- 授信采购（日）
           0 AS revenue_amt,                                   -- 确认收入（日）
           0 AS cost_amt,                                      -- 确认成本（日）
           0 AS net_ticket_qty,                                -- 净票数（日）
           0 AS balance_open_amt,                              -- 期初余额（日快照）
           0 AS balance_in_amt,                                -- 资金流入（日）
           0 AS balance_out_amt,                               -- 资金流出（日）
           0 AS balance_close_amt,                             -- 期末余额（日快照）
           0 AS recharge_amt,                                  -- 充值金额（日）
           0 AS withdraw_amt,                                  -- 提现金额（日）
           0 AS expense_income_amt,                            -- 费用收入（日）
           0 AS expense_out_amt,                               -- 费用支出（日）
           0 AS unclassified_flow_qty                          -- 待归类流水笔数（日）
    FROM dws.dws_fin_merchant_unsettled_df
    WHERE travel_date IN ('${bizdate}', DATE_FORMAT(DATE_SUB(TO_DATE('${bizdate}', 'yyyyMMdd'), 1), 'yyyyMMdd')) AND report_code IN ('ADV_RECEIPT', 'ADV_PAYMENT')
    GROUP BY merchant_tenant_id                                -- 按粒度键汇总
    UNION ALL
    -- 期间值：订单资金（预收 / 预付发生额、确认收入 / 成本、授信销售 / 采购、净票数）
    SELECT merchant_tenant_id AS merchant_tenant_id,
           0 AS adv_receipt_open_amt,                          -- 期初预收（日快照）
           SUM(receive_amt) AS adv_receipt_receive_amt,        -- 本期收（日）
           SUM(refund_amt) AS adv_receipt_refund_amt,          -- 本期退（日）
           SUM(to_revenue_amt) AS adv_receipt_to_revenue_amt,  -- 本期转确认收入（日）
           0 AS adv_receipt_close_amt,                         -- 期末预收（日快照）
           0 AS adv_payment_open_amt,                          -- 期初预付（日快照）
           SUM(pay_amt) AS adv_payment_pay_amt,                -- 本期付（日）
           SUM(return_amt) AS adv_payment_return_amt,          -- 本期退回（日）
           SUM(to_cost_amt) AS adv_payment_to_cost_amt,        -- 本期转确认成本（日）
           0 AS adv_payment_close_amt,                         -- 期末预付（日快照）
           0 AS ar_open_amt,                                   -- 期初应收（日快照）
           0 AS ar_add_amt,                                    -- 本期应收增加（日）
           0 AS ar_settle_amt,                                 -- 本期收回（日）
           0 AS ar_close_amt,                                  -- 期末应收（日快照）
           0 AS ap_open_amt,                                   -- 期初应付（日快照）
           0 AS ap_add_amt,                                    -- 本期应付增加（日）
           0 AS ap_settle_amt,                                 -- 本期偿还（日）
           0 AS ap_close_amt,                                  -- 期末应付（日快照）
           SUM(credit_sale_amt) AS credit_sale_amt,            -- 授信销售（日）
           SUM(credit_purchase_amt) AS credit_purchase_amt,    -- 授信采购（日）
           SUM(revenue_amt) AS revenue_amt,                    -- 确认收入（日）
           SUM(cost_amt) AS cost_amt,                          -- 确认成本（日）
           SUM(sale_ticket_qty) - SUM(refund_ticket_qty) AS net_ticket_qty,  -- 净票数（日）
           0 AS balance_open_amt,                              -- 期初余额（日快照）
           0 AS balance_in_amt,                                -- 资金流入（日）
           0 AS balance_out_amt,                               -- 资金流出（日）
           0 AS balance_close_amt,                             -- 期末余额（日快照）
           0 AS recharge_amt,                                  -- 充值金额（日）
           0 AS withdraw_amt,                                  -- 提现金额（日）
           0 AS expense_income_amt,                            -- 费用收入（日）
           0 AS expense_out_amt,                               -- 费用支出（日）
           0 AS unclassified_flow_qty                          -- 待归类流水笔数（日）
    FROM dws.dws_fin_merchant_order_fund_di WHERE travel_date = '${bizdate}'
    GROUP BY merchant_tenant_id                                -- 按粒度键汇总
    UNION ALL
    -- 应收 / 应付：期初、增加、收回 / 偿还、期末
    SELECT merchant_tenant_id AS merchant_tenant_id,
           0 AS adv_receipt_open_amt,                          -- 期初预收（日快照）
           0 AS adv_receipt_receive_amt,                       -- 本期收（日）
           0 AS adv_receipt_refund_amt,                        -- 本期退（日）
           0 AS adv_receipt_to_revenue_amt,                    -- 本期转确认收入（日）
           0 AS adv_receipt_close_amt,                         -- 期末预收（日快照）
           0 AS adv_payment_open_amt,                          -- 期初预付（日快照）
           0 AS adv_payment_pay_amt,                           -- 本期付（日）
           0 AS adv_payment_return_amt,                        -- 本期退回（日）
           0 AS adv_payment_to_cost_amt,                       -- 本期转确认成本（日）
           0 AS adv_payment_close_amt,                         -- 期末预付（日快照）
           SUM(IF(report_code = 'AR', open_amt, 0)) AS ar_open_amt,  -- 期初应收（日快照）
           SUM(IF(report_code = 'AR', add_amt, 0)) AS ar_add_amt,  -- 本期应收增加（日）
           SUM(IF(report_code = 'AR', settle_amt, 0)) AS ar_settle_amt,  -- 本期收回（日）
           SUM(IF(report_code = 'AR', close_amt, 0)) AS ar_close_amt,  -- 期末应收（日快照）
           SUM(IF(report_code = 'AP', open_amt, 0)) AS ap_open_amt,  -- 期初应付（日快照）
           SUM(IF(report_code = 'AP', add_amt, 0)) AS ap_add_amt,  -- 本期应付增加（日）
           SUM(IF(report_code = 'AP', settle_amt, 0)) AS ap_settle_amt,  -- 本期偿还（日）
           SUM(IF(report_code = 'AP', close_amt, 0)) AS ap_close_amt,  -- 期末应付（日快照）
           0 AS credit_sale_amt,                               -- 授信销售（日）
           0 AS credit_purchase_amt,                           -- 授信采购（日）
           0 AS revenue_amt,                                   -- 确认收入（日）
           0 AS cost_amt,                                      -- 确认成本（日）
           0 AS net_ticket_qty,                                -- 净票数（日）
           0 AS balance_open_amt,                              -- 期初余额（日快照）
           0 AS balance_in_amt,                                -- 资金流入（日）
           0 AS balance_out_amt,                               -- 资金流出（日）
           0 AS balance_close_amt,                             -- 期末余额（日快照）
           0 AS recharge_amt,                                  -- 充值金额（日）
           0 AS withdraw_amt,                                  -- 提现金额（日）
           0 AS expense_income_amt,                            -- 费用收入（日）
           0 AS expense_out_amt,                               -- 费用支出（日）
           0 AS unclassified_flow_qty                          -- 待归类流水笔数（日）
    FROM dws.dws_fin_merchant_credit_df WHERE travel_date = '${bizdate}'
    GROUP BY merchant_tenant_id                                -- 按粒度键汇总
    UNION ALL
    -- 余额：期初 / 期末取账户日快照（同一主体多账户相加）
    SELECT a.subject_id AS merchant_tenant_id,
           0 AS adv_receipt_open_amt,                          -- 期初预收（日快照）
           0 AS adv_receipt_receive_amt,                       -- 本期收（日）
           0 AS adv_receipt_refund_amt,                        -- 本期退（日）
           0 AS adv_receipt_to_revenue_amt,                    -- 本期转确认收入（日）
           0 AS adv_receipt_close_amt,                         -- 期末预收（日快照）
           0 AS adv_payment_open_amt,                          -- 期初预付（日快照）
           0 AS adv_payment_pay_amt,                           -- 本期付（日）
           0 AS adv_payment_return_amt,                        -- 本期退回（日）
           0 AS adv_payment_to_cost_amt,                       -- 本期转确认成本（日）
           0 AS adv_payment_close_amt,                         -- 期末预付（日快照）
           0 AS ar_open_amt,                                   -- 期初应收（日快照）
           0 AS ar_add_amt,                                    -- 本期应收增加（日）
           0 AS ar_settle_amt,                                 -- 本期收回（日）
           0 AS ar_close_amt,                                  -- 期末应收（日快照）
           0 AS ap_open_amt,                                   -- 期初应付（日快照）
           0 AS ap_add_amt,                                    -- 本期应付增加（日）
           0 AS ap_settle_amt,                                 -- 本期偿还（日）
           0 AS ap_close_amt,                                  -- 期末应付（日快照）
           0 AS credit_sale_amt,                               -- 授信销售（日）
           0 AS credit_purchase_amt,                           -- 授信采购（日）
           0 AS revenue_amt,                                   -- 确认收入（日）
           0 AS cost_amt,                                      -- 确认成本（日）
           0 AS net_ticket_qty,                                -- 净票数（日）
           SUM(b.opening_balance_amt) AS balance_open_amt,     -- 期初余额（日快照）
           0 AS balance_in_amt,                                -- 资金流入（日）
           0 AS balance_out_amt,                               -- 资金流出（日）
           SUM(b.closing_balance_amt) AS balance_close_amt,    -- 期末余额（日快照）
           0 AS recharge_amt,                                  -- 充值金额（日）
           0 AS withdraw_amt,                                  -- 提现金额（日）
           0 AS expense_income_amt,                            -- 费用收入（日）
           0 AS expense_out_amt,                               -- 费用支出（日）
           0 AS unclassified_flow_qty                          -- 待归类流水笔数（日）
    FROM (SELECT account_no, opening_balance_amt, closing_balance_amt FROM dws.dws_fin_account_balance_df WHERE travel_date = '${bizdate}') b
    JOIN (SELECT account_no, subject_id FROM dim.dim_fin_account_df WHERE travel_date = '${bizdate}' AND account_type IN ('MERCHANT', 'DISTRIBUTOR')) a ON a.account_no = b.account_no
    GROUP BY a.subject_id                                      -- 按粒度键汇总
    UNION ALL
    -- 余额流入 / 流出、费用收支、待归类：取归属后的流水
    SELECT merchant_tenant_id AS merchant_tenant_id,
           0 AS adv_receipt_open_amt,                          -- 期初预收（日快照）
           0 AS adv_receipt_receive_amt,                       -- 本期收（日）
           0 AS adv_receipt_refund_amt,                        -- 本期退（日）
           0 AS adv_receipt_to_revenue_amt,                    -- 本期转确认收入（日）
           0 AS adv_receipt_close_amt,                         -- 期末预收（日快照）
           0 AS adv_payment_open_amt,                          -- 期初预付（日快照）
           0 AS adv_payment_pay_amt,                           -- 本期付（日）
           0 AS adv_payment_return_amt,                        -- 本期退回（日）
           0 AS adv_payment_to_cost_amt,                       -- 本期转确认成本（日）
           0 AS adv_payment_close_amt,                         -- 期末预付（日快照）
           0 AS ar_open_amt,                                   -- 期初应收（日快照）
           0 AS ar_add_amt,                                    -- 本期应收增加（日）
           0 AS ar_settle_amt,                                 -- 本期收回（日）
           0 AS ar_close_amt,                                  -- 期末应收（日快照）
           0 AS ap_open_amt,                                   -- 期初应付（日快照）
           0 AS ap_add_amt,                                    -- 本期应付增加（日）
           0 AS ap_settle_amt,                                 -- 本期偿还（日）
           0 AS ap_close_amt,                                  -- 期末应付（日快照）
           0 AS credit_sale_amt,                               -- 授信销售（日）
           0 AS credit_purchase_amt,                           -- 授信采购（日）
           0 AS revenue_amt,                                   -- 确认收入（日）
           0 AS cost_amt,                                      -- 确认成本（日）
           0 AS net_ticket_qty,                                -- 净票数（日）
           0 AS balance_open_amt,                              -- 期初余额（日快照）
           SUM(IF(report_code IN ('BALANCE', 'EXPENSE'), fund_in_amt, 0)) AS balance_in_amt,  -- 资金流入（日）
           SUM(IF(report_code IN ('BALANCE', 'EXPENSE'), fund_out_amt, 0)) AS balance_out_amt,  -- 资金流出（日）
           0 AS balance_close_amt,                             -- 期末余额（日快照）
           SUM(IF(flow_type = 'RECHARGE', fund_in_amt, 0)) AS recharge_amt,  -- 充值金额（日）
           SUM(IF(flow_type = 'WITHDRAW', fund_out_amt, 0)) AS withdraw_amt,  -- 提现金额（日）
           SUM(IF(report_code = 'EXPENSE', fund_in_amt, 0)) AS expense_income_amt,  -- 费用收入（日）
           SUM(IF(report_code = 'EXPENSE', fund_out_amt, 0)) AS expense_out_amt,  -- 费用支出（日）
           SUM(IF(report_code = 'UNCLASSIFIED', fund_flow_qty, 0)) AS unclassified_flow_qty  -- 待归类流水笔数（日）
    FROM dws.dws_fin_merchant_balance_di WHERE travel_date = '${bizdate}'
    GROUP BY merchant_tenant_id                                -- 按粒度键汇总
)
INSERT OVERWRITE TABLE ads.ads_fin_merchant_report_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
    merchant_tenant_id,                                        -- 本方商户租户ID
    SUM(adv_receipt_open_amt)        AS adv_receipt_open_amt,  -- 期初预收（日快照）
    SUM(adv_receipt_receive_amt)     AS adv_receipt_receive_amt,  -- 本期收（日）
    SUM(adv_receipt_refund_amt)      AS adv_receipt_refund_amt,  -- 本期退（日）
    SUM(adv_receipt_to_revenue_amt)  AS adv_receipt_to_revenue_amt,  -- 本期转确认收入（日）
    SUM(adv_receipt_close_amt)       AS adv_receipt_close_amt,  -- 期末预收（日快照）
    SUM(adv_payment_open_amt)        AS adv_payment_open_amt,  -- 期初预付（日快照）
    SUM(adv_payment_pay_amt)         AS adv_payment_pay_amt,   -- 本期付（日）
    SUM(adv_payment_return_amt)      AS adv_payment_return_amt,  -- 本期退回（日）
    SUM(adv_payment_to_cost_amt)     AS adv_payment_to_cost_amt,  -- 本期转确认成本（日）
    SUM(adv_payment_close_amt)       AS adv_payment_close_amt,  -- 期末预付（日快照）
    SUM(ar_open_amt)                 AS ar_open_amt,           -- 期初应收（日快照）
    SUM(ar_add_amt)                  AS ar_add_amt,            -- 本期应收增加（日）
    SUM(ar_settle_amt)               AS ar_settle_amt,         -- 本期收回（日）
    SUM(ar_close_amt)                AS ar_close_amt,          -- 期末应收（日快照）
    SUM(ap_open_amt)                 AS ap_open_amt,           -- 期初应付（日快照）
    SUM(ap_add_amt)                  AS ap_add_amt,            -- 本期应付增加（日）
    SUM(ap_settle_amt)               AS ap_settle_amt,         -- 本期偿还（日）
    SUM(ap_close_amt)                AS ap_close_amt,          -- 期末应付（日快照）
    SUM(credit_sale_amt)             AS credit_sale_amt,       -- 授信销售（日）
    SUM(credit_purchase_amt)         AS credit_purchase_amt,   -- 授信采购（日）
    SUM(revenue_amt)                 AS revenue_amt,           -- 确认收入（日）
    SUM(cost_amt)                    AS cost_amt,              -- 确认成本（日）
    SUM(net_ticket_qty)              AS net_ticket_qty,        -- 净票数（日）
    SUM(balance_open_amt)            AS balance_open_amt,      -- 期初余额（日快照）
    SUM(balance_in_amt)              AS balance_in_amt,        -- 资金流入（日）
    SUM(balance_out_amt)             AS balance_out_amt,       -- 资金流出（日）
    SUM(balance_close_amt)           AS balance_close_amt,     -- 期末余额（日快照）
    SUM(recharge_amt)                AS recharge_amt,          -- 充值金额（日）
    SUM(withdraw_amt)                AS withdraw_amt,          -- 提现金额（日）
    SUM(expense_income_amt)          AS expense_income_amt,    -- 费用收入（日）
    SUM(expense_out_amt)             AS expense_out_amt,       -- 费用支出（日）
    SUM(unclassified_flow_qty)       AS unclassified_flow_qty,  -- 待归类流水笔数（日）
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time  -- ETL 加载时间
FROM x
GROUP BY merchant_tenant_id;                                   -- 按粒度键汇总
