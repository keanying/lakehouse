-- ================================================================================================
-- dwd.dwd_fin_trade_journal_di  账户交易流水
-- 粒度：1行=1笔账户流水
-- 分区：travel_date（YYYYMMDD）
-- 调度：每日，依赖上游 ODS 当日分区与相关维表
-- 上游：ods_fin_trade_journal_di、ods_fin_account_book_subject_df
-- 业务规则 / 修正：
--   · 收支方向带符号：daction=0 收入为正，1 支出为负（旧财务平衡脚本 IF(daction=0, dmoney, 0) 规则）；金额分 → 元
-- ================================================================================================
INSERT OVERWRITE TABLE dwd.dwd_fin_trade_journal_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
    CAST(account_id AS BIGINT)                                   AS account_id,   -- 账户ID
    CAST(subject_code AS STRING)                                 AS subject_code,  -- 账本科目编码
    rectime                                                      AS trade_time,   -- 交易时间
    CAST(id AS BIGINT)                                           AS journal_id,   -- 流水ID
    CAST(IF(daction = 0, dmoney, -dmoney) AS DECIMAL(18,2)) / 100 AS trade_amt,   -- 交易金额
    CAST(lmoney AS DECIMAL(18,2)) / 100                          AS balance_amt,  -- 余额金额
    id,                                                                           -- 自增ID
    customer_id,                                                                  -- 客户ID
    trade_account_id,                                                             -- 交易目标账户
    CAST(fid AS BIGINT)                                          AS member_id,    -- 会员ID
    CAST(aid AS BIGINT)                                          AS supplier_id,  -- 供应商ID（租户ID）
    dmoney,                                                                       -- 本次记录金额
    lmoney,                                                                       -- 本次结束后剩余金额
    CAST(frozen_money AS DECIMAL(14,0))                          AS frozen_amt,   -- 本次记录冻结金额
    CAST(frozen_remain_money AS DECIMAL(14,0))                   AS frozen_remain_amt,  -- 冻结余额
    CAST(trade_limit_money AS BIGINT)                            AS trade_limit_amt,  -- 交易限定金额
    trade_limit_type,                                                             -- 交易限定金额类型
    trade_limit_total,                                                            -- 累计交易限定金额
    orderid                                                      AS order_no,     -- 订单号
    trade_no,                                                                     -- 外部交易流水
    account_book_id,                                                              -- 当前账户账本ID
    trade_subject_code,                                                           -- 交易对方账本科目编码
    subject_type,                                                                 -- 账本科目类型
    template_code,                                                                -- 专项模板编码
    template_item_code,                                                           -- 模板费用项编码
    function_code,                                                                -- 系统功能编码
    settle_mark,                                                                  -- 所属账期
    daction,                                                                      -- 0增加 1减少
    rectime,                                                                      -- 插入时间
    recmonth,                                                                     -- 交易月份
    dtype,                                                                        -- 0下单 1取消 3账户资金变化[充值/扣款] 4供应商…
    ptype,                                                                        -- 金额类型 0帐号资金 1支付宝 2供应商处可用资金
    account_type,                                                                 -- 资金流向类型
    reversal_trade_id,                                                            -- 被冲正交易流水ID
    last_trade_id,                                                                -- 上一条交易流水ID
    channel,                                                                      -- 交易请求来源
    account_adjust,                                                               -- 调账标识
    CAST(opid AS BIGINT)                                         AS operator_id,  -- 操作人员ID
    memo,                                                                         -- 备注
    CAST(status AS BIGINT)                                       AS order_status,  -- 流水状态 1=正常
    sequence,                                                                     -- 交易序列（确保同rectime下的顺序）
    total_trade,                                                                  -- 总金额交易
    available_trade,                                                              -- 可用金额交易
    CAST(available_money AS BIGINT)                              AS available_amt,  -- 可用交易金额
    CAST(available_remain_money AS BIGINT)                       AS available_remain_amt,  -- 可用金额余额
    available_trade_type,                                                         -- 可用金额交易类型
    frozen_trade,                                                                 -- 冻结金额交易
    frozen_trade_type,                                                            -- 冻结金额交易类型
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time           -- ETL 加载时间
FROM ods.ods_fin_trade_journal_di
WHERE travel_date = '${bizdate}'                                                  -- 只取当日分区
