-- ================================================================================================
-- ads.ads_fin_account_balance_di  财务平衡
-- 粒度：1行=1天×账户×科目
-- 分区：travel_date（YYYYMMDD）
-- 调度：每日，依赖上游 DWS 当日分区；完成后回流 / 服务层读取
-- 上游：dws_fin_account_trans_di
-- 替代旧任务 3 个（上线对数一致后下线）：
--   · 业务工厂/财务平衡/财务平衡汇总/ads_daily_account_trans_item_summary_d_i（EMR_SPARK_SQL，cron 00 02 00 * * ?）
--   · 业务工厂/财务平衡/财务平衡汇总/ads_daily_account_trans_summary_d_i（EMR_SPARK_SQL，cron 00 02 00 * * ?）
--   · 业务工厂/财务平衡/财务平衡汇总/ads_daily_trade_account_trans_summary_d_i（EMR_SPARK_SQL，cron 00 02 00 * * ?）
-- 性能：
--   · ADS 只存日粒度：周 / 月 / 年 / 节假日 / 自定义区间与同比环比在查询时关联 dim_opr_period_f（见「指标口径 · ADS 业务指标」）
--   · 比率类不落比率值，只存分子分母；去重类存位图；快照类取日终值
-- ================================================================================================
INSERT OVERWRITE TABLE ads.ads_fin_account_balance_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
    account_id,                                                                   -- 账户ID
    subject_code,                                                                 -- 账本科目编码
    trade_account_id,                                                             -- 交易账户ID
    account_book_id,                                                              -- 账本ID
    template_item_code,                                                           -- 账本专项费用项编码
    SUM(account_income_amt)                                      AS account_income_amt,  -- 账户收入金额（日）
    SUM(account_expense_amt)                                     AS account_expense_amt,  -- 账户支出金额（日）
    MAX(account_balance_amt)                                     AS account_balance_amt,  -- 账户日终余额（日快照）
    SUM(account_frozen_income_amt)                               AS account_frozen_income_amt,  -- 账户冻结收入（日）
    SUM(account_frozen_expense_amt)                              AS account_frozen_expense_amt,  -- 账户冻结支出（解冻）（日）
    SUM(account_available_income_amt)                            AS account_available_income_amt,  -- 账户可用收入（日）
    SUM(account_available_expense_amt)                           AS account_available_expense_amt,  -- 账户可用支出（日）
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time           -- ETL 加载时间
FROM (
    -- dws_fin_account_trans_di
    SELECT
        account_id,                                                               -- 账户ID
        subject_code,                                                             -- 账本科目编码
        trade_account_id,                                                         -- 交易账户ID
        account_book_id,                                                          -- 账本ID
        template_item_code,                                                       -- 账本专项费用项编码
        SUM(account_income_amt)                                      AS account_income_amt,  -- 账户收入金额（日）
        SUM(account_expense_amt)                                     AS account_expense_amt,  -- 账户支出金额（日）
        SUM(account_balance_amt)                                     AS account_balance_amt,  -- 账户日终余额（日快照）
        SUM(account_frozen_income_amt)                               AS account_frozen_income_amt,  -- 账户冻结收入（日）
        SUM(account_frozen_expense_amt)                              AS account_frozen_expense_amt,  -- 账户冻结支出（解冻）（日）
        SUM(account_available_income_amt)                            AS account_available_income_amt,  -- 账户可用收入（日）
        SUM(account_available_expense_amt)                           AS account_available_expense_amt  -- 账户可用支出（日）
    FROM dws.dws_fin_account_trans_di
    WHERE travel_date = '${bizdate}'                                              -- 只取当日分区
    GROUP BY account_id, subject_code, trade_account_id, account_book_id, template_item_code  -- 按粒度键汇总
) u                                                                               -- 各来源合并后的明细
GROUP BY account_id, subject_code, trade_account_id, account_book_id, template_item_code  -- 按粒度键汇总
