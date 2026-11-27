-- dwd.dwd_opr_audit_log_di  审计操作明细
-- 粒度：1行=1条操作日志
-- 来源：ods_opr_audit_log_di
-- 生成方式：Spark SQL / Hive；字段 17 个：直接翻译 15 · 规则翻译 2 · 待确认 0
-- 流水/状态变更类：保留每条变更记录；每个 WITH 逻辑块只取用到的列并先过滤分区

WITH
audit_log_chg AS (                                    -- 主表「审计日志」：保留每条变更记录，只取用到的列
  SELECT action, create_time, id, ip_address, log_no, log_scope, operator_id, operator_type, resource_id,
         resource_type, tenant_id, update_time
  FROM ods.ods_opr_audit_log_di
  WHERE travel_date = '${bizdate}'                    -- 只取当日分区
)
INSERT OVERWRITE TABLE dwd.dwd_opr_audit_log_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  audit_log_chg.id                AS audit_log_id,    -- 审计日志ID（源表主键 id）
  audit_log_chg.log_no            AS log_no,          -- 日志编号
  audit_log_chg.operator_id       AS operator_id,     -- 操作人ID
  audit_log_chg.operator_type     AS operator_type,   -- 操作人类型
  audit_log_chg.action            AS action_type,     -- 操作动作（如PLACE_ORDER-下单
  audit_log_chg.resource_type     AS resource_type,   -- 资源类型
  audit_log_chg.resource_id       AS resource_id,     -- 资源ID
  audit_log_chg.ip_address        AS client_ip_code,  -- IP地址
  audit_log_chg.tenant_id         AS tenant_id,       -- 租户ID
  audit_log_chg.log_scope         AS log_scope_type,  -- 日志范围
  audit_log_chg.create_time       AS create_time,     -- 创建时间
  audit_log_chg.update_time       AS update_time,     -- 更新时间
  audit_log_chg.create_time       AS action_time,     -- 操作时间
  HOUR(audit_log_chg.create_time) AS action_hour_no,  -- 操作小时
  CASE WHEN HOUR(audit_log_chg.create_time) < 6 THEN 1 ELSE 0 END AS night_action_type,  -- 是否凌晨操作｜口径：0~6 点（不含 6 点）的操作
  1                               AS action_qty,      -- 操作次数
  CURRENT_TIMESTAMP()             AS etl_time         -- ETL 加载时间
FROM audit_log_chg;
