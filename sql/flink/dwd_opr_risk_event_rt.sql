-- dwd.dwd_opr_risk_event_rt  实时风控事件
-- 粒度：1行=1个风控事件
-- 来源：ods_opr_risk_event_rt
-- 生成方式：Flink SQL（CDC 源表 → StarRocks 主键模型表；维表 Lookup Join）；字段 16 个：直接翻译 15 · 规则翻译 1 · 待确认 0
-- 源表 ods.*_rt 为 Flink CDC 表（含 proc_time AS PROCTIME()），目标表在 StarRocks catalog 中

INSERT INTO dwd.dwd_opr_risk_event_rt                        -- 写入 StarRocks 目标表
SELECT
  DATE_FORMAT(a.create_time, 'yyyyMMdd') AS travel_date,     -- 数据日期
  a.id                                   AS risk_event_id,   -- 风控事件ID（源表主键 id）
  a.event_no                             AS event_no,        -- 事件编号
  a.event_type                           AS event_type,      -- 类型
  a.subject_id                           AS subject_id,      -- 主体ID（用户/商户）
  a.dimension_values                     AS dimension_value_desc,  -- 触发维度值集合
  a.rule_id                              AS rule_id,         -- 关联规则ID
  a.action                               AS action_type,     -- 执行动作
  a.audit_log_id                         AS audit_log_id,    -- 关联审计日志ID
  a.tenant_id                            AS tenant_id,       -- 租户ID
  a.create_time                          AS create_time,     -- 创建时间
  a.update_time                          AS update_time,     -- 更新时间
  j1.rule_type                           AS rule_type,       -- 规则类型
  j2.dimension_type                      AS dimension_type,  -- 规则维度
  a.create_time                          AS event_time,      -- 事件发生时间
  1                                      AS event_qty        -- 事件数
FROM ods.ods_opr_risk_event_rt a                             -- 主表「风控事件 binlog 流」
LEFT JOIN dim.dim_opr_risk_rule_df FOR SYSTEM_TIME AS OF a.proc_time AS j1  -- 关联「风控规则维度」，取 规则类型
  ON j1.risk_rule_id = a.rule_id                             -- 按 rule_id→risk_rule_id 关联
LEFT JOIN dim.dim_opr_risk_rule_df FOR SYSTEM_TIME AS OF a.proc_time AS j2  -- 关联「风控规则维度」，取 规则维度
  ON j2.tenant_id = a.tenant_id;                             -- 按 tenant_id 关联
