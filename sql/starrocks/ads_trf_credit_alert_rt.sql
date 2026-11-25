-- ads.ads_trf_credit_alert_rt  分销授信实时预警
-- 粒度：relation_no × 当前
-- 来源：dws_trf_distributor_credit_rt
-- 生成方式：StarRocks 异步物化视图（每分钟刷新）；字段 6 个：直接翻译 3 · 规则翻译 3 · 待确认 0

CREATE MATERIALIZED VIEW IF NOT EXISTS ads.ads_trf_credit_alert_rt
REFRESH ASYNC EVERY (INTERVAL 1 MINUTE)
AS
SELECT
  u.travel_date,
  u.relation_no,
  SUM(u.credit_limit_amt) AS credit_limit_now_amt,
  SUM(u.credit_used_amt) AS credit_used_now_amt,
  SUM(u.credit_used_amt) * 100 / NULLIF(SUM(u.credit_limit_amt), 0) AS credit_usage_now_rate,
  NOW() AS update_time
FROM (
  -- 来源：dws_trf_distributor_credit_rt
  SELECT
    s.travel_date AS travel_date,
    s.relation_no AS relation_no,
    SUM(s.credit_limit_amt) AS credit_limit_amt,
    SUM(s.credit_used_amt) AS credit_used_amt
  FROM dws.dws_trf_distributor_credit_rt s
  WHERE s.travel_date = DATE_FORMAT(CURDATE(), '%Y%m%d')
  GROUP BY s.travel_date, s.relation_no
) u
GROUP BY u.travel_date, u.relation_no;
