-- dim.dim_opr_risk_rule_df  风控规则维度
-- 粒度：1行=1条规则
-- 来源：ods_opr_risk_rule_df
-- 生成方式：Spark SQL / Hive；字段 15 个：直接翻译 15 · 规则翻译 0 · 待确认 0

INSERT OVERWRITE TABLE dim.dim_opr_risk_rule_df PARTITION (travel_date = '${bizdate}')
SELECT
  a.id                AS risk_rule_id,
  a.rule_no           AS rule_no,
  a.rule_name         AS rule_name,
  a.rule_type         AS rule_type,
  a.scope             AS scope_type,
  a.dimension         AS dimension_type,
  a.threshold         AS threshold_desc,
  a.time_window       AS time_window_second_qty,
  a.action            AS action_type,
  a.rule_status       AS rule_status,
  a.created_by_type   AS created_by_type,
  a.tenant_id         AS tenant_id,
  a.create_time       AS create_time,
  a.update_time       AS update_time,
  CURRENT_TIMESTAMP() AS etl_time
FROM ods.ods_opr_risk_rule_df a
WHERE a.travel_date = '${bizdate}';
