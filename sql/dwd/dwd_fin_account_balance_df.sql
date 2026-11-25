-- dwd.dwd_fin_account_balance_df  账户余额日快照
-- 粒度：1行=1个账户×1日
-- 来源：ods_fin_account_df
-- 生成方式：Spark SQL / Hive；字段 11 个：直接翻译 10 · 规则翻译 1 · 待确认 0

INSERT OVERWRITE TABLE dwd.dwd_fin_account_balance_df PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  a.id                                                  AS account_id,          -- 统一账户ID（源表主键 id）
  a.account_no                                          AS account_no,          -- 账户编号
  a.subject_id                                          AS subject_id,          -- 主体ID（商户/分销商/平台）
  a.account_kind                                        AS account_type,        -- 账户类型
  ROUND(a.available_balance / 100, 2)                   AS available_balance_amt,  -- 可用余额（元）
  ROUND(a.frozen_balance / 100, 2)                      AS frozen_balance_amt,  -- 冻结余额（元）
  a.tenant_id                                           AS tenant_id,           -- 租户ID（分库维度）
  a.create_time                                         AS create_time,         -- 创建时间
  a.update_time                                         AS update_time,         -- 更新时间
  ROUND(a.available_balance + a.frozen_balance /100, 2) AS total_balance_amt,   -- 账户总余额
  CURRENT_TIMESTAMP()                                   AS etl_time             -- ETL 加载时间
FROM ods.ods_fin_account_df a                                                   -- 主表「统一账户」
WHERE a.travel_date = '${bizdate}';                                             -- 只取当日分区
