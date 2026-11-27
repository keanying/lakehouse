-- ================================================================================================
-- dwd.dwd_fin_trade_journal_di  账户交易流水
-- 粒度：1行=1笔账户流水
-- 分区：travel_date（YYYYMMDD）
-- 调度：每日，依赖上游 ODS 当日分区与相关维表
-- 上游：ods_fin_trade_journal_di、ods_fin_account_book_subject_df
-- 业务规则 / 修正：
--   · 收支方向带符号：daction=0 收入为正，1 支出为负（旧财务平衡脚本 IF(daction=0, dmoney, 0) 规则）；金额分 → 元
-- ================================================================================================
INSERT OVERWRITE TABLE dwd.dwd_fin_trade_journal_di PARTITION (travel_date = '${bizdate}')
SELECT
    CAST(account_id AS BIGINT)                                   AS account_id,
    CAST(subject_code AS STRING)                                 AS subject_code,
    rectime                                                      AS trade_time,
    CAST(id AS BIGINT)                                           AS journal_id,
    CAST(IF(daction = 0, dmoney, -dmoney) AS DECIMAL(18,2)) / 100 AS trade_amt,
    CAST(lmoney AS DECIMAL(18,2)) / 100                          AS balance_amt,
    id,
    CAST(NULL AS STRING)                                         AS subject_name,   -- 冗余维度属性：查询时关联维表，建议从明细移除
    CAST(NULL AS BIGINT)                                         AS type,   -- 待确认：来源未同步（旧字段 ods_fin_account_book_subject_df.type）
    CAST(NULL AS STRING)                                         AS unit,   -- 待确认：来源未同步（旧字段 ods_fin_account_book_subject_df.unit）
    CAST(NULL AS BIGINT)                                         AS can_withdraw,   -- 待确认：来源未同步（旧字段 ods_fin_account_book_subject_df.can_withdraw）
    CAST(NULL AS BIGINT)                                         AS can_invoice,   -- 待确认：来源未同步（旧字段 ods_fin_account_book_subject_df.can_invoice）
    CAST(NULL AS BIGINT)                                         AS can_integral,   -- 待确认：来源未同步（旧字段 ods_fin_account_book_subject_df.can_integral）
    CAST(NULL AS BIGINT)                                         AS is_default,   -- 待确认：来源未同步（旧字段 ods_fin_account_book_subject_df.is_default）
    CAST(NULL AS BIGINT)                                         AS priority,   -- 待确认：来源未同步（旧字段 ods_fin_account_book_subject_df.priority）
    CAST(NULL AS BIGINT)                                         AS repeatable,   -- 待确认：来源未同步（旧字段 ods_fin_account_book_subject_df.repeatable）
    CAST(NULL AS BIGINT)                                         AS refund_expires,   -- 待确认：来源未同步（旧字段 ods_fin_account_book_subject_df.refund_expires）
    CAST(NULL AS BIGINT)                                         AS refund_limit,   -- 待确认：来源未同步（旧字段 ods_fin_account_book_subject_df.refund_limit）
    CAST(NULL AS BIGINT)                                         AS remaining_limit,   -- 待确认：来源未同步（旧字段 ods_fin_account_book_subject_df.remaining_limit）
    CAST(NULL AS BIGINT)                                         AS third_party,   -- 待确认：来源未同步（旧字段 ods_fin_account_book_subject_df.third_party）
    CAST(NULL AS BIGINT)                                         AS trade_type,   -- 待确认：来源未同步（旧字段 ods_fin_account_book_subject_df.trade_type）
    CAST(NULL AS STRING)                                         AS ext,   -- 待确认：来源未同步（旧字段 ods_fin_account_book_subject_df.ext）
    CAST(NULL AS STRING)                                         AS remark,   -- 待确认：来源未同步（旧字段 ods_fin_account_book_subject_df.remark）
    CAST(NULL AS BIGINT)                                         AS add_time,   -- 待确认：来源未同步（旧字段 ods_fin_account_book_subject_df.add_time）
    CAST(NULL AS BIGINT)                                         AS update_time,   -- 待确认：来源未同步（旧字段 ods_fin_account_book_subject_df.update_time）
    customer_id,
    trade_account_id,
    CAST(fid AS BIGINT)                                          AS member_id,
    CAST(aid AS BIGINT)                                          AS supplier_id,
    dmoney,
    lmoney,
    CAST(frozen_money AS DECIMAL(14,0))                          AS frozen_amt,
    CAST(frozen_remain_money AS DECIMAL(14,0))                   AS frozen_remain_amt,
    CAST(trade_limit_money AS BIGINT)                            AS trade_limit_amt,
    trade_limit_type,
    trade_limit_total,
    orderid                                                      AS order_no,
    trade_no,
    account_book_id,
    trade_subject_code,
    subject_type,
    template_code,
    template_item_code,
    function_code,
    settle_mark,
    daction,
    rectime,
    recmonth,
    dtype,
    ptype,
    account_type,
    reversal_trade_id,
    last_trade_id,
    channel,
    account_adjust,
    CAST(opid AS BIGINT)                                         AS operator_id,
    memo,
    CAST(status AS BIGINT)                                       AS order_status,
    sequence,
    total_trade,
    available_trade,
    CAST(available_money AS BIGINT)                              AS available_amt,
    CAST(available_remain_money AS BIGINT)                       AS available_remain_amt,
    available_trade_type,
    frozen_trade,
    frozen_trade_type,
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time
FROM ods.ods_fin_trade_journal_di
WHERE travel_date = '${bizdate}'
