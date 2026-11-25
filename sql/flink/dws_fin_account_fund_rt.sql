-- dws.dws_fin_account_fund_rt  账户实时资金
-- 粒度：account_no
-- 来源：dwd_fin_account_balance_rt + dwd_fin_frozen_rt
-- 生成方式：Flink SQL（1 分钟滚动窗口聚合 → StarRocks 主键模型表）；字段 7 个：直接翻译 2 · 规则翻译 0 · 待确认 5
-- 多来源：每个来源表按粒度键先汇总，UNION ALL 后再合并
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT INTO dws.dws_fin_account_fund_rt
SELECT
  u.window_start_time,
  u.window_end_time,
  u.travel_date,
  u.account_no,
  SUM(u.available_balance_amt) AS available_balance_amt,
  SUM(u.frozen_balance_amt) AS frozen_balance_amt,
  SUM(u.freeze_amt) AS freeze_amt,
  SUM(u.unfreeze_verify_amt) AS unfreeze_verify_amt,
  SUM(u.unfreeze_refund_amt) AS unfreeze_refund_amt,
  CURRENT_TIMESTAMP AS update_time
FROM (
  -- 来源：dwd_fin_account_balance_rt
  SELECT
    window_start AS window_start_time,
    window_end AS window_end_time,
    travel_date AS travel_date,
    account_no AS account_no,
    NULL AS available_balance_amt,  -- 待确认：available_balance/100
    NULL AS frozen_balance_amt,  -- 待确认：frozen_balance/100
    NULL AS freeze_amt,
    NULL AS unfreeze_verify_amt,
    NULL AS unfreeze_refund_amt
  FROM TABLE(TUMBLE(TABLE dwd.dwd_fin_account_balance_rt, DESCRIPTOR(event_time), INTERVAL '1' MINUTE)) s
  GROUP BY window_start, window_end, travel_date, account_no
  UNION ALL
  -- 来源：dwd_fin_frozen_rt
  SELECT
    window_start AS window_start_time,
    window_end AS window_end_time,
    travel_date AS travel_date,
    account_no AS account_no,
    NULL AS available_balance_amt,
    NULL AS frozen_balance_amt,
    NULL AS freeze_amt,  -- 待确认：sum(amount) by create_date（与离线同一口径 A058）
    NULL AS unfreeze_verify_amt,  -- 待确认：sum(amount) where frozen_status='RELEASED' and frozen_event='VERIFY'（与离线同一口径 A059）
    NULL AS unfreeze_refund_amt  -- 待确认：sum(amount) where RELEASED and frozen_event='REFUND'（与离线同一口径 A060）
  FROM TABLE(TUMBLE(TABLE dwd.dwd_fin_frozen_rt, DESCRIPTOR(event_time), INTERVAL '1' MINUTE)) s
  GROUP BY window_start, window_end, travel_date, account_no
) u
GROUP BY u.window_start_time, u.window_end_time, u.travel_date, u.account_no;
