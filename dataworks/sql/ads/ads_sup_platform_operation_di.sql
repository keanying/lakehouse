-- ================================================================================================
-- ads.ads_sup_platform_operation_di  平台经营（内部）
-- 粒度：1行=1天×商户
-- 分区：travel_date（YYYYMMDD）
-- 调度：每日，依赖上游 DWS 当日分区；完成后回流 / 服务层读取
-- 上游：dws_sup_member_di、dws_ord_scenic_ticket_trade_di
-- 替代旧任务 6 个（上线对数一致后下线）：
--   · 业务工厂/内部信息/市场（平台事业部）/公司BI/公司BI工作流/ads_company_order_month_summary_d_f（EMR_SPARK_SQL，cron 00 00 00 * * ?）
--   · 业务工厂/内部信息/市场（平台事业部）/公司BI/公司BI工作流/ads_marketing_department_supply_gmv_d_f（EMR_SPARK_SQL，cron 00 00 00 * * ?）
--   · 业务工厂/内部信息/市场（平台事业部）/公司BI/公司BI工作流/ads_module_open_rank_d_f（EMR_SPARK_SQL，cron 00 00 00 * * ?）
--   · 业务工厂/内部信息/市场（平台事业部）/公司BI/公司BI工作流/ads_operate_lv1_num_d_f（EMR_SPARK_SQL，cron 00 00 00 * * ?）
--   · 业务工厂/内部信息/公司/公司大屏/公司大屏工作流/ads_plat_map_fly_d_f（EMR_SPARK_SQL，cron 00 00 00 * * ?）
--   · 业务工厂/内部信息/公司/公司大屏/公司大屏工作流/ads_plat_third_purchase_order_d_f（EMR_SPARK_SQL，cron 00 00 00 * * ?）
-- 性能：
--   · ADS 只存日粒度：周 / 月 / 年 / 节假日 / 自定义区间与同比环比在查询时关联 dim_opr_period_f（见「指标口径 · ADS 业务指标」）
--   · 比率类不落比率值，只存分子分母；去重类存位图；快照类取日终值
--   · 多个上游各自预聚合后 UNION ALL，按 ADS 粒度合并（替代旧系统多表 FULL JOIN）
-- ================================================================================================
INSERT OVERWRITE TABLE ads.ads_sup_platform_operation_di PARTITION (travel_date = '${bizdate}')
SELECT
    member_id,
    BITMAP_UNION(login_member_bitmap)                            AS login_member_bitmap,
    SUM(module_open_qty)                                         AS module_open_qty,
    SUM(order_sale_amt)                                          AS order_sale_amt,
    SUM(pay_sale_amt)                                            AS pay_sale_amt,
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time
FROM (
    -- dws_sup_member_di
    SELECT
        member_id,
        BITMAP_UNION(login_member_qty)                               AS login_member_bitmap,
        SUM(module_open_qty)                                         AS module_open_qty,
        CAST(0 AS DECIMAL(18,2))                                     AS order_sale_amt,
        CAST(0 AS DECIMAL(18,2))                                     AS pay_sale_amt
    FROM dws.dws_sup_member_di
    WHERE travel_date = '${bizdate}'
    GROUP BY member_id
    UNION ALL
    -- dws_ord_scenic_ticket_trade_di
    SELECT
        CAST(-1 AS BIGINT)                                           AS member_id,   -- 该上游无此维度
        CAST(NULL AS BINARY)                                         AS login_member_bitmap,
        CAST(0 AS BIGINT)                                            AS module_open_qty,
        SUM(order_sale_amt)                                          AS order_sale_amt,
        SUM(pay_sale_amt)                                            AS pay_sale_amt
    FROM dws.dws_ord_scenic_ticket_trade_di
    WHERE travel_date = '${bizdate}'
) u
GROUP BY member_id
