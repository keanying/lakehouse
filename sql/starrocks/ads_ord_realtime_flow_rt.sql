-- ads.ads_ord_realtime_flow_rt  实时客流大屏
-- 粒度：tenant_id × verify_point_id × 窗口
-- 来源：dws_ord_verify_point_flow_rt
-- 生成方式：StarRocks 异步物化视图（每分钟刷新）；字段 17 个：直接翻译 8 · 规则翻译 9 · 待确认 0
-- 来源按粒度键预聚合后按公式计算

CREATE MATERIALIZED VIEW IF NOT EXISTS ads.ads_ord_realtime_flow_rt               -- 异步物化视图，StarRocks 定时刷新
REFRESH ASYNC EVERY (INTERVAL 1 MINUTE)
AS
WITH
src_verify_point_flow AS (                                                        -- 来源「核销点 分钟级客流」按粒度键预聚合
  SELECT
    s.travel_date AS travel_date,                                                 -- 数据日期
    s.window_start_time AS window_start_time,                                     -- 窗口开始时间
    s.window_end_time AS window_end_time,                                         -- 窗口结束时间
    s.seller_tenant_id AS tenant_id,                                              -- 租户ID
    s.verify_point_id AS verify_point_id,                                         -- 核销点ID
    SUM(s.verify_person_qty) AS verify_person_qty,                                -- 核销人次（入园人次）
    SUM(CASE WHEN s.window_start_time >= NOW() - INTERVAL 1 HOUR THEN s.verify_person_qty END) AS verify_person_qty_1,  -- 核销人次（入园人次）（第 1 个来源的部分值，外层相加）
    SUM(CASE WHEN s.window_start_time >= NOW() - INTERVAL 5 MINUTE THEN s.verify_person_qty END) AS verify_person_qty_2,  -- 核销人次（入园人次）（第 2 个来源的部分值，外层相加）
    SUM(s.verify_fail_qty) AS verify_fail_qty,                                    -- 核销失败次数
    SUM(CASE WHEN s.window_start_time >= NOW() - INTERVAL 1 HOUR THEN s.verify_fail_qty END) AS verify_fail_qty_1,  -- 核销失败次数（第 1 个来源的部分值，外层相加）
    SUM(CASE WHEN s.window_start_time >= NOW() - INTERVAL 5 MINUTE THEN s.verify_fail_qty END) AS verify_fail_qty_2,  -- 核销失败次数（第 2 个来源的部分值，外层相加）
    SUM(s.verify_entitlement_qty) AS verify_entitlement_qty,                      -- 核销权益次数
    SUM(CASE WHEN s.window_start_time >= NOW() - INTERVAL 1 HOUR THEN s.verify_entitlement_qty END) AS verify_entitlement_qty_1,  -- 核销权益次数（第 1 个来源的部分值，外层相加）
    SUM(CASE WHEN s.window_start_time >= NOW() - INTERVAL 5 MINUTE THEN s.verify_entitlement_qty END) AS verify_entitlement_qty_2  -- 核销权益次数（第 2 个来源的部分值，外层相加）
  FROM dws.dws_ord_verify_point_flow_rt s                                         -- 来源表「核销点 分钟级客流」
  WHERE s.travel_date = DATE_FORMAT(CURDATE(), '%Y%m%d')                          -- 只取今日数据
  GROUP BY s.travel_date, s.window_start_time, s.window_end_time, s.seller_tenant_id, s.verify_point_id  -- 按粒度键汇总
),
merged AS (                                                                       -- 按粒度键汇总，计算派生指标
  SELECT
    u.travel_date,                                                                -- 数据日期
    u.window_start_time,                                                          -- 窗口开始时间
    u.window_end_time,                                                            -- 窗口结束时间
    u.tenant_id,                                                                  -- 租户ID
    u.verify_point_id,                                                            -- 核销点ID
    u.verify_person_qty AS verify_person_today_qty,                               -- 今日实时核销人次（入园人次）
    u.verify_person_qty_1 AS verify_person_1h_qty,                                -- 近1小时核销人次（入园人次）
    u.verify_person_qty_2 AS verify_person_5m_qty,                                -- 近5分钟核销人次（入园人次）
    u.verify_fail_qty AS verify_fail_today_qty,                                   -- 今日实时核销失败次数
    u.verify_fail_qty_1 AS verify_fail_1h_qty,                                    -- 近1小时核销失败次数
    u.verify_fail_qty_2 AS verify_fail_5m_qty,                                    -- 近5分钟核销失败次数
    u.verify_fail_qty * 100 / NULLIF(u.verify_entitlement_qty, 0) AS verify_fail_today_rate,  -- 今日实时核销失败率
    u.verify_fail_qty_1 * 100 / NULLIF(u.verify_entitlement_qty_1, 0) AS verify_fail_1h_rate,  -- 近1小时核销失败率
    u.verify_fail_qty_2 * 100 / NULLIF(u.verify_entitlement_qty_2, 0) AS verify_fail_5m_rate,  -- 近5分钟核销失败率
    NOW() AS update_time                                                          -- 最近一次写入时间
  FROM src_verify_point_flow u
),
tenant_cur AS (                                                                   -- 「租户（商户/供应商/分销商）维度」当前有效版本，只取名称类字段
  SELECT tenant_id, tenant_name
  FROM dim.dim_sup_tenant_zip
  WHERE end_date = '9999-12-31'                                                   -- 只取拉链当前有效版本
),
verify_point_dim AS (                                                             -- 「核销点维度」当日数据，只取名称类字段
  SELECT verify_point_id, verify_point_name
  FROM dim.dim_opr_verify_point_df
)
SELECT  /*+ BROADCAST(verify_point_dim) */
  merged.travel_date,                                                             -- 数据日期
  merged.window_start_time,                                                       -- 窗口开始时间
  merged.window_end_time,                                                         -- 窗口结束时间
  merged.tenant_id,                                                               -- 租户ID
  merged.verify_point_id,                                                         -- 核销点ID
  tenant_cur.tenant_name AS tenant_name,                                          -- 租户名称
  verify_point_dim.verify_point_name AS verify_point_name,                        -- 核销点名称
  merged.verify_person_today_qty,                                                 -- 今日实时核销人次（入园人次）
  merged.verify_person_1h_qty,                                                    -- 近1小时核销人次（入园人次）
  merged.verify_person_5m_qty,                                                    -- 近5分钟核销人次（入园人次）
  merged.verify_fail_today_qty,                                                   -- 今日实时核销失败次数
  merged.verify_fail_1h_qty,                                                      -- 近1小时核销失败次数
  merged.verify_fail_5m_qty,                                                      -- 近5分钟核销失败次数
  merged.verify_fail_today_rate,                                                  -- 今日实时核销失败率
  merged.verify_fail_1h_rate,                                                     -- 近1小时核销失败率
  merged.verify_fail_5m_rate,                                                     -- 近5分钟核销失败率
  merged.update_time                                                              -- 最近一次写入时间
FROM merged
LEFT JOIN tenant_cur                                                              -- 关联「租户（商户/供应商/分销商）维度」，补 tenant_name
  ON tenant_cur.tenant_id = merged.tenant_id                                      -- 按 tenant_id 关联
LEFT JOIN verify_point_dim                                                        -- 关联「核销点维度」，补 verify_point_name
  ON verify_point_dim.verify_point_id = merged.verify_point_id;                   -- 按 verify_point_id 关联
