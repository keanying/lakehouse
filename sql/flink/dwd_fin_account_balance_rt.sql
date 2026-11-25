-- dwd.dwd_fin_account_balance_rt  实时账户余额
-- 粒度：1行=1个账户×1日
-- 来源：ods_fin_account_rt
-- 生成方式：Flink SQL（CDC 源表 → StarRocks 主键模型表；维表 Lookup Join）；字段 12 个：直接翻译 10 · 规则翻译 2 · 待确认 0
-- 源表 ods.*_rt 为 Flink CDC 表（含 proc_time AS PROCTIME()），目标表在 StarRocks catalog 中

INSERT INTO dwd.dwd_fin_account_balance_rt
SELECT
  DATE_FORMAT(a.binlog_time, 'yyyyMMdd')                AS travel_date,
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
  CURRENT_TIMESTAMP                                     AS event_time
FROM ods.ods_fin_account_rt a;
