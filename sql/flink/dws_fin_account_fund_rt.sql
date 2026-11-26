-- dws.dws_fin_account_fund_rt  账户实时资金
-- 粒度：account_no
-- 来源：dwd_fin_account_balance_rt + dwd_fin_frozen_rt
-- 生成方式：Flink SQL（持续聚合（快照类，按主键更新） → StarRocks 主键模型表）；字段 7 个：直接翻译 2 · 规则翻译 0 · 待确认 5
-- 多来源：每个来源先按粒度键预聚合，UNION ALL 后再汇总
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT INTO dws.dws_fin_account_fund_rt             -- 写入 StarRocks 目标表
WITH
src_account_balance AS (                            -- 来源「实时账户余额」按粒度键预聚合
  SELECT
    travel_date AS travel_date,                     -- 数据日期
    account_no AS account_no,                       -- 账户编号
    NULL AS available_balance_amt,                  -- 待确认：available_balance/100
    NULL AS frozen_balance_amt,                     -- 待确认：frozen_balance/100
    NULL AS freeze_amt,
    NULL AS unfreeze_verify_amt,
    NULL AS unfreeze_refund_amt
  FROM dwd.dwd_fin_account_balance_rt s             -- 来源表「实时账户余额」
  GROUP BY travel_date, account_no                  -- 按粒度键汇总
),
src_frozen AS (                                     -- 来源「实时冻结/解冻明细」按粒度键预聚合
  SELECT
    travel_date AS travel_date,                     -- 数据日期
    account_no AS account_no,                       -- 账户编号
    NULL AS available_balance_amt,
    NULL AS frozen_balance_amt,
    NULL AS freeze_amt,                             -- 待确认：sum(amount) by create_date（与离线同一口径 A058）
    NULL AS unfreeze_verify_amt,                    -- 待确认：sum(amount) where frozen_status='RELEASED' and frozen_event='VERIFY'（与离线同一口径 A059）
    NULL AS unfreeze_refund_amt                     -- 待确认：sum(amount) where RELEASED and frozen_event='REFUND'（与离线同一口径 A060）
  FROM dwd.dwd_fin_frozen_rt s                      -- 来源表「实时冻结/解冻明细」
  GROUP BY travel_date, account_no                  -- 按粒度键汇总
),
all_src AS (                                        -- 各来源字段已对齐，UNION ALL 合并（比多表 FULL JOIN 少 shuffle）
  SELECT * FROM src_account_balance
  UNION ALL
  SELECT * FROM src_frozen
)
SELECT
  u.travel_date,                                    -- 数据日期
  u.account_no,                                     -- 账户编号
  SUM(u.available_balance_amt) AS available_balance_amt,  -- 可用余额
  SUM(u.frozen_balance_amt) AS frozen_balance_amt,  -- 冻结余额
  SUM(u.freeze_amt) AS freeze_amt,                  -- 冻结金额
  SUM(u.unfreeze_verify_amt) AS unfreeze_verify_amt,  -- 核销解冻金额
  SUM(u.unfreeze_refund_amt) AS unfreeze_refund_amt,  -- 退款释放金额
  CURRENT_TIMESTAMP AS update_time                  -- 最近一次写入时间
FROM all_src u
GROUP BY u.travel_date, u.account_no;               -- 按粒度键汇总
