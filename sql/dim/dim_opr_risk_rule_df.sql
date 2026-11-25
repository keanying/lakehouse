-- dim.dim_opr_risk_rule_df  风控规则维度
-- 粒度：1行=1条规则
-- 来源：ods_opr_risk_rule_df
-- 生成方式：Spark SQL / Hive；字段 15 个：直接翻译 15 · 规则翻译 0 · 待确认 0

INSERT OVERWRITE TABLE dim.dim_opr_risk_rule_df PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  a.id                AS risk_rule_id,     -- 风控规则ID（源表主键 id）
  a.rule_no           AS rule_no,          -- 规则编号
  a.rule_name         AS rule_name,        -- 规则名称（如"凌晨操作检测"）
  a.rule_type         AS rule_type,        -- 规则类型
  a.scope             AS scope_type,       -- 范围
  a.dimension         AS dimension_type,   -- 维度
  a.threshold         AS threshold_desc,   -- 阈值（如"1小时内3次"）
  a.time_window       AS time_window_second_qty,  -- 时间窗口（秒）
  a.action            AS action_type,      -- 动作
  a.rule_status       AS rule_status,      -- 状态
  a.created_by_type   AS created_by_type,  -- 创建方
  a.tenant_id         AS tenant_id,        -- 租户ID
  a.create_time       AS create_time,      -- 创建时间
  a.update_time       AS update_time,      -- 更新时间
  CURRENT_TIMESTAMP() AS etl_time          -- ETL 加载时间
FROM ods.ods_opr_risk_rule_df a            -- 主表「风控规则」
WHERE a.travel_date = '${bizdate}';        -- 只取当日分区
