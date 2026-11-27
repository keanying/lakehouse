-- dws.dws_fin_account_flow_di  账户×流水类型 资金日汇总
-- 粒度：travel_date × account_no × flow_type
-- 来源：dwd_fin_fund_flow_di, dwd_fin_withdraw_di
-- 生成方式：Spark SQL / Hive；字段 10 个：直接翻译 2 · 规则翻译 8 · 待确认 0
-- 多来源：每个来源先按粒度键预聚合，UNION ALL 后再汇总

WITH
src_fund_flow AS (                                                   -- 来源「资金流水明细」按粒度键预聚合
  SELECT
    account_no AS account_no,                                        -- 账户编号
    flow_type AS flow_type,                                          -- 流水类型
    COUNT(flow_no) AS fund_flow_qty,                                 -- 资金流水笔数
    SUM(CASE WHEN change_amt>0 THEN change_amt END) AS fund_in_amt,  -- 资金流入
    SUM(CASE WHEN change_amt<0 THEN -change_amt END) AS fund_out_amt,  -- 资金流出
    SUM(CASE WHEN flow_type='FEE' THEN -change_amt END) AS fee_amt,  -- 手续费金额
    NULL AS withdraw_apply_amt,
    NULL AS withdraw_success_amt,
    NULL AS withdraw_fail_qty
  FROM dwd.dwd_fin_fund_flow_di s                                    -- 来源表「资金流水明细」
  WHERE s.travel_date = '${bizdate}'                                 -- 只取当日分区
  GROUP BY account_no, flow_type                                     -- 按粒度键汇总
),
src_withdraw AS (                                                    -- 来源「提现明细」按粒度键预聚合
  SELECT
    account_no AS account_no,                                        -- 账户编号
    CAST(NULL AS STRING) AS flow_type,
    NULL AS fund_flow_qty,
    NULL AS fund_in_amt,
    NULL AS fund_out_amt,
    NULL AS fee_amt,
    SUM(withdraw_amt) AS withdraw_apply_amt,                         -- 提现申请金额
    SUM(CASE WHEN withdraw_status = 'COMPLETED' THEN withdraw_amt END) AS withdraw_success_amt,  -- 提现成功金额
    COUNT(CASE WHEN withdraw_status IN ('FAILED', 'REJECTED') THEN withdraw_no END) AS withdraw_fail_qty  -- 提现失败笔数｜口径：提现失败或被驳回
  FROM dwd.dwd_fin_withdraw_di s                                     -- 来源表「提现明细」
  WHERE s.travel_date = '${bizdate}'                                 -- 只取当日分区
  GROUP BY account_no                                                -- 按粒度键汇总
),
all_src AS (                                                         -- 各来源字段已对齐，UNION ALL 合并（比多表 FULL JOIN 少 shuffle）
  SELECT * FROM src_fund_flow
  UNION ALL
  SELECT * FROM src_withdraw
)
INSERT OVERWRITE TABLE dws.dws_fin_account_flow_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  u.account_no,                                                      -- 账户编号
  u.flow_type,                                                       -- 流水类型
  SUM(u.fund_flow_qty) AS fund_flow_qty,                             -- 资金流水笔数
  SUM(u.fund_in_amt) AS fund_in_amt,                                 -- 资金流入
  SUM(u.fund_out_amt) AS fund_out_amt,                               -- 资金流出
  SUM(u.fee_amt) AS fee_amt,                                         -- 手续费金额
  SUM(u.withdraw_apply_amt) AS withdraw_apply_amt,                   -- 提现申请金额
  SUM(u.withdraw_success_amt) AS withdraw_success_amt,               -- 提现成功金额
  SUM(u.withdraw_fail_qty) AS withdraw_fail_qty,                     -- 提现失败笔数
  CURRENT_TIMESTAMP() AS etl_time                                    -- ETL 加载时间
FROM all_src u
GROUP BY u.account_no, u.flow_type;                                  -- 按粒度键汇总
