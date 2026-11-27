-- ================================================================================================
-- ads.ads_fin_balance_report_rt  余额报表（实时 · 日 × 账本）
-- 依据：《3.0 通用财务报表 · 需求说明》v1.0（2026-11-24）
-- 业务规则：
--   · 余额报表始终实时（6.3）：直接由实时余额明细（保留全部历史）按日 × 账本汇总
--   · 期初 = 当日第一笔流水的变动前余额，期末 = 最后一笔的变动后余额（快照值，5.7）
-- 性能：
--   · StarRocks 异步物化视图，按 travel_date 分区增量刷新
-- ================================================================================================

CREATE MATERIALIZED VIEW IF NOT EXISTS ads.ads_fin_balance_report_rt              -- 异步物化视图，StarRocks 定时刷新
PARTITION BY travel_date
REFRESH ASYNC EVERY (INTERVAL 1 MINUTE)
AS
SELECT travel_date, merchant_tenant_id, account_no,
       MIN_BY(balance_before_amt, flow_time)                         AS balance_open_amt,  -- 期初余额（日快照）
       SUM(balance_in_amt)                                           AS balance_in_amt,  -- 资金流入
       SUM(balance_out_amt)                                          AS balance_out_amt,  -- 资金流出
       MAX_BY(balance_after_amt, flow_time)                          AS balance_close_amt,  -- 期末余额（日快照）
       SUM(IF(flow_type = 'RECHARGE' AND change_amt > 0, change_amt, 0))    AS recharge_amt,  -- 其中充值
       SUM(IF(flow_type = 'WITHDRAW' AND change_amt < 0, -change_amt, 0))   AS withdraw_amt,  -- 其中提现
       SUM(IF(report_code = 'EXPENSE' AND change_amt > 0, change_amt, 0))   AS expense_income_amt,  -- 费用收入（二期 · 费用收支报表）
       SUM(IF(report_code = 'EXPENSE' AND change_amt < 0, -change_amt, 0))  AS expense_out_amt,  -- 费用支出（二期 · 费用收支报表）
       SUM(IF(report_code = 'UNCLASSIFIED', 1, 0))                   AS unclassified_flow_qty,  -- 待归类流水笔数（应为 0）
       NOW()                                                         AS update_time  -- 最近一次刷新时间
FROM dwd.dwd_fin_balance_detail_rt
GROUP BY travel_date, merchant_tenant_id, account_no;                             -- 按粒度键汇总
