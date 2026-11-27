-- ================================================================================================
-- ads.ads_cus_scenic_traveler_profile_di  景区游客画像
-- 粒度：1行=1天×景区×门票×行为×主子单×团散×客源省市×性别×年龄段×同行人数段
-- 分区：travel_date（YYYYMMDD）
-- 调度：每日，依赖上游 DWS 当日分区；完成后回流 / 服务层读取
-- 上游：dws_ord_scenic_traveler_profile_di
-- 替代旧任务 66 个（上线对数一致后下线）：
--   · 业务工厂/景区指标旧表/每日景区同行人数旧表工作流/ads_daily_fellow_group_d_i（EMR_SPARK_SQL，cron 00 00 00 * * ?）
--   · 业务工厂/景区指标旧表/每日景区同行人数旧表工作流/ads_daily_scenic_fellow_group_d_i（EMR_SPARK_SQL，cron 00 00 00 * * ?）
--   · 业务工厂/景区指标旧表/每日景区同行人数旧表工作流/ads_daily_scenic_fellow_group_remain_d_i（EMR_SPARK_SQL，cron 00 00 00 * * ?）
--   · 业务工厂/景区指标宽表/每日景区预定画像工作流/ads_daily_scenic_order_draw_d_i（EMR_SPARK_SQL，cron 00 00 00 * * ?）
--   · 业务工厂/景区指标旧表/每日景区同行人数旧表工作流/ads_daily_scenic_province_fellow_group_d_i（EMR_SPARK_SQL，cron 00 00 00 * * ?）
--   · 业务工厂/景区指标旧表/每日景区同行人数旧表工作流/ads_daily_scenic_province_fellow_group_remain_d_i（EMR_SPARK_SQL，cron 00 00 00 * * ?）
--   · 业务工厂/景区指标旧表/每日景区预定画像旧表工作流/ads_daily_scenic_province_sex_age_d_i（EMR_SPARK_SQL，cron 00 00 00 * * ?）
--   · 业务工厂/景区指标宽表/每日景区预定画像主子票工作流/ads_daily_scenic_sub_order_draw_detail_d_i（SERVERLESS_SPARK_SQL，cron 00 00 04 * * ?）
--   · 业务工厂/景区指标旧表/每日景区同行人数旧表工作流/ads_daily_scenic_ticket_fellow_group_d_i（EMR_SPARK_SQL，cron 00 00 00 * * ?）
--   · 业务工厂/景区指标旧表/每日景区同行人数旧表工作流/ads_daily_scenic_ticket_province_fellow_group_d_i（EMR_SPARK_SQL，cron 00 00 00 * * ?）
--   · 业务工厂/景区指标旧表/每日景区预定画像旧表工作流/ads_daily_scenic_ticket_province_sex_age_d_i（EMR_SPARK_SQL，cron 00 00 00 * * ?）
--   · 业务工厂/景区指标宽表/每日景区取票人画像工作流/ads_daily_scenic_ticket_taker_order_draw_d_i（EMR_SPARK_SQL，cron 00 00 00 * * ?）
--   · … 另 54 个
-- 性能：
--   · ADS 只存日粒度：周 / 月 / 年 / 节假日 / 自定义区间与同比环比在查询时关联 dim_opr_period_f（见「指标口径 · ADS 业务指标」）
--   · 比率类不落比率值，只存分子分母；去重类存位图；快照类取日终值
-- ================================================================================================
INSERT OVERWRITE TABLE ads.ads_cus_scenic_traveler_profile_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
    scenic_id,                                                           -- 景区ID
    ticket_id,                                                           -- 票ID
    behavior_type,                                                       -- 行为
    order_role,                                                          -- 主子单
    team_type,                                                           -- 团散
    province_code,                                                       -- 客源省编码（取票人证件 / 手机号归属）
    city_code,                                                           -- 客源市编码
    gender,                                                              -- 性别
    age_group,                                                           -- 年龄段
    fellow_group,                                                        -- 同行人数段
    district_code,                                                       -- 客源区县编码
    order_mode,                                                          -- 下单渠道编码
    pay_mode,                                                            -- 支付方式编码
    SUM(traveler_qty)                                            AS traveler_qty,  -- 游客人数（日）
    SUM(order_order_qty)                                         AS order_order_qty,  -- 预订订单数（日）
    SUM(order_ticket_qty)                                        AS order_ticket_qty,  -- 预订票数（日）
    SUM(verify_ticket_qty)                                       AS verify_ticket_qty,  -- 验证票数（日）
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time  -- ETL 加载时间
FROM (
    -- dws_ord_scenic_traveler_profile_di
    SELECT
        scenic_id,                                                       -- 景区ID
        ticket_id,                                                       -- 票ID
        behavior_type,                                                   -- 行为
        order_role,                                                      -- 主子单
        team_type,                                                       -- 团散
        province_code,                                                   -- 客源省编码（取票人证件 / 手机号归属）
        city_code,                                                       -- 客源市编码
        gender,                                                          -- 性别
        age_group,                                                       -- 年龄段
        fellow_group,                                                    -- 同行人数段
        district_code,                                                   -- 客源区县编码
        order_mode,                                                      -- 下单渠道编码
        pay_mode,                                                        -- 支付方式编码
        SUM(traveler_qty)                                            AS traveler_qty,  -- 游客人数（日）
        SUM(order_order_qty)                                         AS order_order_qty,  -- 预订订单数（日）
        SUM(order_ticket_qty)                                        AS order_ticket_qty,  -- 预订票数（日）
        SUM(verify_ticket_qty)                                       AS verify_ticket_qty  -- 验证票数（日）
    FROM dws.dws_ord_scenic_traveler_profile_di
    WHERE travel_date = '${bizdate}'                                     -- 只取当日分区
    GROUP BY scenic_id,                                                  -- 按粒度键汇总
             ticket_id,                                                  -- 票ID
             behavior_type,                                              -- 行为
             order_role,                                                 -- 主子单
             team_type,                                                  -- 团散
             province_code,                                              -- 客源省编码（取票人证件 / 手机号归属）
             city_code,                                                  -- 客源市编码
             gender,                                                     -- 性别
             age_group,                                                  -- 年龄段
             fellow_group,                                               -- 同行人数段
             district_code,                                              -- 客源区县编码
             order_mode,                                                 -- 下单渠道编码
             pay_mode                                                    -- 支付方式编码
) u                                                                      -- 各来源合并后的明细
GROUP BY scenic_id,                                                      -- 按粒度键汇总
         ticket_id,                                                      -- 票ID
         behavior_type,                                                  -- 行为
         order_role,                                                     -- 主子单
         team_type,                                                      -- 团散
         province_code,                                                  -- 客源省编码（取票人证件 / 手机号归属）
         city_code,                                                      -- 客源市编码
         gender,                                                         -- 性别
         age_group,                                                      -- 年龄段
         fellow_group,                                                   -- 同行人数段
         district_code,                                                  -- 客源区县编码
         order_mode,                                                     -- 下单渠道编码
         pay_mode                                                        -- 支付方式编码
