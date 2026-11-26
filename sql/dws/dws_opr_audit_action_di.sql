-- dws.dws_opr_audit_action_di  操作审计日汇总
-- 粒度：travel_date × tenant_id × operator_type × operator_id × action_type
-- 来源：dwd_opr_audit_log_di
-- 生成方式：Spark SQL / Hive；字段 6 个：直接翻译 4 · 规则翻译 2 · 待确认 0
-- 来源先按粒度键预聚合

WITH
src_audit_log AS (                                             -- 来源「审计操作明细」按粒度键预聚合
  SELECT
    tenant_id AS tenant_id,                                    -- 租户ID
    operator_type AS operator_type,                            -- 操作人类型
    operator_id AS operator_id,                                -- 操作人ID
    action_type AS action_type,                                -- 处置动作
    COUNT(log_no) AS audit_action_qty,                         -- 操作次数
    COUNT(CASE WHEN hour(create_time) between 0 and 5 THEN 1 END) AS night_action_qty  -- 凌晨操作次数
  FROM dwd.dwd_opr_audit_log_di s                              -- 来源表「审计操作明细」
  WHERE s.travel_date = '${bizdate}'                           -- 只取当日分区
  GROUP BY tenant_id, operator_type, operator_id, action_type  -- 按粒度键汇总
)
INSERT OVERWRITE TABLE dws.dws_opr_audit_action_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  u.tenant_id,                                                 -- 租户ID
  u.operator_type,                                             -- 操作人类型
  u.operator_id,                                               -- 操作人ID
  u.action_type,                                               -- 处置动作
  u.audit_action_qty,                                          -- 操作次数
  u.night_action_qty,                                          -- 凌晨操作次数
  CURRENT_TIMESTAMP() AS etl_time                              -- ETL 加载时间
FROM src_audit_log u;
