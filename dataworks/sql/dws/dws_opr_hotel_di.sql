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
-- 补 0 / 补空列：多来源 UNION ALL 时，某来源不产出的指标补 0 或空，外层按粒度 SUM 后即为各来源之和，不影响结果
INSERT OVERWRITE TABLE dws.dws_opr_hotel_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
    hotel_code,                                                                   -- 酒店编码
    SUM(hotel_room_night_qty)                                    AS hotel_room_night_qty,  -- 酒店间夜数
    SUM(hotel_revenue_amt)                                       AS hotel_revenue_amt,  -- 酒店营收
    SUM(hotel_booking_order_qty)                                 AS hotel_booking_order_qty,  -- 酒店预订单数
    SUM(hotel_booking_room_qty)                                  AS hotel_booking_room_qty,  -- 酒店预订房间数
    SUM(hotel_booking_adult_qty)                                 AS hotel_booking_adult_qty,  -- 酒店预订成人数
    SUM(hotel_booking_child_qty)                                 AS hotel_booking_child_qty,  -- 酒店预订儿童数
    SUM(hotel_booking_guest_qty)                                 AS hotel_booking_guest_qty,  -- 酒店预订人数
    SUM(hotel_booking_sales_amt)                                 AS hotel_booking_sales_amt,  -- 酒店预订消费合计
    SUM(hotel_booking_pay_amt)                                   AS hotel_booking_pay_amt,  -- 酒店预订实付合计
    SUM(hotel_booking_cancel_order_qty)                          AS hotel_booking_cancel_order_qty,  -- 酒店预订取消单数
    SUM(hotel_booking_cancel_room_qty)                           AS hotel_booking_cancel_room_qty,  -- 酒店预订取消房间数
    SUM(hotel_booking_cancel_adult_qty)                          AS hotel_booking_cancel_adult_qty,  -- 酒店预订取消成人数
    SUM(hotel_booking_cancel_child_qty)                          AS hotel_booking_cancel_child_qty,  -- 酒店预订取消儿童数
    SUM(hotel_booking_cancel_guest_qty)                          AS hotel_booking_cancel_guest_qty,  -- 酒店预订取消人数
    SUM(hotel_booking_cancel_sales_amt)                          AS hotel_booking_cancel_sales_amt,  -- 酒店预订取消消费合计
    SUM(hotel_booking_cancel_pay_amt)                            AS hotel_booking_cancel_pay_amt,  -- 酒店预订取消实付合计
    SUM(hotel_checkin_order_qty)                                 AS hotel_checkin_order_qty,  -- 酒店入住单数
    SUM(hotel_checkin_room_qty)                                  AS hotel_checkin_room_qty,  -- 酒店入住房间数
    SUM(hotel_checkin_adult_qty)                                 AS hotel_checkin_adult_qty,  -- 酒店入住成人数
    SUM(hotel_checkin_child_qty)                                 AS hotel_checkin_child_qty,  -- 酒店入住儿童数
    SUM(hotel_checkin_guest_qty)                                 AS hotel_checkin_guest_qty,  -- 酒店入住人数
    SUM(hotel_checkin_sales_amt)                                 AS hotel_checkin_sales_amt,  -- 酒店入住消费合计
    SUM(hotel_checkin_pay_amt)                                   AS hotel_checkin_pay_amt,  -- 酒店入住实付合计
    SUM(hotel_checkin_cancel_order_qty)                          AS hotel_checkin_cancel_order_qty,  -- 酒店入住取消单数
    SUM(hotel_checkin_cancel_room_qty)                           AS hotel_checkin_cancel_room_qty,  -- 酒店入住取消房间数
    SUM(hotel_checkin_cancel_adult_qty)                          AS hotel_checkin_cancel_adult_qty,  -- 酒店入住取消成人数
    SUM(hotel_checkin_cancel_child_qty)                          AS hotel_checkin_cancel_child_qty,  -- 酒店入住取消儿童数
    SUM(hotel_checkin_cancel_guest_qty)                          AS hotel_checkin_cancel_guest_qty,  -- 酒店入住取消人数
    SUM(hotel_checkin_cancel_sales_amt)                          AS hotel_checkin_cancel_sales_amt,  -- 酒店入住取消消费合计
    SUM(hotel_checkin_cancel_pay_amt)                            AS hotel_checkin_cancel_pay_amt,  -- 酒店入住取消实付合计
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time           -- ETL 加载时间
FROM (
    -- hotel：绿云在住订单：到店日 ≤ bizdate < 离店日（酒店订单明细，全量快照）
    SELECT
        hotel_code,                                                               -- 酒店编码
        SUM(room_qty)                                                AS hotel_room_night_qty,  -- 酒店间夜数
        SUM(room_rate_amt * room_qty)                                AS hotel_revenue_amt,  -- 酒店营收
        CAST(0 AS BIGINT)                                            AS hotel_booking_order_qty,  -- 酒店预订单数：此来源不产出，补0
        CAST(0 AS BIGINT)                                            AS hotel_booking_room_qty,  -- 酒店预订房间数：此来源不产出，补0
        CAST(0 AS BIGINT)                                            AS hotel_booking_adult_qty,  -- 酒店预订成人数：此来源不产出，补0
        CAST(0 AS BIGINT)                                            AS hotel_booking_child_qty,  -- 酒店预订儿童数：此来源不产出，补0
        CAST(0 AS BIGINT)                                            AS hotel_booking_guest_qty,  -- 酒店预订人数：此来源不产出，补0
        CAST(0 AS DECIMAL(18,2))                                     AS hotel_booking_sales_amt,  -- 酒店预订消费合计：此来源不产出，补0
        CAST(0 AS DECIMAL(18,2))                                     AS hotel_booking_pay_amt,  -- 酒店预订实付合计：此来源不产出，补0
        CAST(0 AS BIGINT)                                            AS hotel_booking_cancel_order_qty,  -- 酒店预订取消单数：此来源不产出，补0
        CAST(0 AS BIGINT)                                            AS hotel_booking_cancel_room_qty,  -- 酒店预订取消房间数：此来源不产出，补0
        CAST(0 AS BIGINT)                                            AS hotel_booking_cancel_adult_qty,  -- 酒店预订取消成人数：此来源不产出，补0
        CAST(0 AS BIGINT)                                            AS hotel_booking_cancel_child_qty,  -- 酒店预订取消儿童数：此来源不产出，补0
        CAST(0 AS BIGINT)                                            AS hotel_booking_cancel_guest_qty,  -- 酒店预订取消人数：此来源不产出，补0
        CAST(0 AS DECIMAL(18,2))                                     AS hotel_booking_cancel_sales_amt,  -- 酒店预订取消消费合计：此来源不产出，补0
        CAST(0 AS DECIMAL(18,2))                                     AS hotel_booking_cancel_pay_amt,  -- 酒店预订取消实付合计：此来源不产出，补0
        CAST(0 AS BIGINT)                                            AS hotel_checkin_order_qty,  -- 酒店入住单数：此来源不产出，补0
        CAST(0 AS BIGINT)                                            AS hotel_checkin_room_qty,  -- 酒店入住房间数：此来源不产出，补0
        CAST(0 AS BIGINT)                                            AS hotel_checkin_adult_qty,  -- 酒店入住成人数：此来源不产出，补0
        CAST(0 AS BIGINT)                                            AS hotel_checkin_child_qty,  -- 酒店入住儿童数：此来源不产出，补0
        CAST(0 AS BIGINT)                                            AS hotel_checkin_guest_qty,  -- 酒店入住人数：此来源不产出，补0
        CAST(0 AS DECIMAL(18,2))                                     AS hotel_checkin_sales_amt,  -- 酒店入住消费合计：此来源不产出，补0
        CAST(0 AS DECIMAL(18,2))                                     AS hotel_checkin_pay_amt,  -- 酒店入住实付合计：此来源不产出，补0
        CAST(0 AS BIGINT)                                            AS hotel_checkin_cancel_order_qty,  -- 酒店入住取消单数：此来源不产出，补0
        CAST(0 AS BIGINT)                                            AS hotel_checkin_cancel_room_qty,  -- 酒店入住取消房间数：此来源不产出，补0
        CAST(0 AS BIGINT)                                            AS hotel_checkin_cancel_adult_qty,  -- 酒店入住取消成人数：此来源不产出，补0
        CAST(0 AS BIGINT)                                            AS hotel_checkin_cancel_child_qty,  -- 酒店入住取消儿童数：此来源不产出，补0
        CAST(0 AS BIGINT)                                            AS hotel_checkin_cancel_guest_qty,  -- 酒店入住取消人数：此来源不产出，补0
        CAST(0 AS DECIMAL(18,2))                                     AS hotel_checkin_cancel_sales_amt,  -- 酒店入住取消消费合计：此来源不产出，补0
        CAST(0 AS DECIMAL(18,2))                                     AS hotel_checkin_cancel_pay_amt  -- 酒店入住取消实付合计：此来源不产出，补0
    FROM dwd.dwd_opr_hotel_order_df
    WHERE travel_date = '${bizdate}'                                              -- 只取当日分区
      AND arrive_date <= TO_DATE('${bizdate}', 'yyyyMMdd')
      AND depart_date > TO_DATE('${bizdate}', 'yyyyMMdd')
    GROUP BY hotel_code                                                           -- 按粒度键汇总
    UNION ALL
    -- hotel_evt：酒店订单：按预订日 / 到店日取当日事件（全量快照）
    SELECT
        hotel_code,                                                               -- 酒店编码
        CAST(0 AS BIGINT)                                            AS hotel_room_night_qty,  -- 酒店间夜数：此来源不产出，补0
        CAST(0 AS DECIMAL(18,2))                                     AS hotel_revenue_amt,  -- 酒店营收：此来源不产出，补0
        SUM(IF(TO_DATE(reserve_time) = TO_DATE('${bizdate}', 'yyyyMMdd'), 1, 0)) AS hotel_booking_order_qty,  -- 酒店预订单数
        SUM(IF(
            TO_DATE(reserve_time) = TO_DATE('${bizdate}', 'yyyyMMdd'),
            room_qty,
            0
        )) AS hotel_booking_room_qty,                                             -- 酒店预订房间数
        SUM(IF(
            TO_DATE(reserve_time) = TO_DATE('${bizdate}', 'yyyyMMdd'),
            adult_qty,
            0
        )) AS hotel_booking_adult_qty,                                            -- 酒店预订成人数
        SUM(IF(
            TO_DATE(reserve_time) = TO_DATE('${bizdate}', 'yyyyMMdd'),
            child_qty,
            0
        )) AS hotel_booking_child_qty,                                            -- 酒店预订儿童数
        SUM(IF(
            TO_DATE(reserve_time) = TO_DATE('${bizdate}', 'yyyyMMdd'),
            adult_qty + child_qty,
            0
        )) AS hotel_booking_guest_qty,                                            -- 酒店预订人数
        SUM(IF(
            TO_DATE(reserve_time) = TO_DATE('${bizdate}', 'yyyyMMdd'),
            charge_amt,
            0
        )) AS hotel_booking_sales_amt,                                            -- 酒店预订消费合计
        SUM(IF(
            TO_DATE(reserve_time) = TO_DATE('${bizdate}', 'yyyyMMdd'),
            pay_amt,
            0
        )) AS hotel_booking_pay_amt,                                              -- 酒店预订实付合计
        SUM(IF(
            TO_DATE(reserve_time) = TO_DATE('${bizdate}', 'yyyyMMdd') AND order_status = 'X',
            1,
            0
        )) AS hotel_booking_cancel_order_qty,                                     -- 酒店预订取消单数
        SUM(IF(
            TO_DATE(reserve_time) = TO_DATE('${bizdate}', 'yyyyMMdd') AND order_status = 'X',
            room_qty,
            0
        )) AS hotel_booking_cancel_room_qty,                                      -- 酒店预订取消房间数
        SUM(IF(
            TO_DATE(reserve_time) = TO_DATE('${bizdate}', 'yyyyMMdd') AND order_status = 'X',
            adult_qty,
            0
        )) AS hotel_booking_cancel_adult_qty,                                     -- 酒店预订取消成人数
        SUM(IF(
            TO_DATE(reserve_time) = TO_DATE('${bizdate}', 'yyyyMMdd') AND order_status = 'X',
            child_qty,
            0
        )) AS hotel_booking_cancel_child_qty,                                     -- 酒店预订取消儿童数
        SUM(IF(
            TO_DATE(reserve_time) = TO_DATE('${bizdate}', 'yyyyMMdd') AND order_status = 'X',
            adult_qty + child_qty,
            0
        )) AS hotel_booking_cancel_guest_qty,                                     -- 酒店预订取消人数
        SUM(IF(
            TO_DATE(reserve_time) = TO_DATE('${bizdate}', 'yyyyMMdd') AND order_status = 'X',
            charge_amt,
            0
        )) AS hotel_booking_cancel_sales_amt,                                     -- 酒店预订取消消费合计
        SUM(IF(
            TO_DATE(reserve_time) = TO_DATE('${bizdate}', 'yyyyMMdd') AND order_status = 'X',
            pay_amt,
            0
        )) AS hotel_booking_cancel_pay_amt,                                       -- 酒店预订取消实付合计
        SUM(IF(arrive_date = TO_DATE('${bizdate}', 'yyyyMMdd'), 1, 0)) AS hotel_checkin_order_qty,  -- 酒店入住单数
        SUM(IF(arrive_date = TO_DATE('${bizdate}', 'yyyyMMdd'), room_qty, 0)) AS hotel_checkin_room_qty,  -- 酒店入住房间数
        SUM(IF(arrive_date = TO_DATE('${bizdate}', 'yyyyMMdd'), adult_qty, 0)) AS hotel_checkin_adult_qty,  -- 酒店入住成人数
        SUM(IF(arrive_date = TO_DATE('${bizdate}', 'yyyyMMdd'), child_qty, 0)) AS hotel_checkin_child_qty,  -- 酒店入住儿童数
        SUM(IF(
            arrive_date = TO_DATE('${bizdate}', 'yyyyMMdd'),
            adult_qty + child_qty,
            0
        )) AS hotel_checkin_guest_qty,                                            -- 酒店入住人数
        SUM(IF(arrive_date = TO_DATE('${bizdate}', 'yyyyMMdd'), charge_amt, 0)) AS hotel_checkin_sales_amt,  -- 酒店入住消费合计
        SUM(IF(arrive_date = TO_DATE('${bizdate}', 'yyyyMMdd'), pay_amt, 0)) AS hotel_checkin_pay_amt,  -- 酒店入住实付合计
        SUM(IF(
            arrive_date = TO_DATE('${bizdate}', 'yyyyMMdd') AND order_status = 'X',
            1,
            0
        )) AS hotel_checkin_cancel_order_qty,                                     -- 酒店入住取消单数
        SUM(IF(
            arrive_date = TO_DATE('${bizdate}', 'yyyyMMdd') AND order_status = 'X',
            room_qty,
            0
        )) AS hotel_checkin_cancel_room_qty,                                      -- 酒店入住取消房间数
        SUM(IF(
            arrive_date = TO_DATE('${bizdate}', 'yyyyMMdd') AND order_status = 'X',
            adult_qty,
            0
        )) AS hotel_checkin_cancel_adult_qty,                                     -- 酒店入住取消成人数
        SUM(IF(
            arrive_date = TO_DATE('${bizdate}', 'yyyyMMdd') AND order_status = 'X',
            child_qty,
            0
        )) AS hotel_checkin_cancel_child_qty,                                     -- 酒店入住取消儿童数
        SUM(IF(
            arrive_date = TO_DATE('${bizdate}', 'yyyyMMdd') AND order_status = 'X',
            adult_qty + child_qty,
            0
        )) AS hotel_checkin_cancel_guest_qty,                                     -- 酒店入住取消人数
        SUM(IF(
            arrive_date = TO_DATE('${bizdate}', 'yyyyMMdd') AND order_status = 'X',
            charge_amt,
            0
        )) AS hotel_checkin_cancel_sales_amt,                                     -- 酒店入住取消消费合计
        SUM(IF(
            arrive_date = TO_DATE('${bizdate}', 'yyyyMMdd') AND order_status = 'X',
            pay_amt,
            0
        )) AS hotel_checkin_cancel_pay_amt                                        -- 酒店入住取消实付合计
    FROM dwd.dwd_opr_hotel_order_df
    WHERE travel_date = '${bizdate}'                                              -- 只取当日分区
    GROUP BY hotel_code                                                           -- 按粒度键汇总
) u                                                                               -- 各来源合并后的明细
GROUP BY hotel_code                                                               -- 按粒度键汇总
