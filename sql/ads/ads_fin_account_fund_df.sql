-- ads.ads_fin_account_fund_df  账户资金看板
-- 粒度：travel_date × account_no
-- 来源：dws_fin_account_balance_df, dws_trf_distributor_credit_df, dws_fin_account_flow_di
-- 生成方式：Spark SQL / Hive；字段 13 个：直接翻译 12 · 规则翻译 0 · 待确认 1
-- 多来源：每个来源表按粒度键先汇总，UNION ALL 后再合并；快照/累计表：增量来源取截至统计日的全部分区
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT OVERWRITE TABLE ads.ads_fin_account_fund_df PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  u.account_no,                                           -- 账户编号
  SUM(u.available_balance_amt) AS available_balance_amt,  -- 可用余额（日快照）
  SUM(u.frozen_balance_amt) AS frozen_balance_amt,        -- 冻结余额（日快照）
  SUM(u.credit_limit_amt) AS credit_limit_amt,            -- 授信额度（日快照）
  SUM(u.credit_used_amt) AS credit_used_amt,              -- 已用授信（日快照）
  SUM(u.credit_usage_numerator_amt) AS credit_usage_numerator_amt,  -- 授信使用率分子（日）
  SUM(u.credit_usage_denominator_amt) AS credit_usage_denominator_amt,  -- 授信使用率分母（日）
  SUM(u.withdraw_apply_amt) AS withdraw_apply_amt,        -- 提现申请金额（日）
  SUM(u.withdraw_success_amt) AS withdraw_success_amt,    -- 提现成功金额（日）
  SUM(u.withdraw_fail_qty) AS withdraw_fail_qty,          -- 提现失败笔数（日）
  SUM(u.withdraw_success_numerator_amt) AS withdraw_success_numerator_amt,  -- 提现成功率分子（日）
  SUM(u.withdraw_success_denominator_amt) AS withdraw_success_denominator_amt,  -- 提现成功率分母（日）
  CURRENT_TIMESTAMP() AS etl_time                         -- ETL 加载时间
FROM (
  -- 来源：dws_fin_account_balance_df
  SELECT
    account_no AS account_no,                             -- 账户编号
    SUM(available_balance_amt) AS available_balance_amt,  -- 可用余额（日快照）
    SUM(frozen_balance_amt) AS frozen_balance_amt,        -- 冻结余额（日快照）
    NULL AS credit_limit_amt,                             -- 授信额度（日快照）
    NULL AS credit_used_amt,                              -- 已用授信（日快照）
    NULL AS credit_usage_numerator_amt,                   -- 授信使用率分子（日）
    NULL AS credit_usage_denominator_amt,                 -- 授信使用率分母（日）
    NULL AS withdraw_apply_amt,                           -- 提现申请金额（日）
    NULL AS withdraw_success_amt,                         -- 提现成功金额（日）
    NULL AS withdraw_fail_qty,                            -- 提现失败笔数（日）
    NULL AS withdraw_success_numerator_amt,               -- 提现成功率分子（日）
    NULL AS withdraw_success_denominator_amt              -- 提现成功率分母（日）
  FROM dws.dws_fin_account_balance_df s                   -- 来源表「账户余额日快照」
  WHERE s.travel_date = '${bizdate}'                      -- 只取当日分区
  GROUP BY account_no                                     -- 按粒度键汇总
  UNION ALL                                               -- 合并各来源
  -- 来源：dws_trf_distributor_credit_df
  SELECT
    CAST(NULL AS STRING) AS account_no,                   -- 账户编号
    NULL AS available_balance_amt,                        -- 可用余额（日快照）
    NULL AS frozen_balance_amt,                           -- 冻结余额（日快照）
    SUM(credit_limit_amt) AS credit_limit_amt,            -- 授信额度（日快照）
    SUM(credit_used_amt) AS credit_used_amt,              -- 已用授信（日快照）
    SUM(credit_used_amt) AS credit_usage_numerator_amt,   -- 授信使用率分子（日）
    SUM(credit_limit_amt) AS credit_usage_denominator_amt,  -- 授信使用率分母（日）
    NULL AS withdraw_apply_amt,                           -- 提现申请金额（日）
    NULL AS withdraw_success_amt,                         -- 提现成功金额（日）
    NULL AS withdraw_fail_qty,                            -- 提现失败笔数（日）
    NULL AS withdraw_success_numerator_amt,               -- 提现成功率分子（日）
    NULL AS withdraw_success_denominator_amt              -- 提现成功率分母（日）
  FROM dws.dws_trf_distributor_credit_df s                -- 来源表「分销关系授信快照」
  WHERE s.travel_date = '${bizdate}'                      -- 只取当日分区
  UNION ALL                                               -- 合并各来源
  -- 来源：dws_fin_account_flow_di
  SELECT
    account_no AS account_no,                             -- 账户编号
    NULL AS available_balance_amt,                        -- 可用余额（日快照）
    NULL AS frozen_balance_amt,                           -- 冻结余额（日快照）
    NULL AS credit_limit_amt,                             -- 授信额度（日快照）
    NULL AS credit_used_amt,                              -- 已用授信（日快照）
    NULL AS credit_usage_numerator_amt,                   -- 授信使用率分子（日）
    NULL AS credit_usage_denominator_amt,                 -- 授信使用率分母（日）
    SUM(withdraw_apply_amt) AS withdraw_apply_amt,        -- 提现申请金额（日）
    SUM(withdraw_success_amt) AS withdraw_success_amt,    -- 提现成功金额（日）
    SUM(withdraw_fail_qty) AS withdraw_fail_qty,          -- 提现失败笔数（日）
    SUM(withdraw_success_amt) AS withdraw_success_numerator_amt,  -- 提现成功率分子（日）
    SUM(withdraw_apply_amt) AS withdraw_success_denominator_amt  -- 提现成功率分母（日）
  FROM dws.dws_fin_account_flow_di s                      -- 来源表「账户×流水类型 资金日汇总」
  WHERE s.travel_date <= '${bizdate}'                     -- 累计口径：取截至统计日的全部分区
  GROUP BY account_no                                     -- 按粒度键汇总
) u                                                       -- 各来源合并后的明细
GROUP BY u.account_no;                                    -- 按粒度键汇总
