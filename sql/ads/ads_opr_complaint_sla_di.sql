-- ads.ads_opr_complaint_sla_di  投诉SLA与审批时效
-- 粒度：travel_date × tenant_id × complaint_type
-- 来源：dws_opr_complaint_di, dws_opr_approval_di
-- 生成方式：Spark SQL / Hive；字段 15 个：直接翻译 14 · 规则翻译 0 · 待确认 1
-- 多来源：每个来源表按粒度键先汇总，UNION ALL 后再合并
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT OVERWRITE TABLE ads.ads_opr_complaint_sla_di PARTITION (travel_date = '${bizdate}')
SELECT
  x.tenant_id,
  x.complaint_type,
  d1.tenant_name AS tenant_name,
  x.complaint_qty,
  x.complaint_resolved_qty,
  x.complaint_overdue_qty,
  x.complaint_sla_numerator_qty,
  x.complaint_sla_denominator_qty,
  x.approval_qty,
  x.approval_pass_numerator_qty,
  x.approval_pass_denominator_qty,
  x.approval_timeout_qty,
  x.avg_approval_minute_numerator_qty,
  x.avg_approval_minute_denominator_qty,
  x.etl_time
FROM (
SELECT
  u.tenant_id,
  u.complaint_type,
  SUM(u.complaint_qty) AS complaint_qty,
  SUM(u.complaint_resolved_qty) AS complaint_resolved_qty,
  SUM(u.complaint_overdue_qty) AS complaint_overdue_qty,
  SUM(u.complaint_sla_numerator_qty) AS complaint_sla_numerator_qty,
  SUM(u.complaint_sla_denominator_qty) AS complaint_sla_denominator_qty,
  SUM(u.approval_qty) AS approval_qty,
  SUM(u.approval_pass_numerator_qty) AS approval_pass_numerator_qty,
  SUM(u.approval_pass_denominator_qty) AS approval_pass_denominator_qty,
  SUM(u.approval_timeout_qty) AS approval_timeout_qty,
  SUM(u.avg_approval_minute_numerator_qty) AS avg_approval_minute_numerator_qty,
  SUM(u.avg_approval_minute_denominator_qty) AS avg_approval_minute_denominator_qty,
  CURRENT_TIMESTAMP() AS etl_time
FROM (
  -- 来源：dws_opr_complaint_di
  SELECT
    tenant_id AS tenant_id,
    complaint_type AS complaint_type,
    SUM(complaint_qty) AS complaint_qty,
    SUM(complaint_resolved_qty) AS complaint_resolved_qty,
    SUM(complaint_overdue_qty) AS complaint_overdue_qty,
    SUM(complaint_overdue_qty) AS complaint_sla_numerator_qty,
    SUM(complaint_qty) AS complaint_sla_denominator_qty,
    NULL AS approval_qty,
    NULL AS approval_pass_numerator_qty,
    NULL AS approval_pass_denominator_qty,
    NULL AS approval_timeout_qty,
    NULL AS avg_approval_minute_numerator_qty,
    NULL AS avg_approval_minute_denominator_qty
  FROM dws.dws_opr_complaint_di s
  WHERE s.travel_date = '${bizdate}'
  GROUP BY tenant_id, complaint_type
  UNION ALL
  -- 来源：dws_opr_approval_di
  SELECT
    tenant_id AS tenant_id,
    CAST(NULL AS STRING) AS complaint_type,
    NULL AS complaint_qty,
    NULL AS complaint_resolved_qty,
    NULL AS complaint_overdue_qty,
    NULL AS complaint_sla_numerator_qty,
    NULL AS complaint_sla_denominator_qty,
    SUM(approval_qty) AS approval_qty,
    SUM(approval_pass_qty) AS approval_pass_numerator_qty,
    SUM(approval_qty) AS approval_pass_denominator_qty,
    SUM(approval_timeout_qty) AS approval_timeout_qty,
    SUM(approval_minute_qty) AS avg_approval_minute_numerator_qty,
    SUM(approval_minute_qty) AS avg_approval_minute_denominator_qty
  FROM dws.dws_opr_approval_di s
  WHERE s.travel_date = '${bizdate}'
  GROUP BY tenant_id
) u
GROUP BY u.tenant_id, u.complaint_type
) x
LEFT JOIN dim.dim_sup_tenant_zip d1 ON d1.tenant_id = x.tenant_id AND d1.travel_date = '${bizdate}' AND d1.end_date = '9999-12-31';
