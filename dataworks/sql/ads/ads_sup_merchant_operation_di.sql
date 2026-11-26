-- ================================================================================================
-- ads.ads_sup_merchant_operation_di  商户经营数据中心
-- 粒度：1行=1天×商户×景区×门票
-- 分区：travel_date（YYYYMMDD）
-- 调度：每日，依赖上游 DWS 当日分区；完成后回流 / 服务层读取
-- 上游：dws_ord_scenic_ticket_trade_di、dws_sup_member_di
-- 替代旧任务 32 个（上线对数一致后下线）：
--   · 数据平台/平台湖仓工作流/商户数据中心/ads_s_company_channel_instance_stat_1h_i_workflow（EMR_SPARK_SQL，cron 00 00 00 * * ?）
--   · 业务工厂/商户数据中心/ADS/ads_s_company_channel_instance_stat_d_f（EMR_SPARK_SQL，cron 00 30 02 * * ?）
--   · 业务工厂/商户数据中心/ADS/ads_s_company_channel_stat_d_f（EMR_SPARK_SQL，cron 00 30 02 * * ?）
--   · 业务工厂/商户数据中心/ADS/ads_s_company_day_stat_d_i_f（EMR_SPARK_SQL，cron 00 00 02 * * ?）
--   · 数据平台/平台湖仓工作流/商户数据中心/ads_s_company_distributor_instance_stat_1h_i_workflow（EMR_SPARK_SQL，cron 00 00 00 * * ?）
--   · 业务工厂/商户数据中心/ADS/ads_s_company_distributor_instance_stat_d_f（EMR_SPARK_SQL，cron 00 27 00 * * ?）
--   · 业务工厂/商户数据中心/ADS/ads_s_company_distributor_stat_d_f（EMR_SPARK_SQL，cron 00 30 02 * * ?）
--   · 业务工厂/商户数据中心/ADS/ads_s_company_distributor_stat_d_i（EMR_SPARK_SQL，cron 00 21 00 * * ?）
--   · 业务工厂/商户数据中心/ADS/ads_s_company_distributor_stat_o_i（EMR_SPARK_SQL，cron 00 18 00 * * ?）
--   · 数据平台/平台湖仓工作流/商户数据中心/ads_s_company_order_instance_stat_1h_i_workflow（EMR_SPARK_SQL，cron 00 00 00 * * ?）
--   · 业务工厂/商户数据中心/ADS/ads_s_company_order_instance_stat_d_f（EMR_SPARK_SQL，cron 00 40 02 * * ?）
--   · 业务工厂/商户数据中心/ADS/ads_s_company_order_stat_d_f（EMR_SPARK_SQL，cron 00 30 02 * * ?）
--   · … 另 20 个
-- 性能：
--   · ADS 只存日粒度：周 / 月 / 年 / 节假日 / 自定义区间与同比环比在查询时关联 dim_opr_period_f（见「指标口径 · ADS 业务指标」）
--   · 比率类不落比率值，只存分子分母；去重类存位图；快照类取日终值
--   · 多个上游各自预聚合后 UNION ALL，按 ADS 粒度合并（替代旧系统多表 FULL JOIN）
-- ================================================================================================
INSERT OVERWRITE TABLE ads.ads_sup_merchant_operation_di PARTITION (travel_date = '${bizdate}')
SELECT
    member_id,
    scenic_id,
    ticket_id,
    city_code,
    district_code,
    province_code,
    SUM(order_order_qty)                                         AS order_order_qty,
    SUM(order_ticket_qty)                                        AS order_ticket_qty,
    SUM(order_sale_amt)                                          AS order_sale_amt,
    SUM(order_cost_amt)                                          AS order_cost_amt,
    SUM(pay_order_qty)                                           AS pay_order_qty,
    SUM(pay_ticket_qty)                                          AS pay_ticket_qty,
    SUM(pay_sale_amt)                                            AS pay_sale_amt,
    SUM(verify_order_qty)                                        AS verify_order_qty,
    SUM(verify_ticket_qty)                                       AS verify_ticket_qty,
    SUM(verify_sale_amt)                                         AS verify_sale_amt,
    SUM(verify_cost_amt)                                         AS verify_cost_amt,
    SUM(cancel_order_qty)                                        AS cancel_order_qty,
    SUM(cancel_ticket_qty)                                       AS cancel_ticket_qty,
    SUM(cancel_sale_amt)                                         AS cancel_sale_amt,
    SUM(cancel_cost_amt)                                         AS cancel_cost_amt,
    SUM(new_distributor_qty)                                     AS new_distributor_qty,
    MAX(distributor_total_qty)                                   AS distributor_total_qty,
    MAX(onshelf_product_qty)                                     AS onshelf_product_qty,
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time
FROM (
    -- dws_ord_scenic_ticket_trade_di
    SELECT
        CAST(-1 AS BIGINT)                                           AS member_id,   -- 该上游无此维度
        scenic_id,
        ticket_id,
        city_code,
        district_code,
        province_code,
        SUM(order_order_qty)                                         AS order_order_qty,
        SUM(order_ticket_qty)                                        AS order_ticket_qty,
        SUM(order_sale_amt)                                          AS order_sale_amt,
        SUM(order_cost_amt)                                          AS order_cost_amt,
        SUM(pay_order_qty)                                           AS pay_order_qty,
        SUM(pay_ticket_qty)                                          AS pay_ticket_qty,
        SUM(pay_sale_amt)                                            AS pay_sale_amt,
        SUM(verify_order_qty)                                        AS verify_order_qty,
        SUM(verify_ticket_qty)                                       AS verify_ticket_qty,
        SUM(verify_sale_amt)                                         AS verify_sale_amt,
        SUM(verify_cost_amt)                                         AS verify_cost_amt,
        SUM(cancel_order_qty)                                        AS cancel_order_qty,
        SUM(cancel_ticket_qty)                                       AS cancel_ticket_qty,
        SUM(cancel_sale_amt)                                         AS cancel_sale_amt,
        SUM(cancel_cost_amt)                                         AS cancel_cost_amt,
        CAST(0 AS BIGINT)                                            AS new_distributor_qty,
        CAST(NULL AS BIGINT)                                         AS distributor_total_qty,
        CAST(NULL AS BIGINT)                                         AS onshelf_product_qty
    FROM dws.dws_ord_scenic_ticket_trade_di
    WHERE travel_date = '${bizdate}'
    GROUP BY scenic_id, ticket_id, city_code, district_code, province_code
    UNION ALL
    -- dws_sup_member_di
    SELECT
        member_id,
        CAST(-1 AS BIGINT)                                           AS scenic_id,   -- 该上游无此维度
        CAST(-1 AS BIGINT)                                           AS ticket_id,   -- 该上游无此维度
        city_code,
        district_code,
        province_code,
        CAST(0 AS BIGINT)                                            AS order_order_qty,
        CAST(0 AS BIGINT)                                            AS order_ticket_qty,
        CAST(0 AS DECIMAL(18,2))                                     AS order_sale_amt,
        CAST(0 AS DECIMAL(18,2))                                     AS order_cost_amt,
        CAST(0 AS BIGINT)                                            AS pay_order_qty,
        CAST(0 AS BIGINT)                                            AS pay_ticket_qty,
        CAST(0 AS DECIMAL(18,2))                                     AS pay_sale_amt,
        CAST(0 AS BIGINT)                                            AS verify_order_qty,
        CAST(0 AS BIGINT)                                            AS verify_ticket_qty,
        CAST(0 AS DECIMAL(18,2))                                     AS verify_sale_amt,
        CAST(0 AS DECIMAL(18,2))                                     AS verify_cost_amt,
        CAST(0 AS BIGINT)                                            AS cancel_order_qty,
        CAST(0 AS BIGINT)                                            AS cancel_ticket_qty,
        CAST(0 AS DECIMAL(18,2))                                     AS cancel_sale_amt,
        CAST(0 AS DECIMAL(18,2))                                     AS cancel_cost_amt,
        SUM(new_distributor_qty)                                     AS new_distributor_qty,
        SUM(distributor_total_qty)                                   AS distributor_total_qty,
        SUM(onshelf_product_qty)                                     AS onshelf_product_qty
    FROM dws.dws_sup_member_di
    WHERE travel_date = '${bizdate}'
    GROUP BY member_id, city_code, district_code, province_code
) u
GROUP BY member_id, scenic_id, ticket_id, city_code, district_code, province_code
