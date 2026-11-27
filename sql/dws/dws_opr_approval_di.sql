-- dws.dws_opr_approval_di  审批日汇总
-- 粒度：travel_date × tenant_id × flow_code
-- 来源：dwd_opr_approval_di
-- 生成方式：Spark SQL / Hive；字段 7 个：直接翻译 2 · 规则翻译 5 · 待确认 0
-- 来源先按粒度键预聚合

WITH
src_approval AS (                                                                 -- 来源「审批实例明细」按粒度键预聚合
  SELECT
    tenant_id AS tenant_id,                                                       -- 租户ID
    flow_code AS flow_code,                                                       -- 审批流编码
    COUNT(instance_no) AS approval_qty,                                           -- 审批发起数
    COUNT(CASE WHEN instance_status = 'APPROVED' THEN 1 END) AS approval_pass_qty,  -- 审批通过数
    COUNT(CASE WHEN instance_status = 'REJECTED' THEN 1 END) AS approval_reject_qty,  -- 审批拒绝数
    SUM(CASE WHEN finish_time IS NOT NULL THEN approval_minute_qty END) AS approval_minute_qty,  -- 审批总耗时｜口径：已结束审批的耗时合计（求平均耗时用）
    COUNT(CASE WHEN timeout_type = 1 THEN instance_no END) AS approval_timeout_qty  -- 审批超时数｜口径：完成时间晚于超时时间，或进行中已超时
  FROM dwd.dwd_opr_approval_di s                                                  -- 来源表「审批实例明细」
  WHERE s.travel_date = '${bizdate}'                                              -- 只取当日分区
  GROUP BY tenant_id, flow_code                                                   -- 按粒度键汇总
)
INSERT OVERWRITE TABLE dws.dws_opr_approval_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  u.tenant_id,                                                                    -- 租户ID
  u.flow_code,                                                                    -- 审批流编码
  u.approval_qty,                                                                 -- 审批发起数
  u.approval_pass_qty,                                                            -- 审批通过数
  u.approval_reject_qty,                                                          -- 审批拒绝数
  u.approval_minute_qty,                                                          -- 审批总耗时
  u.approval_timeout_qty,                                                         -- 审批超时数
  CURRENT_TIMESTAMP() AS etl_time                                                 -- ETL 加载时间
FROM src_approval u;
