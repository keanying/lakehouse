-- dim.dim_prd_ticket_meta_f  票属性元数据码表
-- 粒度：1行=1个票属性
-- 来源：ods_prd_ticket_meta_df
-- 生成方式：Spark SQL / Hive；字段 15 个：直接翻译 15 · 规则翻译 0 · 待确认 0

INSERT OVERWRITE TABLE dim.dim_prd_ticket_meta_f  -- 整表覆盖写入
SELECT
  a.id                AS ticket_meta_id,      -- 票属性元数据ID（源表主键 id）
  a.attribute_code    AS attribute_code,      -- 属性代码（全局唯一Code）
  a.attribute_name    AS attribute_name,      -- 属性名称
  a.value_type        AS value_type,          -- 值类型
  a.default_value     AS default_value_desc,  -- 默认值
  a.scope             AS applicable_business_list_desc,  -- 适用业态（逗号分隔）
  a.impacts           AS impact_list_desc,    -- 影响链
  a.conflicts         AS conflict_list_desc,  -- 互斥属性列表
  a.depends_on        AS depend_list_desc,    -- 依赖前置属性列表
  a.enabled_when      AS enabled_when_desc,   -- 条件可用性
  a.disabled_when     AS disabled_when_desc,  -- 条件禁用
  a.attribute_status  AS attribute_status,    -- 状态
  a.create_time       AS create_time,         -- 创建时间
  a.update_time       AS update_time,         -- 更新时间
  CURRENT_TIMESTAMP() AS etl_time             -- ETL 加载时间
FROM ods.ods_prd_ticket_meta_df a             -- 主表「票属性元数据」
WHERE a.travel_date = '${bizdate}';           -- 只取当日分区
