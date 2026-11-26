-- dwd.dwd_opr_risk_event_di  风控事件明细
-- 粒度：1行=1个风控事件
-- 来源：ods_opr_risk_event_di
-- 生成方式：Spark SQL / Hive；字段 17 个：直接翻译 17 · 规则翻译 0 · 待确认 0
-- 主表增量先去重再关联；每个 WITH 逻辑块只取用到的列并先过滤分区；小维表广播关联

WITH
risk_event_rn AS (                                       -- 「风控事件」当日增量，同一主键按 binlog 时间倒序编号
  SELECT action, audit_log_id, create_time, detail, dimension_values, event_no, event_type, id, rule_id,
         subject_id, tenant_id, update_time, binlog_op_type,
         ROW_NUMBER() OVER (PARTITION BY id ORDER BY binlog_time DESC) AS rn  -- 同一主键多次变更，按 binlog 时间倒序编号
  FROM ods.ods_opr_risk_event_di
  WHERE travel_date = '${bizdate}'                       -- 只取当日分区
),
risk_event_latest AS (                                   -- 「风控事件」每个主键只保留最新一条，剔除已删除记录
  SELECT action, audit_log_id, create_time, detail, dimension_values, event_no, event_type, id, rule_id,
         subject_id, tenant_id, update_time
  FROM risk_event_rn
  WHERE rn = 1
    AND binlog_op_type <> 'DELETE'                       -- 剔除源库已删除的记录
),
risk_rule_dim AS (                                       -- 「风控规则维度」当日数据，只取用到的列
  SELECT dimension_type, risk_rule_id, rule_type
  FROM dim.dim_opr_risk_rule_df
  WHERE travel_date = '${bizdate}'                       -- 只取当日分区
)
INSERT OVERWRITE TABLE dwd.dwd_opr_risk_event_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT  /*+ BROADCAST(risk_rule_dim) */
  risk_event_latest.id               AS risk_event_id,   -- 风控事件ID（源表主键 id）
  risk_event_latest.event_no         AS event_no,        -- 事件编号
  risk_event_latest.event_type       AS event_type,      -- 类型
  risk_event_latest.subject_id       AS subject_id,      -- 主体ID（用户/商户）
  risk_event_latest.dimension_values AS dimension_value_desc,  -- 触发维度值集合
  risk_event_latest.rule_id          AS rule_id,         -- 关联规则ID
  risk_event_latest.action           AS action_type,     -- 执行动作
  risk_event_latest.detail           AS detail_desc,     -- 详细描述
  risk_event_latest.audit_log_id     AS audit_log_id,    -- 关联审计日志ID
  risk_event_latest.tenant_id        AS tenant_id,       -- 租户ID
  risk_event_latest.create_time      AS create_time,     -- 创建时间
  risk_event_latest.update_time      AS update_time,     -- 更新时间
  risk_rule_dim.rule_type            AS rule_type,       -- 规则类型
  risk_rule_dim.dimension_type       AS dimension_type,  -- 规则维度
  risk_event_latest.create_time      AS event_time,      -- 事件发生时间
  1                                  AS event_qty,       -- 事件数
  CURRENT_TIMESTAMP()                AS etl_time         -- ETL 加载时间
FROM risk_event_latest
LEFT JOIN risk_rule_dim                                  -- 关联「风控规则维度」，取 规则类型、规则维度
  ON risk_rule_dim.risk_rule_id = risk_event_latest.rule_id;  -- 按 rule_id→risk_rule_id 关联
