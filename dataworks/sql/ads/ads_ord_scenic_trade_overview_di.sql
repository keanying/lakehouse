-- ================================================================================================
-- ads.ads_ord_scenic_trade_overview_di  景区经营概览
-- 粒度：1行=1天×景区×门票
-- 分区：travel_date（YYYYMMDD）
-- 调度：每日，依赖上游 DWS 当日分区；完成后回流 / 服务层读取
-- 上游：dws_ord_scenic_ticket_trade_di
-- 替代旧任务 17 个（上线对数一致后下线）：
--   · 业务工厂/景区指标宽表/每日景区其他工作流/ads_daily_scenic_summary_d_i（SERVERLESS_SPARK_SQL，cron 00 30 03 * * ?）
--   · 业务工厂/景区指标宽表/每日景区其他工作流/ads_daily_scenic_estimate_d_f（EMR_SPARK_SQL，cron 00 00 00 * * ?）
--   · 业务工厂/景区指标宽表/每日景区其他工作流/ads_daily_ticket_refund_ratio_d_i（EMR_SPARK_SQL，cron 00 00 00 * * ?）
--   · 业务工厂/景区指标宽表/每日景区其他工作流/ads_monthly_ticket_refund_ratio_d_i（EMR_SPARK_SQL，cron 00 00 00 * * ?）
--   · 业务工厂/景区指标宽表/每日景区其他工作流/ads_yearly_ticket_refund_ratio_d_i（EMR_SPARK_SQL，cron 00 00 00 * * ?）
--   · 业务工厂/景区指标宽表/每日景区其他工作流/ads_daily_scenic_toi_d_i（EMR_SPARK_SQL，cron 00 00 00 * * ?）
--   · 业务工厂/景区指标宽表/每日景区其他工作流/ads_monthly_scenic_toi_d_i（EMR_SPARK_SQL，cron 00 00 00 * * ?）
--   · 业务工厂/景区指标宽表/每日景区其他工作流/ads_yearly_scenic_toi_d_i（EMR_SPARK_SQL，cron 00 00 00 * * ?）
--   · 业务工厂/数据开放服务/团散客/ads_toi_count_d_i（EMR_SPARK_SQL，cron 00 57 02 * * ?）
--   · 数据中台/应用数据层(ADS)/大数据分析/数据罗盘/ads_booking_sum_d_f（EMR_SPARK_SQL，cron 00 30 02 * * ?）
--   · 数据平台/ADS/ads_ord_order_booking_metric_di（SERVERLESS_SPARK_SQL，cron 00 29 04 * * ?）
--   · 数据平台/ADS/ads_ord_trade_metrics_di（SERVERLESS_SPARK_SQL，cron 00 30 04 * * ?）
--   · … 另 5 个
-- 性能：
--   · ADS 只存日粒度：周 / 月 / 年 / 节假日 / 自定义区间与同比环比在查询时关联 dim_opr_period_f（见「指标口径 · ADS 业务指标」）
--   · 比率类不落比率值，只存分子分母；去重类存位图；快照类取日终值
-- ================================================================================================
INSERT OVERWRITE TABLE ads.ads_ord_scenic_trade_overview_di PARTITION (travel_date = '${bizdate}')
SELECT
    scenic_id,
    ticket_id,
    distributor_id,
    order_mode,
    order_role,
    pay_mode,
    SUM(order_order_qty)                                         AS order_order_qty,
    SUM(order_ticket_qty)                                        AS order_ticket_qty,
    SUM(order_sale_amt)                                          AS order_sale_amt,
    SUM(order_cost_amt)                                          AS order_cost_amt,
    SUM(pay_order_qty)                                           AS pay_order_qty,
    SUM(pay_ticket_qty)                                          AS pay_ticket_qty,
    SUM(pay_sale_amt)                                            AS pay_sale_amt,
    SUM(cancel_order_qty)                                        AS cancel_order_qty,
    SUM(cancel_ticket_qty)                                       AS cancel_ticket_qty,
    SUM(cancel_sale_amt)                                         AS cancel_sale_amt,
    SUM(cancel_cost_amt)                                         AS cancel_cost_amt,
    SUM(verify_order_qty)                                        AS verify_order_qty,
    SUM(verify_ticket_qty)                                       AS verify_ticket_qty,
    SUM(verify_sale_amt)                                         AS verify_sale_amt,
    SUM(verify_cost_amt)                                         AS verify_cost_amt,
    SUM(finish_order_qty)                                        AS finish_order_qty,
    SUM(finish_ticket_qty)                                       AS finish_ticket_qty,
    SUM(finish_sale_amt)                                         AS finish_sale_amt,
    SUM(finish_cost_amt)                                         AS finish_cost_amt,
    SUM(revoke_order_qty)                                        AS revoke_order_qty,
    SUM(revoke_ticket_qty)                                       AS revoke_ticket_qty,
    SUM(revoke_sale_amt)                                         AS revoke_sale_amt,
    SUM(revoke_cost_amt)                                         AS revoke_cost_amt,
    SUM(after_sale_refund_amt)                                   AS after_sale_refund_amt,
    BITMAP_UNION(buyer_bitmap)                                   AS buyer_bitmap,
    SUM(after_sale_income_amt)                                   AS after_sale_income_amt,
    SUM(after_sale_ticket_qty)                                   AS after_sale_ticket_qty,
    SUM(card_sale_amt)                                           AS card_sale_amt,
    SUM(card_sale_qty)                                           AS card_sale_qty,
    SUM(enter_qty)                                               AS enter_qty,
    SUM(print_order_qty)                                         AS print_order_qty,
    SUM(print_sale_amt)                                          AS print_sale_amt,
    SUM(print_ticket_qty)                                        AS print_ticket_qty,
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time
FROM (
    -- dws_ord_scenic_ticket_trade_di
    SELECT
        scenic_id,
        ticket_id,
        distributor_id,
        order_mode,
        order_role,
        pay_mode,
        SUM(order_order_qty)                                         AS order_order_qty,
        SUM(order_ticket_qty)                                        AS order_ticket_qty,
        SUM(order_sale_amt)                                          AS order_sale_amt,
        SUM(order_cost_amt)                                          AS order_cost_amt,
        SUM(pay_order_qty)                                           AS pay_order_qty,
        SUM(pay_ticket_qty)                                          AS pay_ticket_qty,
        SUM(pay_sale_amt)                                            AS pay_sale_amt,
        SUM(cancel_order_qty)                                        AS cancel_order_qty,
        SUM(cancel_ticket_qty)                                       AS cancel_ticket_qty,
        SUM(cancel_sale_amt)                                         AS cancel_sale_amt,
        SUM(cancel_cost_amt)                                         AS cancel_cost_amt,
        SUM(verify_order_qty)                                        AS verify_order_qty,
        SUM(verify_ticket_qty)                                       AS verify_ticket_qty,
        SUM(verify_sale_amt)                                         AS verify_sale_amt,
        SUM(verify_cost_amt)                                         AS verify_cost_amt,
        SUM(finish_order_qty)                                        AS finish_order_qty,
        SUM(finish_ticket_qty)                                       AS finish_ticket_qty,
        SUM(finish_sale_amt)                                         AS finish_sale_amt,
        SUM(finish_cost_amt)                                         AS finish_cost_amt,
        SUM(revoke_order_qty)                                        AS revoke_order_qty,
        SUM(revoke_ticket_qty)                                       AS revoke_ticket_qty,
        SUM(revoke_sale_amt)                                         AS revoke_sale_amt,
        SUM(revoke_cost_amt)                                         AS revoke_cost_amt,
        SUM(after_sale_refund_amt)                                   AS after_sale_refund_amt,
        BITMAP_UNION(buyer_qty)                                      AS buyer_bitmap,
        SUM(after_sale_income_amt)                                   AS after_sale_income_amt,
        SUM(after_sale_ticket_qty)                                   AS after_sale_ticket_qty,
        SUM(card_sale_amt)                                           AS card_sale_amt,
        SUM(card_sale_qty)                                           AS card_sale_qty,
        SUM(enter_qty)                                               AS enter_qty,
        SUM(print_order_qty)                                         AS print_order_qty,
        SUM(print_sale_amt)                                          AS print_sale_amt,
        SUM(print_ticket_qty)                                        AS print_ticket_qty
    FROM dws.dws_ord_scenic_ticket_trade_di
    WHERE travel_date = '${bizdate}'
    GROUP BY scenic_id, ticket_id, distributor_id, order_mode, order_role, pay_mode
) u
GROUP BY scenic_id, ticket_id, distributor_id, order_mode, order_role, pay_mode
