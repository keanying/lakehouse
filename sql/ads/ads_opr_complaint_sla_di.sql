-- ads.ads_opr_complaint_sla_di  投诉SLA与审批时效
-- 粒度：travel_date × tenant_id × complaint_type
-- 来源：dws_opr_complaint_di, dws_opr_approval_di
-- 生成方式：Spark SQL / Hive；字段 15 个：直接翻译 14 · 规则翻译 1 · 待确认 0
-- 多来源：每个来源先按粒度键预聚合，UNION ALL 后再汇总
-- 补 0 / 补空列：多来源 UNION ALL 时，某来源不产出的指标补 0 或空，外层按粒度 SUM 后即为各来源之和，不影响结果

WITH
src_complaint AS (                                              -- 来源「投诉日汇总」按粒度键预聚合
  SELECT
    tenant_id AS tenant_id,                                     -- 租户ID
    complaint_type AS complaint_type,                           -- 投诉类型
    SUM(complaint_qty) AS complaint_qty,                        -- 投诉数（日）
    SUM(complaint_resolved_qty) AS complaint_resolved_qty,      -- 投诉解决数（日）
    SUM(complaint_overdue_qty) AS complaint_overdue_qty,        -- 投诉超SLA数（日）
    SUM(complaint_overdue_qty) AS complaint_sla_numerator_qty,  -- 投诉SLA达成率分子（日）
    SUM(complaint_qty) AS complaint_sla_denominator_qty,        -- 投诉SLA达成率分母（日）
    NULL AS approval_qty,                                       -- 审批发起数（日）：此来源不产出，补空
    NULL AS approval_pass_numerator_qty,                        -- 审批通过率分子（日）：此来源不产出，补空
    NULL AS approval_pass_denominator_qty,                      -- 审批通过率分母（日）：此来源不产出，补空
    NULL AS approval_timeout_qty,                               -- 审批超时数（日）：此来源不产出，补空
    NULL AS avg_approval_minute_numerator_qty,                  -- 平均审批耗时分子（日）：此来源不产出，补空
    NULL AS avg_approval_minute_denominator_qty                 -- 平均审批耗时分母（日）：此来源不产出，补空
  FROM dws.dws_opr_complaint_di s                               -- 来源表「投诉日汇总」
  WHERE s.travel_date = '${bizdate}'                            -- 只取当日分区
  GROUP BY tenant_id, complaint_type                            -- 按粒度键汇总
),
src_approval AS (                                               -- 来源「审批日汇总」按粒度键预聚合
  SELECT
    tenant_id AS tenant_id,                                     -- 租户ID
    CAST(NULL AS STRING) AS complaint_type,                     -- 投诉类型：此来源不产出，补空
    NULL AS complaint_qty,                                      -- 投诉数（日）：此来源不产出，补空
    NULL AS complaint_resolved_qty,                             -- 投诉解决数（日）：此来源不产出，补空
    NULL AS complaint_overdue_qty,                              -- 投诉超SLA数（日）：此来源不产出，补空
    NULL AS complaint_sla_numerator_qty,                        -- 投诉SLA达成率分子（日）：此来源不产出，补空
    NULL AS complaint_sla_denominator_qty,                      -- 投诉SLA达成率分母（日）：此来源不产出，补空
    SUM(approval_qty) AS approval_qty,                          -- 审批发起数（日）
    SUM(approval_pass_qty) AS approval_pass_numerator_qty,      -- 审批通过率分子（日）
    SUM(approval_qty) AS approval_pass_denominator_qty,         -- 审批通过率分母（日）
    SUM(approval_timeout_qty) AS approval_timeout_qty,          -- 审批超时数（日）
    SUM(approval_minute_qty) AS avg_approval_minute_numerator_qty,  -- 平均审批耗时分子（日）
    SUM(approval_minute_qty) AS avg_approval_minute_denominator_qty  -- 平均审批耗时分母（日）
  FROM dws.dws_opr_approval_di s                                -- 来源表「审批日汇总」
  WHERE s.travel_date = '${bizdate}'                            -- 只取当日分区
  GROUP BY tenant_id                                            -- 按粒度键汇总
),
all_src AS (                                                    -- 各来源字段已对齐，UNION ALL 合并（比多表 FULL JOIN 少 shuffle）
  SELECT * FROM src_complaint
  UNION ALL
  SELECT * FROM src_approval
),
merged AS (                                                     -- 按粒度键汇总，计算派生指标
  SELECT
    u.tenant_id,                                                -- 租户ID
    u.complaint_type,                                           -- 投诉类型
    SUM(u.complaint_qty) AS complaint_qty,                      -- 投诉数（日）
    SUM(u.complaint_resolved_qty) AS complaint_resolved_qty,    -- 投诉解决数（日）
    SUM(u.complaint_overdue_qty) AS complaint_overdue_qty,      -- 投诉超SLA数（日）
    SUM(u.complaint_sla_numerator_qty) AS complaint_sla_numerator_qty,  -- 投诉SLA达成率分子（日）
    SUM(u.complaint_sla_denominator_qty) AS complaint_sla_denominator_qty,  -- 投诉SLA达成率分母（日）
    SUM(u.approval_qty) AS approval_qty,                        -- 审批发起数（日）
    SUM(u.approval_pass_numerator_qty) AS approval_pass_numerator_qty,  -- 审批通过率分子（日）
    SUM(u.approval_pass_denominator_qty) AS approval_pass_denominator_qty,  -- 审批通过率分母（日）
    SUM(u.approval_timeout_qty) AS approval_timeout_qty,        -- 审批超时数（日）
    SUM(u.avg_approval_minute_numerator_qty) AS avg_approval_minute_numerator_qty,  -- 平均审批耗时分子（日）
    SUM(u.avg_approval_minute_denominator_qty) AS avg_approval_minute_denominator_qty,  -- 平均审批耗时分母（日）
    CURRENT_TIMESTAMP() AS etl_time                             -- ETL 加载时间
  FROM all_src u
  GROUP BY u.tenant_id, u.complaint_type                        -- 按粒度键汇总
),
tenant_cur AS (                                                 -- 「租户（商户/供应商/分销商）维度」当前有效版本，只取名称类字段
  SELECT tenant_id, tenant_name
  FROM dim.dim_sup_tenant_zip
  WHERE travel_date = '${bizdate}' AND end_date = '9999-12-31'  -- 取当日分区里的拉链当前有效版本
)
INSERT OVERWRITE TABLE ads.ads_opr_complaint_sla_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  merged.tenant_id,                                             -- 租户ID
  merged.complaint_type,                                        -- 投诉类型
  tenant_cur.tenant_name AS tenant_name,                        -- 租户名称
  merged.complaint_qty,                                         -- 投诉数（日）
  merged.complaint_resolved_qty,                                -- 投诉解决数（日）
  merged.complaint_overdue_qty,                                 -- 投诉超SLA数（日）
  merged.complaint_sla_numerator_qty,                           -- 投诉SLA达成率分子（日）
  merged.complaint_sla_denominator_qty,                         -- 投诉SLA达成率分母（日）
  merged.approval_qty,                                          -- 审批发起数（日）
  merged.approval_pass_numerator_qty,                           -- 审批通过率分子（日）
  merged.approval_pass_denominator_qty,                         -- 审批通过率分母（日）
  merged.approval_timeout_qty,                                  -- 审批超时数（日）
  merged.avg_approval_minute_numerator_qty,                     -- 平均审批耗时分子（日）
  merged.avg_approval_minute_denominator_qty,                   -- 平均审批耗时分母（日）
  merged.etl_time                                               -- ETL 加载时间
FROM merged
LEFT JOIN tenant_cur                                            -- 关联「租户（商户/供应商/分销商）维度」，补 tenant_name
  ON tenant_cur.tenant_id = merged.tenant_id;                   -- 按 tenant_id 关联
