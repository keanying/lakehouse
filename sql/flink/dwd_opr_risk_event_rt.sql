-- dwd.dwd_opr_risk_event_rt  实时风控事件
-- 粒度：1行=1个风控事件
-- 来源：ods_opr_risk_event_rt
-- 生成方式：Flink SQL（CDC 源表 → StarRocks 主键模型表；维表 Lookup Join）；字段 16 个：直接翻译 15 · 规则翻译 1 · 待确认 0
-- 源表 ods.*_rt 为 Flink CDC 表（含 proc_time AS PROCTIME()），目标表在 StarRocks catalog 中

INSERT INTO dwd.dwd_opr_risk_event_rt
SELECT
  DATE_FORMAT(a.create_time, 'yyyyMMdd') AS travel_date,
  a.id                                   AS risk_event_id,
  a.event_no                             AS event_no,
  a.event_type                           AS event_type,
  a.subject_id                           AS subject_id,
  a.dimension_values                     AS dimension_value_desc,
  a.rule_id                              AS rule_id,
  a.action                               AS action_type,
  a.audit_log_id                         AS audit_log_id,
  a.tenant_id                            AS tenant_id,
  a.create_time                          AS create_time,
  a.update_time                          AS update_time,
  j1.rule_type                           AS rule_type,
  j2.dimension_type                      AS dimension_type,
  a.create_time                          AS event_time,
  1                                      AS event_qty
FROM ods.ods_opr_risk_event_rt a
LEFT JOIN dim.dim_opr_risk_rule_df FOR SYSTEM_TIME AS OF a.proc_time AS j1
  ON j1.risk_rule_id = a.rule_id
LEFT JOIN dim.dim_opr_risk_rule_df FOR SYSTEM_TIME AS OF a.proc_time AS j2
  ON j2.tenant_id = a.tenant_id;
