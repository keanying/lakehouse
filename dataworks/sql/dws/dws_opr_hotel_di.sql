-- ================================================================================================
-- dws.dws_opr_hotel_di  酒店日汇总
-- 粒度：1行=1天×酒店
-- 分区：travel_date（YYYYMMDD）
-- 调度：每日，依赖上游 DWD 当日分区
-- 上游：ods_opr_hotel_lvyun_hotel_master_df
-- 替代旧任务 1 个（上线对数一致后下线）：
--   · 数据平台/平台湖仓工作流/绿云酒店系统/dws_sup_hotel_summary_di（SERVERLESS_SPARK_SQL，cron 00 30 06 * * ?）
-- 性能：
--   · 同一来源的指标在一个子查询里预聚合（一次扫描），各来源 UNION ALL 后按粒度汇总，不做明细级 JOIN
--   · 来源：hotel = ods.ods_opr_hotel_lvyun_hotel_master_df（绿云在住订单：入住日 ≤ bizdate < 离店日（ODS 全量快照））
-- ================================================================================================
INSERT OVERWRITE TABLE dws.dws_opr_hotel_di PARTITION (travel_date = '${bizdate}')
SELECT
    hotel_code,
    SUM(hotel_room_night_qty)                                    AS hotel_room_night_qty,
    SUM(hotel_revenue_amt)                                       AS hotel_revenue_amt,
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time
FROM (
    -- hotel：绿云在住订单：入住日 ≤ bizdate < 离店日（ODS 全量快照）
    SELECT
        hotel_code,
        SUM(CAST(rmnum AS BIGINT))                                   AS hotel_room_night_qty,
        SUM(CAST(real_rate AS DECIMAL(18,2)) * CAST(rmnum AS BIGINT)) AS hotel_revenue_amt
    FROM ods.ods_opr_hotel_lvyun_hotel_master_df
    WHERE travel_date = '${bizdate}'
      AND TO_DATE(arr) <= TO_DATE('${bizdate}', 'yyyyMMdd')
      AND TO_DATE(dep) > TO_DATE('${bizdate}', 'yyyyMMdd')
    GROUP BY hotel_code
) u
GROUP BY hotel_code
