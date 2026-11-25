-- dim.dim_fin_account_df  账户维度
-- 粒度：1行=1个账户
-- 来源：ods_fin_account_df
-- 生成方式：Spark SQL / Hive；字段 9 个：直接翻译 9 · 规则翻译 0 · 待确认 0

INSERT OVERWRITE TABLE dim.dim_fin_account_df PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  a.id                AS account_id,    -- 统一账户ID（源表主键 id）
  a.account_no        AS account_no,    -- 账户编号
  a.subject_id        AS subject_id,    -- 主体ID（商户/分销商/平台）
  a.account_kind      AS account_type,  -- 账户类型
  a.tenant_id         AS tenant_id,     -- 租户ID（分库维度）
  a.create_time       AS create_time,   -- 创建时间
  a.update_time       AS update_time,   -- 更新时间
  j1.tenant_name      AS subject_name,  -- 主体名称
  CURRENT_TIMESTAMP() AS etl_time       -- ETL 加载时间
FROM ods.ods_fin_account_df a           -- 主表「统一账户」
LEFT JOIN dim.dim_sup_tenant_zip j1     -- 关联「租户（商户/供应商/分销商）维度」，取 主体名称
  ON j1.tenant_id = a.tenant_id         -- 按 tenant_id 关联
 AND j1.travel_date = '${bizdate}' AND j1.end_date = '9999-12-31'  -- 取当日分区里的拉链当前有效版本
WHERE a.travel_date = '${bizdate}';     -- 只取当日分区
