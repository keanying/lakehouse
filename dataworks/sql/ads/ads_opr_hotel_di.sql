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
INSERT OVERWRITE TABLE ads.ads_opr_hotel_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
    hotel_code,                                                                   -- 酒店编码
    SUM(hotel_room_night_qty)                                    AS hotel_room_night_qty,  -- 酒店间夜数（日）
    SUM(hotel_revenue_amt)                                       AS hotel_revenue_amt,  -- 酒店营收（日）
    SUM(hotel_booking_order_qty)                                 AS hotel_booking_order_qty,  -- 酒店预订单数（日）
    SUM(hotel_booking_room_qty)                                  AS hotel_booking_room_qty,  -- 酒店预订房间数（日）
    SUM(hotel_booking_adult_qty)                                 AS hotel_booking_adult_qty,  -- 酒店预订成人数（日）
    SUM(hotel_booking_child_qty)                                 AS hotel_booking_child_qty,  -- 酒店预订儿童数（日）
    SUM(hotel_booking_guest_qty)                                 AS hotel_booking_guest_qty,  -- 酒店预订人数（日）
    SUM(hotel_booking_sales_amt)                                 AS hotel_booking_sales_amt,  -- 酒店预订消费合计（日）
    SUM(hotel_booking_pay_amt)                                   AS hotel_booking_pay_amt,  -- 酒店预订实付合计（日）
    SUM(hotel_booking_cancel_order_qty)                          AS hotel_booking_cancel_order_qty,  -- 酒店预订取消单数（日）
    SUM(hotel_booking_cancel_room_qty)                           AS hotel_booking_cancel_room_qty,  -- 酒店预订取消房间数（日）
    SUM(hotel_booking_cancel_adult_qty)                          AS hotel_booking_cancel_adult_qty,  -- 酒店预订取消成人数（日）
    SUM(hotel_booking_cancel_child_qty)                          AS hotel_booking_cancel_child_qty,  -- 酒店预订取消儿童数（日）
    SUM(hotel_booking_cancel_guest_qty)                          AS hotel_booking_cancel_guest_qty,  -- 酒店预订取消人数（日）
    SUM(hotel_booking_cancel_sales_amt)                          AS hotel_booking_cancel_sales_amt,  -- 酒店预订取消消费合计（日）
    SUM(hotel_booking_cancel_pay_amt)                            AS hotel_booking_cancel_pay_amt,  -- 酒店预订取消实付合计（日）
    SUM(hotel_checkin_order_qty)                                 AS hotel_checkin_order_qty,  -- 酒店入住单数（日）
    SUM(hotel_checkin_room_qty)                                  AS hotel_checkin_room_qty,  -- 酒店入住房间数（日）
    SUM(hotel_checkin_adult_qty)                                 AS hotel_checkin_adult_qty,  -- 酒店入住成人数（日）
    SUM(hotel_checkin_child_qty)                                 AS hotel_checkin_child_qty,  -- 酒店入住儿童数（日）
    SUM(hotel_checkin_guest_qty)                                 AS hotel_checkin_guest_qty,  -- 酒店入住人数（日）
    SUM(hotel_checkin_sales_amt)                                 AS hotel_checkin_sales_amt,  -- 酒店入住消费合计（日）
    SUM(hotel_checkin_pay_amt)                                   AS hotel_checkin_pay_amt,  -- 酒店入住实付合计（日）
    SUM(hotel_checkin_cancel_order_qty)                          AS hotel_checkin_cancel_order_qty,  -- 酒店入住取消单数（日）
    SUM(hotel_checkin_cancel_room_qty)                           AS hotel_checkin_cancel_room_qty,  -- 酒店入住取消房间数（日）
    SUM(hotel_checkin_cancel_adult_qty)                          AS hotel_checkin_cancel_adult_qty,  -- 酒店入住取消成人数（日）
    SUM(hotel_checkin_cancel_child_qty)                          AS hotel_checkin_cancel_child_qty,  -- 酒店入住取消儿童数（日）
    SUM(hotel_checkin_cancel_guest_qty)                          AS hotel_checkin_cancel_guest_qty,  -- 酒店入住取消人数（日）
    SUM(hotel_checkin_cancel_sales_amt)                          AS hotel_checkin_cancel_sales_amt,  -- 酒店入住取消消费合计（日）
    SUM(hotel_checkin_cancel_pay_amt)                            AS hotel_checkin_cancel_pay_amt,  -- 酒店入住取消实付合计（日）
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time           -- ETL 加载时间
FROM (
    -- dws_opr_hotel_di
    SELECT
        hotel_code,                                                               -- 酒店编码
        SUM(hotel_room_night_qty)                                    AS hotel_room_night_qty,  -- 酒店间夜数（日）
        SUM(hotel_revenue_amt)                                       AS hotel_revenue_amt,  -- 酒店营收（日）
        SUM(hotel_booking_order_qty)                                 AS hotel_booking_order_qty,  -- 酒店预订单数（日）
        SUM(hotel_booking_room_qty)                                  AS hotel_booking_room_qty,  -- 酒店预订房间数（日）
        SUM(hotel_booking_adult_qty)                                 AS hotel_booking_adult_qty,  -- 酒店预订成人数（日）
        SUM(hotel_booking_child_qty)                                 AS hotel_booking_child_qty,  -- 酒店预订儿童数（日）
        SUM(hotel_booking_guest_qty)                                 AS hotel_booking_guest_qty,  -- 酒店预订人数（日）
        SUM(hotel_booking_sales_amt)                                 AS hotel_booking_sales_amt,  -- 酒店预订消费合计（日）
        SUM(hotel_booking_pay_amt)                                   AS hotel_booking_pay_amt,  -- 酒店预订实付合计（日）
        SUM(hotel_booking_cancel_order_qty)                          AS hotel_booking_cancel_order_qty,  -- 酒店预订取消单数（日）
        SUM(hotel_booking_cancel_room_qty)                           AS hotel_booking_cancel_room_qty,  -- 酒店预订取消房间数（日）
        SUM(hotel_booking_cancel_adult_qty)                          AS hotel_booking_cancel_adult_qty,  -- 酒店预订取消成人数（日）
        SUM(hotel_booking_cancel_child_qty)                          AS hotel_booking_cancel_child_qty,  -- 酒店预订取消儿童数（日）
        SUM(hotel_booking_cancel_guest_qty)                          AS hotel_booking_cancel_guest_qty,  -- 酒店预订取消人数（日）
        SUM(hotel_booking_cancel_sales_amt)                          AS hotel_booking_cancel_sales_amt,  -- 酒店预订取消消费合计（日）
        SUM(hotel_booking_cancel_pay_amt)                            AS hotel_booking_cancel_pay_amt,  -- 酒店预订取消实付合计（日）
        SUM(hotel_checkin_order_qty)                                 AS hotel_checkin_order_qty,  -- 酒店入住单数（日）
        SUM(hotel_checkin_room_qty)                                  AS hotel_checkin_room_qty,  -- 酒店入住房间数（日）
        SUM(hotel_checkin_adult_qty)                                 AS hotel_checkin_adult_qty,  -- 酒店入住成人数（日）
        SUM(hotel_checkin_child_qty)                                 AS hotel_checkin_child_qty,  -- 酒店入住儿童数（日）
        SUM(hotel_checkin_guest_qty)                                 AS hotel_checkin_guest_qty,  -- 酒店入住人数（日）
        SUM(hotel_checkin_sales_amt)                                 AS hotel_checkin_sales_amt,  -- 酒店入住消费合计（日）
        SUM(hotel_checkin_pay_amt)                                   AS hotel_checkin_pay_amt,  -- 酒店入住实付合计（日）
        SUM(hotel_checkin_cancel_order_qty)                          AS hotel_checkin_cancel_order_qty,  -- 酒店入住取消单数（日）
        SUM(hotel_checkin_cancel_room_qty)                           AS hotel_checkin_cancel_room_qty,  -- 酒店入住取消房间数（日）
        SUM(hotel_checkin_cancel_adult_qty)                          AS hotel_checkin_cancel_adult_qty,  -- 酒店入住取消成人数（日）
        SUM(hotel_checkin_cancel_child_qty)                          AS hotel_checkin_cancel_child_qty,  -- 酒店入住取消儿童数（日）
        SUM(hotel_checkin_cancel_guest_qty)                          AS hotel_checkin_cancel_guest_qty,  -- 酒店入住取消人数（日）
        SUM(hotel_checkin_cancel_sales_amt)                          AS hotel_checkin_cancel_sales_amt,  -- 酒店入住取消消费合计（日）
        SUM(hotel_checkin_cancel_pay_amt)                            AS hotel_checkin_cancel_pay_amt  -- 酒店入住取消实付合计（日）
    FROM dws.dws_opr_hotel_di
    WHERE travel_date = '${bizdate}'                                              -- 只取当日分区
    GROUP BY hotel_code                                                           -- 按粒度键汇总
) u                                                                               -- 各来源合并后的明细
GROUP BY hotel_code                                                               -- 按粒度键汇总
