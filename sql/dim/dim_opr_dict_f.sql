-- dim.dim_opr_dict_f  枚举码表
-- 粒度：1行=1个枚举值
-- 来源：ods_opr_sys_dict_df + 文档状态机枚举
-- 生成方式：Spark SQL / Hive；字段 12 个：直接翻译 12 · 规则翻译 0 · 待确认 0

INSERT OVERWRITE TABLE dim.dim_opr_dict_f
SELECT
  a.id                AS dict_id,
  a.dict_type         AS dict_type_code,
  a.dict_code         AS dict_code,
  a.dict_name         AS dict_name,
  a.dict_name_en      AS dict_en_name,
  a.dict_order        AS sort_no,
  a.dict_status       AS dict_status,
  a.scope             AS scope_type,
  a.tenant_id         AS tenant_id,
  a.create_time       AS create_time,
  a.update_time       AS update_time,
  CURRENT_TIMESTAMP() AS etl_time
FROM ods.ods_opr_sys_dict_df a
WHERE a.travel_date = '${bizdate}';
