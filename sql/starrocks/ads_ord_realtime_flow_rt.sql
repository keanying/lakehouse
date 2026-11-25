-- ads.ads_ord_realtime_flow_rt  实时客流大屏
-- 粒度：tenant_id × verify_point_id × 窗口
-- 来源：dws_ord_verify_point_flow_rt
-- 生成方式：StarRocks 异步物化视图（每分钟刷新）；字段 17 个：直接翻译 8 · 规则翻译 9 · 待确认 0

CREATE MATERIALIZED VIEW IF NOT EXISTS ads.ads_ord_realtime_flow_rt               -- 异步物化视图，StarRocks 定时刷新
REFRESH ASYNC EVERY (INTERVAL 1 MINUTE)
AS
SELECT
  x.travel_date,                                                                  -- 数据日期
  x.window_start_time,                                                            -- 窗口开始时间
  x.window_end_time,                                                              -- 窗口结束时间
  x.tenant_id,                                                                    -- 租户ID
  x.verify_point_id,                                                              -- 核销点ID
  d1.tenant_name AS tenant_name,                                                  -- 租户名称
  d2.verify_point_name AS verify_point_name,                                      -- 核销点名称
  x.verify_person_today_qty,                                                      -- 今日实时核销人次（入园人次）
  x.verify_person_1h_qty,                                                         -- 近1小时核销人次（入园人次）
  x.verify_person_5m_qty,                                                         -- 近5分钟核销人次（入园人次）
  x.verify_fail_today_qty,                                                        -- 今日实时核销失败次数
  x.verify_fail_1h_qty,                                                           -- 近1小时核销失败次数
  x.verify_fail_5m_qty,                                                           -- 近5分钟核销失败次数
  x.verify_fail_today_rate,                                                       -- 今日实时核销失败率
  x.verify_fail_1h_rate,                                                          -- 近1小时核销失败率
  x.verify_fail_5m_rate,                                                          -- 近5分钟核销失败率
  x.update_time                                                                   -- 最近一次写入时间
FROM (
SELECT
  u.travel_date,                                                                  -- 数据日期
  u.window_start_time,                                                            -- 窗口开始时间
  u.window_end_time,                                                              -- 窗口结束时间
  u.tenant_id,                                                                    -- 租户ID
  u.verify_point_id,                                                              -- 核销点ID
  SUM(u.verify_person_qty) AS verify_person_today_qty,                            -- 今日实时核销人次（入园人次）
  SUM(u.verify_person_qty_1) AS verify_person_1h_qty,                             -- 近1小时核销人次（入园人次）
  SUM(u.verify_person_qty_2) AS verify_person_5m_qty,                             -- 近5分钟核销人次（入园人次）
  SUM(u.verify_fail_qty) AS verify_fail_today_qty,                                -- 今日实时核销失败次数
  SUM(u.verify_fail_qty_1) AS verify_fail_1h_qty,                                 -- 近1小时核销失败次数
  SUM(u.verify_fail_qty_2) AS verify_fail_5m_qty,                                 -- 近5分钟核销失败次数
  SUM(u.verify_fail_qty) * 100 / NULLIF(SUM(u.verify_entitlement_qty), 0) AS verify_fail_today_rate,  -- 今日实时核销失败率
  SUM(u.verify_fail_qty_1) * 100 / NULLIF(SUM(u.verify_entitlement_qty_1), 0) AS verify_fail_1h_rate,  -- 近1小时核销失败率
  SUM(u.verify_fail_qty_2) * 100 / NULLIF(SUM(u.verify_entitlement_qty_2), 0) AS verify_fail_5m_rate,  -- 近5分钟核销失败率
  NOW() AS update_time                                                            -- 最近一次写入时间
FROM (
  -- 来源：dws_ord_verify_point_flow_rt
  SELECT
    s.travel_date AS travel_date,                                                 -- 数据日期
    s.window_start_time AS window_start_time,                                     -- 窗口开始时间
    s.window_end_time AS window_end_time,                                         -- 窗口结束时间
    s.seller_tenant_id AS tenant_id,                                              -- 租户ID
    s.verify_point_id AS verify_point_id,                                         -- 核销点ID
    SUM(s.verify_person_qty) AS verify_person_qty,
    SUM(CASE WHEN s.window_start_time >= NOW() - INTERVAL 1 HOUR THEN s.verify_person_qty END) AS verify_person_qty_1,
    SUM(CASE WHEN s.window_start_time >= NOW() - INTERVAL 5 MINUTE THEN s.verify_person_qty END) AS verify_person_qty_2,
    SUM(s.verify_fail_qty) AS verify_fail_qty,
    SUM(CASE WHEN s.window_start_time >= NOW() - INTERVAL 1 HOUR THEN s.verify_fail_qty END) AS verify_fail_qty_1,
    SUM(CASE WHEN s.window_start_time >= NOW() - INTERVAL 5 MINUTE THEN s.verify_fail_qty END) AS verify_fail_qty_2,
    SUM(s.verify_entitlement_qty) AS verify_entitlement_qty,
    SUM(CASE WHEN s.window_start_time >= NOW() - INTERVAL 1 HOUR THEN s.verify_entitlement_qty END) AS verify_entitlement_qty_1,
    SUM(CASE WHEN s.window_start_time >= NOW() - INTERVAL 5 MINUTE THEN s.verify_entitlement_qty END) AS verify_entitlement_qty_2
  FROM dws.dws_ord_verify_point_flow_rt s                                         -- 来源表「核销点 分钟级客流」
  WHERE s.travel_date = DATE_FORMAT(CURDATE(), '%Y%m%d')                          -- 只取今日数据
  GROUP BY s.travel_date, s.window_start_time, s.window_end_time, s.seller_tenant_id, s.verify_point_id  -- 按粒度键汇总
) u                                                                               -- 各来源合并后的明细
GROUP BY u.travel_date, u.window_start_time, u.window_end_time, u.tenant_id, u.verify_point_id  -- 按粒度键汇总
) x                                                                               -- 汇总结果，外层再补维度名称
LEFT JOIN dim.dim_sup_tenant_zip d1 ON d1.tenant_id = x.tenant_id AND d1.end_date = '9999-12-31'  -- 关联「租户（商户/供应商/分销商）维度」，取维度名称
LEFT JOIN dim.dim_opr_verify_point_df d2 ON d2.verify_point_id = x.verify_point_id;  -- 关联「核销点维度」，取维度名称
