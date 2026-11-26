-- dwd.dwd_fin_withdraw_di  提现明细
-- 粒度：1行=1个提现单（withdraw_no）
-- 来源：ods_fin_withdraw_order_di
-- 生成方式：Spark SQL / Hive；字段 18 个：直接翻译 17 · 规则翻译 1 · 待确认 0
-- 主表增量先去重再关联；每个 WITH 逻辑块只取用到的列并先过滤分区；小维表广播关联

WITH
withdraw_order_rn AS (                                                            -- 「提现单」当日增量，同一主键按 binlog 时间倒序编号
  SELECT account_no, approval_no, bank_card_id, binlog_time, create_time, fail_reason, id, subject_id,
         tenant_id, transaction_no, update_time, withdraw_amount, withdraw_no, withdraw_status,
         binlog_op_type,
         ROW_NUMBER() OVER (PARTITION BY id ORDER BY binlog_time DESC) AS rn      -- 同一主键多次变更，按 binlog 时间倒序编号
  FROM ods.ods_fin_withdraw_order_di
  WHERE travel_date = '${bizdate}'                                                -- 只取当日分区
),
withdraw_order_latest AS (                                                        -- 「提现单」每个主键只保留最新一条，剔除已删除记录
  SELECT account_no, approval_no, bank_card_id, binlog_time, create_time, fail_reason, id, subject_id,
         tenant_id, transaction_no, update_time, withdraw_amount, withdraw_no, withdraw_status
  FROM withdraw_order_rn
  WHERE rn = 1
    AND binlog_op_type <> 'DELETE'                                                -- 剔除源库已删除的记录
),
account_dim AS (                                                                  -- 「账户维度」当日数据，只取用到的列
  SELECT account_no, account_type
  FROM dim.dim_fin_account_df
  WHERE travel_date = '${bizdate}'                                                -- 只取当日分区
),
bank_card_dim AS (                                                                -- 「银行卡维度（脱敏）」当日数据，只取用到的列
  SELECT bank_card_id, bank_name
  FROM dim.dim_fin_bank_card_df
  WHERE travel_date = '${bizdate}'                                                -- 只取当日分区
)
INSERT OVERWRITE TABLE dwd.dwd_fin_withdraw_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT  /*+ BROADCAST(account_dim, bank_card_dim) */
  withdraw_order_latest.id                                     AS withdraw_id,    -- 提现单ID（源表主键 id）
  withdraw_order_latest.withdraw_no                            AS withdraw_no,    -- 提现单号
  withdraw_order_latest.account_no                             AS account_no,     -- 提现账户编号
  withdraw_order_latest.subject_id                             AS subject_id,     -- 提现主体ID（商户/分销商）
  ROUND(withdraw_order_latest.withdraw_amount / 100, 2)        AS withdraw_amt,   -- 提现金额（元）
  withdraw_order_latest.bank_card_id                           AS bank_card_id,   -- 提现银行卡ID
  withdraw_order_latest.withdraw_status                        AS withdraw_status,  -- 状态
  withdraw_order_latest.approval_no                            AS approval_no,    -- 审批实例号
  withdraw_order_latest.transaction_no                         AS transaction_no,  -- 第三方打款流水号
  withdraw_order_latest.fail_reason                            AS fail_reason_desc,  -- 失败原因
  withdraw_order_latest.tenant_id                              AS tenant_id,      -- 租户ID（分库维度）
  withdraw_order_latest.create_time                            AS create_time,    -- 创建时间
  withdraw_order_latest.update_time                            AS update_time,    -- 更新时间
  account_dim.account_type                                     AS account_type,   -- 账户类型
  bank_card_dim.bank_name                                      AS bank_name,      -- 提现银行
  withdraw_order_latest.create_time                            AS apply_time,     -- 提现申请时间
  CASE WHEN withdraw_order_latest.withdraw_status = 'COMPLETED' THEN withdraw_order_latest.binlog_time END AS finish_time,  -- 提现完成时间
  CURRENT_TIMESTAMP()                                          AS etl_time        -- ETL 加载时间
FROM withdraw_order_latest
LEFT JOIN account_dim                                                             -- 关联「账户维度」，取 账户类型
  ON account_dim.account_no = withdraw_order_latest.account_no                    -- 按 account_no 关联
LEFT JOIN bank_card_dim                                                           -- 关联「银行卡维度（脱敏）」，取 提现银行
  ON bank_card_dim.bank_card_id = withdraw_order_latest.bank_card_id;             -- 按 bank_card_id 关联
