-- dim.dim_opr_risk_rule_df  风控规则维度
-- 粒度：1行=1条规则
-- 来源：ods_opr_risk_rule_df
-- 生成方式：Spark SQL / Hive；字段 15 个：直接翻译 15 · 规则翻译 0 · 待确认 0
-- 每个 WITH 逻辑块只取用到的列并先过滤分区

WITH
risk_rule_src AS (                                   -- 主表「风控规则」，只取用到的列
  SELECT action, create_time, created_by_type, dimension, id, rule_name, rule_no, rule_status, rule_type,
         scope, tenant_id, threshold, time_window, update_time
  FROM ods.ods_opr_risk_rule_df
  WHERE travel_date = '${bizdate}'                   -- 只取当日分区
)
INSERT OVERWRITE TABLE dim.dim_opr_risk_rule_df PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  risk_rule_src.id              AS risk_rule_id,     -- 风控规则ID（源表主键 id）
  risk_rule_src.rule_no         AS rule_no,          -- 规则编号
  risk_rule_src.rule_name       AS rule_name,        -- 规则名称（如"凌晨操作检测"）
  risk_rule_src.rule_type       AS rule_type,        -- 规则类型
  risk_rule_src.scope           AS scope_type,       -- 范围
  risk_rule_src.dimension       AS dimension_type,   -- 维度
  risk_rule_src.threshold       AS threshold_desc,   -- 阈值（如"1小时内3次"）
  risk_rule_src.time_window     AS time_window_second_qty,  -- 时间窗口（秒）
  risk_rule_src.action          AS action_type,      -- 动作
  risk_rule_src.rule_status     AS rule_status,      -- 状态
  risk_rule_src.created_by_type AS created_by_type,  -- 创建方
  risk_rule_src.tenant_id       AS tenant_id,        -- 租户ID
  risk_rule_src.create_time     AS create_time,      -- 创建时间
  risk_rule_src.update_time     AS update_time,      -- 更新时间
  CURRENT_TIMESTAMP()           AS etl_time          -- ETL 加载时间
FROM risk_rule_src;
