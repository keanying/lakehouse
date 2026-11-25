-- dim.dim_fin_account_df  账户维度
-- 粒度：1行=1个账户
-- 来源：ods_fin_account_df
-- 生成方式：Spark SQL / Hive；字段 9 个：直接翻译 9 · 规则翻译 0 · 待确认 0

INSERT OVERWRITE TABLE dim.dim_fin_account_df PARTITION (travel_date = '${bizdate}')
SELECT
  a.id                AS account_id,
  a.account_no        AS account_no,
  a.subject_id        AS subject_id,
  a.account_kind      AS account_type,
  a.tenant_id         AS tenant_id,
  a.create_time       AS create_time,
  a.update_time       AS update_time,
  j1.tenant_name      AS subject_name,
  CURRENT_TIMESTAMP() AS etl_time
FROM ods.ods_fin_account_df a
LEFT JOIN dim.dim_sup_tenant_zip j1
  ON j1.tenant_id = a.tenant_id
 AND j1.travel_date = '${bizdate}' AND j1.end_date = '9999-12-31'
WHERE a.travel_date = '${bizdate}';
