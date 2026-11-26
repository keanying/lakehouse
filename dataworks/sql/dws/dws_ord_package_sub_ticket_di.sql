-- ================================================================================================
-- dws.dws_ord_package_sub_ticket_di  套票子票预约使用日汇总
-- 粒度：1行=1天×主票×子票
-- 分区：travel_date（YYYYMMDD）
-- 调度：每日，依赖上游 DWD 当日分区
-- 上游：dwd_ord_order_di、dwd_ord_verify_di
-- 替代旧任务 2 个（上线对数一致后下线）：
--   · 数据平台/平台湖仓工作流/提前预定主子票汇总/dws_ord_scenic_package_sub_ticket_use_di（SERVERLESS_SPARK_SQL，cron 00 00 00 * * ?）
--   · 数据平台/平台湖仓工作流/提前预定主子票汇总/dws_ord_scenic_pkg_sub_ticket_reserve_di（SERVERLESS_SPARK_SQL，cron 00 00 00 * * ?）
-- 性能：
--   · 同一来源的指标在一个子查询里预聚合（一次扫描），各来源 UNION ALL 后按粒度汇总，不做明细级 JOIN
--   · 来源：pkg = dwd.dwd_ord_order_di（套票子票：关联同日主票订单取主票票ID）；pkg_vfy = dwd.dwd_ord_verify_di（子票核销）
-- ================================================================================================
INSERT OVERWRITE TABLE dws.dws_ord_package_sub_ticket_di PARTITION (travel_date = '${bizdate}')
SELECT
    scenic_id,
    main_ticket_id,
    sub_ticket_id,
    SUM(order_ticket_qty)                                        AS order_ticket_qty,
    SUM(verify_ticket_qty)                                       AS verify_ticket_qty,
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time
FROM (
    -- pkg：套票子票：关联同日主票订单取主票票ID
    SELECT
        COALESCE(scenic_id, CAST(-1 AS BIGINT))                      AS scenic_id,
        COALESCE(main_ticket_id, CAST(-1 AS BIGINT))                 AS main_ticket_id,
        COALESCE(ticket_id, CAST(-1 AS BIGINT))                      AS sub_ticket_id,
        SUM(origin_ticket_qty)                                       AS order_ticket_qty,
        CAST(0 AS BIGINT)                                            AS verify_ticket_qty
    FROM (
        SELECT s.*, m.ticket_id AS main_ticket_id
        FROM dwd.dwd_ord_order_di s
        JOIN (SELECT order_no, ticket_id FROM dwd.dwd_ord_order_di WHERE travel_date = '${bizdate}') m ON m.order_no = s.main_order_no
        WHERE s.travel_date = '${bizdate}'
    ) t
    WHERE test_flag = 0
      AND pay_status <> '2'
      AND order_role = 'SUB'
    GROUP BY COALESCE(scenic_id, CAST(-1 AS BIGINT)), COALESCE(main_ticket_id, CAST(-1 AS BIGINT)), COALESCE(ticket_id, CAST(-1 AS BIGINT))
    UNION ALL
    -- pkg_vfy：子票核销
    SELECT
        COALESCE(scenic_id, CAST(-1 AS BIGINT))                      AS scenic_id,
        COALESCE(main_ticket_id, CAST(-1 AS BIGINT))                 AS main_ticket_id,
        COALESCE(ticket_id, CAST(-1 AS BIGINT))                      AS sub_ticket_id,
        CAST(0 AS BIGINT)                                            AS order_ticket_qty,
        SUM(verify_ticket_qty)                                       AS verify_ticket_qty
    FROM (
        SELECT v.*, o.ticket_id AS main_ticket_id
        FROM dwd.dwd_ord_verify_di v
        JOIN (SELECT order_no, ticket_id FROM dwd.dwd_ord_order_di) o ON o.order_no = v.main_order_no
        WHERE v.travel_date = '${bizdate}'
    ) t
    WHERE test_flag = 0
      AND order_role = 'SUB'
    GROUP BY COALESCE(scenic_id, CAST(-1 AS BIGINT)), COALESCE(main_ticket_id, CAST(-1 AS BIGINT)), COALESCE(ticket_id, CAST(-1 AS BIGINT))
) u
GROUP BY scenic_id, main_ticket_id, sub_ticket_id
