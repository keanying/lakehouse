-- ================================================================================================
-- dwd.dwd_fin_trade_journal_di  账户交易流水
-- 粒度：1行=1笔账户流水
-- 分区：travel_date（YYYYMMDD）
-- 调度：每日，依赖上游 ODS 当日分区与相关维表
-- 上游：ods_fin_trade_journal_di、ods_fin_account_book_subject_df
-- 替代旧任务 1 个（上线对数一致后下线）：
--   · 业务工厂/内部信息/财务部/amb相关表同步任务/dwd_pft_trade_journal_d_f（EMR_SPARK_SQL，cron 00 00 00 * * ?）
-- 业务规则 / 修正：
--   · 收支方向带符号：daction=0 收入为正，1 支出为负（旧财务平衡脚本 IF(daction=0, dmoney, 0) 规则）；金额分 → 元
-- ================================================================================================
INSERT OVERWRITE TABLE dwd.dwd_fin_trade_journal_di PARTITION (travel_date = '${bizdate}')
SELECT
    CAST(account_id AS BIGINT)                                   AS account_id,
    CAST(id AS BIGINT)                                           AS journal_id,
    CAST(subject_code AS STRING)                                 AS subject_code,
    CAST(IF(daction = 0, dmoney, -dmoney) AS DECIMAL(18,2)) / 100 AS trade_amt,
    CAST(lmoney AS DECIMAL(18,2)) / 100                          AS balance_amt,
    rectime                                                      AS trade_time,
    recmonth                                                     AS oper_month,
    customer_id,
    template_item_code,
    dmoney,
    fid                                                          AS member_id,
    CAST(NULL AS STRING)                                         AS code_qty,   -- 待确认：来源未同步（旧字段 dwd_pft_trade_journal_d_f.code_num）
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time
FROM ods.ods_fin_trade_journal_di
WHERE travel_date = '${bizdate}'
