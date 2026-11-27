-- ================================================================================================
-- ads.ads_sup_merchant_operation_di  商户经营数据中心
-- 粒度：1行=1天×商户×景区×门票
-- 分区：travel_date（YYYYMMDD）
-- 调度：每日，依赖上游 DWS 当日分区；完成后回流 / 服务层读取
-- 上游：dws_ord_scenic_ticket_trade_di、dws_sup_member_di
-- 替代旧任务 29 个（上线对数一致后下线）：
--   · 数据平台/平台湖仓工作流/商户数据中心/ads_s_company_channel_instance_stat_1h_i_workflow（EMR_SPARK_SQL，cron 00 00 00 * * ?）
--   · 业务工厂/商户数据中心/ADS/ads_s_company_channel_instance_stat_d_f（EMR_SPARK_SQL，cron 00 30 02 * * ?）
--   · 业务工厂/商户数据中心/ADS/ads_s_company_channel_stat_d_f（EMR_SPARK_SQL，cron 00 30 02 * * ?）
--   · 业务工厂/商户数据中心/ADS/ads_s_company_day_stat_d_i_f（EMR_SPARK_SQL，cron 00 00 02 * * ?）
--   · 数据平台/平台湖仓工作流/商户数据中心/ads_s_company_distributor_instance_stat_1h_i_workflow（EMR_SPARK_SQL，cron 00 00 00 * * ?）
--   · 业务工厂/商户数据中心/ADS/ads_s_company_distributor_instance_stat_d_f（EMR_SPARK_SQL，cron 00 27 00 * * ?）
--   · 业务工厂/商户数据中心/ADS/ads_s_company_distributor_stat_d_f（EMR_SPARK_SQL，cron 00 30 02 * * ?）
--   · 业务工厂/商户数据中心/ADS/ads_s_company_distributor_stat_d_i（EMR_SPARK_SQL，cron 00 21 00 * * ?）
--   · 数据平台/平台湖仓工作流/商户数据中心/ads_s_company_order_instance_stat_1h_i_workflow（EMR_SPARK_SQL，cron 00 00 00 * * ?）
--   · 业务工厂/商户数据中心/ADS/ads_s_company_order_instance_stat_d_f（EMR_SPARK_SQL，cron 00 40 02 * * ?）
--   · 业务工厂/商户数据中心/ADS/ads_s_company_order_stat_d_f（EMR_SPARK_SQL，cron 00 30 02 * * ?）
--   · 数据平台/平台湖仓工作流/商户数据中心/ads_s_company_product_instance_stat_1h_i_workflow（EMR_SPARK_SQL，cron 00 00 00 * * ?）
--   · … 另 17 个
-- 性能：
--   · ADS 只存日粒度：周 / 月 / 年 / 节假日 / 自定义区间与同比环比在查询时关联 dim_opr_period_f（见「指标口径 · ADS 业务指标」）
--   · 比率类不落比率值，只存分子分母；去重类存位图；快照类取日终值
--   · 多个上游各自预聚合后 UNION ALL，按 ADS 粒度合并（替代旧系统多表 FULL JOIN）
-- ================================================================================================
-- 补 0 / 补空列：多来源 UNION ALL 时，某来源不产出的指标补 0 或空，外层按粒度 SUM 后即为各来源之和，不影响结果
-- 取 -1 的维度列：该来源没有这个维度（如核销来源没有下单渠道），用 -1 表示「不适用」，按该维度分析时只看产出它的来源
INSERT OVERWRITE TABLE ads.ads_sup_merchant_operation_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
    member_id,                                                                    -- 商户ID
    scenic_id,                                                                    -- 景区ID
    ticket_id,                                                                    -- 票ID
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
    SUM(new_distributor_qty)                                     AS new_distributor_qty,  -- 新增分销商数（日）
    MAX(distributor_total_qty)                                   AS distributor_total_qty,  -- 分销商总数（日快照）
    MAX(onshelf_product_qty)                                     AS onshelf_product_qty,  -- 在售产品数（日快照）
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time           -- ETL 加载时间
FROM (
    -- dws_ord_scenic_ticket_trade_di
    SELECT
        CAST(-1 AS BIGINT)                                           AS member_id,  -- 商户ID：此来源不区分，取 -1（不适用）
        scenic_id,                                                                -- 景区ID
        ticket_id,                                                                -- 票ID
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
        CAST(0 AS BIGINT)                                            AS new_distributor_qty,  -- 新增分销商数（日）：此来源不产出，补0
        CAST(NULL AS BIGINT)                                         AS distributor_total_qty,  -- 分销商总数（日快照）：此来源不产出，补空
        CAST(NULL AS BIGINT)                                         AS onshelf_product_qty  -- 在售产品数（日快照）：此来源不产出，补空
    FROM dws.dws_ord_scenic_ticket_trade_di
    WHERE travel_date = '${bizdate}'                                              -- 只取当日分区
    GROUP BY scenic_id, ticket_id                                                 -- 按粒度键汇总
    UNION ALL
    -- dws_sup_member_di
    SELECT
        member_id,                                                                -- 商户ID
        CAST(-1 AS BIGINT)                                           AS scenic_id,  -- 景区ID：此来源不区分，取 -1（不适用）
        CAST(-1 AS BIGINT)                                           AS ticket_id,  -- 票ID：此来源不区分，取 -1（不适用）
        CAST(0 AS BIGINT)                                            AS order_order_qty,  -- 预订订单数（日）：此来源不产出，补0
        CAST(0 AS BIGINT)                                            AS order_ticket_qty,  -- 预订票数（日）：此来源不产出，补0
        CAST(0 AS DECIMAL(18,2))                                     AS order_sale_amt,  -- 预订金额（日）：此来源不产出，补0
        CAST(0 AS DECIMAL(18,2))                                     AS order_cost_amt,  -- 预订成本金额（日）：此来源不产出，补0
        CAST(0 AS BIGINT)                                            AS pay_order_qty,  -- 支付订单数（日）：此来源不产出，补0
        CAST(0 AS BIGINT)                                            AS pay_ticket_qty,  -- 支付票数（日）：此来源不产出，补0
        CAST(0 AS DECIMAL(18,2))                                     AS pay_sale_amt,  -- 支付金额（日）：此来源不产出，补0
        CAST(0 AS BIGINT)                                            AS verify_order_qty,  -- 验证订单数（日）：此来源不产出，补0
        CAST(0 AS BIGINT)                                            AS verify_ticket_qty,  -- 验证票数（日）：此来源不产出，补0
        CAST(0 AS DECIMAL(18,2))                                     AS verify_sale_amt,  -- 验证金额（日）：此来源不产出，补0
        CAST(0 AS DECIMAL(18,2))                                     AS verify_cost_amt,  -- 验证成本金额（日）：此来源不产出，补0
        CAST(0 AS BIGINT)                                            AS cancel_order_qty,  -- 取消订单数（日）：此来源不产出，补0
        CAST(0 AS BIGINT)                                            AS cancel_ticket_qty,  -- 取消票数（日）：此来源不产出，补0
        CAST(0 AS DECIMAL(18,2))                                     AS cancel_sale_amt,  -- 取消金额（日）：此来源不产出，补0
        CAST(0 AS DECIMAL(18,2))                                     AS cancel_cost_amt,  -- 取消成本金额（日）：此来源不产出，补0
        SUM(new_distributor_qty)                                     AS new_distributor_qty,  -- 新增分销商数（日）
        SUM(distributor_total_qty)                                   AS distributor_total_qty,  -- 分销商总数（日快照）
        SUM(onshelf_product_qty)                                     AS onshelf_product_qty  -- 在售产品数（日快照）
    FROM dws.dws_sup_member_di
    WHERE travel_date = '${bizdate}'                                              -- 只取当日分区
    GROUP BY member_id                                                            -- 按粒度键汇总
) u                                                                               -- 各来源合并后的明细
GROUP BY member_id, scenic_id, ticket_id                                          -- 按粒度键汇总
