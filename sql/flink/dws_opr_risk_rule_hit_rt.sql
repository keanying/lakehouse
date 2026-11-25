-- dws.dws_opr_risk_rule_hit_rt  风控规则 分钟级命中
-- 粒度：rule_id × action_type × 窗口
-- 来源：dwd_opr_risk_event_rt
-- 生成方式：Flink SQL（1 分钟滚动窗口聚合 → StarRocks 主键模型表）；字段 5 个：直接翻译 3 · 规则翻译 1 · 待确认 1
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT INTO dws.dws_opr_risk_rule_hit_rt
SELECT
  u.window_start_time,
  u.window_end_time,
  u.travel_date,
  u.rule_id,
  u.action_type,
  SUM(u.risk_hit_qty) AS risk_hit_qty,
  SUM(u.risk_block_qty) AS risk_block_qty,
  CURRENT_TIMESTAMP AS update_time
FROM (
  -- 来源：dwd_opr_risk_event_rt
  SELECT
    window_start AS window_start_time,
    window_end AS window_end_time,
    travel_date AS travel_date,
    rule_id AS rule_id,
    action_type AS action_type,
    COUNT(event_no) AS risk_hit_qty,
    COUNT(CASE WHEN 1 = 1 THEN event_no END) AS risk_block_qty  -- 待确认：action='BLOCK'
  FROM TABLE(TUMBLE(TABLE dwd.dwd_opr_risk_event_rt, DESCRIPTOR(event_time), INTERVAL '1' MINUTE)) s
  GROUP BY window_start, window_end, travel_date, rule_id, action_type
) u
GROUP BY u.window_start_time, u.window_end_time, u.travel_date, u.rule_id, u.action_type;
