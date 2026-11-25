-- ads.ads_opr_complaint_sla_di  投诉SLA与审批时效
-- 粒度：travel_date × tenant_id × complaint_type
-- 来源：dws_opr_complaint_di, dws_opr_approval_di
-- 生成方式：Spark SQL / Hive；字段 15 个：直接翻译 14 · 规则翻译 0 · 待确认 1
-- 多来源：每个来源表按粒度键先汇总，UNION ALL 后再合并
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT OVERWRITE TABLE ads.ads_opr_complaint_sla_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  x.tenant_id,                                                  -- 租户ID
  x.complaint_type,                                             -- 投诉类型
  d1.tenant_name AS tenant_name,                                -- 租户名称
  x.complaint_qty,                                              -- 投诉数（日）
  x.complaint_resolved_qty,                                     -- 投诉解决数（日）
  x.complaint_overdue_qty,                                      -- 投诉超SLA数（日）
  x.complaint_sla_numerator_qty,                                -- 投诉SLA达成率分子（日）
  x.complaint_sla_denominator_qty,                              -- 投诉SLA达成率分母（日）
  x.approval_qty,                                               -- 审批发起数（日）
  x.approval_pass_numerator_qty,                                -- 审批通过率分子（日）
  x.approval_pass_denominator_qty,                              -- 审批通过率分母（日）
  x.approval_timeout_qty,                                       -- 审批超时数（日）
  x.avg_approval_minute_numerator_qty,                          -- 平均审批耗时分子（日）
  x.avg_approval_minute_denominator_qty,                        -- 平均审批耗时分母（日）
  x.etl_time                                                    -- ETL 加载时间
FROM (
SELECT
  u.tenant_id,                                                  -- 租户ID
  u.complaint_type,                                             -- 投诉类型
  SUM(u.complaint_qty) AS complaint_qty,                        -- 投诉数（日）
  SUM(u.complaint_resolved_qty) AS complaint_resolved_qty,      -- 投诉解决数（日）
  SUM(u.complaint_overdue_qty) AS complaint_overdue_qty,        -- 投诉超SLA数（日）
  SUM(u.complaint_sla_numerator_qty) AS complaint_sla_numerator_qty,  -- 投诉SLA达成率分子（日）
  SUM(u.complaint_sla_denominator_qty) AS complaint_sla_denominator_qty,  -- 投诉SLA达成率分母（日）
  SUM(u.approval_qty) AS approval_qty,                          -- 审批发起数（日）
  SUM(u.approval_pass_numerator_qty) AS approval_pass_numerator_qty,  -- 审批通过率分子（日）
  SUM(u.approval_pass_denominator_qty) AS approval_pass_denominator_qty,  -- 审批通过率分母（日）
  SUM(u.approval_timeout_qty) AS approval_timeout_qty,          -- 审批超时数（日）
  SUM(u.avg_approval_minute_numerator_qty) AS avg_approval_minute_numerator_qty,  -- 平均审批耗时分子（日）
  SUM(u.avg_approval_minute_denominator_qty) AS avg_approval_minute_denominator_qty,  -- 平均审批耗时分母（日）
  CURRENT_TIMESTAMP() AS etl_time                               -- ETL 加载时间
FROM (
  -- 来源：dws_opr_complaint_di
  SELECT
    tenant_id AS tenant_id,                                     -- 租户ID
    complaint_type AS complaint_type,                           -- 投诉类型
    SUM(complaint_qty) AS complaint_qty,                        -- 投诉数（日）
    SUM(complaint_resolved_qty) AS complaint_resolved_qty,      -- 投诉解决数（日）
    SUM(complaint_overdue_qty) AS complaint_overdue_qty,        -- 投诉超SLA数（日）
    SUM(complaint_overdue_qty) AS complaint_sla_numerator_qty,  -- 投诉SLA达成率分子（日）
    SUM(complaint_qty) AS complaint_sla_denominator_qty,        -- 投诉SLA达成率分母（日）
    NULL AS approval_qty,                                       -- 审批发起数（日）
    NULL AS approval_pass_numerator_qty,                        -- 审批通过率分子（日）
    NULL AS approval_pass_denominator_qty,                      -- 审批通过率分母（日）
    NULL AS approval_timeout_qty,                               -- 审批超时数（日）
    NULL AS avg_approval_minute_numerator_qty,                  -- 平均审批耗时分子（日）
    NULL AS avg_approval_minute_denominator_qty                 -- 平均审批耗时分母（日）
  FROM dws.dws_opr_complaint_di s                               -- 来源表「投诉日汇总」
  WHERE s.travel_date = '${bizdate}'                            -- 只取当日分区
  GROUP BY tenant_id, complaint_type                            -- 按粒度键汇总
  UNION ALL                                                     -- 合并各来源
  -- 来源：dws_opr_approval_di
  SELECT
    tenant_id AS tenant_id,                                     -- 租户ID
    CAST(NULL AS STRING) AS complaint_type,                     -- 投诉类型
    NULL AS complaint_qty,                                      -- 投诉数（日）
    NULL AS complaint_resolved_qty,                             -- 投诉解决数（日）
    NULL AS complaint_overdue_qty,                              -- 投诉超SLA数（日）
    NULL AS complaint_sla_numerator_qty,                        -- 投诉SLA达成率分子（日）
    NULL AS complaint_sla_denominator_qty,                      -- 投诉SLA达成率分母（日）
    SUM(approval_qty) AS approval_qty,                          -- 审批发起数（日）
    SUM(approval_pass_qty) AS approval_pass_numerator_qty,      -- 审批通过率分子（日）
    SUM(approval_qty) AS approval_pass_denominator_qty,         -- 审批通过率分母（日）
    SUM(approval_timeout_qty) AS approval_timeout_qty,          -- 审批超时数（日）
    SUM(approval_minute_qty) AS avg_approval_minute_numerator_qty,  -- 平均审批耗时分子（日）
    SUM(approval_minute_qty) AS avg_approval_minute_denominator_qty  -- 平均审批耗时分母（日）
  FROM dws.dws_opr_approval_di s                                -- 来源表「审批日汇总」
  WHERE s.travel_date = '${bizdate}'                            -- 只取当日分区
  GROUP BY tenant_id                                            -- 按粒度键汇总
) u                                                             -- 各来源合并后的明细
GROUP BY u.tenant_id, u.complaint_type                          -- 按粒度键汇总
) x                                                             -- 汇总结果，外层再补维度名称
LEFT JOIN dim.dim_sup_tenant_zip d1 ON d1.tenant_id = x.tenant_id AND d1.travel_date = '${bizdate}' AND d1.end_date = '9999-12-31';  -- 关联「租户（商户/供应商/分销商）维度」，取维度名称
