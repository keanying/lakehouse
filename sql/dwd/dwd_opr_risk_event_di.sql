-- dwd.dwd_opr_risk_event_di  风控事件明细
-- 粒度：1行=1个风控事件
-- 来源：ods_opr_risk_event_di
-- 生成方式：Spark SQL / Hive；字段 17 个：直接翻译 17 · 规则翻译 0 · 待确认 0
-- ODS 增量按主键取最新一条（ROW_NUMBER），剔除删除记录

INSERT OVERWRITE TABLE dwd.dwd_opr_risk_event_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  a.id                AS risk_event_id,  -- 风控事件ID（源表主键 id）
  a.event_no          AS event_no,       -- 事件编号
  a.event_type        AS event_type,     -- 类型
  a.subject_id        AS subject_id,     -- 主体ID（用户/商户）
  a.dimension_values  AS dimension_value_desc,  -- 触发维度值集合
  a.rule_id           AS rule_id,        -- 关联规则ID
  a.action            AS action_type,    -- 执行动作
  a.detail            AS detail_desc,    -- 详细描述
  a.audit_log_id      AS audit_log_id,   -- 关联审计日志ID
  a.tenant_id         AS tenant_id,      -- 租户ID
  a.create_time       AS create_time,    -- 创建时间
  a.update_time       AS update_time,    -- 更新时间
  j1.rule_type        AS rule_type,      -- 规则类型
  j2.dimension_type   AS dimension_type,  -- 规则维度
  a.create_time       AS event_time,     -- 事件发生时间
  1                   AS event_qty,      -- 事件数
  CURRENT_TIMESTAMP() AS etl_time        -- ETL 加载时间
FROM (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY id ORDER BY binlog_time DESC) AS rn  -- 同一主键多次变更，按 binlog 时间倒序编号
  FROM ods.ods_opr_risk_event_di
  WHERE travel_date = '${bizdate}'       -- 只取当日分区
) a                                      -- 主表当日增量，按主键取最新一条
LEFT JOIN dim.dim_opr_risk_rule_df j1    -- 关联「风控规则维度」，取 规则类型
  ON j1.risk_rule_id = a.rule_id         -- 按 rule_id→risk_rule_id 关联
 AND j1.travel_date = '${bizdate}'       -- 只取当日分区
LEFT JOIN dim.dim_opr_risk_rule_df j2    -- 关联「风控规则维度」，取 规则维度
  ON j2.tenant_id = a.tenant_id          -- 按 tenant_id 关联
 AND j2.travel_date = '${bizdate}'       -- 只取当日分区
WHERE a.rn = 1                           -- 只保留每个主键的最新一条
  AND a.binlog_op_type <> 'DELETE';      -- 剔除源库已删除的记录
