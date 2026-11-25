-- ads.ads_opr_risk_alert_rt  实时风控预警
-- 粒度：rule_id × 窗口
-- 来源：dws_opr_risk_rule_hit_rt, dws_ord_verify_point_flow_rt
-- 生成方式：StarRocks 异步物化视图（每分钟刷新）；字段 14 个：直接翻译 6 · 规则翻译 8 · 待确认 0
-- 多来源：各来源按粒度键汇总后 UNION ALL 合并，再按公式计算

CREATE MATERIALIZED VIEW IF NOT EXISTS ads.ads_opr_risk_alert_rt
REFRESH ASYNC EVERY (INTERVAL 1 MINUTE)
AS
SELECT
  x.travel_date,
  x.window_start_time,
  x.window_end_time,
  x.rule_id,
  d1.rule_name AS rule_name,
  x.risk_hit_5m_qty,
  x.risk_hit_today_qty,
  x.risk_block_5m_qty,
  x.risk_block_today_qty,
  x.duplicate_verify_5m_qty,
  x.duplicate_verify_today_qty,
  x.offline_conflict_5m_qty,
  x.offline_conflict_today_qty,
  x.update_time
FROM (
SELECT
  u.travel_date,
  u.window_start_time,
  u.window_end_time,
  u.rule_id,
  SUM(u.risk_hit_qty) AS risk_hit_5m_qty,
  SUM(u.risk_hit_qty_1) AS risk_hit_today_qty,
  SUM(u.risk_block_qty) AS risk_block_5m_qty,
  SUM(u.risk_block_qty_1) AS risk_block_today_qty,
  SUM(u.duplicate_verify_qty) AS duplicate_verify_5m_qty,
  SUM(u.duplicate_verify_qty_1) AS duplicate_verify_today_qty,
  SUM(u.offline_conflict_qty) AS offline_conflict_5m_qty,
  SUM(u.offline_conflict_qty_1) AS offline_conflict_today_qty,
  NOW() AS update_time
FROM (
  -- 来源：dws_opr_risk_rule_hit_rt
  SELECT
    s.travel_date AS travel_date,
    s.window_start_time AS window_start_time,
    s.window_end_time AS window_end_time,
    s.rule_id AS rule_id,
    SUM(CASE WHEN s.window_start_time >= NOW() - INTERVAL 5 MINUTE THEN s.risk_hit_qty END) AS risk_hit_qty,
    SUM(s.risk_hit_qty) AS risk_hit_qty_1,
    SUM(CASE WHEN s.window_start_time >= NOW() - INTERVAL 5 MINUTE THEN s.risk_block_qty END) AS risk_block_qty,
    SUM(s.risk_block_qty) AS risk_block_qty_1,
    NULL AS duplicate_verify_qty,
    NULL AS duplicate_verify_qty_1,
    NULL AS offline_conflict_qty,
    NULL AS offline_conflict_qty_1
  FROM dws.dws_opr_risk_rule_hit_rt s
  WHERE s.travel_date = DATE_FORMAT(CURDATE(), '%Y%m%d')
  GROUP BY s.travel_date, s.window_start_time, s.window_end_time, s.rule_id
  UNION ALL
  -- 来源：dws_ord_verify_point_flow_rt
  SELECT
    s.travel_date AS travel_date,
    s.window_start_time AS window_start_time,
    s.window_end_time AS window_end_time,
    CAST(NULL AS BIGINT) AS rule_id,
    NULL AS risk_hit_qty,
    NULL AS risk_hit_qty_1,
    NULL AS risk_block_qty,
    NULL AS risk_block_qty_1,
    SUM(CASE WHEN s.window_start_time >= NOW() - INTERVAL 5 MINUTE THEN s.duplicate_verify_qty END) AS duplicate_verify_qty,
    SUM(s.duplicate_verify_qty) AS duplicate_verify_qty_1,
    SUM(CASE WHEN s.window_start_time >= NOW() - INTERVAL 5 MINUTE THEN s.offline_conflict_qty END) AS offline_conflict_qty,
    SUM(s.offline_conflict_qty) AS offline_conflict_qty_1
  FROM dws.dws_ord_verify_point_flow_rt s
  WHERE s.travel_date = DATE_FORMAT(CURDATE(), '%Y%m%d')
  GROUP BY s.travel_date, s.window_start_time, s.window_end_time
) u
GROUP BY u.travel_date, u.window_start_time, u.window_end_time, u.rule_id
) x
LEFT JOIN dim.dim_opr_risk_rule_df d1 ON d1.risk_rule_id = x.rule_id;
