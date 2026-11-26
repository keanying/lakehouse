-- dwd.dwd_fin_account_balance_df  账户余额日快照
-- 粒度：1行=1个账户×1日
-- 来源：ods_fin_account_df
-- 生成方式：Spark SQL / Hive；字段 11 个：直接翻译 10 · 规则翻译 1 · 待确认 0
-- 每个 WITH 逻辑块只取用到的列并先过滤分区

WITH
account_src AS (                                                                  -- 主表「统一账户」，只取用到的列
  SELECT account_kind, account_no, available_balance, create_time, frozen_balance, id, subject_id,
         tenant_id, update_time
  FROM ods.ods_fin_account_df
  WHERE travel_date = '${bizdate}'                                                -- 只取当日分区
)
INSERT OVERWRITE TABLE dwd.dwd_fin_account_balance_df PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  account_src.id                                               AS account_id,     -- 统一账户ID（源表主键 id）
  account_src.account_no                                       AS account_no,     -- 账户编号
  account_src.subject_id                                       AS subject_id,     -- 主体ID（商户/分销商/平台）
  account_src.account_kind                                     AS account_type,   -- 账户类型
  ROUND(account_src.available_balance / 100, 2)                AS available_balance_amt,  -- 可用余额（元）
  ROUND(account_src.frozen_balance / 100, 2)                   AS frozen_balance_amt,  -- 冻结余额（元）
  account_src.tenant_id                                        AS tenant_id,      -- 租户ID（分库维度）
  account_src.create_time                                      AS create_time,    -- 创建时间
  account_src.update_time                                      AS update_time,    -- 更新时间
  ROUND(account_src.available_balance + account_src.frozen_balance /100, 2) AS total_balance_amt,  -- 账户总余额
  CURRENT_TIMESTAMP()                                          AS etl_time        -- ETL 加载时间
FROM account_src;
