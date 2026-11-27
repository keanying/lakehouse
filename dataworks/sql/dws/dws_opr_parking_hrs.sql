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
-- 取 -1 的维度列：该来源没有这个维度（如核销来源没有下单渠道），用 -1 表示「不适用」，按该维度分析时只看产出它的来源
INSERT OVERWRITE TABLE dws.dws_opr_parking_hrs PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
    scenic_id,                                                                    -- 景区ID
    parking_lot_code,                                                             -- 停车场编码
    parking_vendor,                                                               -- 停车系统厂商
    stat_hour,                                                                    -- 小时
    SUM(park_entry_qty)                                          AS park_entry_qty,  -- 入场车次
    SUM(park_exit_qty)                                           AS park_exit_qty,  -- 出场车次
    SUM(park_fee_amt)                                            AS park_fee_amt,  -- 停车收费金额
    SUM(park_minute_qty)                                         AS park_minute_qty,  -- 停车总时长
    SUM(park_in_lot_qty)                                         AS park_in_lot_qty,  -- 场内车辆净增
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time           -- ETL 加载时间
FROM (
    -- park：停车进出（5 厂商已在 DWD 归一）
    SELECT
        CAST(-1 AS BIGINT)                                           AS scenic_id,  -- 景区ID：此来源不区分，取 -1（不适用）
        parking_lot_code,                                                         -- 停车场编码
        parking_vendor,                                                           -- 停车系统厂商
        COALESCE(HOUR(inout_time), CAST(-1 AS INT))                  AS stat_hour,  -- 小时
        SUM(IF(inout_type = 'IN', 1, 0))                             AS park_entry_qty,  -- 入场车次
        SUM(IF(inout_type = 'OUT', 1, 0))                            AS park_exit_qty,  -- 出场车次
        SUM(IF(inout_type = 'OUT', fee_amt, 0))                      AS park_fee_amt,  -- 停车收费金额
        SUM(IF(
            inout_type = 'OUT',
            (UNIX_TIMESTAMP(inout_time) - UNIX_TIMESTAMP(in_time)) DIV 60,
            0
        )) AS park_minute_qty,                                                    -- 停车总时长
        SUM(CASE inout_type WHEN 'IN' THEN 1 WHEN 'OUT' THEN -1 ELSE 0 END) AS park_in_lot_qty  -- 场内车辆净增
    FROM dwd.dwd_opr_parking_record_di
    WHERE travel_date = '${bizdate}'                                              -- 只取当日分区
    GROUP BY parking_lot_code, parking_vendor, COALESCE(HOUR(inout_time), CAST(-1 AS INT))  -- 按粒度键汇总
) u                                                                               -- 各来源合并后的明细
GROUP BY scenic_id, parking_lot_code, parking_vendor, stat_hour                   -- 按粒度键汇总
