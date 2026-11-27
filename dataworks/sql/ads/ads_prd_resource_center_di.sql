-- ================================================================================================
-- ads.ads_prd_resource_center_di  资源中心经营
-- 粒度：1行=1天×资源×供应商
-- 分区：travel_date（YYYYMMDD）
-- 调度：每日，依赖上游 DWS 当日分区；完成后回流 / 服务层读取
-- 上游：dws_prd_resource_center_di
-- 替代旧任务 2 个（上线对数一致后下线）：
--   · 业务工厂/内部信息/财务部/资源中心考核2/ads_resource_center_cutchain_order_d_f2（EMR_SPARK_SQL，cron 00 00 00 * * ?）
--   · 业务工厂/内部信息/财务部/资源中心考核2/ads_resource_center_order_d_f（EMR_SPARK_SQL，cron 00 00 00 * * ?）
-- 性能：
--   · ADS 只存日粒度：周 / 月 / 年 / 节假日 / 自定义区间与同比环比在查询时关联 dim_opr_period_f（见「指标口径 · ADS 业务指标」）
--   · 比率类不落比率值，只存分子分母；去重类存位图；快照类取日终值
-- ================================================================================================
INSERT OVERWRITE TABLE ads.ads_prd_resource_center_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
    resource_id,                                                                  -- 资源中心资源ID
    supplier_id,                                                                  -- 供应商ID（租户ID）
    SUM(resource_purchase_qty)                                   AS resource_purchase_qty,  -- 资源采购数（日）
    SUM(resource_order_qty)                                      AS resource_order_qty,  -- 资源中心订单数（日）
    SUM(order_sale_amt)                                          AS order_sale_amt,  -- 预订金额（日）
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time           -- ETL 加载时间
FROM (
    -- dws_prd_resource_center_di
    SELECT
        resource_id,                                                              -- 资源中心资源ID
        supplier_id,                                                              -- 供应商ID（租户ID）
        SUM(resource_purchase_qty)                                   AS resource_purchase_qty,  -- 资源采购数（日）
        SUM(resource_order_qty)                                      AS resource_order_qty,  -- 资源中心订单数（日）
        SUM(order_sale_amt)                                          AS order_sale_amt  -- 预订金额（日）
    FROM dws.dws_prd_resource_center_di
    WHERE travel_date = '${bizdate}'                                              -- 只取当日分区
    GROUP BY resource_id, supplier_id                                             -- 按粒度键汇总
) u                                                                               -- 各来源合并后的明细
GROUP BY resource_id, supplier_id                                                 -- 按粒度键汇总
