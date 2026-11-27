-- ================================================================================================
-- dim.dim_opr_phone_area_f  手机号段 / 国际区号维度
-- 粒度：1行=1个手机号段（前 7 位）或 1 个国际电话区号
-- 分区：无分区
-- 调度：每日，ODS 全部完成后；维表之间按上游顺序
-- 上游：ods_opr_city_phone_df、ods_opr_global_phone_area_df、ods_opr_country_region_df
-- 替代旧任务 5 个（上线对数一致后下线）：
--   · 数据中台/数据维度(DIM)/dim_其他/dim_phone_city_d_f（EMR_SPARK_SQL，cron 00 08 00 * * ?）
--   · 数据中台/DIM/dim_phone_city_fixed_d_f_workflow/dim_phone_city_fixed_d_f（EMR_SPARK_SQL，cron 00 00 00 * * ?）
--   · 数据中台/DIM/dim_phone_global_d_f（EMR_SPARK_SQL，cron 00 15 00 * * ?）
--   · 数据平台/DIM/dim_common_phone_prefix_area_df（SERVERLESS_SPARK_SQL，cron 00 25 00 * * ?）
--   · 数据平台/DIM/dim_common_phone_code_country_df（SERVERLESS_SPARK_SQL，cron 00 10 00 * * ?）
-- 业务规则 / 修正：
--   · 号段与国际区号两类 UNION ALL（phone_prefix_type 区分）；号段到地市级，没有区县
--   · 旧表 phone_city_id / phone_number（与主键、号段重复）、stat_date 不再保留；号段、区号是编码不是个人号码，ODS 不再误脱敏
-- ================================================================================================
-- 置空列：多个源表 UNION ALL 归一时，某源表没有的字段置空（各源表字段对照见各分支）
INSERT OVERWRITE TABLE dim.dim_opr_phone_area_f                                   -- 整表覆盖写入
-- (1) ods_opr_city_phone_df
SELECT
    'SEGMENT'                                                    AS phone_prefix_type,  -- 前缀类型
    CAST(number AS STRING)                                       AS phone_prefix,  -- 前缀
    CAST(type AS INT)                                            AS carrier_type,  -- 运营商
    CAST(province_code AS STRING)                                AS province_code,  -- 省编码
    province_name,                                                                -- 省名称
    CAST(city_code AS STRING)                                    AS city_code,    -- 市编码
    city_name,                                                                    -- 市名称
    COALESCE(pft_area_code, CAST(area_code AS STRING))           AS area_code,    -- 区域编码（平台区域码）
    zip_code,                                                                     -- 邮编
    CAST(country_code AS STRING)                                 AS country_code,  -- 国家编码
    country_name,                                                                 -- 国家名称（中文）
    CAST(NULL AS STRING)                                         AS country_name_en,  -- 国家名称（英文）：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS country_full_name,  -- 国家中文全称：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS country_full_name_en,  -- 国家英文全称：此源表无此字段，置空
    CAST(NULL AS INT)                                            AS is_country,   -- 是否独立国家：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS alpha_2_code,  -- ISO 3166-1 二位字母码：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS alpha_3_code,  -- ISO 3166-1 三位字母码：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS numeric_3_code,  -- ISO 3166-1 三位数字码：此源表无此字段，置空
    lng,                                                                          -- 经度
    lat,                                                                          -- 纬度
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time           -- ETL 加载时间
FROM ods.ods_opr_city_phone_df
WHERE travel_date = '${bizdate}'                                                  -- 只取当日分区
UNION ALL
-- (2) ods_opr_global_phone_area_df
SELECT
    'COUNTRY_CODE'                                               AS phone_prefix_type,  -- 前缀类型
    phone_area_code                                              AS phone_prefix,  -- 前缀
    CAST(NULL AS INT)                                            AS carrier_type,  -- 运营商：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS province_code,  -- 省编码：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS province_name,  -- 省名称：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS city_code,    -- 市编码：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS city_name,    -- 市名称：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS area_code,    -- 区域编码（平台区域码）：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS zip_code,     -- 邮编：此源表无此字段，置空
    CAST(country_id AS STRING)                                   AS country_code,  -- 国家编码
    name_zh                                                      AS country_name,  -- 国家名称（中文）
    name_en                                                      AS country_name_en,  -- 国家名称（英文）
    full_name_zh                                                 AS country_full_name,  -- 国家中文全称
    full_name_en                                                 AS country_full_name_en,  -- 国家英文全称
    CAST(is_country AS INT)                                      AS is_country,   -- 是否独立国家
    alpha_2_code,                                                                 -- ISO 3166-1 二位字母码
    alpha_3_code,                                                                 -- ISO 3166-1 三位字母码
    numeric_3_code,                                                               -- ISO 3166-1 三位数字码
    CAST(NULL AS STRING)                                         AS lng,          -- 经度：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS lat,          -- 纬度：此源表无此字段，置空
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time           -- ETL 加载时间
FROM (
        SELECT g.*,
               c.name_zh,
               c.name_en,
               c.full_name_zh,
               c.full_name_en,
               c.is_country,                                                      -- 是否独立国家
               c.alpha_2_code,                                                    -- ISO 3166-1 二位字母码
               c.alpha_3_code,                                                    -- ISO 3166-1 三位字母码
               c.numeric_3_code                                                   -- ISO 3166-1 三位数字码
        FROM ods.ods_opr_global_phone_area_df g
        LEFT JOIN ods.ods_opr_country_region_df c ON c.id = g.country_id AND c.travel_date = '${bizdate}'  -- 国家码表
        WHERE g.travel_date = '${bizdate}'                                        -- 只取当日分区
    ) t
