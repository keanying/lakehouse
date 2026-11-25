-- ads.ads_opr_risk_alert_rt  实时风控预警
-- 粒度：rule_id × 窗口
-- 来源：dws_opr_risk_rule_hit_rt, dws_ord_verify_point_flow_rt
-- 生成方式：StarRocks 异步物化视图（每分钟刷新）；字段 14 个：直接翻译 6 · 规则翻译 8 · 待确认 0
-- 多来源：各来源按粒度键汇总后 UNION ALL 合并，再按公式计算

CREATE MATERIALIZED VIEW IF NOT EXISTS ads.ads_opr_risk_alert_rt  -- 异步物化视图，StarRocks 定时刷新
REFRESH ASYNC EVERY (INTERVAL 1 MINUTE)
AS
SELECT
  x.travel_date,                                           -- 数据日期
  x.window_start_time,                                     -- 窗口开始时间
  x.window_end_time,                                       -- 窗口结束时间
  x.rule_id,                                               -- 风控规则ID
  d1.rule_name AS rule_name,                               -- 规则名称
  x.risk_hit_5m_qty,                                       -- 近5分钟风控命中次数
  x.risk_hit_today_qty,                                    -- 今日实时风控命中次数
  x.risk_block_5m_qty,                                     -- 近5分钟风控拦截次数
  x.risk_block_today_qty,                                  -- 今日实时风控拦截次数
  x.duplicate_verify_5m_qty,                               -- 近5分钟重复核销次数
  x.duplicate_verify_today_qty,                            -- 今日实时重复核销次数
  x.offline_conflict_5m_qty,                               -- 近5分钟离线核销冲突次数
  x.offline_conflict_today_qty,                            -- 今日实时离线核销冲突次数
  x.update_time                                            -- 最近一次写入时间
FROM (
SELECT
  u.travel_date,                                           -- 数据日期
  u.window_start_time,                                     -- 窗口开始时间
  u.window_end_time,                                       -- 窗口结束时间
  u.rule_id,                                               -- 风控规则ID
  SUM(u.risk_hit_qty) AS risk_hit_5m_qty,                  -- 近5分钟风控命中次数
  SUM(u.risk_hit_qty_1) AS risk_hit_today_qty,             -- 今日实时风控命中次数
  SUM(u.risk_block_qty) AS risk_block_5m_qty,              -- 近5分钟风控拦截次数
  SUM(u.risk_block_qty_1) AS risk_block_today_qty,         -- 今日实时风控拦截次数
  SUM(u.duplicate_verify_qty) AS duplicate_verify_5m_qty,  -- 近5分钟重复核销次数
  SUM(u.duplicate_verify_qty_1) AS duplicate_verify_today_qty,  -- 今日实时重复核销次数
  SUM(u.offline_conflict_qty) AS offline_conflict_5m_qty,  -- 近5分钟离线核销冲突次数
  SUM(u.offline_conflict_qty_1) AS offline_conflict_today_qty,  -- 今日实时离线核销冲突次数
  NOW() AS update_time                                     -- 最近一次写入时间
FROM (
  -- 来源：dws_opr_risk_rule_hit_rt
  SELECT
    s.travel_date AS travel_date,                          -- 数据日期
    s.window_start_time AS window_start_time,              -- 窗口开始时间
    s.window_end_time AS window_end_time,                  -- 窗口结束时间
    s.rule_id AS rule_id,                                  -- 风控规则ID
    SUM(CASE WHEN s.window_start_time >= NOW() - INTERVAL 5 MINUTE THEN s.risk_hit_qty END) AS risk_hit_qty,
    SUM(s.risk_hit_qty) AS risk_hit_qty_1,
    SUM(CASE WHEN s.window_start_time >= NOW() - INTERVAL 5 MINUTE THEN s.risk_block_qty END) AS risk_block_qty,
    SUM(s.risk_block_qty) AS risk_block_qty_1,
    NULL AS duplicate_verify_qty,
    NULL AS duplicate_verify_qty_1,
    NULL AS offline_conflict_qty,
    NULL AS offline_conflict_qty_1
  FROM dws.dws_opr_risk_rule_hit_rt s                      -- 来源表「风控规则 分钟级命中」
  WHERE s.travel_date = DATE_FORMAT(CURDATE(), '%Y%m%d')   -- 只取今日数据
  GROUP BY s.travel_date, s.window_start_time, s.window_end_time, s.rule_id  -- 按粒度键汇总
  UNION ALL                                                -- 合并各来源
  -- 来源：dws_ord_verify_point_flow_rt
  SELECT
    s.travel_date AS travel_date,                          -- 数据日期
    s.window_start_time AS window_start_time,              -- 窗口开始时间
    s.window_end_time AS window_end_time,                  -- 窗口结束时间
    CAST(NULL AS BIGINT) AS rule_id,                       -- 风控规则ID
    NULL AS risk_hit_qty,
    NULL AS risk_hit_qty_1,
    NULL AS risk_block_qty,
    NULL AS risk_block_qty_1,
    SUM(CASE WHEN s.window_start_time >= NOW() - INTERVAL 5 MINUTE THEN s.duplicate_verify_qty END) AS duplicate_verify_qty,
    SUM(s.duplicate_verify_qty) AS duplicate_verify_qty_1,
    SUM(CASE WHEN s.window_start_time >= NOW() - INTERVAL 5 MINUTE THEN s.offline_conflict_qty END) AS offline_conflict_qty,
    SUM(s.offline_conflict_qty) AS offline_conflict_qty_1
  FROM dws.dws_ord_verify_point_flow_rt s                  -- 来源表「核销点 分钟级客流」
  WHERE s.travel_date = DATE_FORMAT(CURDATE(), '%Y%m%d')   -- 只取今日数据
  GROUP BY s.travel_date, s.window_start_time, s.window_end_time  -- 按粒度键汇总
) u                                                        -- 各来源合并后的明细
GROUP BY u.travel_date, u.window_start_time, u.window_end_time, u.rule_id  -- 按粒度键汇总
) x                                                        -- 汇总结果，外层再补维度名称
LEFT JOIN dim.dim_opr_risk_rule_df d1 ON d1.risk_rule_id = x.rule_id;  -- 关联「风控规则维度」，取维度名称
