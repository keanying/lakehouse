-- ================================================================================================
-- ads.ads_ord_scenic_trade_overview_di  景区经营概览
-- 粒度：1行=1天×景区×门票
-- 分区：travel_date（YYYYMMDD）
-- 调度：每日，依赖上游 DWS 当日分区；完成后回流 / 服务层读取
-- 上游：dws_ord_scenic_ticket_trade_di
-- 替代旧任务 15 个（上线对数一致后下线）：
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
--   · … 另 3 个
-- 性能：
--   · ADS 只存日粒度：周 / 月 / 年 / 节假日 / 自定义区间与同比环比在查询时关联 dim_opr_period_f（见「指标口径 · ADS 业务指标」）
--   · 比率类不落比率值，只存分子分母；去重类存位图；快照类取日终值
-- ================================================================================================
INSERT OVERWRITE TABLE ads.ads_ord_scenic_trade_overview_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
    scenic_id,                                                                    -- 景区ID
    ticket_id,                                                                    -- 票ID
    SUM(order_order_qty)                                         AS order_order_qty,  -- 预订订单数（日）
    SUM(order_ticket_qty)                                        AS order_ticket_qty,  -- 预订票数（日）
    SUM(order_sale_amt)                                          AS order_sale_amt,  -- 预订金额（日）
    SUM(order_cost_amt)                                          AS order_cost_amt,  -- 预订成本金额（日）
    SUM(pay_order_qty)                                           AS pay_order_qty,  -- 支付订单数（日）
    SUM(pay_ticket_qty)                                          AS pay_ticket_qty,  -- 支付票数（日）
    SUM(pay_sale_amt)                                            AS pay_sale_amt,  -- 支付金额（日）
    SUM(cancel_order_qty)                                        AS cancel_order_qty,  -- 取消订单数（日）
    SUM(cancel_ticket_qty)                                       AS cancel_ticket_qty,  -- 取消票数（日）
    SUM(cancel_sale_amt)                                         AS cancel_sale_amt,  -- 取消金额（日）
    SUM(cancel_cost_amt)                                         AS cancel_cost_amt,  -- 取消成本金额（日）
    SUM(verify_order_qty)                                        AS verify_order_qty,  -- 验证订单数（日）
    SUM(verify_ticket_qty)                                       AS verify_ticket_qty,  -- 验证票数（日）
    SUM(verify_sale_amt)                                         AS verify_sale_amt,  -- 验证金额（日）
    SUM(verify_cost_amt)                                         AS verify_cost_amt,  -- 验证成本金额（日）
    SUM(finish_order_qty)                                        AS finish_order_qty,  -- 完结订单数（日）
    SUM(finish_ticket_qty)                                       AS finish_ticket_qty,  -- 完结票数（日）
    SUM(finish_sale_amt)                                         AS finish_sale_amt,  -- 完结金额（日）
    SUM(finish_cost_amt)                                         AS finish_cost_amt,  -- 完结成本金额（日）
    SUM(revoke_order_qty)                                        AS revoke_order_qty,  -- 撤销订单数（日）
    SUM(revoke_ticket_qty)                                       AS revoke_ticket_qty,  -- 撤销票数（日）
    SUM(revoke_sale_amt)                                         AS revoke_sale_amt,  -- 撤销金额（日）
    SUM(revoke_cost_amt)                                         AS revoke_cost_amt,  -- 撤销成本金额（日）
    SUM(after_sale_refund_amt)                                   AS after_sale_refund_amt,  -- 售后退回金额（日）
    BITMAP_UNION(buyer_bitmap)                                   AS buyer_bitmap,  -- 购买人数去重位图（日）
    SUM(pay_cost_amt)                                            AS pay_cost_amt,  -- 支付成本金额（日）
    SUM(cancel_fee_amt)                                          AS cancel_fee_amt,  -- 取消手续费（日）
    SUM(revoke_fee_amt)                                          AS revoke_fee_amt,  -- 撤销手续费（日）
    SUM(pay_sale_discount_amt)                                   AS pay_sale_discount_amt,  -- 预订销售优惠金额（日）
    SUM(pay_cost_discount_amt)                                   AS pay_cost_discount_amt,  -- 预订采购优惠金额（日）
    SUM(verify_sale_discount_amt)                                AS verify_sale_discount_amt,  -- 核销销售优惠金额（日）
    SUM(verify_cost_discount_amt)                                AS verify_cost_discount_amt,  -- 核销采购优惠金额（日）
    SUM(cancel_sale_discount_amt)                                AS cancel_sale_discount_amt,  -- 取消销售优惠金额（日）
    SUM(cancel_cost_discount_amt)                                AS cancel_cost_discount_amt,  -- 取消采购优惠金额（日）
    SUM(revoke_sale_discount_amt)                                AS revoke_sale_discount_amt,  -- 撤销销售优惠金额（日）
    SUM(revoke_cost_discount_amt)                                AS revoke_cost_discount_amt,  -- 撤销采购优惠金额（日）
    SUM(cancel_cost_fee_amt)                                     AS cancel_cost_fee_amt,  -- 取消采购手续费（日）
    SUM(revoke_cost_fee_amt)                                     AS revoke_cost_fee_amt,  -- 撤销采购手续费（日）
    SUM(after_sale_cost_amt)                                     AS after_sale_cost_amt,  -- 售后支出金额（日）
    SUM(reprint_ticket_qty)                                      AS reprint_ticket_qty,  -- 重打印票数（日）
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time           -- ETL 加载时间
FROM (
    -- dws_ord_scenic_ticket_trade_di
    SELECT
        scenic_id,                                                                -- 景区ID
        ticket_id,                                                                -- 票ID
        SUM(order_order_qty)                                         AS order_order_qty,  -- 预订订单数（日）
        SUM(order_ticket_qty)                                        AS order_ticket_qty,  -- 预订票数（日）
        SUM(order_sale_amt)                                          AS order_sale_amt,  -- 预订金额（日）
        SUM(order_cost_amt)                                          AS order_cost_amt,  -- 预订成本金额（日）
        SUM(pay_order_qty)                                           AS pay_order_qty,  -- 支付订单数（日）
        SUM(pay_ticket_qty)                                          AS pay_ticket_qty,  -- 支付票数（日）
        SUM(pay_sale_amt)                                            AS pay_sale_amt,  -- 支付金额（日）
        SUM(cancel_order_qty)                                        AS cancel_order_qty,  -- 取消订单数（日）
        SUM(cancel_ticket_qty)                                       AS cancel_ticket_qty,  -- 取消票数（日）
        SUM(cancel_sale_amt)                                         AS cancel_sale_amt,  -- 取消金额（日）
        SUM(cancel_cost_amt)                                         AS cancel_cost_amt,  -- 取消成本金额（日）
        SUM(verify_order_qty)                                        AS verify_order_qty,  -- 验证订单数（日）
        SUM(verify_ticket_qty)                                       AS verify_ticket_qty,  -- 验证票数（日）
        SUM(verify_sale_amt)                                         AS verify_sale_amt,  -- 验证金额（日）
        SUM(verify_cost_amt)                                         AS verify_cost_amt,  -- 验证成本金额（日）
        SUM(finish_order_qty)                                        AS finish_order_qty,  -- 完结订单数（日）
        SUM(finish_ticket_qty)                                       AS finish_ticket_qty,  -- 完结票数（日）
        SUM(finish_sale_amt)                                         AS finish_sale_amt,  -- 完结金额（日）
        SUM(finish_cost_amt)                                         AS finish_cost_amt,  -- 完结成本金额（日）
        SUM(revoke_order_qty)                                        AS revoke_order_qty,  -- 撤销订单数（日）
        SUM(revoke_ticket_qty)                                       AS revoke_ticket_qty,  -- 撤销票数（日）
        SUM(revoke_sale_amt)                                         AS revoke_sale_amt,  -- 撤销金额（日）
        SUM(revoke_cost_amt)                                         AS revoke_cost_amt,  -- 撤销成本金额（日）
        SUM(after_sale_refund_amt)                                   AS after_sale_refund_amt,  -- 售后退回金额（日）
        BITMAP_UNION(buyer_qty)                                      AS buyer_bitmap,  -- 购买人数去重位图（日）
        SUM(pay_cost_amt)                                            AS pay_cost_amt,  -- 支付成本金额（日）
        SUM(cancel_fee_amt)                                          AS cancel_fee_amt,  -- 取消手续费（日）
        SUM(revoke_fee_amt)                                          AS revoke_fee_amt,  -- 撤销手续费（日）
        SUM(pay_sale_discount_amt)                                   AS pay_sale_discount_amt,  -- 预订销售优惠金额（日）
        SUM(pay_cost_discount_amt)                                   AS pay_cost_discount_amt,  -- 预订采购优惠金额（日）
        SUM(verify_sale_discount_amt)                                AS verify_sale_discount_amt,  -- 核销销售优惠金额（日）
        SUM(verify_cost_discount_amt)                                AS verify_cost_discount_amt,  -- 核销采购优惠金额（日）
        SUM(cancel_sale_discount_amt)                                AS cancel_sale_discount_amt,  -- 取消销售优惠金额（日）
        SUM(cancel_cost_discount_amt)                                AS cancel_cost_discount_amt,  -- 取消采购优惠金额（日）
        SUM(revoke_sale_discount_amt)                                AS revoke_sale_discount_amt,  -- 撤销销售优惠金额（日）
        SUM(revoke_cost_discount_amt)                                AS revoke_cost_discount_amt,  -- 撤销采购优惠金额（日）
        SUM(cancel_cost_fee_amt)                                     AS cancel_cost_fee_amt,  -- 取消采购手续费（日）
        SUM(revoke_cost_fee_amt)                                     AS revoke_cost_fee_amt,  -- 撤销采购手续费（日）
        SUM(after_sale_cost_amt)                                     AS after_sale_cost_amt,  -- 售后支出金额（日）
        SUM(reprint_ticket_qty)                                      AS reprint_ticket_qty  -- 重打印票数（日）
    FROM dws.dws_ord_scenic_ticket_trade_di
    WHERE travel_date = '${bizdate}'                                              -- 只取当日分区
    GROUP BY scenic_id, ticket_id                                                 -- 按粒度键汇总
) u                                                                               -- 各来源合并后的明细
GROUP BY scenic_id, ticket_id                                                     -- 按粒度键汇总
