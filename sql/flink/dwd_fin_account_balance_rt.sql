-- dwd.dwd_fin_account_balance_rt  实时账户余额
-- 粒度：1行=1个账户×1日
-- 来源：ods_fin_account_rt
-- 生成方式：Flink SQL（CDC 源表 → StarRocks 主键模型表；维表 Lookup Join）；字段 12 个：直接翻译 10 · 规则翻译 2 · 待确认 0
-- 源表 ods.*_rt 为 Flink CDC 表（含 proc_time AS PROCTIME()），目标表在 StarRocks catalog 中

INSERT INTO dwd.dwd_fin_account_balance_rt                                      -- 写入 StarRocks 目标表
SELECT
  DATE_FORMAT(a.binlog_time, 'yyyyMMdd')                AS travel_date,         -- 数据日期
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
  CURRENT_TIMESTAMP                                     AS event_time           -- 事件时间（binlog 时间）
FROM ods.ods_fin_account_rt a;
