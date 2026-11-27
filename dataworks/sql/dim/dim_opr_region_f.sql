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
INSERT OVERWRITE TABLE dim.dim_opr_region_f                                       -- 整表覆盖写入
SELECT
    area_code                                                    AS region_code,  -- 地区编码
    area_name                                                    AS region_name,  -- 地区名称
    parent_code,                                                                  -- 父级编码
    level                                                        AS region_level,  -- 地区级别
    CAST(NULL AS STRING)                                         AS stat_date,    -- 统计日期｜待确认：来源未同步（旧字段 dim_city_d_f.stat_date）
    CAST(NULL AS BIGINT)                                         AS city_id,      -- 市编码｜待确认：来源未同步（旧字段 dim_city_d_f.city_id）
    city_code,                                                                    -- 市-编码
    CAST(NULL AS STRING)                                         AS city_name,    -- 市-名称｜冗余维度属性：查询时关联维表，建议从明细移除
    CAST(NULL AS BIGINT)                                         AS province_code,  -- 省/直辖市/特别行政区/州-编码｜待确认：来源未同步（旧字段 dim_city_d_f.province_code）
    CAST(NULL AS STRING)                                         AS province_name,  -- 省/直辖市/特别行政区/州-名称｜冗余维度属性：查询时关联维表，建议从明细移除
    CAST(NULL AS BIGINT)                                         AS district_code,  -- 区/县-编码｜待确认：来源未同步（旧字段 dim_city_d_f.district_code）
    CAST(NULL AS STRING)                                         AS district_name,  -- 区/县-名称｜冗余维度属性：查询时关联维表，建议从明细移除
    CAST(NULL AS BIGINT)                                         AS country_code,  -- 国家编码｜待确认：来源未同步（旧字段 dim_city_d_f.country_code）
    CAST(NULL AS STRING)                                         AS country_name,  -- 国家名称｜冗余维度属性：查询时关联维表，建议从明细移除
    area_code,                                                                    -- 区域编码
    zip_code,                                                                     -- 邮编
    lng,                                                                          -- 末级经度
    lat,                                                                          -- 末级维度
    CAST(NULL AS STRING)                                         AS city_adcode,  -- 城市行政编码｜待确认：来源未同步（旧字段 dim_city_d_f.city_adcode）
    CAST(NULL AS STRING)                                         AS province_adcode,  -- 省行政编码｜待确认：来源未同步（旧字段 dim_city_d_f.province_adcode）
    CAST(NULL AS STRING)                                         AS province_lng,  -- 省经度｜待确认：来源未同步（旧字段 dim_city_d_f.province_lng）
    CAST(NULL AS STRING)                                         AS province_lat,  -- 省维度｜待确认：来源未同步（旧字段 dim_city_d_f.province_lat）
    CAST(NULL AS STRING)                                         AS province_zip_code,  -- 省/直辖市/特别行政区/州-邮政编码｜待确认：来源未同步（旧字段 dim_city_fixed_d_f.province_zip_code）
    CAST(NULL AS STRING)                                         AS city_zip_code,  -- 市-邮政编码｜待确认：来源未同步（旧字段 dim_city_fixed_d_f.city_zip_code）
    CAST(NULL AS STRING)                                         AS city_lng,     -- 市-经度｜待确认：来源未同步（旧字段 dim_city_fixed_d_f.city_lng）
    CAST(NULL AS STRING)                                         AS city_lat,     -- 市-纬度｜待确认：来源未同步（旧字段 dim_city_fixed_d_f.city_lat）
    CAST(NULL AS STRING)                                         AS district_zip_code,  -- 区/县-邮政编码｜待确认：来源未同步（旧字段 dim_city_fixed_d_f.district_zip_code）
    CAST(NULL AS STRING)                                         AS district_lng,  -- 区/县-经度｜待确认：来源未同步（旧字段 dim_city_fixed_d_f.district_lng）
    CAST(NULL AS STRING)                                         AS district_lat,  -- 区/县-纬度｜待确认：来源未同步（旧字段 dim_city_fixed_d_f.district_lat）
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time           -- ETL 加载时间
FROM ods.ods_opr_region_area_df
WHERE travel_date = '${bizdate}'                                                  -- 只取当日分区
  AND COALESCE(status, '0') = '0'
