-- ================================================================================================
-- ads.ads_opr_hotel_di  酒店经营
-- 粒度：1行=1天×酒店
-- 分区：travel_date（YYYYMMDD）
-- 调度：每日，依赖上游 DWS 当日分区；完成后回流 / 服务层读取
-- 上游：dws_opr_hotel_di
-- 性能：
--   · ADS 只存日粒度：周 / 月 / 年 / 节假日 / 自定义区间与同比环比在查询时关联 dim_opr_period_f（见「指标口径 · ADS 业务指标」）
--   · 比率类不落比率值，只存分子分母；去重类存位图；快照类取日终值
-- ================================================================================================
INSERT OVERWRITE TABLE ads.ads_opr_hotel_di PARTITION (travel_date = '${bizdate}')
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
    -- dws_opr_hotel_di
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
        SUM(hotel_checkin_cancel_pay_amt)                            AS hotel_checkin_cancel_pay_amt
    FROM dws.dws_opr_hotel_di
    WHERE travel_date = '${bizdate}'
    GROUP BY hotel_code
) u
GROUP BY hotel_code
