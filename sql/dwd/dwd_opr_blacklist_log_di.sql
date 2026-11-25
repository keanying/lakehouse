-- dwd.dwd_opr_blacklist_log_di  黑名单变更明细
-- 粒度：1行=1次黑名单新增/失效/撤销
-- 来源：ods_opr_blacklist_di
-- 生成方式：Spark SQL / Hive；字段 18 个：直接翻译 17 · 规则翻译 0 · 待确认 1
-- 流水/状态变更类：保留每条变更记录
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT OVERWRITE TABLE dwd.dwd_opr_blacklist_log_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  a.id                AS blacklist_id,      -- 黑名单ID（源表主键 id）
  a.blacklist_no      AS blacklist_no,      -- 黑名单记录编号
  a.dimension         AS dimension_type,    -- 维度
  a.dimension_value   AS dimension_value_desc,  -- 维度值（身份证号/IP等）（脱敏）
  a.reason            AS reason_desc,       -- 封禁原因
  a.scope             AS scope_type,        -- 范围
  a.banned_actions    AS banned_action_list_desc,  -- 封禁动作组合
  a.expires_at        AS expire_time,       -- 过期时间（null=永久）
  a.blacklist_status  AS blacklist_status,  -- 状态
  a.created_by_type   AS created_by_type,   -- 创建方
  a.rule_id           AS rule_id,           -- 关联规则ID（规则触发时）
  a.tenant_id         AS tenant_id,         -- 租户ID
  a.create_time       AS create_time,       -- 创建时间
  a.update_time       AS update_time,       -- 更新时间
  a.blacklist_status  AS change_type,       -- 变更类型｜待确认：ods_opr_blacklist_di.blacklist_status 变化判定
  a.binlog_time       AS change_time,       -- 变更时间
  1                   AS change_qty,        -- 变更次数
  CURRENT_TIMESTAMP() AS etl_time           -- ETL 加载时间
FROM ods.ods_opr_blacklist_di a             -- 主表「黑名单」
WHERE a.travel_date = '${bizdate}';         -- 只取当日分区
