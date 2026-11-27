-- dws.dws_opr_risk_rule_hit_rt  风控规则 分钟级命中
-- 粒度：rule_id × action_type × 窗口
-- 来源：dwd_opr_risk_event_rt
-- 生成方式：Flink SQL（1 分钟滚动窗口聚合 → StarRocks 主键模型表）；字段 5 个：直接翻译 3 · 规则翻译 2 · 待确认 0
-- 来源先按粒度键预聚合

INSERT INTO dws.dws_opr_risk_rule_hit_rt                                -- 写入 StarRocks 目标表
WITH
src_risk_event AS (                                                     -- 来源「实时风控事件」按粒度键预聚合（1 分钟滚动窗口）
  SELECT
    window_start AS window_start_time,                                  -- 窗口开始时间
    window_end AS window_end_time,                                      -- 窗口结束时间
    travel_date AS travel_date,                                         -- 数据日期
    rule_id AS rule_id,                                                 -- 风控规则ID
    action_type AS action_type,                                         -- 处置动作
    COUNT(event_no) AS risk_hit_qty,                                    -- 风控命中次数
    COUNT(CASE WHEN action_type='BLOCK' THEN event_no END) AS risk_block_qty  -- 风控拦截次数
  FROM TABLE(TUMBLE(TABLE dwd.dwd_opr_risk_event_rt, DESCRIPTOR(event_time), INTERVAL '1' MINUTE)) s  -- 按事件时间切 1 分钟滚动窗口
  GROUP BY window_start, window_end, travel_date, rule_id, action_type  -- 按粒度键汇总
)
SELECT
  u.travel_date,                                                        -- 数据日期
  u.window_start_time,                                                  -- 窗口开始时间
  u.window_end_time,                                                    -- 窗口结束时间
  u.rule_id,                                                            -- 风控规则ID
  u.action_type,                                                        -- 处置动作
  u.risk_hit_qty,                                                       -- 风控命中次数
  u.risk_block_qty,                                                     -- 风控拦截次数
  CURRENT_TIMESTAMP AS update_time                                      -- 最近一次写入时间
FROM src_risk_event u;
