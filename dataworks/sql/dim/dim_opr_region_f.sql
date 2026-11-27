-- ================================================================================================
-- dim.dim_opr_region_f  地区维度
-- 粒度：1行=1个行政区划（国家 / 省 / 市 / 区县）
-- 分区：无分区
-- 调度：每日，ODS 全部完成后；维表之间按上游顺序
-- 上游：ods_opr_region_area_df、ods_opr_country_region_df、ods_opr_city_df、ods_opr_province_df
-- 替代旧任务 4 个（上线对数一致后下线）：
--   · 数据中台/数据维度(DIM)/dim_其他/dim_city_d_f（EMR_SPARK_SQL，cron 00 05 00 * * ?）
--   · 数据中台/数据维度(DIM)/dim_其他/dim_province_d_f（EMR_SPARK_SQL，cron 00 10 00 * * ?）
--   · 数据中台/DIM/dim_city_fixed_d_f（EMR_SPARK_SQL，cron 00 10 00 * * ?）
--   · 数据平台/DIM/dim_common_region_area_df（SERVERLESS_SPARK_SQL，cron 00 11 00 * * ?）
-- 业务规则 / 修正：
--   · 行政区划一张表（省 / 市 / 区县同表，parent_code 串联）；旧系统 3 张城市表（dim_city_d_f / fixed / 省表）合一
-- ================================================================================================
INSERT OVERWRITE TABLE dim.dim_opr_region_f
SELECT
    area_code                                                    AS region_code,
    area_name                                                    AS region_name,
    parent_code,
    level                                                        AS region_level,
    CAST(NULL AS STRING)                                         AS stat_date,   -- 待确认：来源未同步（旧字段 dim_city_d_f.stat_date）
    CAST(NULL AS BIGINT)                                         AS city_id,   -- 待确认：来源未同步（旧字段 dim_city_d_f.city_id）
    city_code,
    CAST(NULL AS STRING)                                         AS city_name,   -- 冗余维度属性：查询时关联维表，建议从明细移除
    CAST(NULL AS BIGINT)                                         AS province_code,   -- 待确认：来源未同步（旧字段 dim_city_d_f.province_code）
    CAST(NULL AS STRING)                                         AS province_name,   -- 冗余维度属性：查询时关联维表，建议从明细移除
    CAST(NULL AS BIGINT)                                         AS district_code,   -- 待确认：来源未同步（旧字段 dim_city_d_f.district_code）
    CAST(NULL AS STRING)                                         AS district_name,   -- 冗余维度属性：查询时关联维表，建议从明细移除
    CAST(NULL AS BIGINT)                                         AS country_code,   -- 待确认：来源未同步（旧字段 dim_city_d_f.country_code）
    CAST(NULL AS STRING)                                         AS country_name,   -- 冗余维度属性：查询时关联维表，建议从明细移除
    area_code,
    zip_code,
    lng,
    lat,
    CAST(NULL AS STRING)                                         AS city_adcode,   -- 待确认：来源未同步（旧字段 dim_city_d_f.city_adcode）
    CAST(NULL AS STRING)                                         AS province_adcode,   -- 待确认：来源未同步（旧字段 dim_city_d_f.province_adcode）
    CAST(NULL AS STRING)                                         AS province_lng,   -- 待确认：来源未同步（旧字段 dim_city_d_f.province_lng）
    CAST(NULL AS STRING)                                         AS province_lat,   -- 待确认：来源未同步（旧字段 dim_city_d_f.province_lat）
    CAST(NULL AS STRING)                                         AS province_zip_code,   -- 待确认：来源未同步（旧字段 dim_city_fixed_d_f.province_zip_code）
    CAST(NULL AS STRING)                                         AS city_zip_code,   -- 待确认：来源未同步（旧字段 dim_city_fixed_d_f.city_zip_code）
    CAST(NULL AS STRING)                                         AS city_lng,   -- 待确认：来源未同步（旧字段 dim_city_fixed_d_f.city_lng）
    CAST(NULL AS STRING)                                         AS city_lat,   -- 待确认：来源未同步（旧字段 dim_city_fixed_d_f.city_lat）
    CAST(NULL AS STRING)                                         AS district_zip_code,   -- 待确认：来源未同步（旧字段 dim_city_fixed_d_f.district_zip_code）
    CAST(NULL AS STRING)                                         AS district_lng,   -- 待确认：来源未同步（旧字段 dim_city_fixed_d_f.district_lng）
    CAST(NULL AS STRING)                                         AS district_lat,   -- 待确认：来源未同步（旧字段 dim_city_fixed_d_f.district_lat）
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time
FROM ods.ods_opr_region_area_df
WHERE travel_date = '${bizdate}'
  AND COALESCE(status, '0') = '0'
