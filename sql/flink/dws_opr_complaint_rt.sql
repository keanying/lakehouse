-- dws.dws_opr_complaint_rt  投诉实时处理
-- 粒度：tenant_id × complaint_type
-- 来源：dwd_opr_complaint_rt
-- 生成方式：Flink SQL（持续聚合（快照类，按主键更新） → StarRocks 主键模型表）；字段 6 个：直接翻译 3 · 规则翻译 1 · 待确认 2
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT INTO dws.dws_opr_complaint_rt
SELECT
  u.travel_date,
  u.tenant_id,
  u.complaint_type,
  SUM(u.complaint_qty) AS complaint_qty,
  SUM(u.complaint_resolved_qty) AS complaint_resolved_qty,
  SUM(u.complaint_overdue_qty) AS complaint_overdue_qty,
  CURRENT_TIMESTAMP AS update_time
FROM (
  -- 来源：dwd_opr_complaint_rt
  SELECT
    travel_date AS travel_date,
    tenant_id AS tenant_id,
    complaint_type AS complaint_type,
    COUNT(complaint_no) AS complaint_qty,
    COUNT(CASE WHEN 1 = 1 THEN 1 END) AS complaint_resolved_qty,  -- 待确认：status in ('RESOLVED','CLOSED')
    COUNT(CASE WHEN 1 = 1 THEN 1 END) AS complaint_overdue_qty  -- 待确认：解决时间>sla_deadline
  FROM dwd.dwd_opr_complaint_rt s
  GROUP BY travel_date, tenant_id, complaint_type
) u
GROUP BY u.travel_date, u.tenant_id, u.complaint_type;
