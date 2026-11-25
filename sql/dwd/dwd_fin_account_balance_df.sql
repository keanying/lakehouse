-- dwd.dwd_fin_account_balance_df  账户余额日快照
-- 粒度：1行=1个账户×1日
-- 来源：ods_fin_account_df
-- 生成方式：Spark SQL / Hive；字段 11 个：直接翻译 10 · 规则翻译 1 · 待确认 0

INSERT OVERWRITE TABLE dwd.dwd_fin_account_balance_df PARTITION (travel_date = '${bizdate}')
SELECT
  a.id                                                  AS account_id,
  a.account_no                                          AS account_no,
  a.subject_id                                          AS subject_id,
  a.account_kind                                        AS account_type,
  ROUND(a.available_balance / 100, 2)                   AS available_balance_amt,
  ROUND(a.frozen_balance / 100, 2)                      AS frozen_balance_amt,
  a.tenant_id                                           AS tenant_id,
  a.create_time                                         AS create_time,
  a.update_time                                         AS update_time,
  ROUND(a.available_balance + a.frozen_balance /100, 2) AS total_balance_amt,
  CURRENT_TIMESTAMP()                                   AS etl_time
FROM ods.ods_fin_account_df a
WHERE a.travel_date = '${bizdate}';
