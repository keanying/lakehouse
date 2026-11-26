-- ================================================================================================
-- ads.ads_trf_scenic_passenger_flow_di  景区客流
-- 粒度：1行=1天×景区×闸机组
-- 分区：travel_date（YYYYMMDD）
-- 调度：每日，依赖上游 DWS 当日分区；完成后回流 / 服务层读取
-- 上游：dws_trf_scenic_inout_hrs、dws_ord_scenic_ticket_trade_di
-- 替代旧任务 9 个（上线对数一致后下线）：
--   · 业务工厂/手动任务/历史任务重跑/ads_trf_scenic_passenger_flow_oi（SERVERLESS_SPARK_SQL，cron 00 12 00 * * ?）
--   · 数据平台/ADS/ads_trf_cwd_scenic_traffic_oi（SERVERLESS_SPARK_SQL，cron 00 29 00 * * ?）
--   · 数据平台/平台湖仓工作流/景区实时客流/ads_trf_scenic_passenger_flow_di（SERVERLESS_SPARK_SQL，cron 00 00 00 * * ?）
--   · 数据平台/平台湖仓工作流/出入园数据/ads_trf_tourist_in_out_qty（SERVERLESS_SPARK_SQL，cron 00 00 00 * * ?）
--   · 业务工厂/出入园/ADS/ads_datav_device_inout_statistics_d_i（EMR_SPARK_SQL，cron 00 30 00 * * ?）
--   · 业务工厂/出入园/ADS/ads_datav_device_inout_statistics_month_d_i（EMR_SPARK_SQL，cron 00 30 00 * * ?）
--   · 业务工厂/出入园/ADS/ads_datav_device_ticket_verification_d_i（EMR_SPARK_SQL，cron 00 30 00 * * ?）
--   · 业务工厂/数据备份服务/ADS/ads_everyday_land_enter_into_number_d_f（EMR_SPARK_SQL，cron 00 29 00 * * ?）
--   · 业务工厂/数据备份服务/ADS/ads_everyday_land_enter_into_number_d_i（EMR_SPARK_SQL，cron 00 00 01 * * ?）
-- 性能：
--   · ADS 只存日粒度：周 / 月 / 年 / 节假日 / 自定义区间与同比环比在查询时关联 dim_opr_period_f（见「指标口径 · ADS 业务指标」）
--   · 比率类不落比率值，只存分子分母；去重类存位图；快照类取日终值
--   · 多个上游各自预聚合后 UNION ALL，按 ADS 粒度合并（替代旧系统多表 FULL JOIN）
-- ================================================================================================
INSERT OVERWRITE TABLE ads.ads_trf_scenic_passenger_flow_di PARTITION (travel_date = '${bizdate}')
SELECT
    scenic_id,
    gate_group_id,
    SUM(enter_qty)                                               AS enter_qty,
    SUM(exit_qty)                                                AS exit_qty,
    MAX(in_park_qty)                                             AS in_park_qty,
    SUM(verify_ticket_qty)                                       AS verify_ticket_qty,
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time
FROM (
    -- dws_trf_scenic_inout_hrs
    SELECT
        scenic_id,
        gate_group_id,
        SUM(enter_qty)                                               AS enter_qty,
        SUM(exit_qty)                                                AS exit_qty,
        MAX_BY(in_park_qty, stat_hour)                               AS in_park_qty,
        CAST(0 AS BIGINT)                                            AS verify_ticket_qty
    FROM dws.dws_trf_scenic_inout_hrs
    WHERE travel_date = '${bizdate}'
    GROUP BY scenic_id, gate_group_id
    UNION ALL
    -- dws_ord_scenic_ticket_trade_di
    SELECT
        scenic_id,
        CAST(-1 AS BIGINT)                                           AS gate_group_id,   -- 该上游无此维度
        CAST(0 AS BIGINT)                                            AS enter_qty,
        CAST(0 AS BIGINT)                                            AS exit_qty,
        CAST(NULL AS BIGINT)                                         AS in_park_qty,
        SUM(verify_ticket_qty)                                       AS verify_ticket_qty
    FROM dws.dws_ord_scenic_ticket_trade_di
    WHERE travel_date = '${bizdate}'
    GROUP BY scenic_id
) u
GROUP BY scenic_id, gate_group_id
