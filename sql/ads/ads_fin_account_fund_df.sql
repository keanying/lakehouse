-- ads.ads_fin_account_fund_df  账户资金看板
-- 粒度：travel_date × account_no
-- 来源：dws_fin_account_balance_df, dws_trf_distributor_credit_df, dws_fin_account_flow_di
-- 生成方式：Spark SQL / Hive；字段 13 个：直接翻译 12 · 规则翻译 1 · 待确认 0
-- 多来源：每个来源先按粒度键预聚合，UNION ALL 后再汇总；快照/累计表：增量来源取截至统计日的全部分区

WITH
src_account_balance AS (                                          -- 来源「账户余额日快照」按粒度键预聚合
  SELECT
    account_no AS account_no,                                     -- 账户编号
    SUM(available_balance_amt) AS available_balance_amt,          -- 可用余额（日快照）
    SUM(frozen_balance_amt) AS frozen_balance_amt,                -- 冻结余额（日快照）
    NULL AS credit_limit_amt,
    NULL AS credit_used_amt,
    NULL AS credit_usage_numerator_amt,
    NULL AS credit_usage_denominator_amt,
    NULL AS withdraw_apply_amt,
    NULL AS withdraw_success_amt,
    NULL AS withdraw_fail_qty,
    NULL AS withdraw_success_numerator_amt,
    NULL AS withdraw_success_denominator_amt
  FROM dws.dws_fin_account_balance_df s                           -- 来源表「账户余额日快照」
  WHERE s.travel_date = '${bizdate}'                              -- 只取当日分区
  GROUP BY account_no                                             -- 按粒度键汇总
),
src_distributor_credit AS (                                       -- 来源「分销关系授信快照」按粒度键预聚合
  SELECT
    CAST(NULL AS STRING) AS account_no,
    NULL AS available_balance_amt,
    NULL AS frozen_balance_amt,
    SUM(credit_limit_amt) AS credit_limit_amt,                    -- 授信额度（日快照）
    SUM(credit_used_amt) AS credit_used_amt,                      -- 已用授信（日快照）
    SUM(credit_used_amt) AS credit_usage_numerator_amt,           -- 授信使用率分子（日）
    SUM(credit_limit_amt) AS credit_usage_denominator_amt,        -- 授信使用率分母（日）
    NULL AS withdraw_apply_amt,
    NULL AS withdraw_success_amt,
    NULL AS withdraw_fail_qty,
    NULL AS withdraw_success_numerator_amt,
    NULL AS withdraw_success_denominator_amt
  FROM dws.dws_trf_distributor_credit_df s                        -- 来源表「分销关系授信快照」
  WHERE s.travel_date = '${bizdate}'                              -- 只取当日分区
),
src_account_flow AS (                                             -- 来源「账户×流水类型 资金日汇总」按粒度键预聚合
  SELECT
    account_no AS account_no,                                     -- 账户编号
    NULL AS available_balance_amt,
    NULL AS frozen_balance_amt,
    NULL AS credit_limit_amt,
    NULL AS credit_used_amt,
    NULL AS credit_usage_numerator_amt,
    NULL AS credit_usage_denominator_amt,
    SUM(withdraw_apply_amt) AS withdraw_apply_amt,                -- 提现申请金额（日）
    SUM(withdraw_success_amt) AS withdraw_success_amt,            -- 提现成功金额（日）
    SUM(withdraw_fail_qty) AS withdraw_fail_qty,                  -- 提现失败笔数（日）
    SUM(withdraw_success_amt) AS withdraw_success_numerator_amt,  -- 提现成功率分子（日）
    SUM(withdraw_apply_amt) AS withdraw_success_denominator_amt   -- 提现成功率分母（日）
  FROM dws.dws_fin_account_flow_di s                              -- 来源表「账户×流水类型 资金日汇总」
  WHERE s.travel_date <= '${bizdate}'                             -- 累计口径：取截至统计日的全部分区
  GROUP BY account_no                                             -- 按粒度键汇总
),
all_src AS (                                                      -- 各来源字段已对齐，UNION ALL 合并（比多表 FULL JOIN 少 shuffle）
  SELECT * FROM src_account_balance
  UNION ALL
  SELECT * FROM src_distributor_credit
  UNION ALL
  SELECT * FROM src_account_flow
)
INSERT OVERWRITE TABLE ads.ads_fin_account_fund_df PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  u.account_no,                                                   -- 账户编号
  SUM(u.available_balance_amt) AS available_balance_amt,          -- 可用余额（日快照）
  SUM(u.frozen_balance_amt) AS frozen_balance_amt,                -- 冻结余额（日快照）
  SUM(u.credit_limit_amt) AS credit_limit_amt,                    -- 授信额度（日快照）
  SUM(u.credit_used_amt) AS credit_used_amt,                      -- 已用授信（日快照）
  SUM(u.credit_usage_numerator_amt) AS credit_usage_numerator_amt,  -- 授信使用率分子（日）
  SUM(u.credit_usage_denominator_amt) AS credit_usage_denominator_amt,  -- 授信使用率分母（日）
  SUM(u.withdraw_apply_amt) AS withdraw_apply_amt,                -- 提现申请金额（日）
  SUM(u.withdraw_success_amt) AS withdraw_success_amt,            -- 提现成功金额（日）
  SUM(u.withdraw_fail_qty) AS withdraw_fail_qty,                  -- 提现失败笔数（日）
  SUM(u.withdraw_success_numerator_amt) AS withdraw_success_numerator_amt,  -- 提现成功率分子（日）
  SUM(u.withdraw_success_denominator_amt) AS withdraw_success_denominator_amt,  -- 提现成功率分母（日）
  CURRENT_TIMESTAMP() AS etl_time                                 -- ETL 加载时间
FROM all_src u
GROUP BY u.account_no;                                            -- 按粒度键汇总
