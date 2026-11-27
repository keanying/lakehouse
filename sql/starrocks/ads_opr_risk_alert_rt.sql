-- ads.ads_opr_risk_alert_rt  实时风控预警
-- 粒度：rule_id × 窗口
-- 来源：dws_opr_risk_rule_hit_rt, dws_ord_verify_point_flow_rt
-- 生成方式：StarRocks 异步物化视图（每分钟刷新）；字段 14 个：直接翻译 6 · 规则翻译 8 · 待确认 0
-- 多来源：各来源按粒度键预聚合后 UNION ALL 合并，再按公式计算
-- 补 0 / 补空列：多来源 UNION ALL 时，某来源不产出的指标补 0 或空，外层按粒度 SUM 后即为各来源之和，不影响结果

CREATE MATERIALIZED VIEW IF NOT EXISTS ads.ads_opr_risk_alert_rt  -- 异步物化视图，StarRocks 定时刷新
REFRESH ASYNC EVERY (INTERVAL 1 MINUTE)
AS
WITH
src_risk_rule_hit AS (                                            -- 来源「风控规则 分钟级命中」按粒度键预聚合
  SELECT
    s.travel_date AS travel_date,                                 -- 数据日期
    s.window_start_time AS window_start_time,                     -- 窗口开始时间
    s.window_end_time AS window_end_time,                         -- 窗口结束时间
    s.rule_id AS rule_id,                                         -- 风控规则ID
    SUM(CASE WHEN s.window_start_time >= NOW() - INTERVAL 5 MINUTE THEN s.risk_hit_qty END) AS risk_hit_qty,  -- 风控命中次数
    SUM(s.risk_hit_qty) AS risk_hit_qty_1,                        -- 风控命中次数（第 1 个来源的部分值，外层相加）
    SUM(CASE WHEN s.window_start_time >= NOW() - INTERVAL 5 MINUTE THEN s.risk_block_qty END) AS risk_block_qty,  -- 风控拦截次数
    SUM(s.risk_block_qty) AS risk_block_qty_1,                    -- 风控拦截次数（第 1 个来源的部分值，外层相加）
    NULL AS duplicate_verify_qty,                                 -- 重复核销次数：此来源不产出，补空
    NULL AS duplicate_verify_qty_1,                               -- duplicate_verify_qty_1：此来源不产出，补空
    NULL AS offline_conflict_qty,                                 -- 离线核销冲突次数：此来源不产出，补空
    NULL AS offline_conflict_qty_1                                -- offline_conflict_qty_1：此来源不产出，补空
  FROM dws.dws_opr_risk_rule_hit_rt s                             -- 来源表「风控规则 分钟级命中」
  WHERE s.travel_date = DATE_FORMAT(CURDATE(), '%Y%m%d')          -- 只取今日数据
  GROUP BY s.travel_date, s.window_start_time, s.window_end_time, s.rule_id  -- 按粒度键汇总
),
src_verify_point_flow AS (                                        -- 来源「核销点 分钟级客流」按粒度键预聚合
  SELECT
    s.travel_date AS travel_date,                                 -- 数据日期
    s.window_start_time AS window_start_time,                     -- 窗口开始时间
    s.window_end_time AS window_end_time,                         -- 窗口结束时间
    CAST(NULL AS BIGINT) AS rule_id,                              -- 风控规则ID：此来源不产出，补空
    NULL AS risk_hit_qty,                                         -- 风控命中次数：此来源不产出，补空
    NULL AS risk_hit_qty_1,                                       -- risk_hit_qty_1：此来源不产出，补空
    NULL AS risk_block_qty,                                       -- 风控拦截次数：此来源不产出，补空
    NULL AS risk_block_qty_1,                                     -- risk_block_qty_1：此来源不产出，补空
    SUM(CASE WHEN s.window_start_time >= NOW() - INTERVAL 5 MINUTE THEN s.duplicate_verify_qty END) AS duplicate_verify_qty,  -- 重复核销次数
    SUM(s.duplicate_verify_qty) AS duplicate_verify_qty_1,        -- 重复核销次数（第 1 个来源的部分值，外层相加）
    SUM(CASE WHEN s.window_start_time >= NOW() - INTERVAL 5 MINUTE THEN s.offline_conflict_qty END) AS offline_conflict_qty,  -- 离线核销冲突次数
    SUM(s.offline_conflict_qty) AS offline_conflict_qty_1         -- 离线核销冲突次数（第 1 个来源的部分值，外层相加）
  FROM dws.dws_ord_verify_point_flow_rt s                         -- 来源表「核销点 分钟级客流」
  WHERE s.travel_date = DATE_FORMAT(CURDATE(), '%Y%m%d')          -- 只取今日数据
  GROUP BY s.travel_date, s.window_start_time, s.window_end_time  -- 按粒度键汇总
),
all_src AS (                                                      -- 各来源字段已对齐，UNION ALL 合并（比多表 FULL JOIN 少 shuffle）
  SELECT * FROM src_risk_rule_hit
  UNION ALL
  SELECT * FROM src_verify_point_flow
),
merged AS (                                                       -- 按粒度键汇总，计算派生指标
  SELECT
    u.travel_date,                                                -- 数据日期
    u.window_start_time,                                          -- 窗口开始时间
    u.window_end_time,                                            -- 窗口结束时间
    u.rule_id,                                                    -- 风控规则ID
    SUM(u.risk_hit_qty) AS risk_hit_5m_qty,                       -- 近5分钟风控命中次数
    SUM(u.risk_hit_qty_1) AS risk_hit_today_qty,                  -- 今日实时风控命中次数
    SUM(u.risk_block_qty) AS risk_block_5m_qty,                   -- 近5分钟风控拦截次数
    SUM(u.risk_block_qty_1) AS risk_block_today_qty,              -- 今日实时风控拦截次数
    SUM(u.duplicate_verify_qty) AS duplicate_verify_5m_qty,       -- 近5分钟重复核销次数
    SUM(u.duplicate_verify_qty_1) AS duplicate_verify_today_qty,  -- 今日实时重复核销次数
    SUM(u.offline_conflict_qty) AS offline_conflict_5m_qty,       -- 近5分钟离线核销冲突次数
    SUM(u.offline_conflict_qty_1) AS offline_conflict_today_qty,  -- 今日实时离线核销冲突次数
    NOW() AS update_time                                          -- 最近一次写入时间
  FROM all_src u
  GROUP BY u.travel_date, u.window_start_time, u.window_end_time, u.rule_id  -- 按粒度键汇总
),
risk_rule_dim AS (                                                -- 「风控规则维度」当日数据，只取名称类字段
  SELECT risk_rule_id, rule_name
  FROM dim.dim_opr_risk_rule_df
)
SELECT  /*+ BROADCAST(risk_rule_dim) */
  merged.travel_date,                                             -- 数据日期
  merged.window_start_time,                                       -- 窗口开始时间
  merged.window_end_time,                                         -- 窗口结束时间
  merged.rule_id,                                                 -- 风控规则ID
  risk_rule_dim.rule_name AS rule_name,                           -- 规则名称
  merged.risk_hit_5m_qty,                                         -- 近5分钟风控命中次数
  merged.risk_hit_today_qty,                                      -- 今日实时风控命中次数
  merged.risk_block_5m_qty,                                       -- 近5分钟风控拦截次数
  merged.risk_block_today_qty,                                    -- 今日实时风控拦截次数
  merged.duplicate_verify_5m_qty,                                 -- 近5分钟重复核销次数
  merged.duplicate_verify_today_qty,                              -- 今日实时重复核销次数
  merged.offline_conflict_5m_qty,                                 -- 近5分钟离线核销冲突次数
  merged.offline_conflict_today_qty,                              -- 今日实时离线核销冲突次数
  merged.update_time                                              -- 最近一次写入时间
FROM merged
LEFT JOIN risk_rule_dim                                           -- 关联「风控规则维度」，补 rule_name
  ON risk_rule_dim.risk_rule_id = merged.rule_id;                 -- 按 rule_id→risk_rule_id 关联
