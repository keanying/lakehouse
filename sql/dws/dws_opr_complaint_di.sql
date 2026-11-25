-- dws.dws_opr_complaint_di  投诉日汇总
-- 粒度：travel_date × tenant_id × complaint_type × complainant_type
-- 来源：dwd_opr_complaint_di
-- 生成方式：Spark SQL / Hive；字段 6 个：直接翻译 3 · 规则翻译 1 · 待确认 2
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT OVERWRITE TABLE dws.dws_opr_complaint_di PARTITION (travel_date = '${bizdate}')
SELECT
  u.tenant_id,
  u.complaint_type,
  u.complainant_type,
  SUM(u.complaint_qty) AS complaint_qty,
  SUM(u.complaint_resolved_qty) AS complaint_resolved_qty,
  SUM(u.complaint_overdue_qty) AS complaint_overdue_qty,
  CURRENT_TIMESTAMP() AS etl_time
FROM (
  -- 来源：dwd_opr_complaint_di
  SELECT
    tenant_id AS tenant_id,
    complaint_type AS complaint_type,
    complainant_type AS complainant_type,
    COUNT(complaint_no) AS complaint_qty,
    COUNT(CASE WHEN 1 = 1 THEN 1 END) AS complaint_resolved_qty,  -- 待确认：status in ('RESOLVED','CLOSED')
    COUNT(CASE WHEN 1 = 1 THEN 1 END) AS complaint_overdue_qty  -- 待确认：解决时间>sla_deadline
  FROM dwd.dwd_opr_complaint_di s
  WHERE s.travel_date = '${bizdate}'
  GROUP BY tenant_id, complaint_type, complainant_type
) u
GROUP BY u.tenant_id, u.complaint_type, u.complainant_type;
