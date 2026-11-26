-- ================================================================================================
-- dws.dws_fin_account_trans_di  账户收支日汇总
-- 粒度：1行=1天×账户×科目
-- 分区：travel_date（YYYYMMDD）
-- 调度：每日，依赖上游 DWD 当日分区
-- 上游：dwd_fin_trade_journal_di
-- 性能：
--   · 同一来源的指标在一个子查询里预聚合（一次扫描），各来源 UNION ALL 后按粒度汇总，不做明细级 JOIN
--   · 来源：journal = dwd.dwd_fin_trade_journal_di（账户流水）
-- ================================================================================================
INSERT OVERWRITE TABLE dws.dws_fin_account_trans_di PARTITION (travel_date = '${bizdate}')
SELECT
    account_id,
    subject_code,
    SUM(account_income_amt)                                      AS account_income_amt,
    SUM(account_expense_amt)                                     AS account_expense_amt,
    MAX(account_balance_amt)                                     AS account_balance_amt,
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time
FROM (
    -- journal：账户流水
    SELECT
        COALESCE(account_id, CAST(-1 AS BIGINT))                     AS account_id,
        subject_code,
        SUM(IF(trade_amt > 0, trade_amt, 0))                         AS account_income_amt,
        SUM(IF(trade_amt < 0, -trade_amt, 0))                        AS account_expense_amt,
        MAX_BY(balance_amt, trade_time)                              AS account_balance_amt
    FROM dwd.dwd_fin_trade_journal_di
    WHERE travel_date = '${bizdate}'
    GROUP BY COALESCE(account_id, CAST(-1 AS BIGINT)), subject_code
) u
GROUP BY account_id, subject_code
