-- dws.dws_opr_audit_action_di  操作审计日汇总
-- 粒度：travel_date × tenant_id × operator_type × operator_id × action_type
-- 来源：dwd_opr_audit_log_di
-- 生成方式：Spark SQL / Hive；字段 6 个：直接翻译 4 · 规则翻译 2 · 待确认 0

INSERT OVERWRITE TABLE dws.dws_opr_audit_action_di PARTITION (travel_date = '${bizdate}')
SELECT
  u.tenant_id,
  u.operator_type,
  u.operator_id,
  u.action_type,
  SUM(u.audit_action_qty) AS audit_action_qty,
  SUM(u.night_action_qty) AS night_action_qty,
  CURRENT_TIMESTAMP() AS etl_time
FROM (
  -- 来源：dwd_opr_audit_log_di
  SELECT
    tenant_id AS tenant_id,
    operator_type AS operator_type,
    operator_id AS operator_id,
    action_type AS action_type,
    COUNT(log_no) AS audit_action_qty,
    COUNT(CASE WHEN hour(create_time) between 0 and 5 THEN 1 END) AS night_action_qty
  FROM dwd.dwd_opr_audit_log_di s
  WHERE s.travel_date = '${bizdate}'
  GROUP BY tenant_id, operator_type, operator_id, action_type
) u
GROUP BY u.tenant_id, u.operator_type, u.operator_id, u.action_type;
