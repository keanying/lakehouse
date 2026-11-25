-- dwd.dwd_opr_audit_log_di  审计操作明细
-- 粒度：1行=1条操作日志
-- 来源：ods_opr_audit_log_di
-- 生成方式：Spark SQL / Hive；字段 17 个：直接翻译 15 · 规则翻译 1 · 待确认 1
-- 流水/状态变更类：保留每条变更记录
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT OVERWRITE TABLE dwd.dwd_opr_audit_log_di PARTITION (travel_date = '${bizdate}')
SELECT
  a.id                AS audit_log_id,
  a.log_no            AS log_no,
  a.operator_id       AS operator_id,
  a.operator_type     AS operator_type,
  a.action            AS action_type,
  a.resource_type     AS resource_type,
  a.resource_id       AS resource_id,
  a.ip_address        AS client_ip_code,
  a.tenant_id         AS tenant_id,
  a.log_scope         AS log_scope_type,
  a.create_time       AS create_time,
  a.update_time       AS update_time,
  a.create_time       AS action_time,
  HOUR(a.create_time) AS action_hour_no,
  NULL                AS night_action_type,  -- 待确认：action_hour_no 判定
  1                   AS action_qty,
  CURRENT_TIMESTAMP() AS etl_time
FROM ods.ods_opr_audit_log_di a
WHERE a.travel_date = '${bizdate}';
