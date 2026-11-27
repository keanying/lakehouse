-- ================================================================================================
-- dws.dws_prd_resource_center_di  资源中心日汇总
-- 粒度：1行=1天×资源×供应商
-- 分区：travel_date（YYYYMMDD）
-- 调度：每日，依赖上游 DWD 当日分区
-- 上游：dwd_prd_resource_order_di、dim_prd_resource_df
-- 替代旧任务 2 个（上线对数一致后下线）：
--   · 业务工厂/内部信息/财务部/资源中心考核2/dws_resource_center_land_summary_d_f（EMR_SPARK_SQL，cron 00 00 00 * * ?）
--   · 业务工厂/内部信息/财务部/资源中心考核2/dws_resource_center_user_d_f2（EMR_SPARK_SQL，cron 00 00 00 * * ?）
-- 性能：
--   · 同一来源的指标在一个子查询里预聚合（一次扫描），各来源 UNION ALL 后按粒度汇总，不做明细级 JOIN
--   · 来源：resource = dwd.dwd_prd_resource_order_di（资源中心订单）
-- ================================================================================================
INSERT OVERWRITE TABLE dws.dws_prd_resource_center_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
    resource_id,                                                                  -- 资源中心资源ID
    supplier_id,                                                                  -- 供应商ID（租户ID）
    SUM(resource_purchase_qty)                                   AS resource_purchase_qty,  -- 资源采购数
    SUM(resource_order_qty)                                      AS resource_order_qty,  -- 资源中心订单数
    SUM(order_sale_amt)                                          AS order_sale_amt,  -- 预订金额
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time           -- ETL 加载时间
FROM (
    -- resource：资源中心订单
    SELECT
        COALESCE(resource_id, CAST(-1 AS BIGINT))                    AS resource_id,  -- 资源中心资源ID
        COALESCE(supplier_id, CAST(-1 AS BIGINT))                    AS supplier_id,  -- 供应商ID（租户ID）
        COUNT(DISTINCT purchase_member_id)                           AS resource_purchase_qty,  -- 资源采购数
        COUNT(DISTINCT order_no)                                     AS resource_order_qty,  -- 资源中心订单数
        SUM(booking_pay_amt)                                         AS order_sale_amt  -- 预订金额
    FROM dwd.dwd_prd_resource_order_di
    WHERE travel_date = '${bizdate}'                                              -- 只取当日分区
    GROUP BY COALESCE(resource_id, CAST(-1 AS BIGINT)), COALESCE(supplier_id, CAST(-1 AS BIGINT))  -- 按粒度键汇总
) u                                                                               -- 各来源合并后的明细
GROUP BY resource_id, supplier_id                                                 -- 按粒度键汇总
