-- ================================================================================================
-- dws.dws_opr_hotel_di  酒店日汇总
-- 粒度：1行=1天×酒店
-- 分区：travel_date（YYYYMMDD）
-- 调度：每日，依赖上游 DWD 当日分区
-- 上游：dwd_opr_hotel_order_df
-- 替代旧任务 1 个（上线对数一致后下线）：
--   · 数据平台/平台湖仓工作流/绿云酒店系统/dws_sup_hotel_summary_di（SERVERLESS_SPARK_SQL，cron 00 30 06 * * ?）
-- 性能：
--   · 同一来源的指标在一个子查询里预聚合（一次扫描），各来源 UNION ALL 后按粒度汇总，不做明细级 JOIN
--   · 来源：hotel = dwd.dwd_opr_hotel_order_df（绿云在住订单：到店日 ≤ bizdate < 离店日（酒店订单明细，全量快照））
-- ================================================================================================
INSERT OVERWRITE TABLE dws.dws_opr_hotel_di PARTITION (travel_date = '${bizdate}')
SELECT
    hotel_code,
    SUM(hotel_room_night_qty)                                    AS hotel_room_night_qty,
    SUM(hotel_revenue_amt)                                       AS hotel_revenue_amt,
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time
FROM (
    -- hotel：绿云在住订单：到店日 ≤ bizdate < 离店日（酒店订单明细，全量快照）
    SELECT
        hotel_code,
        SUM(room_qty)                                                AS hotel_room_night_qty,
        SUM(room_rate_amt * room_qty)                                AS hotel_revenue_amt
    FROM dwd.dwd_opr_hotel_order_df
    WHERE travel_date = '${bizdate}'
      AND arrive_date <= TO_DATE('${bizdate}', 'yyyyMMdd')
      AND depart_date > TO_DATE('${bizdate}', 'yyyyMMdd')
    GROUP BY hotel_code
) u
GROUP BY hotel_code
