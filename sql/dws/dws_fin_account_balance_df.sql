-- dws.dws_fin_account_balance_df  账户余额日快照
-- 粒度：travel_date × account_no
-- 来源：dwd_fin_account_balance_df, dwd_fin_fund_flow_di
-- 生成方式：Spark SQL / Hive；字段 5 个：直接翻译 1 · 规则翻译 4 · 待确认 0
-- 多来源：每个来源先按粒度键预聚合，UNION ALL 后再汇总；快照/累计表：增量来源取截至统计日的全部分区
-- 补 0 / 补空列：多来源 UNION ALL 时，某来源不产出的指标补 0 或空，外层按粒度 SUM 后即为各来源之和，不影响结果

WITH
src_account_balance AS (                                  -- 来源「账户余额日快照」按粒度键预聚合
  SELECT
    account_no AS account_no,                             -- 账户编号
    SUM(available_balance_amt) AS available_balance_amt,  -- 可用余额
    SUM(frozen_balance_amt) AS frozen_balance_amt,        -- 冻结余额
    NULL AS opening_balance_amt,                          -- 期初余额：此来源不产出，补空
    NULL AS closing_balance_amt                           -- 期末余额：此来源不产出，补空
  FROM dwd.dwd_fin_account_balance_df s                   -- 来源表「账户余额日快照」
  WHERE s.travel_date = '${bizdate}'                      -- 只取当日分区
  GROUP BY account_no                                     -- 按粒度键汇总
),
src_fund_flow AS (                                        -- 来源「资金流水明细」按粒度键预聚合
  SELECT
    account_no AS account_no,                             -- 账户编号
    NULL AS available_balance_amt,                        -- 可用余额：此来源不产出，补空
    NULL AS frozen_balance_amt,                           -- 冻结余额：此来源不产出，补空
    MIN_BY(balance_before_amt, flow_id) AS opening_balance_amt,  -- 期初余额｜口径：当日第一笔流水的变动前余额（按流水主键自增顺序）
    MAX_BY(balance_after_amt, flow_id) AS closing_balance_amt  -- 期末余额｜口径：当日最后一笔流水的变动后余额
  FROM dwd.dwd_fin_fund_flow_di s                         -- 来源表「资金流水明细」
  WHERE s.travel_date <= '${bizdate}'                     -- 累计口径：取截至统计日的全部分区
  GROUP BY account_no                                     -- 按粒度键汇总
),
all_src AS (                                              -- 各来源字段已对齐，UNION ALL 合并（比多表 FULL JOIN 少 shuffle）
  SELECT * FROM src_account_balance
  UNION ALL
  SELECT * FROM src_fund_flow
)
INSERT OVERWRITE TABLE dws.dws_fin_account_balance_df PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  u.account_no,                                           -- 账户编号
  SUM(u.available_balance_amt) AS available_balance_amt,  -- 可用余额
  SUM(u.frozen_balance_amt) AS frozen_balance_amt,        -- 冻结余额
  SUM(u.opening_balance_amt) AS opening_balance_amt,      -- 期初余额
  SUM(u.closing_balance_amt) AS closing_balance_amt,      -- 期末余额
  CURRENT_TIMESTAMP() AS etl_time                         -- ETL 加载时间
FROM all_src u
GROUP BY u.account_no;                                    -- 按粒度键汇总
