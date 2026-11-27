-- dwd.dwd_opr_account_ban_di  账号封禁明细
-- 粒度：1行=1条封禁
-- 来源：ods_opr_account_ban_di
-- 生成方式：Spark SQL / Hive；字段 19 个：直接翻译 18 · 规则翻译 1 · 待确认 0
-- 主表增量先去重再关联；每个 WITH 逻辑块只取用到的列并先过滤分区

WITH
account_ban_rn AS (                                                               -- 「账号封禁」当日增量，同一主键按 binlog 时间倒序编号
  SELECT ban_no, ban_source, ban_status, ban_type, banned_actions, create_time, expires_at, id, reason,
         revoked_at, revoked_by, rule_id, subject_id, tenant_id, update_time, binlog_op_type,
         ROW_NUMBER() OVER (PARTITION BY id ORDER BY binlog_time DESC) AS rn      -- 去重序号（1 = 最新）
  FROM ods.ods_opr_account_ban_di
  WHERE travel_date = '${bizdate}'                                                -- 只取当日分区
),
account_ban_latest AS (                                                           -- 「账号封禁」每个主键只保留最新一条，剔除已删除记录
  SELECT ban_no, ban_source, ban_status, ban_type, banned_actions, create_time, expires_at, id, reason,
         revoked_at, revoked_by, rule_id, subject_id, tenant_id, update_time
  FROM account_ban_rn
  WHERE rn = 1
    AND binlog_op_type <> 'DELETE'                                                -- 剔除源库已删除的记录
)
INSERT OVERWRITE TABLE dwd.dwd_opr_account_ban_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  account_ban_latest.id                                        AS ban_id,         -- 账号封禁ID（源表主键 id）
  account_ban_latest.ban_no                                    AS ban_no,         -- 封禁编号
  account_ban_latest.subject_id                                AS subject_id,     -- 被封禁主体（用户/商户）
  account_ban_latest.ban_type                                  AS ban_type,       -- 封禁类型
  account_ban_latest.banned_actions                            AS banned_action_list_desc,  -- 封禁动作组合
  account_ban_latest.reason                                    AS reason_desc,    -- 封禁原因
  account_ban_latest.ban_source                                AS ban_source_type,  -- 来源
  account_ban_latest.rule_id                                   AS rule_id,        -- 关联规则ID（规则自动触发时）
  account_ban_latest.expires_at                                AS expire_time,    -- 过期时间
  account_ban_latest.ban_status                                AS ban_status,     -- 状态
  account_ban_latest.revoked_by                                AS revoke_operator_name,  -- 解封人
  account_ban_latest.revoked_at                                AS revoke_time,    -- 解封时间
  account_ban_latest.tenant_id                                 AS tenant_id,      -- 租户ID
  account_ban_latest.create_time                               AS create_time,    -- 创建时间
  account_ban_latest.update_time                               AS update_time,    -- 更新时间
  account_ban_latest.create_time                               AS ban_time,       -- 封禁时间
  (UNIX_TIMESTAMP(COALESCE(account_ban_latest.revoked_at, account_ban_latest.expires_at))  -- 封禁时长
      - UNIX_TIMESTAMP(account_ban_latest.create_time)) / 3600 AS ban_hour_qty,   -- 封禁时长
  1                                                            AS ban_qty,        -- 封禁次数
  CURRENT_TIMESTAMP()                                          AS etl_time        -- ETL 加载时间
FROM account_ban_latest;
