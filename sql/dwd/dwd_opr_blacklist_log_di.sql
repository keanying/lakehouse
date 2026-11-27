-- dwd.dwd_opr_blacklist_log_di  黑名单变更明细
-- 粒度：1行=1次黑名单新增/失效/撤销
-- 来源：ods_opr_blacklist_di
-- 生成方式：Spark SQL / Hive；字段 18 个：直接翻译 17 · 规则翻译 1 · 待确认 0
-- 流水/状态变更类：保留每条变更记录；每个 WITH 逻辑块只取用到的列并先过滤分区

WITH
blacklist_chg AS (                                     -- 主表「黑名单」：保留每条变更记录，只取用到的列
  SELECT banned_actions, binlog_time, blacklist_no, blacklist_status, create_time, created_by_type,
         dimension, dimension_value, expires_at, id, reason, rule_id, scope, tenant_id, update_time
  FROM ods.ods_opr_blacklist_di
  WHERE travel_date = '${bizdate}'                     -- 只取当日分区
)
INSERT OVERWRITE TABLE dwd.dwd_opr_blacklist_log_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  blacklist_chg.id               AS blacklist_id,      -- 黑名单ID（源表主键 id）
  blacklist_chg.blacklist_no     AS blacklist_no,      -- 黑名单记录编号
  blacklist_chg.dimension        AS dimension_type,    -- 维度
  blacklist_chg.dimension_value  AS dimension_value_desc,  -- 维度值（身份证号/IP等）（脱敏）
  blacklist_chg.reason           AS reason_desc,       -- 封禁原因
  blacklist_chg.scope            AS scope_type,        -- 范围
  blacklist_chg.banned_actions   AS banned_action_list_desc,  -- 封禁动作组合
  blacklist_chg.expires_at       AS expire_time,       -- 过期时间（null=永久）
  blacklist_chg.blacklist_status AS blacklist_status,  -- 状态
  blacklist_chg.created_by_type  AS created_by_type,   -- 创建方
  blacklist_chg.rule_id          AS rule_id,           -- 关联规则ID（规则触发时）
  blacklist_chg.tenant_id        AS tenant_id,         -- 租户ID
  blacklist_chg.create_time      AS create_time,       -- 创建时间
  blacklist_chg.update_time      AS update_time,       -- 更新时间
  CASE blacklist_chg.blacklist_status                  -- 变更类型｜口径：每条变更记录按变更后状态：有效 = 新增，已过期 = 到期失效，已撤销 = 撤销
      WHEN 'ACTIVE' THEN 'ADD'
      WHEN 'EXPIRED' THEN 'EXPIRE'
      WHEN 'REVOKED' THEN 'REVOKE'
  END AS change_type,                                  -- 变更类型
  blacklist_chg.binlog_time      AS change_time,       -- 变更时间
  1                              AS change_qty,        -- 变更次数
  CURRENT_TIMESTAMP()            AS etl_time           -- ETL 加载时间
FROM blacklist_chg;
