-- ================================================================================================
-- dws.dws_ord_scenic_traveler_profile_di  景区游客画像日汇总
-- 粒度：1行=1天×景区×门票×行为（预订 / 核销）×主子单×客源省市×性别×年龄段×同行人数段
-- 分区：travel_date（YYYYMMDD）
-- 调度：每日，依赖上游 DWD 当日分区
-- 上游：dwd_ord_traveler_di、dwd_ord_order_di、dwd_ord_verify_di
-- 性能：
--   · 同一来源的指标在一个子查询里预聚合（一次扫描），各来源 UNION ALL 后按粒度汇总，不做明细级 JOIN
--   · 来源：trv_book = dwd.dwd_ord_traveler_di（预订游客：当日下单）；trv_verify = dwd.dwd_ord_traveler_di（核销游客：当日验证）
-- ================================================================================================
-- 补 0 / 补空列：多来源 UNION ALL 时，某来源不产出的指标补 0 或空，外层按粒度 SUM 后即为各来源之和，不影响结果
INSERT OVERWRITE TABLE dws.dws_ord_scenic_traveler_profile_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
    scenic_id,                                                                    -- 景区ID
    ticket_id,                                                                    -- 票ID
    behavior_type,                                                                -- 行为
    order_role,                                                                   -- 主子单
    team_type,                                                                    -- 团散
    province_code,                                                                -- 客源省编码（取票人证件 / 手机号归属）
    city_code,                                                                    -- 客源市编码
    gender,                                                                       -- 性别
    age_group,                                                                    -- 年龄段
    fellow_group,                                                                 -- 同行人数段
    district_code,                                                                -- 客源区县编码
    order_mode,                                                                   -- 下单渠道编码
    pay_mode,                                                                     -- 支付方式编码
    SUM(traveler_qty)                                            AS traveler_qty,  -- 游客人数
    SUM(order_order_qty)                                         AS order_order_qty,  -- 预订订单数
    SUM(order_ticket_qty)                                        AS order_ticket_qty,  -- 预订票数
    SUM(verify_ticket_qty)                                       AS verify_ticket_qty,  -- 验证票数
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time           -- ETL 加载时间
FROM (
    -- trv_book：预订游客：当日下单
    SELECT
        COALESCE(scenic_id, CAST(-1 AS BIGINT))                      AS scenic_id,  -- 景区ID
        COALESCE(ticket_id, CAST(-1 AS BIGINT))                      AS ticket_id,  -- 票ID
        'BOOK'                                                       AS behavior_type,  -- 行为
        order_role,                                                               -- 主子单
        IF(team_flag = 1, 'TEAM', 'INDIVIDUAL')                      AS team_type,  -- 团散
        province_code,                                                            -- 客源省编码（取票人证件 / 手机号归属）
        city_code,                                                                -- 客源市编码
        gender,                                                                   -- 性别
        age_group,                                                                -- 年龄段
        CASE
            WHEN fellow_qty <= 1 THEN '1'
            WHEN fellow_qty <= 4 THEN '2-4'
            WHEN fellow_qty <= 9 THEN '5-9'
            ELSE '10+'
        END AS fellow_group,                                                      -- 同行人数段
        district_code,                                                            -- 客源区县编码
        COALESCE(order_mode, CAST(-1 AS INT))                        AS order_mode,  -- 下单渠道编码
        COALESCE(pay_mode, CAST(-1 AS INT))                          AS pay_mode,  -- 支付方式编码
        COUNT(1)                                                     AS traveler_qty,  -- 游客人数
        COUNT(DISTINCT order_no)                                     AS order_order_qty,  -- 预订订单数
        COUNT(1)                                                     AS order_ticket_qty,  -- 预订票数
        CAST(0 AS BIGINT)                                            AS verify_ticket_qty  -- 验证票数：此来源不产出，补0
    FROM dwd.dwd_ord_traveler_di
    WHERE travel_date = '${bizdate}'                                              -- 只取当日分区
      AND test_flag = 0
      AND SUBSTR(order_time, 1, 10) = DATE_FORMAT(TO_DATE('${bizdate}', 'yyyyMMdd'), 'yyyy-MM-dd')
    GROUP BY COALESCE(scenic_id, CAST(-1 AS BIGINT)),                             -- 按粒度键汇总
             COALESCE(ticket_id, CAST(-1 AS BIGINT)),
             'BOOK',
             order_role,                                                          -- 主子单
             IF(team_flag = 1, 'TEAM', 'INDIVIDUAL'),
             province_code,                                                       -- 客源省编码（取票人证件 / 手机号归属）
             city_code,                                                           -- 客源市编码
             gender,                                                              -- 性别
             age_group,                                                           -- 年龄段
             CASE
        WHEN fellow_qty <= 1 THEN '1'
        WHEN fellow_qty <= 4 THEN '2-4'
        WHEN fellow_qty <= 9 THEN '5-9'
        ELSE '10+'
    END , district_code, COALESCE(order_mode, CAST(-1 AS INT)), COALESCE(pay_mode, CAST(-1 AS INT))
    UNION ALL
    -- trv_verify：核销游客：当日验证
    SELECT
        COALESCE(scenic_id, CAST(-1 AS BIGINT))                      AS scenic_id,  -- 景区ID
        COALESCE(ticket_id, CAST(-1 AS BIGINT))                      AS ticket_id,  -- 票ID
        'VERIFY'                                                     AS behavior_type,  -- 行为
        order_role,                                                               -- 主子单
        IF(team_flag = 1, 'TEAM', 'INDIVIDUAL')                      AS team_type,  -- 团散
        province_code,                                                            -- 客源省编码（取票人证件 / 手机号归属）
        city_code,                                                                -- 客源市编码
        gender,                                                                   -- 性别
        age_group,                                                                -- 年龄段
        CASE
            WHEN fellow_qty <= 1 THEN '1'
            WHEN fellow_qty <= 4 THEN '2-4'
            WHEN fellow_qty <= 9 THEN '5-9'
            ELSE '10+'
        END AS fellow_group,                                                      -- 同行人数段
        district_code,                                                            -- 客源区县编码
        COALESCE(order_mode, CAST(-1 AS INT))                        AS order_mode,  -- 下单渠道编码
        COALESCE(pay_mode, CAST(-1 AS INT))                          AS pay_mode,  -- 支付方式编码
        CAST(0 AS BIGINT)                                            AS traveler_qty,  -- 游客人数：此来源不产出，补0
        CAST(0 AS BIGINT)                                            AS order_order_qty,  -- 预订订单数：此来源不产出，补0
        CAST(0 AS BIGINT)                                            AS order_ticket_qty,  -- 预订票数：此来源不产出，补0
        COUNT(1)                                                     AS verify_ticket_qty  -- 验证票数
    FROM dwd.dwd_ord_traveler_di
    WHERE travel_date = '${bizdate}'                                              -- 只取当日分区
      AND test_flag = 0
      AND SUBSTR(verify_time, 1, 10) = DATE_FORMAT(TO_DATE('${bizdate}', 'yyyyMMdd'), 'yyyy-MM-dd')
    GROUP BY COALESCE(scenic_id, CAST(-1 AS BIGINT)),                             -- 按粒度键汇总
             COALESCE(ticket_id, CAST(-1 AS BIGINT)),
             'VERIFY',
             order_role,                                                          -- 主子单
             IF(team_flag = 1, 'TEAM', 'INDIVIDUAL'),
             province_code,                                                       -- 客源省编码（取票人证件 / 手机号归属）
             city_code,                                                           -- 客源市编码
             gender,                                                              -- 性别
             age_group,                                                           -- 年龄段
             CASE
        WHEN fellow_qty <= 1 THEN '1'
        WHEN fellow_qty <= 4 THEN '2-4'
        WHEN fellow_qty <= 9 THEN '5-9'
        ELSE '10+'
    END , district_code, COALESCE(order_mode, CAST(-1 AS INT)), COALESCE(pay_mode, CAST(-1 AS INT))
) u                                                                               -- 各来源合并后的明细
GROUP BY scenic_id,                                                               -- 按粒度键汇总
         ticket_id,                                                               -- 票ID
         behavior_type,                                                           -- 行为
         order_role,                                                              -- 主子单
         team_type,                                                               -- 团散
         province_code,                                                           -- 客源省编码（取票人证件 / 手机号归属）
         city_code,                                                               -- 客源市编码
         gender,                                                                  -- 性别
         age_group,                                                               -- 年龄段
         fellow_group,                                                            -- 同行人数段
         district_code,                                                           -- 客源区县编码
         order_mode,                                                              -- 下单渠道编码
         pay_mode                                                                 -- 支付方式编码
