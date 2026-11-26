-- ================================================================================================
-- ads.ads_prd_resource_center_di  资源中心经营
-- 粒度：1行=1天×资源×供应商
-- 分区：travel_date（YYYYMMDD）
-- 调度：每日，依赖上游 DWS 当日分区；完成后回流 / 服务层读取
-- 上游：dws_prd_resource_center_di
-- 替代旧任务 8 个（上线对数一致后下线）：
--   · 业务工厂/内部信息/财务部/资源中心考核2/ads_res_center_assessment_province2022_d_f（EMR_SPARK_SQL，cron 00 00 05 * * ?）
--   · 业务工厂/内部信息/财务部/资源中心考核2/ads_res_center_assessment_province2022_detail_d_f（EMR_SPARK_SQL，cron 00 00 00 * * ?）
--   · 业务工厂/内部信息/财务部/资源中心考核2/ads_resource_center_cutchain_order_d_f2（EMR_SPARK_SQL，cron 00 00 00 * * ?）
--   · 业务工厂/内部信息/资源中心/资源中心汇总工作流/ads_resource_center_cutchain_order_d_f（EMR_SPARK_SQL，cron 00 00 00 * * ?）
--   · 业务工厂/内部信息/财务部/资源中心考核2/ads_resource_center_order_d_f（EMR_SPARK_SQL，cron 00 00 00 * * ?）
--   · 业务工厂/内部信息/资源中心/资源中心汇总工作流/ads_resource_center_order_d_f2（EMR_SPARK_SQL，cron 00 00 00 * * ?）
--   · 业务工厂/内部信息/资源中心/资源中心汇总工作流/ads_resource_center_ticket_summary_d_f（EMR_SPARK_SQL，cron 00 00 00 * * ?）
--   · 业务工厂/内部信息/资源中心/资源中心汇总工作流/ads_resource_purchase_list_d_f（EMR_SPARK_SQL，cron 00 00 00 * * ?）
-- 性能：
--   · ADS 只存日粒度：周 / 月 / 年 / 节假日 / 自定义区间与同比环比在查询时关联 dim_opr_period_f（见「指标口径 · ADS 业务指标」）
--   · 比率类不落比率值，只存分子分母；去重类存位图；快照类取日终值
-- ================================================================================================
INSERT OVERWRITE TABLE ads.ads_prd_resource_center_di PARTITION (travel_date = '${bizdate}')
SELECT
    resource_id,
    supplier_id,
    province_code,
    SUM(resource_purchase_qty)                                   AS resource_purchase_qty,
    SUM(resource_order_qty)                                      AS resource_order_qty,
    SUM(order_sale_amt)                                          AS order_sale_amt,
    SUM(pay_sale_amt)                                            AS pay_sale_amt,
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time
FROM (
    -- dws_prd_resource_center_di
    SELECT
        resource_id,
        supplier_id,
        province_code,
        SUM(resource_purchase_qty)                                   AS resource_purchase_qty,
        SUM(resource_order_qty)                                      AS resource_order_qty,
        SUM(order_sale_amt)                                          AS order_sale_amt,
        SUM(pay_sale_amt)                                            AS pay_sale_amt
    FROM dws.dws_prd_resource_center_di
    WHERE travel_date = '${bizdate}'
    GROUP BY resource_id, supplier_id, province_code
) u
GROUP BY resource_id, supplier_id, province_code
