-- dim.dim_opr_region_f  地区维度
-- 粒度：1行=1个末级地区
-- 来源：ods_opr_region_df + ods_opr_i18n_translation_df + ods_opr_country_df
-- 生成方式：手写（结构不适合按字段自动翻译）；业务规则：
--   · 省 / 市 / 区县编码：沿 parent_id 向上自关联，取层级为 1 / 2 / 3 的祖先（含自身）的行政区划码
--   · 名称：翻译表 zh-CN（表 t_region、字段 region_name、实体 = 地区 ID）；翻译缺失时取完整路径最后一段；省市区名称取完整路径对应段
--   · 身份证前 6 位 = 区县行政区划码，客源地解析按此关联
-- 性能：
--   · 地区表约数千行，全量覆盖

WITH r AS (
    SELECT id, region_code, parent_id, country_code, region_level, region_path, region_status, sort_order, create_time, update_time
    FROM ods.ods_opr_region_df WHERE travel_date = '${bizdate}'
),
tr AS (                                                                           -- 地区中文名（口径说明：翻译表的表名 / 字段名按 t_region.region_name 约定）
    SELECT entity_id, MAX(field_value) AS name_cn
    FROM ods.ods_opr_i18n_translation_df
    WHERE travel_date = '${bizdate}' AND table_name = 't_region' AND field_name = 'region_name' AND locale = 'zh-CN'  -- 只取当日分区，并按条件过滤
    GROUP BY entity_id                                                            -- 按粒度键汇总
),
x AS (
    SELECT r.*, p1.region_code AS c1, p1.region_level AS l1, p2.region_code AS c2, p2.region_level AS l2,
           p3.region_code AS c3, p3.region_level AS l3, p4.region_code AS c4, p4.region_level AS l4
    FROM r
    LEFT JOIN r p1 ON p1.id = r.parent_id
    LEFT JOIN r p2 ON p2.id = p1.parent_id
    LEFT JOIN r p3 ON p3.id = p2.parent_id
    LEFT JOIN r p4 ON p4.id = p3.parent_id
),
country_src AS (
    SELECT country_code, iso3_code FROM ods.ods_opr_country_df WHERE travel_date = '${bizdate}'
)
INSERT OVERWRITE TABLE dim.dim_opr_region_f                                       -- 整表覆盖写入
SELECT /*+ BROADCAST(country_src) */
    x.id AS region_id, x.region_code, x.parent_id, x.country_code, x.region_level AS region_level_no, x.region_path AS region_path_desc,  -- 完整路径含自身
    x.region_status, x.sort_order AS sort_no, x.create_time, x.update_time,
    COALESCE(tr.name_cn, ELEMENT_AT(SPLIT(x.region_path, '/'), -1))                       AS region_name,  -- 地区名称（中文）
    SPLIT(x.region_path, '/')[0]                                                           AS country_name,  -- 国家名称
    c.iso3_code,                                                                  -- 国家三位码
    COALESCE(IF(x.region_level = 1, x.region_code, NULL), IF(x.l1 = 1, x.c1, NULL), IF(x.l2 = 1, x.c2, NULL), IF(x.l3 = 1, x.c3, NULL), IF(x.l4 = 1, x.c4, NULL)) AS province_code,  -- 所属省份编码
    SPLIT(x.region_path, '/')[1]                                                           AS province_name,  -- 所属省份名称
    COALESCE(IF(x.region_level = 2, x.region_code, NULL), IF(x.l1 = 2, x.c1, NULL), IF(x.l2 = 2, x.c2, NULL), IF(x.l3 = 2, x.c3, NULL)) AS city_code,  -- 所属城市编码
    SPLIT(x.region_path, '/')[2]                                                           AS city_name,  -- 所属城市名称
    COALESCE(IF(x.region_level = 3, x.region_code, NULL), IF(x.l1 = 3, x.c1, NULL), IF(x.l2 = 3, x.c2, NULL)) AS district_code,  -- 区县编码
    SPLIT(x.region_path, '/')[3]                                                           AS district_name,  -- 区县名称
    IF(x.region_level = 3, x.region_code, NULL)                                            AS id_card_prefix_code,  -- 身份证前 6 位行政区划码
    CURRENT_TIMESTAMP() AS etl_time                                               -- ETL 加载时间
FROM x
LEFT JOIN tr ON tr.entity_id = x.id
LEFT JOIN country_src c ON c.country_code = x.country_code;
