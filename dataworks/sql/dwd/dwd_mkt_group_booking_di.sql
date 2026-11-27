-- ================================================================================================
-- dwd.dwd_mkt_group_booking_di  拼团订单明细
-- 粒度：1行=1张拼团订单
-- 分区：travel_date（YYYYMMDD）
-- 调度：每日，依赖上游 ODS 当日分区与相关维表
-- 上游：ods_mkt_group_booking_orders_df、ods_mkt_group_booking_df
-- 业务规则 / 修正：
--   · 拼团订单为全量快照，按下单时间 = bizdate 取当日；成团结果在 group_booking_open（开团表），需要时按 group_id 关联
-- ================================================================================================
INSERT OVERWRITE TABLE dwd.dwd_mkt_group_booking_di PARTITION (travel_date = '${bizdate}')
SELECT
    CAST(id AS BIGINT)                                           AS group_order_id,
    ordernum                                                     AS order_no,
    CAST(sid AS BIGINT)                                          AS supplier_id,
    CAST(mid AS BIGINT)                                          AS member_id,
    CAST(activity_id AS BIGINT)                                  AS activity_id,
    CAST(group_id AS BIGINT)                                     AS group_id,
    CAST(lid AS BIGINT)                                          AS scenic_id,
    CAST(tid AS BIGINT)                                          AS ticket_id,
    CAST(sale_channel AS INT)                                    AS sale_channel,
    CAST(price AS DECIMAL(18,2)) / 100                           AS group_price_amt,
    CAST(valid_mans AS BIGINT)                                   AS valid_man_qty,
    FROM_UNIXTIME(create_time)                                   AS order_time,
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time
FROM (
        SELECT o.*, g.lid, g.tid, g.price, g.valid_mans
        FROM ods.ods_mkt_group_booking_orders_df o
        LEFT JOIN ods.ods_mkt_group_booking_df g ON g.id = o.group_id AND g.travel_date = '${bizdate}'   -- 活动主键唯一，不放大
        WHERE o.travel_date = '${bizdate}' AND FROM_UNIXTIME(o.create_time, 'yyyyMMdd') = '${bizdate}'
    ) t
