-- ================================================================================================
-- ads.ads_ord_scenic_channel_di  景区渠道与分销结构
-- 粒度：1行=1天×景区×门票×下单渠道×分销商×支付方式
-- 分区：travel_date（YYYYMMDD）
-- 调度：每日，依赖上游 DWS 当日分区；完成后回流 / 服务层读取
-- 上游：dws_ord_scenic_ticket_trade_di
-- 替代旧任务 19 个（上线对数一致后下线）：
--   · 业务工厂/景区指标旧表/每日景区销售渠道旧表工作流/ads_daily_scenic_channel_d_i（EMR_SPARK_SQL，cron 00 00 00 * * ?）
--   · 业务工厂/景区指标旧表/每日景区支付渠道旧表工作流/ads_daily_scenic_province_channel_d_i（EMR_SPARK_SQL，cron 00 00 00 * * ?）
--   · 业务工厂/景区指标旧表/每日景区销售渠道旧表工作流/ads_daily_scenic_ticket_channel_d_i（EMR_SPARK_SQL，cron 00 00 00 * * ?）
--   · 业务工厂/景区指标旧表/每日景区支付渠道旧表工作流/ads_daily_scenic_ticket_province_channel_d_i（EMR_SPARK_SQL，cron 00 00 00 * * ?）
--   · 业务工厂/景区指标旧表/每日景区销售渠道旧表工作流/ads_monthly_scenic_channel_d_i（EMR_SPARK_SQL，cron 00 00 00 * * ?）
--   · 业务工厂/景区指标旧表/每日景区支付渠道旧表工作流/ads_monthly_scenic_province_channel_d_i（EMR_SPARK_SQL，cron 00 00 00 * * ?）
--   · 业务工厂/景区指标旧表/每日景区销售渠道旧表工作流/ads_monthly_scenic_ticket_channel_d_i（EMR_SPARK_SQL，cron 00 00 00 * * ?）
--   · 业务工厂/景区指标旧表/每日景区销售渠道旧表工作流/ads_yearly_scenic_channel_d_i（EMR_SPARK_SQL，cron 00 00 00 * * ?）
--   · 业务工厂/景区指标旧表/每日景区支付渠道旧表工作流/ads_yearly_scenic_province_channel_d_i（EMR_SPARK_SQL，cron 00 00 00 * * ?）
--   · 业务工厂/景区指标旧表/每日景区销售渠道旧表工作流/ads_yearly_scenic_ticket_channel_d_i（EMR_SPARK_SQL，cron 00 00 00 * * ?）
--   · 业务工厂/景区指标旧表/每日景区销售渠道旧表工作流/ads_daily_full_channel_d_i（EMR_SPARK_SQL，cron 00 00 00 * * ?）
--   · 业务工厂/景区指标旧表/每日景区销售渠道旧表工作流/ads_daily_ticket_full_channel_d_i（EMR_SPARK_SQL，cron 00 00 00 * * ?）
--   · … 另 7 个
-- 性能：
--   · ADS 只存日粒度：周 / 月 / 年 / 节假日 / 自定义区间与同比环比在查询时关联 dim_opr_period_f（见「指标口径 · ADS 业务指标」）
--   · 比率类不落比率值，只存分子分母；去重类存位图；快照类取日终值
-- ================================================================================================
INSERT OVERWRITE TABLE ads.ads_ord_scenic_channel_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
    scenic_id,                                                                    -- 景区ID
    ticket_id,                                                                    -- 票ID
    order_mode,                                                                   -- 下单渠道编码
    distributor_id,                                                               -- 一级分销商ID
    pay_mode,                                                                     -- 支付方式编码
    order_role,                                                                   -- 主子单
    province_code,                                                                -- 客源省编码（取票人证件 / 手机号归属）
    SUM(order_order_qty)                                         AS order_order_qty,  -- 预订订单数（日）
    SUM(order_ticket_qty)                                        AS order_ticket_qty,  -- 预订票数（日）
    SUM(order_sale_amt)                                          AS order_sale_amt,  -- 预订金额（日）
    SUM(order_cost_amt)                                          AS order_cost_amt,  -- 预订成本金额（日）
    SUM(pay_order_qty)                                           AS pay_order_qty,  -- 支付订单数（日）
    SUM(pay_ticket_qty)                                          AS pay_ticket_qty,  -- 支付票数（日）
    SUM(pay_sale_amt)                                            AS pay_sale_amt,  -- 支付金额（日）
    SUM(verify_order_qty)                                        AS verify_order_qty,  -- 验证订单数（日）
    SUM(verify_ticket_qty)                                       AS verify_ticket_qty,  -- 验证票数（日）
    SUM(verify_sale_amt)                                         AS verify_sale_amt,  -- 验证金额（日）
    SUM(verify_cost_amt)                                         AS verify_cost_amt,  -- 验证成本金额（日）
    SUM(cancel_order_qty)                                        AS cancel_order_qty,  -- 取消订单数（日）
    SUM(cancel_ticket_qty)                                       AS cancel_ticket_qty,  -- 取消票数（日）
    SUM(cancel_sale_amt)                                         AS cancel_sale_amt,  -- 取消金额（日）
    SUM(cancel_cost_amt)                                         AS cancel_cost_amt,  -- 取消成本金额（日）
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time           -- ETL 加载时间
FROM (
    -- dws_ord_scenic_ticket_trade_di
    SELECT
        scenic_id,                                                                -- 景区ID
        ticket_id,                                                                -- 票ID
        order_mode,                                                               -- 下单渠道编码
        distributor_id,                                                           -- 一级分销商ID
        pay_mode,                                                                 -- 支付方式编码
        order_role,                                                               -- 主子单
        province_code,                                                            -- 客源省编码（取票人证件 / 手机号归属）
        SUM(order_order_qty)                                         AS order_order_qty,  -- 预订订单数（日）
        SUM(order_ticket_qty)                                        AS order_ticket_qty,  -- 预订票数（日）
        SUM(order_sale_amt)                                          AS order_sale_amt,  -- 预订金额（日）
        SUM(order_cost_amt)                                          AS order_cost_amt,  -- 预订成本金额（日）
        SUM(pay_order_qty)                                           AS pay_order_qty,  -- 支付订单数（日）
        SUM(pay_ticket_qty)                                          AS pay_ticket_qty,  -- 支付票数（日）
        SUM(pay_sale_amt)                                            AS pay_sale_amt,  -- 支付金额（日）
        SUM(verify_order_qty)                                        AS verify_order_qty,  -- 验证订单数（日）
        SUM(verify_ticket_qty)                                       AS verify_ticket_qty,  -- 验证票数（日）
        SUM(verify_sale_amt)                                         AS verify_sale_amt,  -- 验证金额（日）
        SUM(verify_cost_amt)                                         AS verify_cost_amt,  -- 验证成本金额（日）
        SUM(cancel_order_qty)                                        AS cancel_order_qty,  -- 取消订单数（日）
        SUM(cancel_ticket_qty)                                       AS cancel_ticket_qty,  -- 取消票数（日）
        SUM(cancel_sale_amt)                                         AS cancel_sale_amt,  -- 取消金额（日）
        SUM(cancel_cost_amt)                                         AS cancel_cost_amt  -- 取消成本金额（日）
    FROM dws.dws_ord_scenic_ticket_trade_di
    WHERE travel_date = '${bizdate}'                                              -- 只取当日分区
    GROUP BY scenic_id, ticket_id, order_mode, distributor_id, pay_mode, order_role, province_code  -- 按粒度键汇总
) u                                                                               -- 各来源合并后的明细
GROUP BY scenic_id, ticket_id, order_mode, distributor_id, pay_mode, order_role, province_code  -- 按粒度键汇总
