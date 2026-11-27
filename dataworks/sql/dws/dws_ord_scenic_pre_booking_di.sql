-- ================================================================================================
-- dws.dws_ord_scenic_pre_booking_di  景区提前预订日汇总
-- 粒度：1行=1天（游玩日）×景区×门票×主子单×提前预订天数段
-- 分区：travel_date（YYYYMMDD）
-- 调度：每日，依赖上游 DWD 当日分区
-- 上游：dwd_ord_order_di
-- 性能：
--   · 同一来源的指标在一个子查询里预聚合（一次扫描），各来源 UNION ALL 后按粒度汇总，不做明细级 JOIN
--   · 来源：ord_play = dwd.dwd_ord_order_di（按游玩日：近 90 天下单、游玩日 = bizdate（旧 ads_daily_scenic_pre_booking 取近 80 天，放宽到 90））
-- ================================================================================================
INSERT OVERWRITE TABLE dws.dws_ord_scenic_pre_booking_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
    scenic_id,                                                                    -- 景区ID
    ticket_id,                                                                    -- 票ID
    order_role,                                                                   -- 主子单
    advance_day_group,                                                            -- 提前预订天数段
    city_code,                                                                    -- 客源市编码
    district_code,                                                                -- 客源区县编码
    province_code,                                                                -- 客源省编码（取票人证件 / 手机号归属）
    SUM(order_order_qty)                                         AS order_order_qty,  -- 预订订单数
    SUM(order_ticket_qty)                                        AS order_ticket_qty,  -- 预订票数
    SUM(order_sale_amt)                                          AS order_sale_amt,  -- 预订金额
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time           -- ETL 加载时间
FROM (
    -- ord_play：按游玩日：近 90 天下单、游玩日 = bizdate（旧 ads_daily_scenic_pre_booking 取近 80 天，放宽到 90）
    SELECT
        COALESCE(scenic_id, CAST(-1 AS BIGINT))                      AS scenic_id,  -- 景区ID
        COALESCE(ticket_id, CAST(-1 AS BIGINT))                      AS ticket_id,  -- 票ID
        order_role,                                                               -- 主子单
        CASE
            WHEN advance_day_qty <= 0 THEN '当天'
            WHEN advance_day_qty = 1 THEN '1'
            WHEN advance_day_qty <= 3 THEN '2-3'
            WHEN advance_day_qty <= 7 THEN '4-7'
            WHEN advance_day_qty <= 15 THEN '8-15'
            WHEN advance_day_qty <= 30 THEN '16-30'
            ELSE '30+'
        END AS advance_day_group,                                                 -- 提前预订天数段
        taker_city_code                                              AS city_code,  -- 客源市编码
        taker_district_code                                          AS district_code,  -- 客源区县编码
        taker_province_code                                          AS province_code,  -- 客源省编码（取票人证件 / 手机号归属）
        COUNT(1)                                                     AS order_order_qty,  -- 预订订单数
        SUM(origin_ticket_qty)                                       AS order_ticket_qty,  -- 预订票数
        SUM(origin_ticket_qty * sale_price_amt)                      AS order_sale_amt  -- 预订金额
    FROM dwd.dwd_ord_order_di
    WHERE travel_date BETWEEN DATE_FORMAT(DATE_SUB(TO_DATE('${bizdate}', 'yyyyMMdd'), 90), 'yyyyMMdd')
      AND '${bizdate}'
      AND test_flag = 0
      AND pay_status <> '2'
      AND play_date = DATE_FORMAT(TO_DATE('${bizdate}', 'yyyyMMdd'), 'yyyy-MM-dd')
    GROUP BY COALESCE(scenic_id, CAST(-1 AS BIGINT)),                             -- 按粒度键汇总
             COALESCE(ticket_id, CAST(-1 AS BIGINT)),
             order_role,                                                          -- 主子单
             CASE
        WHEN advance_day_qty <= 0 THEN '当天'
        WHEN advance_day_qty = 1 THEN '1'
        WHEN advance_day_qty <= 3 THEN '2-3'
        WHEN advance_day_qty <= 7 THEN '4-7'
        WHEN advance_day_qty <= 15 THEN '8-15'
        WHEN advance_day_qty <= 30 THEN '16-30'
        ELSE '30+'
    END , taker_city_code, taker_district_code, taker_province_code
) u                                                                               -- 各来源合并后的明细
GROUP BY scenic_id, ticket_id, order_role, advance_day_group, city_code, district_code, province_code  -- 按粒度键汇总
