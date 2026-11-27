-- ================================================================================================
-- dws.dws_opr_hotel_di  酒店日汇总
-- 粒度：1行=1天×酒店（在住间夜 + 当日预订 / 入住事件）
-- 分区：travel_date（YYYYMMDD）
-- 调度：每日，依赖上游 DWD 当日分区
-- 上游：dwd_opr_hotel_order_df
-- 替代旧任务 1 个（上线对数一致后下线）：
--   · 数据平台/平台湖仓工作流/绿云酒店系统/dws_sup_hotel_summary_di（SERVERLESS_SPARK_SQL，cron 00 30 06 * * ?）
-- 性能：
--   · 同一来源的指标在一个子查询里预聚合（一次扫描），各来源 UNION ALL 后按粒度汇总，不做明细级 JOIN
--   · 来源：hotel = dwd.dwd_opr_hotel_order_df（绿云在住订单：到店日 ≤ bizdate < 离店日（酒店订单明细，全量快照））；hotel_evt = dwd.dwd_opr_hotel_order_df（酒店订单：按预订日 / 到店日取当日事件（全量快照））
-- ================================================================================================
INSERT OVERWRITE TABLE dws.dws_opr_hotel_di PARTITION (travel_date = '${bizdate}')
SELECT
    hotel_code,
    SUM(hotel_room_night_qty)                                    AS hotel_room_night_qty,
    SUM(hotel_revenue_amt)                                       AS hotel_revenue_amt,
    SUM(hotel_booking_order_qty)                                 AS hotel_booking_order_qty,
    SUM(hotel_booking_room_qty)                                  AS hotel_booking_room_qty,
    SUM(hotel_booking_adult_qty)                                 AS hotel_booking_adult_qty,
    SUM(hotel_booking_child_qty)                                 AS hotel_booking_child_qty,
    SUM(hotel_booking_guest_qty)                                 AS hotel_booking_guest_qty,
    SUM(hotel_booking_sales_amt)                                 AS hotel_booking_sales_amt,
    SUM(hotel_booking_pay_amt)                                   AS hotel_booking_pay_amt,
    SUM(hotel_booking_cancel_order_qty)                          AS hotel_booking_cancel_order_qty,
    SUM(hotel_booking_cancel_room_qty)                           AS hotel_booking_cancel_room_qty,
    SUM(hotel_booking_cancel_adult_qty)                          AS hotel_booking_cancel_adult_qty,
    SUM(hotel_booking_cancel_child_qty)                          AS hotel_booking_cancel_child_qty,
    SUM(hotel_booking_cancel_guest_qty)                          AS hotel_booking_cancel_guest_qty,
    SUM(hotel_booking_cancel_sales_amt)                          AS hotel_booking_cancel_sales_amt,
    SUM(hotel_booking_cancel_pay_amt)                            AS hotel_booking_cancel_pay_amt,
    SUM(hotel_checkin_order_qty)                                 AS hotel_checkin_order_qty,
    SUM(hotel_checkin_room_qty)                                  AS hotel_checkin_room_qty,
    SUM(hotel_checkin_adult_qty)                                 AS hotel_checkin_adult_qty,
    SUM(hotel_checkin_child_qty)                                 AS hotel_checkin_child_qty,
    SUM(hotel_checkin_guest_qty)                                 AS hotel_checkin_guest_qty,
    SUM(hotel_checkin_sales_amt)                                 AS hotel_checkin_sales_amt,
    SUM(hotel_checkin_pay_amt)                                   AS hotel_checkin_pay_amt,
    SUM(hotel_checkin_cancel_order_qty)                          AS hotel_checkin_cancel_order_qty,
    SUM(hotel_checkin_cancel_room_qty)                           AS hotel_checkin_cancel_room_qty,
    SUM(hotel_checkin_cancel_adult_qty)                          AS hotel_checkin_cancel_adult_qty,
    SUM(hotel_checkin_cancel_child_qty)                          AS hotel_checkin_cancel_child_qty,
    SUM(hotel_checkin_cancel_guest_qty)                          AS hotel_checkin_cancel_guest_qty,
    SUM(hotel_checkin_cancel_sales_amt)                          AS hotel_checkin_cancel_sales_amt,
    SUM(hotel_checkin_cancel_pay_amt)                            AS hotel_checkin_cancel_pay_amt,
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time
FROM (
    -- hotel：绿云在住订单：到店日 ≤ bizdate < 离店日（酒店订单明细，全量快照）
    SELECT
        hotel_code,
        SUM(room_qty)                                                AS hotel_room_night_qty,
        SUM(room_rate_amt * room_qty)                                AS hotel_revenue_amt,
        CAST(0 AS BIGINT)                                            AS hotel_booking_order_qty,
        CAST(0 AS BIGINT)                                            AS hotel_booking_room_qty,
        CAST(0 AS BIGINT)                                            AS hotel_booking_adult_qty,
        CAST(0 AS BIGINT)                                            AS hotel_booking_child_qty,
        CAST(0 AS BIGINT)                                            AS hotel_booking_guest_qty,
        CAST(0 AS DECIMAL(18,2))                                     AS hotel_booking_sales_amt,
        CAST(0 AS DECIMAL(18,2))                                     AS hotel_booking_pay_amt,
        CAST(0 AS BIGINT)                                            AS hotel_booking_cancel_order_qty,
        CAST(0 AS BIGINT)                                            AS hotel_booking_cancel_room_qty,
        CAST(0 AS BIGINT)                                            AS hotel_booking_cancel_adult_qty,
        CAST(0 AS BIGINT)                                            AS hotel_booking_cancel_child_qty,
        CAST(0 AS BIGINT)                                            AS hotel_booking_cancel_guest_qty,
        CAST(0 AS DECIMAL(18,2))                                     AS hotel_booking_cancel_sales_amt,
        CAST(0 AS DECIMAL(18,2))                                     AS hotel_booking_cancel_pay_amt,
        CAST(0 AS BIGINT)                                            AS hotel_checkin_order_qty,
        CAST(0 AS BIGINT)                                            AS hotel_checkin_room_qty,
        CAST(0 AS BIGINT)                                            AS hotel_checkin_adult_qty,
        CAST(0 AS BIGINT)                                            AS hotel_checkin_child_qty,
        CAST(0 AS BIGINT)                                            AS hotel_checkin_guest_qty,
        CAST(0 AS DECIMAL(18,2))                                     AS hotel_checkin_sales_amt,
        CAST(0 AS DECIMAL(18,2))                                     AS hotel_checkin_pay_amt,
        CAST(0 AS BIGINT)                                            AS hotel_checkin_cancel_order_qty,
        CAST(0 AS BIGINT)                                            AS hotel_checkin_cancel_room_qty,
        CAST(0 AS BIGINT)                                            AS hotel_checkin_cancel_adult_qty,
        CAST(0 AS BIGINT)                                            AS hotel_checkin_cancel_child_qty,
        CAST(0 AS BIGINT)                                            AS hotel_checkin_cancel_guest_qty,
        CAST(0 AS DECIMAL(18,2))                                     AS hotel_checkin_cancel_sales_amt,
        CAST(0 AS DECIMAL(18,2))                                     AS hotel_checkin_cancel_pay_amt
    FROM dwd.dwd_opr_hotel_order_df
    WHERE travel_date = '${bizdate}'
      AND arrive_date <= TO_DATE('${bizdate}', 'yyyyMMdd')
      AND depart_date > TO_DATE('${bizdate}', 'yyyyMMdd')
    GROUP BY hotel_code
    UNION ALL
    -- hotel_evt：酒店订单：按预订日 / 到店日取当日事件（全量快照）
    SELECT
        hotel_code,
        CAST(0 AS BIGINT)                                            AS hotel_room_night_qty,
        CAST(0 AS DECIMAL(18,2))                                     AS hotel_revenue_amt,
        SUM(IF(TO_DATE(reserve_time) = TO_DATE('${bizdate}', 'yyyyMMdd'), 1, 0)) AS hotel_booking_order_qty,
        SUM(IF(TO_DATE(reserve_time) = TO_DATE('${bizdate}', 'yyyyMMdd'), room_qty, 0)) AS hotel_booking_room_qty,
        SUM(IF(TO_DATE(reserve_time) = TO_DATE('${bizdate}', 'yyyyMMdd'), adult_qty, 0)) AS hotel_booking_adult_qty,
        SUM(IF(TO_DATE(reserve_time) = TO_DATE('${bizdate}', 'yyyyMMdd'), child_qty, 0)) AS hotel_booking_child_qty,
        SUM(IF(TO_DATE(reserve_time) = TO_DATE('${bizdate}', 'yyyyMMdd'), adult_qty + child_qty, 0)) AS hotel_booking_guest_qty,
        SUM(IF(TO_DATE(reserve_time) = TO_DATE('${bizdate}', 'yyyyMMdd'), charge_amt, 0)) AS hotel_booking_sales_amt,
        SUM(IF(TO_DATE(reserve_time) = TO_DATE('${bizdate}', 'yyyyMMdd'), pay_amt, 0)) AS hotel_booking_pay_amt,
        SUM(IF(TO_DATE(reserve_time) = TO_DATE('${bizdate}', 'yyyyMMdd') AND order_status = 'X', 1, 0)) AS hotel_booking_cancel_order_qty,
        SUM(IF(TO_DATE(reserve_time) = TO_DATE('${bizdate}', 'yyyyMMdd') AND order_status = 'X', room_qty, 0)) AS hotel_booking_cancel_room_qty,
        SUM(IF(TO_DATE(reserve_time) = TO_DATE('${bizdate}', 'yyyyMMdd') AND order_status = 'X', adult_qty, 0)) AS hotel_booking_cancel_adult_qty,
        SUM(IF(TO_DATE(reserve_time) = TO_DATE('${bizdate}', 'yyyyMMdd') AND order_status = 'X', child_qty, 0)) AS hotel_booking_cancel_child_qty,
        SUM(IF(TO_DATE(reserve_time) = TO_DATE('${bizdate}', 'yyyyMMdd') AND order_status = 'X', adult_qty + child_qty, 0)) AS hotel_booking_cancel_guest_qty,
        SUM(IF(TO_DATE(reserve_time) = TO_DATE('${bizdate}', 'yyyyMMdd') AND order_status = 'X', charge_amt, 0)) AS hotel_booking_cancel_sales_amt,
        SUM(IF(TO_DATE(reserve_time) = TO_DATE('${bizdate}', 'yyyyMMdd') AND order_status = 'X', pay_amt, 0)) AS hotel_booking_cancel_pay_amt,
        SUM(IF(arrive_date = TO_DATE('${bizdate}', 'yyyyMMdd'), 1, 0)) AS hotel_checkin_order_qty,
        SUM(IF(arrive_date = TO_DATE('${bizdate}', 'yyyyMMdd'), room_qty, 0)) AS hotel_checkin_room_qty,
        SUM(IF(arrive_date = TO_DATE('${bizdate}', 'yyyyMMdd'), adult_qty, 0)) AS hotel_checkin_adult_qty,
        SUM(IF(arrive_date = TO_DATE('${bizdate}', 'yyyyMMdd'), child_qty, 0)) AS hotel_checkin_child_qty,
        SUM(IF(arrive_date = TO_DATE('${bizdate}', 'yyyyMMdd'), adult_qty + child_qty, 0)) AS hotel_checkin_guest_qty,
        SUM(IF(arrive_date = TO_DATE('${bizdate}', 'yyyyMMdd'), charge_amt, 0)) AS hotel_checkin_sales_amt,
        SUM(IF(arrive_date = TO_DATE('${bizdate}', 'yyyyMMdd'), pay_amt, 0)) AS hotel_checkin_pay_amt,
        SUM(IF(arrive_date = TO_DATE('${bizdate}', 'yyyyMMdd') AND order_status = 'X', 1, 0)) AS hotel_checkin_cancel_order_qty,
        SUM(IF(arrive_date = TO_DATE('${bizdate}', 'yyyyMMdd') AND order_status = 'X', room_qty, 0)) AS hotel_checkin_cancel_room_qty,
        SUM(IF(arrive_date = TO_DATE('${bizdate}', 'yyyyMMdd') AND order_status = 'X', adult_qty, 0)) AS hotel_checkin_cancel_adult_qty,
        SUM(IF(arrive_date = TO_DATE('${bizdate}', 'yyyyMMdd') AND order_status = 'X', child_qty, 0)) AS hotel_checkin_cancel_child_qty,
        SUM(IF(arrive_date = TO_DATE('${bizdate}', 'yyyyMMdd') AND order_status = 'X', adult_qty + child_qty, 0)) AS hotel_checkin_cancel_guest_qty,
        SUM(IF(arrive_date = TO_DATE('${bizdate}', 'yyyyMMdd') AND order_status = 'X', charge_amt, 0)) AS hotel_checkin_cancel_sales_amt,
        SUM(IF(arrive_date = TO_DATE('${bizdate}', 'yyyyMMdd') AND order_status = 'X', pay_amt, 0)) AS hotel_checkin_cancel_pay_amt
    FROM dwd.dwd_opr_hotel_order_df
    WHERE travel_date = '${bizdate}'
    GROUP BY hotel_code
) u
GROUP BY hotel_code
