-- ================================================================================================
-- dws.dws_opr_parking_hrs  停车小时汇总
-- 粒度：1行=1小时×景区×停车场×厂商
-- 分区：travel_date（YYYYMMDD）
-- 调度：每日，依赖上游 DWD 当日分区
-- 上游：dwd_opr_parking_record_di
-- 替代旧任务 4 个（上线对数一致后下线）：
--   · 业务工厂/业态通/停车数据/停车数据汇总工作流/dws_scenic_park_day_d_i（EMR_SPARK_SQL，cron 00 13 00 * * ?）
--   · 业务工厂/业态通/停车数据/停车数据汇总工作流/dws_scenic_park_hour_d_i（EMR_SPARK_SQL，cron 00 13 00 * * ?）
--   · 业务工厂/业态通/停车数据/停车数据汇总工作流/dws_scenic_park_hour_full_d_i（EMR_SPARK_SQL，cron 00 13 00 * * ?）
--   · 业务工厂/业态通/停车数据/停车数据汇总工作流/dws_scenic_park_location_day_d_i（EMR_SPARK_SQL，cron 00 13 00 * * ?）
-- 性能：
--   · 同一来源的指标在一个子查询里预聚合（一次扫描），各来源 UNION ALL 后按粒度汇总，不做明细级 JOIN
--   · 来源：park = dwd.dwd_opr_parking_record_di（停车进出（5 厂商已在 DWD 归一））
-- ================================================================================================
INSERT OVERWRITE TABLE dws.dws_opr_parking_hrs PARTITION (travel_date = '${bizdate}')
SELECT
    scenic_id,
    parking_lot_code,
    parking_vendor,
    stat_hour,
    SUM(park_entry_qty)                                          AS park_entry_qty,
    SUM(park_exit_qty)                                           AS park_exit_qty,
    SUM(park_fee_amt)                                            AS park_fee_amt,
    SUM(park_minute_qty)                                         AS park_minute_qty,
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time
FROM (
    -- park：停车进出（5 厂商已在 DWD 归一）
    SELECT
        CAST(-1 AS BIGINT)                                           AS scenic_id,   -- 该来源无此维度，取默认值
        parking_lot_code,
        parking_vendor,
        COALESCE(HOUR(inout_time), CAST(-1 AS INT))                  AS stat_hour,
        SUM(IF(inout_type = 'IN', 1, 0))                             AS park_entry_qty,
        SUM(IF(inout_type = 'OUT', 1, 0))                            AS park_exit_qty,
        SUM(IF(inout_type = 'OUT', fee_amt, 0))                      AS park_fee_amt,
        SUM(IF(inout_type = 'OUT', (UNIX_TIMESTAMP(inout_time) - UNIX_TIMESTAMP(in_time)) DIV 60, 0)) AS park_minute_qty
    FROM dwd.dwd_opr_parking_record_di
    WHERE travel_date = '${bizdate}'
    GROUP BY parking_lot_code, parking_vendor, COALESCE(HOUR(inout_time), CAST(-1 AS INT))
) u
GROUP BY scenic_id, parking_lot_code, parking_vendor, stat_hour
