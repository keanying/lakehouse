-- dim.dim_fin_bank_card_df  银行卡维度（脱敏）
-- 粒度：1行=1张卡
-- 来源：ods_fin_bank_card_df
-- 生成方式：Spark SQL / Hive；字段 14 个：直接翻译 14 · 规则翻译 0 · 待确认 0

INSERT OVERWRITE TABLE dim.dim_fin_bank_card_df PARTITION (travel_date = '${bizdate}')
SELECT
  a.id                AS bank_card_id,
  a.card_no           AS card_no,
  a.subject_id        AS subject_id,
  a.bank_name         AS bank_name,
  a.bank_code         AS bank_code,
  a.card_holder       AS card_holder_name,
  a.card_type         AS card_type,
  a.branch_name       AS branch_name,
  a.card_status       AS card_status,
  a.tenant_id         AS tenant_id,
  a.create_time       AS create_time,
  a.update_time       AS update_time,
  a.card_tail_no      AS card_tail_no,
  CURRENT_TIMESTAMP() AS etl_time
FROM ods.ods_fin_bank_card_df a
WHERE a.travel_date = '${bizdate}';
