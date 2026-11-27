-- ================================================================================================
-- dim.dim_opr_idcard_area_f  身份证地区维度
-- 粒度：1行=1个身份证前 6 位地区码
-- 分区：无分区
-- 调度：每日，ODS 全部完成后；维表之间按上游顺序
-- 上游：ods_opr_idcard_city_df、ods_opr_region_area_df
-- 替代旧任务 3 个（上线对数一致后下线）：
--   · 数据中台/数据维度(DIM)/dim_其他/dim_idcard_city_d_f（EMR_SPARK_SQL，cron 00 30 00 * * ?）
--   · 数据中台/数据维度(DIM)/dim_其他/dim_idcard_city_fixed_d_f（EMR_SPARK_SQL，cron 00 30 00 * * ?）
--   · 数据平台/DIM/dim_common_idcard_area_df（SERVERLESS_SPARK_SQL，cron 00 19 00 * * ?）
-- 业务规则 / 修正：
--   · 源表字段 country 实为区县名；旧表 idcard_city_id / id_card_no（与主键重复）、stat_date 不再保留
-- ================================================================================================
INSERT OVERWRITE TABLE dim.dim_opr_idcard_area_f                                  -- 整表覆盖写入
SELECT
    LPAD(CAST(idcard AS STRING), 6, '0')                         AS area_code,    -- 身份证前 6 位地区码
    CONCAT(SUBSTR(LPAD(CAST(idcard AS STRING), 6, '0'), 1, 2), '0000') AS province_code,  -- 省编码（前 2 位补 0）
    province                                                     AS province_name,  -- 省名称
    CONCAT(SUBSTR(LPAD(CAST(idcard AS STRING), 6, '0'), 1, 4), '00') AS city_code,  -- 市编码（前 4 位补 0）
    city                                                         AS city_name,    -- 市名称
    country                                                      AS district_name,  -- 区县名称
    '中国'                                                         AS country_name,  -- 国家（身份证地区码均为中国大陆）
    CAST(zip_code AS STRING)                                     AS zip_code,     -- 邮编（按地区码关联行政区划）
    CAST(lng AS STRING)                                          AS lng,          -- 经度
    CAST(lat AS STRING)                                          AS lat,          -- 纬度
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time           -- ETL 加载时间
FROM (
        SELECT i.*, r.zip_code, r.lng, r.lat
        FROM ods.ods_opr_idcard_city_df i
        LEFT JOIN ods.ods_opr_region_area_df r                                    -- 关联「国家的地区表」｜地区码 = 行政区划代码
          ON r.area_code = LPAD(CAST(i.idcard AS STRING), 6, '0') AND r.travel_date = '${bizdate}'
        WHERE i.travel_date = '${bizdate}'                                        -- 只取当日分区
    ) t
