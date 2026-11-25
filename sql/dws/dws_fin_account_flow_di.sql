-- dws.dws_fin_account_flow_di  账户×流水类型 资金日汇总
-- 粒度：travel_date × account_no × flow_type
-- 来源：dwd_fin_fund_flow_di, dwd_fin_withdraw_di
-- 生成方式：Spark SQL / Hive；字段 10 个：直接翻译 2 · 规则翻译 1 · 待确认 7
-- 多来源：每个来源表按粒度键先汇总，UNION ALL 后再合并
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT OVERWRITE TABLE dws.dws_fin_account_flow_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  u.account_no,                           -- 账户编号
  u.flow_type,                            -- 流水类型
  SUM(u.fund_flow_qty) AS fund_flow_qty,  -- 资金流水笔数
  SUM(u.fund_in_amt) AS fund_in_amt,      -- 资金流入
  SUM(u.fund_out_amt) AS fund_out_amt,    -- 资金流出
  SUM(u.fee_amt) AS fee_amt,              -- 手续费金额
  SUM(u.withdraw_apply_amt) AS withdraw_apply_amt,  -- 提现申请金额
  SUM(u.withdraw_success_amt) AS withdraw_success_amt,  -- 提现成功金额
  SUM(u.withdraw_fail_qty) AS withdraw_fail_qty,  -- 提现失败笔数
  CURRENT_TIMESTAMP() AS etl_time         -- ETL 加载时间
FROM (
  -- 来源：dwd_fin_fund_flow_di
  SELECT
    account_no AS account_no,             -- 账户编号
    flow_type AS flow_type,               -- 流水类型
    COUNT(flow_no) AS fund_flow_qty,      -- 资金流水笔数
    NULL AS fund_in_amt,                  -- 资金流入｜待确认：sum(amount) where amount>0
    NULL AS fund_out_amt,                 -- 资金流出｜待确认：sum(-amount) where amount<0
    NULL AS fee_amt,                      -- 手续费金额｜待确认：sum(-amount) where flow_type='FEE'
    NULL AS withdraw_apply_amt,           -- 提现申请金额
    NULL AS withdraw_success_amt,         -- 提现成功金额
    NULL AS withdraw_fail_qty             -- 提现失败笔数
  FROM dwd.dwd_fin_fund_flow_di s         -- 来源表「资金流水明细」
  WHERE s.travel_date = '${bizdate}'      -- 只取当日分区
  GROUP BY account_no, flow_type          -- 按粒度键汇总
  UNION ALL                               -- 合并各来源
  -- 来源：dwd_fin_withdraw_di
  SELECT
    account_no AS account_no,             -- 账户编号
    CAST(NULL AS STRING) AS flow_type,    -- 流水类型
    NULL AS fund_flow_qty,                -- 资金流水笔数
    NULL AS fund_in_amt,                  -- 资金流入
    NULL AS fund_out_amt,                 -- 资金流出
    NULL AS fee_amt,                      -- 手续费金额
    NULL AS withdraw_apply_amt,           -- 提现申请金额｜待确认：sum(withdraw_amount)
    NULL AS withdraw_success_amt,         -- 提现成功金额｜待确认：sum(withdraw_amount) where COMPLETED
    COUNT(CASE WHEN 1 = 1 THEN withdraw_no END) AS withdraw_fail_qty  -- 提现失败笔数｜待确认：status in ('FAILED','REJECTED')
  FROM dwd.dwd_fin_withdraw_di s          -- 来源表「提现明细」
  WHERE s.travel_date = '${bizdate}'      -- 只取当日分区
  GROUP BY account_no                     -- 按粒度键汇总
) u                                       -- 各来源合并后的明细
GROUP BY u.account_no, u.flow_type;       -- 按粒度键汇总
