-- ads.ads_fin_account_fund_rt  账户资金实时
-- 粒度：account_no × 当前
-- 来源：dws_fin_account_fund_rt
-- 生成方式：StarRocks 异步物化视图（每分钟刷新）；字段 8 个：直接翻译 3 · 规则翻译 5 · 待确认 0
-- 来源按粒度键预聚合后按公式计算

CREATE MATERIALIZED VIEW IF NOT EXISTS ads.ads_fin_account_fund_rt  -- 异步物化视图，StarRocks 定时刷新
REFRESH ASYNC EVERY (INTERVAL 1 MINUTE)
AS
WITH
src_account_fund AS (                                     -- 来源「账户实时资金」按粒度键预聚合
  SELECT
    s.travel_date AS travel_date,                         -- 数据日期
    s.account_no AS account_no,                           -- 账户编号
    SUM(s.available_balance_amt) AS available_balance_amt,  -- 可用余额（元）
    SUM(s.frozen_balance_amt) AS frozen_balance_amt,      -- 冻结余额（元）
    SUM(s.freeze_amt) AS freeze_amt,                      -- 冻结金额（元）= 利润/采购款/全款
    SUM(s.unfreeze_verify_amt) AS unfreeze_verify_amt,    -- 核销解冻金额
    SUM(s.unfreeze_refund_amt) AS unfreeze_refund_amt     -- 退款释放金额
  FROM dws.dws_fin_account_fund_rt s                      -- 来源表「账户实时资金」
  WHERE s.travel_date = DATE_FORMAT(CURDATE(), '%Y%m%d')  -- 只取今日数据
  GROUP BY s.travel_date, s.account_no                    -- 按粒度键汇总
)
SELECT
  u.travel_date,                                          -- 数据日期
  u.account_no,                                           -- 账户编号
  u.available_balance_amt AS available_balance_now_amt,   -- 当前可用余额
  u.frozen_balance_amt AS frozen_balance_now_amt,         -- 当前冻结余额
  u.freeze_amt AS freeze_today_amt,                       -- 今日实时冻结金额
  u.unfreeze_verify_amt AS unfreeze_verify_today_amt,     -- 今日实时核销解冻金额
  u.unfreeze_refund_amt AS unfreeze_refund_today_amt,     -- 今日实时退款释放金额
  NOW() AS update_time                                    -- 最近一次写入时间
FROM src_account_fund u;
