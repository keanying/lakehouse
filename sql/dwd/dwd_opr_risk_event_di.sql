-- dwd.dwd_opr_risk_event_di  风控事件明细
-- 粒度：1行=1个风控事件
-- 来源：ods_opr_risk_event_di
-- 生成方式：Spark SQL / Hive；字段 17 个：直接翻译 17 · 规则翻译 0 · 待确认 0
-- ODS 增量按主键取最新一条（ROW_NUMBER），剔除删除记录

INSERT OVERWRITE TABLE dwd.dwd_opr_risk_event_di PARTITION (travel_date = '${bizdate}')
SELECT
  a.id                AS risk_event_id,
  a.event_no          AS event_no,
  a.event_type        AS event_type,
  a.subject_id        AS subject_id,
  a.dimension_values  AS dimension_value_desc,
  a.rule_id           AS rule_id,
  a.action            AS action_type,
  a.detail            AS detail_desc,
  a.audit_log_id      AS audit_log_id,
  a.tenant_id         AS tenant_id,
  a.create_time       AS create_time,
  a.update_time       AS update_time,
  j1.rule_type        AS rule_type,
  j2.dimension_type   AS dimension_type,
  a.create_time       AS event_time,
  1                   AS event_qty,
  CURRENT_TIMESTAMP() AS etl_time
FROM (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY id ORDER BY binlog_time DESC) AS rn
  FROM ods.ods_opr_risk_event_di
  WHERE travel_date = '${bizdate}'
) a
LEFT JOIN dim.dim_opr_risk_rule_df j1
  ON j1.risk_rule_id = a.rule_id
 AND j1.travel_date = '${bizdate}'
LEFT JOIN dim.dim_opr_risk_rule_df j2
  ON j2.tenant_id = a.tenant_id
 AND j2.travel_date = '${bizdate}'
WHERE a.rn = 1
  AND a.binlog_op_type <> 'DELETE';
