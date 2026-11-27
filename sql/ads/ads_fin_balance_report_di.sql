-- ================================================================================================
-- ads.ads_fin_balance_report_di  余额报表（日 × 账本）
-- 依据：《3.0 通用财务报表 · 需求说明》v1.0（2026-11-24）
-- 业务规则：
--   · 期初 / 期末：账户日快照（当日第一笔流水前 / 最后一笔流水后的可用余额；无流水取日终可用余额）
--   · 流入 / 流出只计归属为 仅余额 / 费用收支 的流水；冻结、退款释放、下单收付相抵部分不进（5.2、勾稽第 7 条说明）
-- 性能：
--   · 两个来源都按账户预聚合后关联
-- ================================================================================================

WITH b AS (
    SELECT /*+ BROADCAST(a) */ a.subject_id AS merchant_tenant_id, s.account_no,
           COALESCE(s.opening_balance_amt, s.available_balance_amt) AS balance_open_amt,  -- 期初余额（日快照）
           COALESCE(s.closing_balance_amt, s.available_balance_amt) AS balance_close_amt  -- 期末余额（日快照）
    FROM (
        SELECT account_no,                                                        -- 账本
        available_balance_amt,
        opening_balance_amt,
        closing_balance_amt FROM dws.dws_fin_account_balance_df WHERE travel_date = '${bizdate}'
    ) s
    JOIN (SELECT account_no, subject_id FROM dim.dim_fin_account_df
        WHERE travel_date = '${bizdate}' AND account_type IN ('MERCHANT', 'DISTRIBUTOR')) a  -- 只取当日分区，并按条件过滤
      ON a.account_no = s.account_no                                              -- 按 account_no 关联
),
f AS (
    SELECT merchant_tenant_id, account_no,
           SUM(IF(report_code IN ('BALANCE', 'EXPENSE'), fund_in_amt, 0))  AS balance_in_amt,  -- 资金流入
           SUM(IF(report_code IN ('BALANCE', 'EXPENSE'), fund_out_amt, 0)) AS balance_out_amt,  -- 资金流出
           SUM(IF(flow_type = 'RECHARGE', fund_in_amt, 0))                 AS recharge_amt,  -- 其中充值
           SUM(IF(flow_type = 'WITHDRAW', fund_out_amt, 0))                AS withdraw_amt,  -- 其中提现
           SUM(IF(report_code = 'EXPENSE', fund_in_amt, 0))                AS expense_income_amt,  -- 费用收入（二期 · 费用收支报表）
           SUM(IF(report_code = 'EXPENSE', fund_out_amt, 0))               AS expense_out_amt,  -- 费用支出（二期 · 费用收支报表）
           SUM(IF(report_code = 'UNCLASSIFIED', fund_flow_qty, 0))         AS unclassified_flow_qty  -- 待归类流水笔数（应为 0）
    FROM dws.dws_fin_merchant_balance_di WHERE travel_date = '${bizdate}'
    GROUP BY merchant_tenant_id, account_no                                       -- 按粒度键汇总
)
INSERT OVERWRITE TABLE ads.ads_fin_balance_report_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT COALESCE(b.merchant_tenant_id, f.merchant_tenant_id) AS merchant_tenant_id,  -- 本方商户租户ID
       COALESCE(b.account_no, f.account_no) AS account_no,                        -- 账本
       b.balance_open_amt,                                                        -- 期初余额（日快照）
       COALESCE(f.balance_in_amt, 0) AS balance_in_amt,                           -- 资金流入
       COALESCE(f.balance_out_amt, 0) AS balance_out_amt,                         -- 资金流出
       b.balance_close_amt,                                                       -- 期末余额（日快照）
       COALESCE(f.recharge_amt, 0) AS recharge_amt, COALESCE(f.withdraw_amt, 0) AS withdraw_amt,  -- 其中提现
       COALESCE(f.expense_income_amt,                                             -- 费用支出（二期 · 费用收支报表）
                0) AS expense_income_amt, COALESCE(f.expense_out_amt,
                0) AS expense_out_amt,                                            -- 费用支出（二期 · 费用收支报表）
       COALESCE(f.unclassified_flow_qty, 0) AS unclassified_flow_qty,             -- 待归类流水笔数（应为 0）
       DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time        -- ETL 加载时间
FROM b
FULL OUTER JOIN f ON f.account_no = b.account_no;
