-- ================================================================================================
-- ads.ads_ord_scenic_pre_booking_di  景区提前预订
-- 粒度：1行=1天（游玩日）×景区×门票×主子单×提前天数段
-- 分区：travel_date（YYYYMMDD）
-- 调度：每日，依赖上游 DWS 当日分区；完成后回流 / 服务层读取
-- 上游：dws_ord_scenic_pre_booking_di
-- 替代旧任务 7 个（上线对数一致后下线）：
--   · 业务工厂/景区指标宽表/每日景区提前预定汇总工作流/ads_daily_scenic_pre_booking_d_i（EMR_SPARK_SQL，cron 00 00 00 * * ?）
--   · 业务工厂/景区指标宽表/每日景区提前预定汇总工作流/ads_daily_scenic_pre_booking_draw_d_i（EMR_SPARK_SQL，cron 00 00 00 * * ?）
--   · 业务工厂/景区指标宽表/每日景区提前预定汇总工作流/ads_daily_scenic_ticket_pre_booking_d_i（EMR_SPARK_SQL，cron 00 00 00 * * ?）
--   · 业务工厂/景区指标宽表/每日景区提前预定汇总工作流_新版/ads_daily_scenic_pre_booking_d_i（EMR_SPARK_SQL，cron 00 15 03 * * ?）
--   · 业务工厂/景区指标宽表/每日景区提前预定汇总工作流/ads_daily_scenic_ticket_pre_booking_draw_d_i（EMR_SPARK_SQL，cron 00 00 00 * * ?）
--   · 业务工厂/景区指标宽表/每日景区提前预定汇总工作流/ads_monthly_scenic_pre_booking_d_i（EMR_SPARK_SQL，cron 00 00 00 * * ?）
--   · 业务工厂/景区指标宽表/每日景区提前预定汇总工作流/ads_yearly_scenic_pre_booking_d_i（EMR_SPARK_SQL，cron 00 00 00 * * ?）
-- 性能：
--   · ADS 只存日粒度：周 / 月 / 年 / 节假日 / 自定义区间与同比环比在查询时关联 dim_opr_period_f（见「指标口径 · ADS 业务指标」）
--   · 比率类不落比率值，只存分子分母；去重类存位图；快照类取日终值
-- ================================================================================================
INSERT OVERWRITE TABLE ads.ads_ord_scenic_pre_booking_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
    scenic_id,                                                                    -- 景区ID
    ticket_id,                                                                    -- 票ID
    order_role,                                                                   -- 主子单
    advance_day_group,                                                            -- 提前预订天数段
    city_code,                                                                    -- 客源市编码
    district_code,                                                                -- 客源区县编码
    province_code,                                                                -- 客源省编码（取票人证件 / 手机号归属）
    SUM(order_order_qty)                                         AS order_order_qty,  -- 预订订单数（日）
    SUM(order_ticket_qty)                                        AS order_ticket_qty,  -- 预订票数（日）
    SUM(order_sale_amt)                                          AS order_sale_amt,  -- 预订金额（日）
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time           -- ETL 加载时间
FROM (
    -- dws_ord_scenic_pre_booking_di
    SELECT
        scenic_id,                                                                -- 景区ID
        ticket_id,                                                                -- 票ID
        order_role,                                                               -- 主子单
        advance_day_group,                                                        -- 提前预订天数段
        city_code,                                                                -- 客源市编码
        district_code,                                                            -- 客源区县编码
        province_code,                                                            -- 客源省编码（取票人证件 / 手机号归属）
        SUM(order_order_qty)                                         AS order_order_qty,  -- 预订订单数（日）
        SUM(order_ticket_qty)                                        AS order_ticket_qty,  -- 预订票数（日）
        SUM(order_sale_amt)                                          AS order_sale_amt  -- 预订金额（日）
    FROM dws.dws_ord_scenic_pre_booking_di
    WHERE travel_date = '${bizdate}'                                              -- 只取当日分区
    GROUP BY scenic_id, ticket_id, order_role, advance_day_group, city_code, district_code, province_code  -- 按粒度键汇总
) u                                                                               -- 各来源合并后的明细
GROUP BY scenic_id, ticket_id, order_role, advance_day_group, city_code, district_code, province_code  -- 按粒度键汇总
