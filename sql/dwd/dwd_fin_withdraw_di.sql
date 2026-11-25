-- dwd.dwd_fin_withdraw_di  提现明细
-- 粒度：1行=1个提现单（withdraw_no）
-- 来源：ods_fin_withdraw_order_di
-- 生成方式：Spark SQL / Hive；字段 18 个：直接翻译 17 · 规则翻译 1 · 待确认 0
-- ODS 增量按主键取最新一条（ROW_NUMBER），剔除删除记录

INSERT OVERWRITE TABLE dwd.dwd_fin_withdraw_di PARTITION (travel_date = '${bizdate}')
SELECT
  a.id                                                         AS withdraw_id,
  a.withdraw_no                                                AS withdraw_no,
  a.account_no                                                 AS account_no,
  a.subject_id                                                 AS subject_id,
  ROUND(a.withdraw_amount / 100, 2)                            AS withdraw_amt,
  a.bank_card_id                                               AS bank_card_id,
  a.withdraw_status                                            AS withdraw_status,
  a.approval_no                                                AS approval_no,
  a.transaction_no                                             AS transaction_no,
  a.fail_reason                                                AS fail_reason_desc,
  a.tenant_id                                                  AS tenant_id,
  a.create_time                                                AS create_time,
  a.update_time                                                AS update_time,
  j1.account_type                                              AS account_type,
  j2.bank_name                                                 AS bank_name,
  a.create_time                                                AS apply_time,
  CASE WHEN a.withdraw_status = 'COMPLETED' THEN a.binlog_time END AS finish_time,
  CURRENT_TIMESTAMP()                                          AS etl_time
FROM (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY id ORDER BY binlog_time DESC) AS rn
  FROM ods.ods_fin_withdraw_order_di
  WHERE travel_date = '${bizdate}'
) a
LEFT JOIN dim.dim_fin_account_df j1
  ON j1.account_no = a.account_no
 AND j1.travel_date = '${bizdate}'
LEFT JOIN dim.dim_fin_bank_card_df j2
  ON j2.bank_card_id = a.bank_card_id
 AND j2.travel_date = '${bizdate}'
WHERE a.rn = 1
  AND a.binlog_op_type <> 'DELETE';
