-- dws.dws_fin_account_fund_rt  账户实时资金
-- 粒度：account_no
-- 来源：dwd_fin_account_balance_rt + dwd_fin_frozen_rt
-- 生成方式：Flink SQL（持续聚合（快照类，按主键更新） → StarRocks 主键模型表）；字段 7 个：直接翻译 2 · 规则翻译 5 · 待确认 0
-- 多来源：每个来源先按粒度键预聚合，UNION ALL 后再汇总

INSERT INTO dws.dws_fin_account_fund_rt               -- 写入 StarRocks 目标表
WITH
src_account_balance AS (                              -- 来源「实时账户余额」按粒度键预聚合
  SELECT
    travel_date AS travel_date,                       -- 数据日期
    account_no AS account_no,                         -- 账户编号
    SUM(available_balance_amt) AS available_balance_amt,  -- 可用余额
    SUM(frozen_balance_amt) AS frozen_balance_amt,    -- 冻结余额
    NULL AS freeze_amt,                               -- 冻结金额：本来源无，补空对齐 UNION ALL
    NULL AS unfreeze_verify_amt,                      -- 核销解冻金额：本来源无，补空对齐 UNION ALL
    NULL AS unfreeze_refund_amt                       -- 退款释放金额：本来源无，补空对齐 UNION ALL
  FROM dwd.dwd_fin_account_balance_rt s               -- 来源表「实时账户余额」
  GROUP BY travel_date, account_no                    -- 按粒度键汇总
),
src_frozen AS (                                       -- 来源「实时冻结/解冻明细」按粒度键预聚合
  SELECT
    travel_date AS travel_date,                       -- 数据日期
    account_no AS account_no,                         -- 账户编号
    NULL AS available_balance_amt,                    -- 可用余额：本来源无，补空对齐 UNION ALL
    NULL AS frozen_balance_amt,                       -- 冻结余额：本来源无，补空对齐 UNION ALL
    SUM(freeze_amt) AS freeze_amt,                    -- 冻结金额
    SUM(CASE WHEN frozen_status='RELEASED' and release_event_type='VERIFY' THEN freeze_amt END) AS unfreeze_verify_amt,  -- 核销解冻金额
    SUM(CASE WHEN frozen_status = 'RELEASED' and release_event_type='REFUND' THEN freeze_amt END) AS unfreeze_refund_amt  -- 退款释放金额
  FROM dwd.dwd_fin_frozen_rt s                        -- 来源表「实时冻结/解冻明细」
  GROUP BY travel_date, account_no                    -- 按粒度键汇总
),
all_src AS (                                          -- 各来源字段已对齐，UNION ALL 合并（比多表 FULL JOIN 少 shuffle）
  SELECT * FROM src_account_balance
  UNION ALL
  SELECT * FROM src_frozen
)
SELECT
  u.travel_date,                                      -- 数据日期
  u.account_no,                                       -- 账户编号
  SUM(u.available_balance_amt) AS available_balance_amt,  -- 可用余额
  SUM(u.frozen_balance_amt) AS frozen_balance_amt,    -- 冻结余额
  SUM(u.freeze_amt) AS freeze_amt,                    -- 冻结金额
  SUM(u.unfreeze_verify_amt) AS unfreeze_verify_amt,  -- 核销解冻金额
  SUM(u.unfreeze_refund_amt) AS unfreeze_refund_amt,  -- 退款释放金额
  CURRENT_TIMESTAMP AS update_time                    -- 最近一次写入时间
FROM all_src u
GROUP BY u.travel_date, u.account_no;                 -- 按粒度键汇总
