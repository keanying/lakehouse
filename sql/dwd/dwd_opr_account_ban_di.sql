-- dwd.dwd_opr_account_ban_di  账号封禁明细
-- 粒度：1行=1条封禁
-- 来源：ods_opr_account_ban_di
-- 生成方式：Spark SQL / Hive；字段 19 个：直接翻译 18 · 规则翻译 1 · 待确认 0
-- ODS 增量按主键取最新一条（ROW_NUMBER），剔除删除记录

INSERT OVERWRITE TABLE dwd.dwd_opr_account_ban_di PARTITION (travel_date = '${bizdate}')
SELECT
  a.id                                               AS ban_id,
  a.ban_no                                           AS ban_no,
  a.subject_id                                       AS subject_id,
  a.ban_type                                         AS ban_type,
  a.banned_actions                                   AS banned_action_list_desc,
  a.reason                                           AS reason_desc,
  a.ban_source                                       AS ban_source_type,
  a.rule_id                                          AS rule_id,
  a.expires_at                                       AS expire_time,
  a.ban_status                                       AS ban_status,
  a.revoked_by                                       AS revoke_operator_name,
  a.revoked_at                                       AS revoke_time,
  a.tenant_id                                        AS tenant_id,
  a.create_time                                      AS create_time,
  a.update_time                                      AS update_time,
  a.create_time                                      AS ban_time,
  a.revoked_at / NULLIF(expires_at - create_time, 0) AS ban_hour_qty,
  1                                                  AS ban_qty,
  CURRENT_TIMESTAMP()                                AS etl_time
FROM (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY id ORDER BY binlog_time DESC) AS rn
  FROM ods.ods_opr_account_ban_di
  WHERE travel_date = '${bizdate}'
) a
WHERE a.rn = 1
  AND a.binlog_op_type <> 'DELETE';
