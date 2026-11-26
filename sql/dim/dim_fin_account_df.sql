-- dim.dim_fin_account_df  账户维度
-- 粒度：1行=1个账户
-- 来源：ods_fin_account_df
-- 生成方式：Spark SQL / Hive；字段 9 个：直接翻译 9 · 规则翻译 0 · 待确认 0
-- 每个 WITH 逻辑块只取用到的列并先过滤分区

WITH
account_src AS (                                    -- 主表「统一账户」，只取用到的列
  SELECT account_kind, account_no, create_time, id, subject_id, tenant_id, update_time
  FROM ods.ods_fin_account_df
  WHERE travel_date = '${bizdate}'                  -- 只取当日分区
),
tenant_cur AS (                                     -- 「租户（商户/供应商/分销商）维度」当前有效版本，只取用到的列
  SELECT tenant_id, tenant_name
  FROM dim.dim_sup_tenant_zip
  WHERE travel_date = '${bizdate}' AND end_date = '9999-12-31'  -- 取当日分区里的拉链当前有效版本
)
INSERT OVERWRITE TABLE dim.dim_fin_account_df PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  account_src.id           AS account_id,           -- 统一账户ID（源表主键 id）
  account_src.account_no   AS account_no,           -- 账户编号
  account_src.subject_id   AS subject_id,           -- 主体ID（商户/分销商/平台）
  account_src.account_kind AS account_type,         -- 账户类型
  account_src.tenant_id    AS tenant_id,            -- 租户ID（分库维度）
  account_src.create_time  AS create_time,          -- 创建时间
  account_src.update_time  AS update_time,          -- 更新时间
  tenant_cur.tenant_name   AS subject_name,         -- 主体名称
  CURRENT_TIMESTAMP()      AS etl_time              -- ETL 加载时间
FROM account_src
LEFT JOIN tenant_cur                                -- 关联「租户（商户/供应商/分销商）维度」，取 主体名称
  ON tenant_cur.tenant_id = account_src.tenant_id;  -- 按 tenant_id 关联
