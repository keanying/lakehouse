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
INSERT OVERWRITE TABLE dws.dws_mkt_order_tag_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
    supplier_id,                                                                  -- 供应商ID（租户ID）
    scenic_id,                                                                    -- 景区ID
    marketing_type,                                                               -- 营销方式
    SUM(order_order_qty)                                         AS order_order_qty,  -- 预订订单数
    SUM(order_ticket_qty)                                        AS order_ticket_qty,  -- 预订票数
    SUM(order_sale_amt)                                          AS order_sale_amt,  -- 预订金额
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time           -- ETL 加载时间
FROM (
    -- mkt_tag：订单营销标签：当日下单订单 × 营销方式
    SELECT
        COALESCE(supplier_id, CAST(-1 AS BIGINT))                    AS supplier_id,  -- 供应商ID（租户ID）
        COALESCE(scenic_id, CAST(-1 AS BIGINT))                      AS scenic_id,  -- 景区ID
        marketing_type,                                                           -- 营销方式
        COUNT(DISTINCT order_no)                                     AS order_order_qty,  -- 预订订单数
        SUM(ticket_qty)                                              AS order_ticket_qty,  -- 预订票数
        SUM(sale_amt)                                                AS order_sale_amt  -- 预订金额
    FROM dwd.dwd_mkt_order_tag_di
    WHERE travel_date = '${bizdate}'                                              -- 只取当日分区
    GROUP BY COALESCE(supplier_id, CAST(-1 AS BIGINT)),                           -- 按粒度键汇总
             COALESCE(scenic_id, CAST(-1 AS BIGINT)),
             marketing_type                                                       -- 营销方式
) u                                                                               -- 各来源合并后的明细
GROUP BY supplier_id, scenic_id, marketing_type                                   -- 按粒度键汇总
