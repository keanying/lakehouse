-- ================================================================================================
-- dws.dws_sup_member_di  商户经营日汇总
-- 粒度：1行=1天×商户
-- 分区：travel_date（YYYYMMDD）
-- 调度：每日，依赖上游 DWD 当日分区
-- 上游：dwd_sup_member_login_di、dim_sup_member_relation_zip、dim_prd_ticket_df、dwd_opr_module_open_di
-- 替代旧任务 4 个（上线对数一致后下线）：
--   · 业务工厂/内部信息/财务部/客户属性cus_company/dws_cus_company_login_d_f（EMR_SPARK_SQL，cron 00 00 00 * * ?）
--   · 业务工厂/内部信息/财务部/客户属性cus_company/dws_cus_company_partner_d_f（EMR_SPARK_SQL，cron 00 00 00 * * ?）
--   · 业务工厂/内部信息/财务部/客户属性cus_company/dws_cus_company_prod_d_f（EMR_SPARK_SQL，cron 00 00 00 * * ?）
--   · 业务工厂/内部信息/财务部/客户属性cus_company/dws_company_package_it_d_f（EMR_SPARK_SQL，cron 00 00 00 * * ?）
-- 性能：
--   · 同一来源的指标在一个子查询里预聚合（一次扫描），各来源 UNION ALL 后按粒度汇总，不做明细级 JOIN
--   · 去重类指标存位图（TO_BITMAP / BITMAP_UNION，UDF 与 PFT3.0 同一套），任意周期 BITMAP_UNION_COUNT
--   · 来源：login = dwd.dwd_sup_member_login_di（商户登录）；relation = dim.dim_sup_member_relation_zip（分销关系拉链（当前快照））；ticketdim = dim.dim_prd_ticket_df（票维度（当前快照））；module = dwd.dwd_opr_module_open_di（模块开通）
-- ================================================================================================
INSERT OVERWRITE TABLE dws.dws_sup_member_di PARTITION (travel_date = '${bizdate}')
SELECT
    member_id,
    city_code,
    district_code,
    province_code,
    BITMAP_UNION(login_member_qty)                               AS login_member_qty,
    SUM(new_distributor_qty)                                     AS new_distributor_qty,
    MAX(distributor_total_qty)                                   AS distributor_total_qty,
    MAX(onshelf_product_qty)                                     AS onshelf_product_qty,
    SUM(module_open_qty)                                         AS module_open_qty,
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time
FROM (
    -- login：商户登录
    SELECT
        COALESCE(member_id, CAST(-1 AS BIGINT))                      AS member_id,
        CAST(NULL AS STRING)                                         AS city_code,   -- 该来源无此维度，取默认值
        CAST(NULL AS STRING)                                         AS district_code,   -- 该来源无此维度，取默认值
        CAST(NULL AS STRING)                                         AS province_code,   -- 该来源无此维度，取默认值
        BITMAP_UNION(TO_BITMAP(member_id))                           AS login_member_qty,
        CAST(0 AS BIGINT)                                            AS new_distributor_qty,
        CAST(NULL AS BIGINT)                                         AS distributor_total_qty,
        CAST(NULL AS BIGINT)                                         AS onshelf_product_qty,
        CAST(0 AS BIGINT)                                            AS module_open_qty
    FROM dwd.dwd_sup_member_login_di
    WHERE travel_date = '${bizdate}'
    GROUP BY COALESCE(member_id, CAST(-1 AS BIGINT))
    UNION ALL
    -- relation：分销关系拉链（当前快照）
    SELECT
        COALESCE(supplier_id, CAST(-1 AS BIGINT))                    AS member_id,
        CAST(NULL AS STRING)                                         AS city_code,   -- 该来源无此维度，取默认值
        CAST(NULL AS STRING)                                         AS district_code,   -- 该来源无此维度，取默认值
        CAST(NULL AS STRING)                                         AS province_code,   -- 该来源无此维度，取默认值
        CAST(NULL AS BINARY)                                         AS login_member_qty,
        COUNT(DISTINCT IF(DATE_FORMAT(add_time, 'yyyyMMdd') = '${bizdate}', distributor_id, NULL)) AS new_distributor_qty,
        COUNT(DISTINCT IF(end_date = '99991231', distributor_id, NULL)) AS distributor_total_qty,
        CAST(NULL AS BIGINT)                                         AS onshelf_product_qty,
        CAST(0 AS BIGINT)                                            AS module_open_qty
    FROM dim.dim_sup_member_relation_zip
    WHERE supplier_id IS NOT NULL
    GROUP BY COALESCE(supplier_id, CAST(-1 AS BIGINT))
    UNION ALL
    -- ticketdim：票维度（当前快照）
    SELECT
        COALESCE(supplier_id, CAST(-1 AS BIGINT))                    AS member_id,
        CAST(NULL AS STRING)                                         AS city_code,   -- 该来源无此维度，取默认值
        CAST(NULL AS STRING)                                         AS district_code,   -- 该来源无此维度，取默认值
        CAST(NULL AS STRING)                                         AS province_code,   -- 该来源无此维度，取默认值
        CAST(NULL AS BINARY)                                         AS login_member_qty,
        CAST(0 AS BIGINT)                                            AS new_distributor_qty,
        CAST(NULL AS BIGINT)                                         AS distributor_total_qty,
        SUM(IF(ticket_status = '1', 1, 0))                           AS onshelf_product_qty,
        CAST(0 AS BIGINT)                                            AS module_open_qty
    FROM dim.dim_prd_ticket_df
    GROUP BY COALESCE(supplier_id, CAST(-1 AS BIGINT))
    UNION ALL
    -- module：模块开通
    SELECT
        COALESCE(member_id, CAST(-1 AS BIGINT))                      AS member_id,
        CAST(NULL AS STRING)                                         AS city_code,   -- 该来源无此维度，取默认值
        CAST(NULL AS STRING)                                         AS district_code,   -- 该来源无此维度，取默认值
        CAST(NULL AS STRING)                                         AS province_code,   -- 该来源无此维度，取默认值
        CAST(NULL AS BINARY)                                         AS login_member_qty,
        CAST(0 AS BIGINT)                                            AS new_distributor_qty,
        CAST(NULL AS BIGINT)                                         AS distributor_total_qty,
        CAST(NULL AS BIGINT)                                         AS onshelf_product_qty,
        COUNT(1)                                                     AS module_open_qty
    FROM dwd.dwd_opr_module_open_di
    WHERE travel_date = '${bizdate}'
    GROUP BY COALESCE(member_id, CAST(-1 AS BIGINT))
) u
GROUP BY member_id, city_code, district_code, province_code
