-- dim.dim_opr_dict_f  枚举码表
-- 粒度：1行=1个枚举值
-- 来源：ods_opr_sys_dict_df + 文档状态机枚举
-- 生成方式：Spark SQL / Hive；字段 12 个：直接翻译 12 · 规则翻译 0 · 待确认 0

INSERT OVERWRITE TABLE dim.dim_opr_dict_f  -- 整表覆盖写入
SELECT
  a.id                AS dict_id,       -- 平台字典ID（源表主键 id）
  a.dict_type         AS dict_type_code,  -- 字典类型
  a.dict_code         AS dict_code,     -- 字典代码
  a.dict_name         AS dict_name,     -- 字典名称
  a.dict_name_en      AS dict_en_name,  -- 英文名称（i18n）
  a.dict_order        AS sort_no,       -- 排序
  a.dict_status       AS dict_status,   -- 状态
  a.scope             AS scope_type,    -- 范围
  a.tenant_id         AS tenant_id,     -- 租户ID
  a.create_time       AS create_time,   -- 创建时间
  a.update_time       AS update_time,   -- 更新时间
  CURRENT_TIMESTAMP() AS etl_time       -- ETL 加载时间
FROM ods.ods_opr_sys_dict_df a          -- 主表「平台字典」
WHERE a.travel_date = '${bizdate}';     -- 只取当日分区
