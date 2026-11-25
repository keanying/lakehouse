-- dws.dws_fin_account_balance_df  账户余额日快照
-- 粒度：travel_date × account_no
-- 来源：dwd_fin_account_balance_df, dwd_fin_fund_flow_di
-- 生成方式：Spark SQL / Hive；字段 5 个：直接翻译 1 · 规则翻译 0 · 待确认 4
-- 多来源：每个来源表按粒度键先汇总，UNION ALL 后再合并；快照/累计表：增量来源取截至统计日的全部分区
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT OVERWRITE TABLE dws.dws_fin_account_balance_df PARTITION (travel_date = '${bizdate}')
SELECT
  u.account_no,
  SUM(u.available_balance_amt) AS available_balance_amt,
  SUM(u.frozen_balance_amt) AS frozen_balance_amt,
  SUM(u.opening_balance_amt) AS opening_balance_amt,
  SUM(u.closing_balance_amt) AS closing_balance_amt,
  CURRENT_TIMESTAMP() AS etl_time
FROM (
  -- 来源：dwd_fin_account_balance_df
  SELECT
    account_no AS account_no,
    NULL AS available_balance_amt,  -- 待确认：available_balance/100
    NULL AS frozen_balance_amt,  -- 待确认：frozen_balance/100
    NULL AS opening_balance_amt,
    NULL AS closing_balance_amt
  FROM dwd.dwd_fin_account_balance_df s
  WHERE s.travel_date = '${bizdate}'
  GROUP BY account_no
  UNION ALL
  -- 来源：dwd_fin_fund_flow_di
  SELECT
    account_no AS account_no,
    NULL AS available_balance_amt,
    NULL AS frozen_balance_amt,
    NULL AS opening_balance_amt,  -- 待确认：first(balance_before)
    NULL AS closing_balance_amt  -- 待确认：last(balance_after)
  FROM dwd.dwd_fin_fund_flow_di s
  WHERE s.travel_date <= '${bizdate}'
  GROUP BY account_no
) u
GROUP BY u.account_no;
