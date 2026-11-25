-- ads.ads_fin_account_fund_rt  账户资金实时
-- 粒度：account_no × 当前
-- 来源：dws_fin_account_fund_rt
-- 生成方式：StarRocks 异步物化视图（每分钟刷新）；字段 8 个：直接翻译 3 · 规则翻译 5 · 待确认 0

CREATE MATERIALIZED VIEW IF NOT EXISTS ads.ads_fin_account_fund_rt
REFRESH ASYNC EVERY (INTERVAL 1 MINUTE)
AS
SELECT
  u.travel_date,
  u.account_no,
  SUM(u.available_balance_amt) AS available_balance_now_amt,
  SUM(u.frozen_balance_amt) AS frozen_balance_now_amt,
  SUM(u.freeze_amt) AS freeze_today_amt,
  SUM(u.unfreeze_verify_amt) AS unfreeze_verify_today_amt,
  SUM(u.unfreeze_refund_amt) AS unfreeze_refund_today_amt,
  NOW() AS update_time
FROM (
  -- 来源：dws_fin_account_fund_rt
  SELECT
    s.travel_date AS travel_date,
    s.account_no AS account_no,
    SUM(s.available_balance_amt) AS available_balance_amt,
    SUM(s.frozen_balance_amt) AS frozen_balance_amt,
    SUM(s.freeze_amt) AS freeze_amt,
    SUM(s.unfreeze_verify_amt) AS unfreeze_verify_amt,
    SUM(s.unfreeze_refund_amt) AS unfreeze_refund_amt
  FROM dws.dws_fin_account_fund_rt s
  WHERE s.travel_date = DATE_FORMAT(CURDATE(), '%Y%m%d')
  GROUP BY s.travel_date, s.account_no
) u
GROUP BY u.travel_date, u.account_no;
