-- dws.dws_opr_complaint_di  投诉日汇总
-- 粒度：travel_date × tenant_id × complaint_type × complainant_type
-- 来源：dwd_opr_complaint_di
-- 生成方式：Spark SQL / Hive；字段 6 个：直接翻译 3 · 规则翻译 3 · 待确认 0
-- 来源先按粒度键预聚合

WITH
src_complaint AS (                                                                -- 来源「投诉工单明细」按粒度键预聚合
  SELECT
    tenant_id AS tenant_id,                                                       -- 租户ID
    complaint_type AS complaint_type,                                             -- 投诉类型
    complainant_type AS complainant_type,                                         -- 投诉方
    COUNT(complaint_no) AS complaint_qty,                                         -- 投诉数
    COUNT(CASE WHEN complaint_status IN ('RESOLVED', 'CLOSED') THEN complaint_no END) AS complaint_resolved_qty,  -- 投诉解决数｜口径：已解决或已关闭
    COUNT(CASE WHEN sla_timeout_type = 1 THEN complaint_no END) AS complaint_overdue_qty  -- 投诉超SLA数｜口径：解决时间（未解决取当前时间）晚于 SLA 截止
  FROM dwd.dwd_opr_complaint_di s                                                 -- 来源表「投诉工单明细」
  WHERE s.travel_date = '${bizdate}'                                              -- 只取当日分区
  GROUP BY tenant_id, complaint_type, complainant_type                            -- 按粒度键汇总
)
INSERT OVERWRITE TABLE dws.dws_opr_complaint_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  u.tenant_id,                                                                    -- 租户ID
  u.complaint_type,                                                               -- 投诉类型
  u.complainant_type,                                                             -- 投诉方
  u.complaint_qty,                                                                -- 投诉数
  u.complaint_resolved_qty,                                                       -- 投诉解决数
  u.complaint_overdue_qty,                                                        -- 投诉超SLA数
  CURRENT_TIMESTAMP() AS etl_time                                                 -- ETL 加载时间
FROM src_complaint u;
