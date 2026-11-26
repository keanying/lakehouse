-- dim.dim_opr_region_f  地区维度
-- 粒度：1行=1个末级地区
-- 来源：ods_opr_region_df + ods_opr_country_df
-- 生成方式：Spark SQL / Hive；字段 21 个：直接翻译 14 · 规则翻译 3 · 待确认 4
-- 每个 WITH 逻辑块只取用到的列并先过滤分区
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

WITH
region_src AS (                                            -- 主表「地区字典」，只取用到的列
  SELECT country_code, create_time, id, parent_id, region_code, region_level, region_path, region_status,
         sort_order, update_time
  FROM ods.ods_opr_region_df
  WHERE travel_date = '${bizdate}'                         -- 只取当日分区
),
i18n_translation_src AS (                                  -- 「翻译表」当日数据，只取用到的列
  SELECT field_value, id
  FROM ods.ods_opr_i18n_translation_df
  WHERE travel_date = '${bizdate}'                         -- 只取当日分区
),
country_src AS (                                           -- 「国家字典」当日数据，只取用到的列
  SELECT country_code, iso3_code
  FROM ods.ods_opr_country_df
  WHERE travel_date = '${bizdate}'                         -- 只取当日分区
)
INSERT OVERWRITE TABLE dim.dim_opr_region_f                -- 整表覆盖写入
SELECT
  region_src.id                         AS region_id,      -- 地区字典ID（源表主键 id）
  region_src.region_code                AS region_code,    -- 行政区划码(国标
  region_src.parent_id                  AS parent_id,      -- 上级地区ID
  region_src.country_code               AS country_code,   -- 所属国家码(冗余
  region_src.region_level               AS region_level_no,  -- 层级
  region_src.region_path                AS region_path_desc,  -- 完整路径含自身
  region_src.region_status              AS region_status,  -- 状态
  region_src.sort_order                 AS sort_no,        -- 排序权重
  region_src.create_time                AS create_time,    -- 创建时间
  region_src.update_time                AS update_time,    -- 更新时间
  i18n_translation_src.field_value      AS region_name,    -- 地区名称（中文）｜待确认：ods_opr_i18n_translation_df.field_value 取 zh-CN
  i18n_translation_src.field_value      AS country_name,   -- 国家名称
  country_src.iso3_code                 AS iso3_code,      -- 国家三位码
  region_src.parent_id                  AS province_code,  -- 所属省份编码｜待确认：ods_opr_region_df.parent_id 递归到 region_level=1
  SPLIT(region_src.region_path, '/')[1] AS province_name,  -- 所属省份名称
  region_src.parent_id                  AS city_code,      -- 所属城市编码｜待确认：ods_opr_region_df.parent_id 递归到 region_level=2
  SPLIT(region_src.region_path, '/')[2] AS city_name,      -- 所属城市名称
  region_src.region_code                AS district_code,  -- 区县编码｜待确认：ods_opr_region_df.region_code（region_level=3 时）
  SPLIT(region_src.region_path, '/')[3] AS district_name,  -- 区县名称
  region_src.region_code                AS id_card_prefix_code,  -- 身份证前 6 位行政区划码
  CURRENT_TIMESTAMP()                   AS etl_time        -- ETL 加载时间
FROM region_src
LEFT JOIN i18n_translation_src                             -- 关联「翻译表」，取 地区名称（中文）、国家名称
  ON i18n_translation_src.id = region_src.parent_id        -- 按 parent_id→id 关联
LEFT JOIN country_src                                      -- 关联「国家字典」，取 国家三位码
  ON country_src.country_code = region_src.country_code;   -- 按 country_code 关联
