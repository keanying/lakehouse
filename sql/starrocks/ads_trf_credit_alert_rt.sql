-- ads.ads_trf_credit_alert_rt  分销授信实时预警
-- 粒度：relation_no × 当前
-- 来源：dws_trf_distributor_credit_rt
-- 生成方式：StarRocks 异步物化视图（每分钟刷新）；字段 6 个：直接翻译 3 · 规则翻译 3 · 待确认 0
-- 来源按粒度键预聚合后按公式计算

CREATE MATERIALIZED VIEW IF NOT EXISTS ads.ads_trf_credit_alert_rt  -- 异步物化视图，StarRocks 定时刷新
REFRESH ASYNC EVERY (INTERVAL 1 MINUTE)
AS
WITH
src_distributor_credit AS (                                         -- 来源「分销授信实时」按粒度键预聚合
  SELECT
    s.travel_date AS travel_date,                                   -- 数据日期
    s.relation_no AS relation_no,                                   -- 分销关系编号
    SUM(s.credit_limit_amt) AS credit_limit_amt,
    SUM(s.credit_used_amt) AS credit_used_amt
  FROM dws.dws_trf_distributor_credit_rt s                          -- 来源表「分销授信实时」
  WHERE s.travel_date = DATE_FORMAT(CURDATE(), '%Y%m%d')            -- 只取今日数据
  GROUP BY s.travel_date, s.relation_no                             -- 按粒度键汇总
)
SELECT
  u.travel_date,                                                    -- 数据日期
  u.relation_no,                                                    -- 分销关系编号
  u.credit_limit_amt AS credit_limit_now_amt,                       -- 当前授信额度
  u.credit_used_amt AS credit_used_now_amt,                         -- 当前已用授信
  u.credit_used_amt * 100 / NULLIF(u.credit_limit_amt, 0) AS credit_usage_now_rate,  -- 当前授信使用率
  NOW() AS update_time                                              -- 最近一次写入时间
FROM src_distributor_credit u;
