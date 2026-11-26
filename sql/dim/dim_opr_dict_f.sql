-- dim.dim_opr_dict_f  枚举码表
-- 粒度：1行=1个枚举值
-- 来源：ods_opr_sys_dict_df + 文档状态机枚举
-- 生成方式：Spark SQL / Hive；字段 12 个：直接翻译 12 · 规则翻译 0 · 待确认 0
-- 每个 WITH 逻辑块只取用到的列并先过滤分区

WITH
sys_dict_src AS (                            -- 主表「平台字典」，只取用到的列
  SELECT create_time, dict_code, dict_name, dict_name_en, dict_order, dict_status, dict_type, id, scope,
         tenant_id, update_time
  FROM ods.ods_opr_sys_dict_df
  WHERE travel_date = '${bizdate}'           -- 只取当日分区
)
INSERT OVERWRITE TABLE dim.dim_opr_dict_f    -- 整表覆盖写入
SELECT
  sys_dict_src.id           AS dict_id,      -- 平台字典ID（源表主键 id）
  sys_dict_src.dict_type    AS dict_type_code,  -- 字典类型
  sys_dict_src.dict_code    AS dict_code,    -- 字典代码
  sys_dict_src.dict_name    AS dict_name,    -- 字典名称
  sys_dict_src.dict_name_en AS dict_en_name,  -- 英文名称（i18n）
  sys_dict_src.dict_order   AS sort_no,      -- 排序
  sys_dict_src.dict_status  AS dict_status,  -- 状态
  sys_dict_src.scope        AS scope_type,   -- 范围
  sys_dict_src.tenant_id    AS tenant_id,    -- 租户ID
  sys_dict_src.create_time  AS create_time,  -- 创建时间
  sys_dict_src.update_time  AS update_time,  -- 更新时间
  CURRENT_TIMESTAMP()       AS etl_time      -- ETL 加载时间
FROM sys_dict_src;
