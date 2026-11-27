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
INSERT OVERWRITE TABLE ads.ads_fin_account_balance_di PARTITION (travel_date = '${bizdate}')
SELECT
    account_id,
    subject_code,
    trade_account_id,
    account_book_id,
    template_item_code,
    SUM(account_income_amt)                                      AS account_income_amt,
    SUM(account_expense_amt)                                     AS account_expense_amt,
    MAX(account_balance_amt)                                     AS account_balance_amt,
    SUM(account_frozen_income_amt)                               AS account_frozen_income_amt,
    SUM(account_frozen_expense_amt)                              AS account_frozen_expense_amt,
    SUM(account_available_income_amt)                            AS account_available_income_amt,
    SUM(account_available_expense_amt)                           AS account_available_expense_amt,
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time
FROM (
    -- dws_fin_account_trans_di
    SELECT
        account_id,
        subject_code,
        trade_account_id,
        account_book_id,
        template_item_code,
        SUM(account_income_amt)                                      AS account_income_amt,
        SUM(account_expense_amt)                                     AS account_expense_amt,
        SUM(account_balance_amt)                                     AS account_balance_amt,
        SUM(account_frozen_income_amt)                               AS account_frozen_income_amt,
        SUM(account_frozen_expense_amt)                              AS account_frozen_expense_amt,
        SUM(account_available_income_amt)                            AS account_available_income_amt,
        SUM(account_available_expense_amt)                           AS account_available_expense_amt
    FROM dws.dws_fin_account_trans_di
    WHERE travel_date = '${bizdate}'
    GROUP BY account_id, subject_code, trade_account_id, account_book_id, template_item_code
) u
GROUP BY account_id, subject_code, trade_account_id, account_book_id, template_item_code
