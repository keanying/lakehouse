-- ================================================================================================
-- dim.dim_opr_phone_area_f  手机号归属地
-- 粒度：1行=1个号段
-- 分区：无分区
-- 调度：每日，ODS 全部完成后；维表之间按上游顺序
-- 上游：ods_opr_global_phone_area_df、ods_opr_city_phone_df
-- 替代旧任务 5 个（上线对数一致后下线）：
--   · 数据中台/数据维度(DIM)/dim_其他/dim_phone_city_d_f（EMR_SPARK_SQL，cron 00 08 00 * * ?）
--   · 数据中台/DIM/dim_phone_city_fixed_d_f_workflow/dim_phone_city_fixed_d_f（EMR_SPARK_SQL，cron 00 00 00 * * ?）
--   · 数据中台/DIM/dim_phone_global_d_f（EMR_SPARK_SQL，cron 00 15 00 * * ?）
--   · 数据平台/DIM/dim_common_phone_prefix_area_df（SERVERLESS_SPARK_SQL，cron 00 25 00 * * ?）
--   · 数据平台/DIM/dim_common_phone_code_country_df（SERVERLESS_SPARK_SQL，cron 00 10 00 * * ?）
-- 业务规则 / 修正：
--   · 手机号段（前 7 位）→ 归属地；DWD 按 ODS 脱敏前缀等值关联
-- ================================================================================================
INSERT OVERWRITE TABLE dim.dim_opr_phone_area_f
SELECT
    number                                                       AS phone_prefix,
    province_code,
    city_code,
    CAST(NULL AS STRING)                                         AS stat_date,   -- 待确认：来源未同步（旧字段 dim_phone_city_d_f.stat_date）
    CAST(NULL AS BIGINT)                                         AS phone_city_id_mask,   -- 待确认：来源未同步（旧字段 dim_phone_city_d_f.phone_city_id）
    CAST(NULL AS BIGINT)                                         AS phone_number_mask,   -- 待确认：来源未同步（旧字段 dim_phone_city_d_f.phone_number）
    area_code,
    zip_code,
    province_name,
    city_name,
    CAST(NULL AS STRING)                                         AS district_name,   -- 冗余维度属性：查询时关联维表，建议从明细移除
    country_name,
    lng,
    lat,
    CAST(NULL AS STRING)                                         AS phone_area_code_mask,   -- 待确认：来源未同步（旧字段 dim_phone_global_d_f.phone_area_code）
    CAST(NULL AS STRING)                                         AS name_zh,   -- 待确认：来源未同步（旧字段 dim_phone_global_d_f.name_zh）
    CAST(NULL AS STRING)                                         AS name_en,   -- 待确认：来源未同步（旧字段 dim_phone_global_d_f.name_en）
    CAST(NULL AS STRING)                                         AS full_name_zh,   -- 待确认：来源未同步（旧字段 dim_phone_global_d_f.full_name_zh）
    CAST(NULL AS STRING)                                         AS full_name_en,   -- 待确认：来源未同步（旧字段 dim_phone_global_d_f.full_name_en）
    CAST(NULL AS BIGINT)                                         AS is_country,   -- 待确认：来源未同步（旧字段 dim_phone_global_d_f.is_country）
    CAST(NULL AS STRING)                                         AS alpha_2_code,   -- 待确认：来源未同步（旧字段 dim_phone_global_d_f.alpha_2_code）
    CAST(NULL AS STRING)                                         AS alpha_3_code,   -- 待确认：来源未同步（旧字段 dim_phone_global_d_f.alpha_3_code）
    CAST(NULL AS STRING)                                         AS numeric_3_code,   -- 待确认：来源未同步（旧字段 dim_phone_global_d_f.numeric_3_code）
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time
FROM ods.ods_opr_city_phone_df
WHERE travel_date = '${bizdate}'
