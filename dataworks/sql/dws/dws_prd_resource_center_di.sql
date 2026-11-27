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
--   · 待确认（无来源）：pay_sale_amt
--   · 来源：resource = dwd.dwd_prd_resource_order_di（资源中心订单）
-- ================================================================================================
INSERT OVERWRITE TABLE dws.dws_prd_resource_center_di PARTITION (travel_date = '${bizdate}')
SELECT
    resource_id,
    supplier_id,
    province_code,
    SUM(resource_purchase_qty)                                   AS resource_purchase_qty,
    SUM(resource_order_qty)                                      AS resource_order_qty,
    SUM(order_sale_amt)                                          AS order_sale_amt,
    CAST(NULL AS DECIMAL(18,2))                                  AS pay_sale_amt,   -- 待确认：没有可用来源
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time
FROM (
    -- resource：资源中心订单
    SELECT
        COALESCE(resource_id, CAST(-1 AS BIGINT))                    AS resource_id,
        COALESCE(supplier_id, CAST(-1 AS BIGINT))                    AS supplier_id,
        CAST(NULL AS STRING)                                         AS province_code,   -- 该来源无此维度，取默认值
        COUNT(DISTINCT purchase_member_id)                           AS resource_purchase_qty,
        COUNT(DISTINCT order_no)                                     AS resource_order_qty,
        SUM(booking_pay_amt)                                         AS order_sale_amt,
        CAST(0 AS DECIMAL(18,2))                                     AS pay_sale_amt
    FROM dwd.dwd_prd_resource_order_di
    WHERE travel_date = '${bizdate}'
    GROUP BY COALESCE(resource_id, CAST(-1 AS BIGINT)), COALESCE(supplier_id, CAST(-1 AS BIGINT))
) u
GROUP BY resource_id, supplier_id, province_code
