-- ads.ads_fin_account_fund_df  账户资金看板
-- 粒度：travel_date × account_no
-- 来源：dws_fin_account_balance_df, dws_trf_distributor_credit_df, dws_fin_account_flow_di
-- 生成方式：Spark SQL / Hive；字段 13 个：直接翻译 12 · 规则翻译 0 · 待确认 1
-- 多来源：每个来源表按粒度键先汇总，UNION ALL 后再合并；快照/累计表：增量来源取截至统计日的全部分区
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT OVERWRITE TABLE ads.ads_fin_account_fund_df PARTITION (travel_date = '${bizdate}')
SELECT
  u.account_no,
  SUM(u.available_balance_amt) AS available_balance_amt,
  SUM(u.frozen_balance_amt) AS frozen_balance_amt,
  SUM(u.credit_limit_amt) AS credit_limit_amt,
  SUM(u.credit_used_amt) AS credit_used_amt,
  SUM(u.credit_usage_numerator_amt) AS credit_usage_numerator_amt,
  SUM(u.credit_usage_denominator_amt) AS credit_usage_denominator_amt,
  SUM(u.withdraw_apply_amt) AS withdraw_apply_amt,
  SUM(u.withdraw_success_amt) AS withdraw_success_amt,
  SUM(u.withdraw_fail_qty) AS withdraw_fail_qty,
  SUM(u.withdraw_success_numerator_amt) AS withdraw_success_numerator_amt,
  SUM(u.withdraw_success_denominator_amt) AS withdraw_success_denominator_amt,
  CURRENT_TIMESTAMP() AS etl_time
FROM (
  -- 来源：dws_fin_account_balance_df
  SELECT
    account_no AS account_no,
    SUM(available_balance_amt) AS available_balance_amt,
    SUM(frozen_balance_amt) AS frozen_balance_amt,
    NULL AS credit_limit_amt,
    NULL AS credit_used_amt,
    NULL AS credit_usage_numerator_amt,
    NULL AS credit_usage_denominator_amt,
    NULL AS withdraw_apply_amt,
    NULL AS withdraw_success_amt,
    NULL AS withdraw_fail_qty,
    NULL AS withdraw_success_numerator_amt,
    NULL AS withdraw_success_denominator_amt
  FROM dws.dws_fin_account_balance_df s
  WHERE s.travel_date = '${bizdate}'
  GROUP BY account_no
  UNION ALL
  -- 来源：dws_trf_distributor_credit_df
  SELECT
    CAST(NULL AS STRING) AS account_no,
    NULL AS available_balance_amt,
    NULL AS frozen_balance_amt,
    SUM(credit_limit_amt) AS credit_limit_amt,
    SUM(credit_used_amt) AS credit_used_amt,
    SUM(credit_used_amt) AS credit_usage_numerator_amt,
    SUM(credit_limit_amt) AS credit_usage_denominator_amt,
    NULL AS withdraw_apply_amt,
    NULL AS withdraw_success_amt,
    NULL AS withdraw_fail_qty,
    NULL AS withdraw_success_numerator_amt,
    NULL AS withdraw_success_denominator_amt
  FROM dws.dws_trf_distributor_credit_df s
  WHERE s.travel_date = '${bizdate}'
  UNION ALL
  -- 来源：dws_fin_account_flow_di
  SELECT
    account_no AS account_no,
    NULL AS available_balance_amt,
    NULL AS frozen_balance_amt,
    NULL AS credit_limit_amt,
    NULL AS credit_used_amt,
    NULL AS credit_usage_numerator_amt,
    NULL AS credit_usage_denominator_amt,
    SUM(withdraw_apply_amt) AS withdraw_apply_amt,
    SUM(withdraw_success_amt) AS withdraw_success_amt,
    SUM(withdraw_fail_qty) AS withdraw_fail_qty,
    SUM(withdraw_success_amt) AS withdraw_success_numerator_amt,
    SUM(withdraw_apply_amt) AS withdraw_success_denominator_amt
  FROM dws.dws_fin_account_flow_di s
  WHERE s.travel_date <= '${bizdate}'
  GROUP BY account_no
) u
GROUP BY u.account_no;
