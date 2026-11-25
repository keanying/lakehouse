-- dws.dws_fin_account_flow_di  账户×流水类型 资金日汇总
-- 粒度：travel_date × account_no × flow_type
-- 来源：dwd_fin_fund_flow_di, dwd_fin_withdraw_di
-- 生成方式：Spark SQL / Hive；字段 10 个：直接翻译 2 · 规则翻译 1 · 待确认 7
-- 多来源：每个来源表按粒度键先汇总，UNION ALL 后再合并
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT OVERWRITE TABLE dws.dws_fin_account_flow_di PARTITION (travel_date = '${bizdate}')
SELECT
  u.account_no,
  u.flow_type,
  SUM(u.fund_flow_qty) AS fund_flow_qty,
  SUM(u.fund_in_amt) AS fund_in_amt,
  SUM(u.fund_out_amt) AS fund_out_amt,
  SUM(u.fee_amt) AS fee_amt,
  SUM(u.withdraw_apply_amt) AS withdraw_apply_amt,
  SUM(u.withdraw_success_amt) AS withdraw_success_amt,
  SUM(u.withdraw_fail_qty) AS withdraw_fail_qty,
  CURRENT_TIMESTAMP() AS etl_time
FROM (
  -- 来源：dwd_fin_fund_flow_di
  SELECT
    account_no AS account_no,
    flow_type AS flow_type,
    COUNT(flow_no) AS fund_flow_qty,
    NULL AS fund_in_amt,  -- 待确认：sum(amount) where amount>0
    NULL AS fund_out_amt,  -- 待确认：sum(-amount) where amount<0
    NULL AS fee_amt,  -- 待确认：sum(-amount) where flow_type='FEE'
    NULL AS withdraw_apply_amt,
    NULL AS withdraw_success_amt,
    NULL AS withdraw_fail_qty
  FROM dwd.dwd_fin_fund_flow_di s
  WHERE s.travel_date = '${bizdate}'
  GROUP BY account_no, flow_type
  UNION ALL
  -- 来源：dwd_fin_withdraw_di
  SELECT
    account_no AS account_no,
    CAST(NULL AS STRING) AS flow_type,
    NULL AS fund_flow_qty,
    NULL AS fund_in_amt,
    NULL AS fund_out_amt,
    NULL AS fee_amt,
    NULL AS withdraw_apply_amt,  -- 待确认：sum(withdraw_amount)
    NULL AS withdraw_success_amt,  -- 待确认：sum(withdraw_amount) where COMPLETED
    COUNT(CASE WHEN 1 = 1 THEN withdraw_no END) AS withdraw_fail_qty  -- 待确认：status in ('FAILED','REJECTED')
  FROM dwd.dwd_fin_withdraw_di s
  WHERE s.travel_date = '${bizdate}'
  GROUP BY account_no
) u
GROUP BY u.account_no, u.flow_type;
