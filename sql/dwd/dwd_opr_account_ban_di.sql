-- dwd.dwd_opr_account_ban_di  账号封禁明细
-- 粒度：1行=1条封禁
-- 来源：ods_opr_account_ban_di
-- 生成方式：Spark SQL / Hive；字段 19 个：直接翻译 18 · 规则翻译 1 · 待确认 0
-- ODS 增量按主键取最新一条（ROW_NUMBER），剔除删除记录

INSERT OVERWRITE TABLE dwd.dwd_opr_account_ban_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  a.id                                               AS ban_id,                -- 账号封禁ID（源表主键 id）
  a.ban_no                                           AS ban_no,                -- 封禁编号
  a.subject_id                                       AS subject_id,            -- 被封禁主体（用户/商户）
  a.ban_type                                         AS ban_type,              -- 封禁类型
  a.banned_actions                                   AS banned_action_list_desc,  -- 封禁动作组合
  a.reason                                           AS reason_desc,           -- 封禁原因
  a.ban_source                                       AS ban_source_type,       -- 来源
  a.rule_id                                          AS rule_id,               -- 关联规则ID（规则自动触发时）
  a.expires_at                                       AS expire_time,           -- 过期时间
  a.ban_status                                       AS ban_status,            -- 状态
  a.revoked_by                                       AS revoke_operator_name,  -- 解封人
  a.revoked_at                                       AS revoke_time,           -- 解封时间
  a.tenant_id                                        AS tenant_id,             -- 租户ID
  a.create_time                                      AS create_time,           -- 创建时间
  a.update_time                                      AS update_time,           -- 更新时间
  a.create_time                                      AS ban_time,              -- 封禁时间
  a.revoked_at / NULLIF(expires_at - create_time, 0) AS ban_hour_qty,          -- 封禁时长
  1                                                  AS ban_qty,               -- 封禁次数
  CURRENT_TIMESTAMP()                                AS etl_time               -- ETL 加载时间
FROM (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY id ORDER BY binlog_time DESC) AS rn  -- 同一主键多次变更，按 binlog 时间倒序编号
  FROM ods.ods_opr_account_ban_di
  WHERE travel_date = '${bizdate}'                                             -- 只取当日分区
) a                                                                            -- 主表当日增量，按主键取最新一条
WHERE a.rn = 1                                                                 -- 只保留每个主键的最新一条
  AND a.binlog_op_type <> 'DELETE';                                            -- 剔除源库已删除的记录
