-- dim.dim_prd_ticket_meta_f  票属性元数据码表
-- 粒度：1行=1个票属性
-- 来源：ods_prd_ticket_meta_df
-- 生成方式：Spark SQL / Hive；字段 15 个：直接翻译 15 · 规则翻译 0 · 待确认 0
-- 每个 WITH 逻辑块只取用到的列并先过滤分区

WITH
ticket_meta_src AS (                                       -- 主表「票属性元数据」，只取用到的列
  SELECT attribute_code, attribute_name, attribute_status, conflicts, create_time, default_value,
         depends_on, disabled_when, enabled_when, id, impacts, scope, update_time, value_type
  FROM ods.ods_prd_ticket_meta_df
  WHERE travel_date = '${bizdate}'                         -- 只取当日分区
)
INSERT OVERWRITE TABLE dim.dim_prd_ticket_meta_f           -- 整表覆盖写入
SELECT
  ticket_meta_src.id               AS ticket_meta_id,      -- 票属性元数据ID（源表主键 id）
  ticket_meta_src.attribute_code   AS attribute_code,      -- 属性代码（全局唯一Code）
  ticket_meta_src.attribute_name   AS attribute_name,      -- 属性名称
  ticket_meta_src.value_type       AS value_type,          -- 值类型
  ticket_meta_src.default_value    AS default_value_desc,  -- 默认值
  ticket_meta_src.scope            AS applicable_business_list_desc,  -- 适用业态（逗号分隔）
  ticket_meta_src.impacts          AS impact_list_desc,    -- 影响链
  ticket_meta_src.conflicts        AS conflict_list_desc,  -- 互斥属性列表
  ticket_meta_src.depends_on       AS depend_list_desc,    -- 依赖前置属性列表
  ticket_meta_src.enabled_when     AS enabled_when_desc,   -- 条件可用性
  ticket_meta_src.disabled_when    AS disabled_when_desc,  -- 条件禁用
  ticket_meta_src.attribute_status AS attribute_status,    -- 状态
  ticket_meta_src.create_time      AS create_time,         -- 创建时间
  ticket_meta_src.update_time      AS update_time,         -- 更新时间
  CURRENT_TIMESTAMP()              AS etl_time             -- ETL 加载时间
FROM ticket_meta_src;
