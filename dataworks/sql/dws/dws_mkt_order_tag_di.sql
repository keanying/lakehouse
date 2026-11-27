-- ================================================================================================
-- dws.dws_mkt_order_tag_di  订单营销方式日汇总
-- 粒度：1行=1天×供应商×景区×营销方式
-- 分区：travel_date（YYYYMMDD）
-- 调度：每日，依赖上游 DWD 当日分区
-- 上游：dwd_mkt_order_tag_di
-- 性能：
--   · 同一来源的指标在一个子查询里预聚合（一次扫描），各来源 UNION ALL 后按粒度汇总，不做明细级 JOIN
--   · 来源：mkt_tag = dwd.dwd_mkt_order_tag_di（订单营销标签：当日下单订单 × 营销方式）
-- ================================================================================================
INSERT OVERWRITE TABLE dws.dws_mkt_order_tag_di PARTITION (travel_date = '${bizdate}')
SELECT
    supplier_id,
    scenic_id,
    marketing_type,
    SUM(order_order_qty)                                         AS order_order_qty,
    SUM(order_ticket_qty)                                        AS order_ticket_qty,
    SUM(order_sale_amt)                                          AS order_sale_amt,
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time
FROM (
    -- mkt_tag：订单营销标签：当日下单订单 × 营销方式
    SELECT
        COALESCE(supplier_id, CAST(-1 AS BIGINT))                    AS supplier_id,
        COALESCE(scenic_id, CAST(-1 AS BIGINT))                      AS scenic_id,
        marketing_type,
        COUNT(DISTINCT order_no)                                     AS order_order_qty,
        SUM(ticket_qty)                                              AS order_ticket_qty,
        SUM(sale_amt)                                                AS order_sale_amt
    FROM dwd.dwd_mkt_order_tag_di
    WHERE travel_date = '${bizdate}'
    GROUP BY COALESCE(supplier_id, CAST(-1 AS BIGINT)), COALESCE(scenic_id, CAST(-1 AS BIGINT)), marketing_type
) u
GROUP BY supplier_id, scenic_id, marketing_type
