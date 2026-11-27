-- ================================================================================================
-- dim.dim_opr_region_f  行政区划维度
-- 粒度：1行=1个行政区划（省 / 市 / 区县）
-- 分区：无分区
-- 调度：每日，ODS 全部完成后；维表之间按上游顺序
-- 上游：ods_opr_region_area_df、ods_opr_country_region_df
-- 替代旧任务 4 个（上线对数一致后下线）：
--   · 数据中台/数据维度(DIM)/dim_其他/dim_city_d_f（EMR_SPARK_SQL，cron 00 05 00 * * ?）
--   · 数据中台/数据维度(DIM)/dim_其他/dim_province_d_f（EMR_SPARK_SQL，cron 00 10 00 * * ?）
--   · 数据中台/DIM/dim_city_fixed_d_f（EMR_SPARK_SQL，cron 00 10 00 * * ?）
--   · 数据平台/DIM/dim_common_region_area_df（SERVERLESS_SPARK_SQL，cron 00 11 00 * * ?）
-- 业务规则 / 修正：
--   · 上级链自关联两次得到省 / 市；修正：原条件 status = 0 实际取的是非正常记录，源表 1 = 正常
--   · 旧表 stat_date（与分区重复）、*_adcode（与区划代码相同）不再保留；area_code 统一为 region_code
-- ================================================================================================
INSERT OVERWRITE TABLE dim.dim_opr_region_f                                       -- 整表覆盖写入
SELECT
    area_code                                                    AS region_code,  -- 行政区划代码（如 110000）
    area_name                                                    AS region_name,  -- 区划名称
    short_name,                                                                   -- 简称
    join_name                                                    AS full_name,    -- 级联全称（如 福建省 厦门市 思明区）
    parent_code,                                                                  -- 上级区划代码
    CAST(level AS INT)                                           AS region_level,  -- 级别
    CAST(country_id AS BIGINT)                                   AS country_id,   -- 国家ID
    country_name,                                                                 -- 国家名称
    prov_code                                                    AS province_code,  -- 所属省代码
    prov_name                                                    AS province_name,  -- 所属省名称
    prov_zip                                                     AS province_zip_code,  -- 省邮编
    prov_lng                                                     AS province_lng,  -- 省经度
    prov_lat                                                     AS province_lat,  -- 省纬度
    CAST(city_id AS BIGINT)                                      AS city_id,      -- 所属市区划记录ID
    cty_code                                                     AS city_code,    -- 所属市代码
    cty_name                                                     AS city_name,    -- 所属市名称
    cty_zip                                                      AS city_zip_code,  -- 市邮编
    cty_lng                                                      AS city_lng,     -- 市经度
    cty_lat                                                      AS city_lat,     -- 市纬度
    dst_code                                                     AS district_code,  -- 区县代码（区县级才有）
    dst_name                                                     AS district_name,  -- 区县名称
    dst_zip                                                      AS district_zip_code,  -- 区县邮编
    dst_lng                                                      AS district_lng,  -- 区县经度
    dst_lat                                                      AS district_lat,  -- 区县纬度
    phone_area_code,                                                              -- 电话区号
    CAST(zip_code AS STRING)                                     AS zip_code,     -- 本级邮编
    CAST(lng AS STRING)                                          AS lng,          -- 本级经度
    CAST(lat AS STRING)                                          AS lat,          -- 本级纬度
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time           -- ETL 加载时间
FROM (
        SELECT a.*,
               a.city_code AS phone_area_code,                                    -- 电话区号
               c.name_zh AS country_name,                                         -- 国家名称
               -- 按本级级别定位省 / 市 / 区县：1 级本身是省；2 级本身是市、上级是省；3 级本身是区县、上级是市、上上级是省
               CASE a.level
                   WHEN 1 THEN a.area_code
                   WHEN 2 THEN p1.area_code
                   ELSE p2.area_code
               END AS prov_code,
               CASE a.level
                   WHEN 1 THEN a.area_name
                   WHEN 2 THEN p1.area_name
                   ELSE p2.area_name
               END AS prov_name,
               CAST(CASE a.level WHEN 1 THEN a.zip_code WHEN 2 THEN p1.zip_code ELSE p2.zip_code END AS STRING) AS prov_zip,
               CAST(CASE a.level WHEN 1 THEN a.lng WHEN 2 THEN p1.lng ELSE p2.lng END AS STRING) AS prov_lng,
               CAST(CASE a.level WHEN 1 THEN a.lat WHEN 2 THEN p1.lat ELSE p2.lat END AS STRING) AS prov_lat,
               CASE a.level WHEN 2 THEN a.id WHEN 3 THEN p1.id END AS city_id,    -- 所属市区划记录ID
               CASE a.level WHEN 2 THEN a.area_code WHEN 3 THEN p1.area_code END AS cty_code,
               CASE a.level WHEN 2 THEN a.area_name WHEN 3 THEN p1.area_name END AS cty_name,
               CAST(CASE a.level WHEN 2 THEN a.zip_code WHEN 3 THEN p1.zip_code END AS STRING) AS cty_zip,
               CAST(CASE a.level WHEN 2 THEN a.lng WHEN 3 THEN p1.lng END AS STRING) AS cty_lng,
               CAST(CASE a.level WHEN 2 THEN a.lat WHEN 3 THEN p1.lat END AS STRING) AS cty_lat,
               IF(a.level = 3, a.area_code, NULL) AS dst_code,
               IF(a.level = 3, a.area_name, NULL) AS dst_name,
               IF(a.level = 3, CAST(a.zip_code AS STRING), NULL) AS dst_zip,
               IF(a.level = 3, CAST(a.lng AS STRING), NULL) AS dst_lng,
               IF(a.level = 3, CAST(a.lat AS STRING), NULL) AS dst_lat
        FROM ods.ods_opr_region_area_df a                                         -- 主表「国家的地区表」
        LEFT JOIN ods.ods_opr_region_area_df p1                                   -- 关联「国家的地区表」｜上级
          ON p1.area_code = a.parent_code AND p1.travel_date = '${bizdate}'       -- 按 parent_code→area_code 关联
        LEFT JOIN ods.ods_opr_region_area_df p2                                   -- 关联「国家的地区表」｜上上级
          ON p2.area_code = p1.parent_code AND p2.travel_date = '${bizdate}'      -- 按 parent_code→area_code 关联
        LEFT JOIN ods.ods_opr_country_region_df c ON c.id = a.country_id AND c.travel_date = '${bizdate}'  -- 国家
        WHERE a.travel_date = '${bizdate}' AND a.status = 1                       -- 只取当日分区，并按条件过滤｜只取正常（1）；撤消 / 合并的不要
    ) t
