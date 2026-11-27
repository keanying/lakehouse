-- ================================================================================================
-- ads.ads_trf_scenic_passenger_flow_di  景区客流
-- 粒度：1行=1天×景区×闸机组
-- 分区：travel_date（YYYYMMDD）
-- 调度：每日，依赖上游 DWS 当日分区；完成后回流 / 服务层读取
-- 上游：dws_trf_scenic_inout_hrs、dws_ord_scenic_ticket_trade_di
-- 替代旧任务 6 个（上线对数一致后下线）：
--   · 数据平台/ADS/ads_trf_cwd_scenic_traffic_oi（SERVERLESS_SPARK_SQL，cron 00 29 00 * * ?）
--   · 数据平台/平台湖仓工作流/景区实时客流/ads_trf_scenic_passenger_flow_di（SERVERLESS_SPARK_SQL，cron 00 00 00 * * ?）
--   · 数据平台/平台湖仓工作流/出入园数据/ads_trf_tourist_in_out_qty（SERVERLESS_SPARK_SQL，cron 00 00 00 * * ?）
--   · 业务工厂/出入园/ADS/ads_datav_device_inout_statistics_d_i（EMR_SPARK_SQL，cron 00 30 00 * * ?）
--   · 业务工厂/出入园/ADS/ads_datav_device_inout_statistics_month_d_i（EMR_SPARK_SQL，cron 00 30 00 * * ?）
--   · 业务工厂/出入园/ADS/ads_datav_device_ticket_verification_d_i（EMR_SPARK_SQL，cron 00 30 00 * * ?）
-- 性能：
--   · ADS 只存日粒度：周 / 月 / 年 / 节假日 / 自定义区间与同比环比在查询时关联 dim_opr_period_f（见「指标口径 · ADS 业务指标」）
--   · 比率类不落比率值，只存分子分母；去重类存位图；快照类取日终值
-- ================================================================================================
INSERT OVERWRITE TABLE ads.ads_trf_scenic_passenger_flow_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
    scenic_id,                                                                    -- 景区ID
    gate_group_id,                                                                -- 闸机组ID
    SUM(enter_qty)                                               AS enter_qty,    -- 入园人次（日）
    SUM(exit_qty)                                                AS exit_qty,     -- 出园人次（日）
    MAX(in_park_qty)                                             AS in_park_qty,  -- 在园人数（日快照）
    SUM(verify_ticket_qty)                                       AS verify_ticket_qty,  -- 验证票数（日）
    SUM(stay_minutes_qty)                                        AS stay_minutes_qty,  -- 游客停留分钟合计（日）
    SUM(stay_person_qty)                                         AS stay_person_qty,  -- 停留游客数（日）
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time           -- ETL 加载时间
FROM (
    -- dws_trf_scenic_inout_hrs
    SELECT
        scenic_id,                                                                -- 景区ID
        gate_group_id,                                                            -- 闸机组ID
        SUM(enter_qty)                                               AS enter_qty,  -- 入园人次（日）
        SUM(exit_qty)                                                AS exit_qty,  -- 出园人次（日）
        MAX_BY(in_park_qty, stat_hour)                               AS in_park_qty,  -- 在园人数（日快照）
        SUM(verify_ticket_qty)                                       AS verify_ticket_qty,  -- 验证票数（日）
        SUM(stay_minutes_qty)                                        AS stay_minutes_qty,  -- 游客停留分钟合计（日）
        SUM(stay_person_qty)                                         AS stay_person_qty  -- 停留游客数（日）
    FROM dws.dws_trf_scenic_inout_hrs
    WHERE travel_date = '${bizdate}'                                              -- 只取当日分区
    GROUP BY scenic_id, gate_group_id                                             -- 按粒度键汇总
) u                                                                               -- 各来源合并后的明细
GROUP BY scenic_id, gate_group_id                                                 -- 按粒度键汇总
