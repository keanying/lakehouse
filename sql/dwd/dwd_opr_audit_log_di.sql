-- dwd.dwd_opr_audit_log_di  审计操作明细
-- 粒度：1行=1条操作日志
-- 来源：ods_opr_audit_log_di
-- 生成方式：Spark SQL / Hive；字段 17 个：直接翻译 15 · 规则翻译 1 · 待确认 1
-- 流水/状态变更类：保留每条变更记录
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT OVERWRITE TABLE dwd.dwd_opr_audit_log_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  a.id                AS audit_log_id,    -- 审计日志ID（源表主键 id）
  a.log_no            AS log_no,          -- 日志编号
  a.operator_id       AS operator_id,     -- 操作人ID
  a.operator_type     AS operator_type,   -- 操作人类型
  a.action            AS action_type,     -- 操作动作（如PLACE_ORDER-下单
  a.resource_type     AS resource_type,   -- 资源类型
  a.resource_id       AS resource_id,     -- 资源ID
  a.ip_address        AS client_ip_code,  -- IP地址
  a.tenant_id         AS tenant_id,       -- 租户ID
  a.log_scope         AS log_scope_type,  -- 日志范围
  a.create_time       AS create_time,     -- 创建时间
  a.update_time       AS update_time,     -- 更新时间
  a.create_time       AS action_time,     -- 操作时间
  HOUR(a.create_time) AS action_hour_no,  -- 操作小时
  NULL                AS night_action_type,  -- 是否凌晨操作｜待确认：action_hour_no 判定
  1                   AS action_qty,      -- 操作次数
  CURRENT_TIMESTAMP() AS etl_time         -- ETL 加载时间
FROM ods.ods_opr_audit_log_di a           -- 主表「审计日志」
WHERE a.travel_date = '${bizdate}';       -- 只取当日分区
