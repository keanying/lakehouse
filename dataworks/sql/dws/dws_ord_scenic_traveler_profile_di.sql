-- ================================================================================================
-- dws.dws_ord_scenic_traveler_profile_di  景区游客画像日汇总
-- 粒度：1行=1天×景区×门票×行为（预订 / 核销）×主子单×客源省市×性别×年龄段×同行人数段
-- 分区：travel_date（YYYYMMDD）
-- 调度：每日，依赖上游 DWD 当日分区
-- 上游：dwd_ord_traveler_di、dwd_ord_order_di、dwd_ord_verify_di
-- 性能：
--   · 同一来源的指标在一个子查询里预聚合（一次扫描），各来源 UNION ALL 后按粒度汇总，不做明细级 JOIN
--   · 待确认（无来源）：order_sale_amt、pay_sale_amt、pay_ticket_qty、verify_sale_amt
--   · 来源：trv_book = dwd.dwd_ord_traveler_di（预订游客：当日下单）；trv_verify = dwd.dwd_ord_traveler_di（核销游客：当日验证）
-- ================================================================================================
INSERT OVERWRITE TABLE dws.dws_ord_scenic_traveler_profile_di PARTITION (travel_date = '${bizdate}')
SELECT
    scenic_id,
    ticket_id,
    behavior_type,
    order_role,
    team_type,
    province_code,
    city_code,
    gender,
    age_group,
    fellow_group,
    district_code,
    order_mode,
    pay_mode,
    SUM(traveler_qty)                                            AS traveler_qty,
    SUM(order_order_qty)                                         AS order_order_qty,
    SUM(order_ticket_qty)                                        AS order_ticket_qty,
    SUM(verify_ticket_qty)                                       AS verify_ticket_qty,
    CAST(NULL AS DECIMAL(18,2))                                  AS order_sale_amt,   -- 待确认：没有可用来源
    CAST(NULL AS DECIMAL(18,2))                                  AS pay_sale_amt,   -- 待确认：没有可用来源
    CAST(NULL AS BIGINT)                                         AS pay_ticket_qty,   -- 待确认：没有可用来源
    CAST(NULL AS DECIMAL(18,2))                                  AS verify_sale_amt,   -- 待确认：没有可用来源
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time
FROM (
    -- trv_book：预订游客：当日下单
    SELECT
        COALESCE(scenic_id, CAST(-1 AS BIGINT))                      AS scenic_id,
        COALESCE(ticket_id, CAST(-1 AS BIGINT))                      AS ticket_id,
        'BOOK'                                                       AS behavior_type,
        order_role,
        IF(team_flag = 1, 'TEAM', 'INDIVIDUAL')                      AS team_type,
        province_code,
        city_code,
        gender,
        age_group,
        CASE WHEN fellow_qty <= 1 THEN '1' WHEN fellow_qty <= 4 THEN '2-4' WHEN fellow_qty <= 9 THEN '5-9' ELSE '10+' END AS fellow_group,
        district_code,
        CAST(-1 AS INT)                                              AS order_mode,   -- 该来源无此维度，取默认值
        CAST(-1 AS INT)                                              AS pay_mode,   -- 该来源无此维度，取默认值
        COUNT(1)                                                     AS traveler_qty,
        COUNT(DISTINCT order_no)                                     AS order_order_qty,
        COUNT(1)                                                     AS order_ticket_qty,
        CAST(0 AS BIGINT)                                            AS verify_ticket_qty,
        CAST(0 AS DECIMAL(18,2))                                     AS order_sale_amt,
        CAST(0 AS DECIMAL(18,2))                                     AS pay_sale_amt,
        CAST(0 AS BIGINT)                                            AS pay_ticket_qty,
        CAST(0 AS DECIMAL(18,2))                                     AS verify_sale_amt
    FROM dwd.dwd_ord_traveler_di
    WHERE travel_date = '${bizdate}'
      AND test_flag = 0
      AND SUBSTR(order_time, 1, 10) = DATE_FORMAT(TO_DATE('${bizdate}', 'yyyyMMdd'), 'yyyy-MM-dd')
    GROUP BY COALESCE(scenic_id, CAST(-1 AS BIGINT)), COALESCE(ticket_id, CAST(-1 AS BIGINT)), 'BOOK', order_role, IF(team_flag = 1, 'TEAM', 'INDIVIDUAL'), province_code, city_code, gender, age_group, CASE WHEN fellow_qty <= 1 THEN '1' WHEN fellow_qty <= 4 THEN '2-4' WHEN fellow_qty <= 9 THEN '5-9' ELSE '10+' END, district_code
    UNION ALL
    -- trv_verify：核销游客：当日验证
    SELECT
        COALESCE(scenic_id, CAST(-1 AS BIGINT))                      AS scenic_id,
        COALESCE(ticket_id, CAST(-1 AS BIGINT))                      AS ticket_id,
        'VERIFY'                                                     AS behavior_type,
        order_role,
        IF(team_flag = 1, 'TEAM', 'INDIVIDUAL')                      AS team_type,
        province_code,
        city_code,
        gender,
        age_group,
        CASE WHEN fellow_qty <= 1 THEN '1' WHEN fellow_qty <= 4 THEN '2-4' WHEN fellow_qty <= 9 THEN '5-9' ELSE '10+' END AS fellow_group,
        district_code,
        CAST(-1 AS INT)                                              AS order_mode,   -- 该来源无此维度，取默认值
        CAST(-1 AS INT)                                              AS pay_mode,   -- 该来源无此维度，取默认值
        CAST(0 AS BIGINT)                                            AS traveler_qty,
        CAST(0 AS BIGINT)                                            AS order_order_qty,
        CAST(0 AS BIGINT)                                            AS order_ticket_qty,
        COUNT(1)                                                     AS verify_ticket_qty,
        CAST(0 AS DECIMAL(18,2))                                     AS order_sale_amt,
        CAST(0 AS DECIMAL(18,2))                                     AS pay_sale_amt,
        CAST(0 AS BIGINT)                                            AS pay_ticket_qty,
        CAST(0 AS DECIMAL(18,2))                                     AS verify_sale_amt
    FROM dwd.dwd_ord_traveler_di
    WHERE travel_date = '${bizdate}'
      AND test_flag = 0
      AND SUBSTR(verify_time, 1, 10) = DATE_FORMAT(TO_DATE('${bizdate}', 'yyyyMMdd'), 'yyyy-MM-dd')
    GROUP BY COALESCE(scenic_id, CAST(-1 AS BIGINT)), COALESCE(ticket_id, CAST(-1 AS BIGINT)), 'VERIFY', order_role, IF(team_flag = 1, 'TEAM', 'INDIVIDUAL'), province_code, city_code, gender, age_group, CASE WHEN fellow_qty <= 1 THEN '1' WHEN fellow_qty <= 4 THEN '2-4' WHEN fellow_qty <= 9 THEN '5-9' ELSE '10+' END, district_code
) u
GROUP BY scenic_id, ticket_id, behavior_type, order_role, team_type, province_code, city_code, gender, age_group, fellow_group, district_code, order_mode, pay_mode
