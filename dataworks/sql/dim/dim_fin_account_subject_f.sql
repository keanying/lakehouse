-- ================================================================================================
-- dim.dim_fin_account_subject_f  账本科目维度
-- 粒度：1行=1个账本科目
-- 分区：无分区
-- 调度：每日，ODS 全部完成后；维表之间按上游顺序
-- 上游：ods_fin_account_book_subject_df
-- 业务规则 / 修正：
--   · 原来混在账户流水明细里的 18 个科目属性移到本维表（流水只留 subject_code），不再每条流水重复存
-- ================================================================================================
INSERT OVERWRITE TABLE dim.dim_fin_account_subject_f                              -- 整表覆盖写入
SELECT
    CAST(subject_code AS STRING)                                 AS subject_code,  -- 账本科目编码
    subject_name,                                                                 -- 科目名称
    CAST(type AS INT)                                            AS subject_type,  -- 科目类型
    unit,                                                                         -- 单位
    CAST(can_withdraw AS INT)                                    AS can_withdraw,  -- 是否可提现
    CAST(can_invoice AS INT)                                     AS can_invoice,  -- 是否可开发票
    CAST(can_integral AS INT)                                    AS can_integral,  -- 是否可计算积分
    CAST(is_default AS INT)                                      AS is_default,   -- 是否默认创建
    CAST(priority AS INT)                                        AS priority,     -- 优先级（越大越优先）
    CAST(repeatable AS INT)                                      AS repeatable,   -- 是否可多条记录
    CAST(refund_expires AS BIGINT)                               AS refund_expire_hour_qty,  -- 退款期限（小时）
    CAST(refund_limit AS DECIMAL(18,2)) / 100                    AS refund_limit_amt,  -- 退款上限（元）
    CAST(remaining_limit AS DECIMAL(18,2)) / 100                 AS remaining_limit_amt,  -- 余额上限（元）
    CAST(third_party AS INT)                                     AS third_party_flag,  -- 是否第三方支付
    CAST(trade_type AS INT)                                      AS trade_type,   -- 交易类型
    ext                                                          AS ext_rule,     -- 扩展规则
    remark,                                                                       -- 备注
    FROM_UNIXTIME(add_time)                                      AS add_time,     -- 创建时间
    FROM_UNIXTIME(update_time)                                   AS update_time,  -- 更新时间
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time           -- ETL 加载时间
FROM ods.ods_fin_account_book_subject_df
WHERE travel_date = '${bizdate}'                                                  -- 只取当日分区
