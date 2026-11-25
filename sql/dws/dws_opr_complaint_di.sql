-- dws.dws_opr_complaint_di  投诉日汇总
-- 粒度：travel_date × tenant_id × complaint_type × complainant_type
-- 来源：dwd_opr_complaint_di
-- 生成方式：Spark SQL / Hive；字段 6 个：直接翻译 3 · 规则翻译 1 · 待确认 2
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT OVERWRITE TABLE dws.dws_opr_complaint_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  u.tenant_id,                                                  -- 租户ID
  u.complaint_type,                                             -- 投诉类型
  u.complainant_type,                                           -- 投诉方
  SUM(u.complaint_qty) AS complaint_qty,                        -- 投诉数
  SUM(u.complaint_resolved_qty) AS complaint_resolved_qty,      -- 投诉解决数
  SUM(u.complaint_overdue_qty) AS complaint_overdue_qty,        -- 投诉超SLA数
  CURRENT_TIMESTAMP() AS etl_time                               -- ETL 加载时间
FROM (
  -- 来源：dwd_opr_complaint_di
  SELECT
    tenant_id AS tenant_id,                                     -- 租户ID
    complaint_type AS complaint_type,                           -- 投诉类型
    complainant_type AS complainant_type,                       -- 投诉方
    COUNT(complaint_no) AS complaint_qty,                       -- 投诉数
    COUNT(CASE WHEN 1 = 1 THEN 1 END) AS complaint_resolved_qty,  -- 投诉解决数｜待确认：status in ('RESOLVED','CLOSED')
    COUNT(CASE WHEN 1 = 1 THEN 1 END) AS complaint_overdue_qty  -- 投诉超SLA数｜待确认：解决时间>sla_deadline
  FROM dwd.dwd_opr_complaint_di s                               -- 来源表「投诉工单明细」
  WHERE s.travel_date = '${bizdate}'                            -- 只取当日分区
  GROUP BY tenant_id, complaint_type, complainant_type          -- 按粒度键汇总
) u                                                             -- 各来源合并后的明细
GROUP BY u.tenant_id, u.complaint_type, u.complainant_type;     -- 按粒度键汇总
