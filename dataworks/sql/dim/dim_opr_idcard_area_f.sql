-- ================================================================================================
-- dim.dim_opr_idcard_area_f  身份证地区码
-- 粒度：1行=1个身份证前 6 位
-- 分区：无分区
-- 调度：每日，ODS 全部完成后；维表之间按上游顺序
-- 上游：ods_opr_identity_area_code_df、ods_opr_idcard_city_df
-- 替代旧任务 3 个（上线对数一致后下线）：
--   · 数据中台/数据维度(DIM)/dim_其他/dim_idcard_city_d_f（EMR_SPARK_SQL，cron 00 30 00 * * ?）
--   · 数据中台/数据维度(DIM)/dim_其他/dim_idcard_city_fixed_d_f（EMR_SPARK_SQL，cron 00 30 00 * * ?）
--   · 数据平台/DIM/dim_common_idcard_area_df（SERVERLESS_SPARK_SQL，cron 00 19 00 * * ?）
-- 业务规则 / 修正：
--   · 证件前 6 位 → 省市区；省 / 市编码按行政区划码规则（前 2 / 4 位补 0）推出，不再关联两张城市表
-- ================================================================================================
INSERT OVERWRITE TABLE dim.dim_opr_idcard_area_f
SELECT
    idcard                                                       AS area_code,
    CONCAT(SUBSTR(idcard, 1, 2), '0000')                         AS province_code,
    CONCAT(SUBSTR(idcard, 1, 4), '00')                           AS city_code,
    CAST(NULL AS STRING)                                         AS stat_date,   -- 待确认：来源未同步（旧字段 dim_idcard_city_d_f.stat_date）
    CAST(NULL AS BIGINT)                                         AS idcard_city_id_mask,   -- 待确认：来源未同步（旧字段 dim_idcard_city_d_f.idcard_city_id）
    CAST(SUBSTRING_INDEX(idcard, '#', 1) AS BIGINT)              AS id_card_no_mask,
    CAST(NULL AS BIGINT)                                         AS zip_code,   -- 待确认：来源未同步（旧字段 dim_idcard_city_d_f.zip_code）
    province                                                     AS province_name,
    city                                                         AS city_name,
    country                                                      AS district_name,
    CAST(NULL AS STRING)                                         AS country_name,   -- 冗余维度属性：查询时关联维表，建议从明细移除
    CAST(NULL AS STRING)                                         AS lng,   -- 待确认：来源未同步（旧字段 dim_idcard_city_d_f.lng）
    CAST(NULL AS STRING)                                         AS lat,   -- 待确认：来源未同步（旧字段 dim_idcard_city_d_f.lat）
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time
FROM ods.ods_opr_idcard_city_df
WHERE travel_date = '${bizdate}'
