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
INSERT OVERWRITE TABLE dws.dws_fin_account_trans_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
    account_id,                                                                   -- 账户ID
    subject_code,                                                                 -- 账本科目编码
    trade_account_id,                                                             -- 交易账户ID
    account_book_id,                                                              -- 账本ID
    template_item_code,                                                           -- 账本专项费用项编码
    SUM(account_income_amt)                                      AS account_income_amt,  -- 账户收入金额
    SUM(account_expense_amt)                                     AS account_expense_amt,  -- 账户支出金额
    MAX(account_balance_amt)                                     AS account_balance_amt,  -- 账户日终余额
    SUM(account_frozen_income_amt)                               AS account_frozen_income_amt,  -- 账户冻结收入
    SUM(account_frozen_expense_amt)                              AS account_frozen_expense_amt,  -- 账户冻结支出（解冻）
    SUM(account_available_income_amt)                            AS account_available_income_amt,  -- 账户可用收入
    SUM(account_available_expense_amt)                           AS account_available_expense_amt,  -- 账户可用支出
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time           -- ETL 加载时间
FROM (
    -- journal：账户流水
    SELECT
        COALESCE(account_id, CAST(-1 AS BIGINT))                     AS account_id,  -- 账户ID
        subject_code,                                                             -- 账本科目编码
        COALESCE(trade_account_id, CAST(-1 AS BIGINT))               AS trade_account_id,  -- 交易账户ID
        COALESCE(account_book_id, CAST(-1 AS BIGINT))                AS account_book_id,  -- 账本ID
        template_item_code,                                                       -- 账本专项费用项编码
        SUM(IF(trade_amt > 0, trade_amt, 0))                         AS account_income_amt,  -- 账户收入金额
        SUM(IF(trade_amt < 0, -trade_amt, 0))                        AS account_expense_amt,  -- 账户支出金额
        MAX_BY(balance_amt, trade_time)                              AS account_balance_amt,  -- 账户日终余额
        SUM(IF(
            frozen_trade_type = 0,
            CAST(frozen_amt AS DECIMAL(18,2)) / 100,
            0
        )) AS account_frozen_income_amt,                                          -- 账户冻结收入
        SUM(IF(
            frozen_trade_type = 1,
            CAST(frozen_amt AS DECIMAL(18,2)) / 100,
            0
        )) AS account_frozen_expense_amt,                                         -- 账户冻结支出（解冻）
        SUM(IF(
            available_trade_type = 0,
            CAST(available_amt AS DECIMAL(18,2)) / 100,
            0
        )) AS account_available_income_amt,                                       -- 账户可用收入
        SUM(IF(
            available_trade_type = 1,
            CAST(available_amt AS DECIMAL(18,2)) / 100,
            0
        )) AS account_available_expense_amt                                       -- 账户可用支出
    FROM dwd.dwd_fin_trade_journal_di
    WHERE travel_date = '${bizdate}'                                              -- 只取当日分区
    GROUP BY COALESCE(account_id, CAST(-1 AS BIGINT)),                            -- 按粒度键汇总
             subject_code,                                                        -- 账本科目编码
             COALESCE(trade_account_id, CAST(-1 AS BIGINT)),
             COALESCE(account_book_id, CAST(-1 AS BIGINT)),
             template_item_code                                                   -- 账本专项费用项编码
) u                                                                               -- 各来源合并后的明细
GROUP BY account_id, subject_code, trade_account_id, account_book_id, template_item_code  -- 按粒度键汇总
