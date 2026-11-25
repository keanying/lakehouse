-- dwd.dwd_fin_withdraw_di  提现明细
-- 粒度：1行=1个提现单（withdraw_no）
-- 来源：ods_fin_withdraw_order_di
-- 生成方式：Spark SQL / Hive；字段 18 个：直接翻译 17 · 规则翻译 1 · 待确认 0
-- ODS 增量按主键取最新一条（ROW_NUMBER），剔除删除记录

INSERT OVERWRITE TABLE dwd.dwd_fin_withdraw_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  a.id                                                         AS withdraw_id,    -- 提现单ID（源表主键 id）
  a.withdraw_no                                                AS withdraw_no,    -- 提现单号
  a.account_no                                                 AS account_no,     -- 提现账户编号
  a.subject_id                                                 AS subject_id,     -- 提现主体ID（商户/分销商）
  ROUND(a.withdraw_amount / 100, 2)                            AS withdraw_amt,   -- 提现金额（元）
  a.bank_card_id                                               AS bank_card_id,   -- 提现银行卡ID
  a.withdraw_status                                            AS withdraw_status,  -- 状态
  a.approval_no                                                AS approval_no,    -- 审批实例号
  a.transaction_no                                             AS transaction_no,  -- 第三方打款流水号
  a.fail_reason                                                AS fail_reason_desc,  -- 失败原因
  a.tenant_id                                                  AS tenant_id,      -- 租户ID（分库维度）
  a.create_time                                                AS create_time,    -- 创建时间
  a.update_time                                                AS update_time,    -- 更新时间
  j1.account_type                                              AS account_type,   -- 账户类型
  j2.bank_name                                                 AS bank_name,      -- 提现银行
  a.create_time                                                AS apply_time,     -- 提现申请时间
  CASE WHEN a.withdraw_status = 'COMPLETED' THEN a.binlog_time END AS finish_time,  -- 提现完成时间
  CURRENT_TIMESTAMP()                                          AS etl_time        -- ETL 加载时间
FROM (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY id ORDER BY binlog_time DESC) AS rn   -- 同一主键多次变更，按 binlog 时间倒序编号
  FROM ods.ods_fin_withdraw_order_di
  WHERE travel_date = '${bizdate}'                                                -- 只取当日分区
) a                                                                               -- 主表当日增量，按主键取最新一条
LEFT JOIN dim.dim_fin_account_df j1                                               -- 关联「账户维度」，取 账户类型
  ON j1.account_no = a.account_no                                                 -- 按 account_no 关联
 AND j1.travel_date = '${bizdate}'                                                -- 只取当日分区
LEFT JOIN dim.dim_fin_bank_card_df j2                                             -- 关联「银行卡维度（脱敏）」，取 提现银行
  ON j2.bank_card_id = a.bank_card_id                                             -- 按 bank_card_id 关联
 AND j2.travel_date = '${bizdate}'                                                -- 只取当日分区
WHERE a.rn = 1                                                                    -- 只保留每个主键的最新一条
  AND a.binlog_op_type <> 'DELETE';                                               -- 剔除源库已删除的记录
