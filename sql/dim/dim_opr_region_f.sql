-- dim.dim_opr_region_f  地区维度
-- 粒度：1行=1个末级地区
-- 来源：ods_opr_region_df + ods_opr_country_df
-- 生成方式：Spark SQL / Hive；字段 21 个：直接翻译 14 · 规则翻译 3 · 待确认 4
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT OVERWRITE TABLE dim.dim_opr_region_f       -- 整表覆盖写入
SELECT
  a.id                         AS region_id,      -- 地区字典ID（源表主键 id）
  a.region_code                AS region_code,    -- 行政区划码(国标
  a.parent_id                  AS parent_id,      -- 上级地区ID
  a.country_code               AS country_code,   -- 所属国家码(冗余
  a.region_level               AS region_level_no,  -- 层级
  a.region_path                AS region_path_desc,  -- 完整路径含自身
  a.region_status              AS region_status,  -- 状态
  a.sort_order                 AS sort_no,        -- 排序权重
  a.create_time                AS create_time,    -- 创建时间
  a.update_time                AS update_time,    -- 更新时间
  j1.field_value               AS region_name,    -- 地区名称（中文）｜待确认：ods_opr_i18n_translation_df.field_value 取 zh-CN
  j1.field_value               AS country_name,   -- 国家名称
  j2.iso3_code                 AS iso3_code,      -- 国家三位码
  a.parent_id                  AS province_code,  -- 所属省份编码｜待确认：ods_opr_region_df.parent_id 递归到 region_level=1
  SPLIT(a.region_path, '/')[1] AS province_name,  -- 所属省份名称
  a.parent_id                  AS city_code,      -- 所属城市编码｜待确认：ods_opr_region_df.parent_id 递归到 region_level=2
  SPLIT(a.region_path, '/')[2] AS city_name,      -- 所属城市名称
  a.region_code                AS district_code,  -- 区县编码｜待确认：ods_opr_region_df.region_code（region_level=3 时）
  SPLIT(a.region_path, '/')[3] AS district_name,  -- 区县名称
  a.region_code                AS id_card_prefix_code,  -- 身份证前 6 位行政区划码
  CURRENT_TIMESTAMP()          AS etl_time        -- ETL 加载时间
FROM ods.ods_opr_region_df a                      -- 主表「地区字典」
LEFT JOIN ods.ods_opr_i18n_translation_df j1      -- 关联「翻译表」，取 地区名称（中文）、国家名称
  ON j1.id = a.parent_id                          -- 按 parent_id→id 关联
 AND j1.travel_date = '${bizdate}'                -- 只取当日分区
LEFT JOIN ods.ods_opr_country_df j2               -- 关联「国家字典」，取 国家三位码
  ON j2.country_code = a.country_code             -- 按 country_code 关联
 AND j2.travel_date = '${bizdate}'                -- 只取当日分区
WHERE a.travel_date = '${bizdate}';               -- 只取当日分区
