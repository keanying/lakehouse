-- ================================================================================================
-- dws.dws_ord_scenic_ticket_trade_hrs  景区门票交易小时汇总
-- 粒度：1行=1小时×景区×门票×下单渠道×主子单
-- 分区：travel_date（YYYYMMDD）
-- 调度：每日，依赖上游 DWD 当日分区
-- 上游：dwd_ord_order_di、dwd_ord_verify_di
-- 性能：
--   · 同一来源的指标在一个子查询里预聚合（一次扫描），各来源 UNION ALL 后按粒度汇总，不做明细级 JOIN
--   · 来源：ord = dwd.dwd_ord_order_di（预订：下单日分区 = bizdate，已支付（含现场支付、含之后取消））；trk = dwd.dwd_ord_order_track_di（订单操作：操作日分区 = bizdate）；vfy = dwd.dwd_ord_verify_di（核销：验证日分区 = bizdate）
-- ================================================================================================
INSERT OVERWRITE TABLE dws.dws_ord_scenic_ticket_trade_hrs PARTITION (travel_date = '${bizdate}')
SELECT
    scenic_id,
    ticket_id,
    order_mode,
    order_role,
    stat_hour,
    SUM(order_order_qty)                                         AS order_order_qty,
    SUM(order_ticket_qty)                                        AS order_ticket_qty,
    SUM(order_sale_amt)                                          AS order_sale_amt,
    SUM(order_cost_amt)                                          AS order_cost_amt,
    SUM(verify_order_qty)                                        AS verify_order_qty,
    SUM(verify_ticket_qty)                                       AS verify_ticket_qty,
    SUM(verify_sale_amt)                                         AS verify_sale_amt,
    SUM(verify_cost_amt)                                         AS verify_cost_amt,
    SUM(cancel_order_qty)                                        AS cancel_order_qty,
    SUM(cancel_ticket_qty)                                       AS cancel_ticket_qty,
    SUM(cancel_sale_amt)                                         AS cancel_sale_amt,
    SUM(cancel_cost_amt)                                         AS cancel_cost_amt,
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time
FROM (
    -- ord：预订：下单日分区 = bizdate，已支付（含现场支付、含之后取消）
    SELECT
        COALESCE(scenic_id, CAST(-1 AS BIGINT))                      AS scenic_id,
        COALESCE(ticket_id, CAST(-1 AS BIGINT))                      AS ticket_id,
        COALESCE(order_mode, CAST(-1 AS INT))                        AS order_mode,
        order_role,
        COALESCE(HOUR(order_time), CAST(-1 AS INT))                  AS stat_hour,
        COUNT(1)                                                     AS order_order_qty,
        SUM(origin_ticket_qty)                                       AS order_ticket_qty,
        SUM(origin_ticket_qty * sale_price_amt)                      AS order_sale_amt,
        SUM(origin_ticket_qty * cost_price_amt)                      AS order_cost_amt,
        CAST(0 AS BIGINT)                                            AS verify_order_qty,
        CAST(0 AS BIGINT)                                            AS verify_ticket_qty,
        CAST(0 AS DECIMAL(18,2))                                     AS verify_sale_amt,
        CAST(0 AS DECIMAL(18,2))                                     AS verify_cost_amt,
        CAST(0 AS BIGINT)                                            AS cancel_order_qty,
        CAST(0 AS BIGINT)                                            AS cancel_ticket_qty,
        CAST(0 AS DECIMAL(18,2))                                     AS cancel_sale_amt,
        CAST(0 AS DECIMAL(18,2))                                     AS cancel_cost_amt
    FROM dwd.dwd_ord_order_di
    WHERE travel_date = '${bizdate}'
      AND test_flag = 0
      AND pay_status <> '2'
    GROUP BY COALESCE(scenic_id, CAST(-1 AS BIGINT)), COALESCE(ticket_id, CAST(-1 AS BIGINT)), COALESCE(order_mode, CAST(-1 AS INT)), order_role, COALESCE(HOUR(order_time), CAST(-1 AS INT))
    UNION ALL
    -- trk：订单操作：操作日分区 = bizdate
    SELECT
        COALESCE(scenic_id, CAST(-1 AS BIGINT))                      AS scenic_id,
        COALESCE(ticket_id, CAST(-1 AS BIGINT))                      AS ticket_id,
        COALESCE(order_mode, CAST(-1 AS INT))                        AS order_mode,
        order_role,
        COALESCE(HOUR(action_time), CAST(-1 AS INT))                 AS stat_hour,
        CAST(0 AS BIGINT)                                            AS order_order_qty,
        CAST(0 AS BIGINT)                                            AS order_ticket_qty,
        CAST(0 AS DECIMAL(18,2))                                     AS order_sale_amt,
        CAST(0 AS DECIMAL(18,2))                                     AS order_cost_amt,
        CAST(0 AS BIGINT)                                            AS verify_order_qty,
        CAST(0 AS BIGINT)                                            AS verify_ticket_qty,
        CAST(0 AS DECIMAL(18,2))                                     AS verify_sale_amt,
        CAST(0 AS DECIMAL(18,2))                                     AS verify_cost_amt,
        COUNT(DISTINCT IF(track_action IN ('CANCEL', 'MODIFY'), order_no, NULL)) AS cancel_order_qty,
        SUM(IF(track_action IN ('CANCEL', 'MODIFY'), ticket_qty, 0)) AS cancel_ticket_qty,
        SUM(IF(track_action IN ('CANCEL', 'MODIFY'), sale_amt, 0))   AS cancel_sale_amt,
        SUM(IF(track_action IN ('CANCEL', 'MODIFY'), cost_amt, 0))   AS cancel_cost_amt
    FROM dwd.dwd_ord_order_track_di
    WHERE travel_date = '${bizdate}'
      AND test_flag = 0
    GROUP BY COALESCE(scenic_id, CAST(-1 AS BIGINT)), COALESCE(ticket_id, CAST(-1 AS BIGINT)), COALESCE(order_mode, CAST(-1 AS INT)), order_role, COALESCE(HOUR(action_time), CAST(-1 AS INT))
    UNION ALL
    -- vfy：核销：验证日分区 = bizdate
    SELECT
        COALESCE(scenic_id, CAST(-1 AS BIGINT))                      AS scenic_id,
        COALESCE(ticket_id, CAST(-1 AS BIGINT))                      AS ticket_id,
        COALESCE(order_mode, CAST(-1 AS INT))                        AS order_mode,
        order_role,
        COALESCE(HOUR(verify_time), CAST(-1 AS INT))                 AS stat_hour,
        CAST(0 AS BIGINT)                                            AS order_order_qty,
        CAST(0 AS BIGINT)                                            AS order_ticket_qty,
        CAST(0 AS DECIMAL(18,2))                                     AS order_sale_amt,
        CAST(0 AS DECIMAL(18,2))                                     AS order_cost_amt,
        COUNT(DISTINCT order_no)                                     AS verify_order_qty,
        SUM(verify_ticket_qty)                                       AS verify_ticket_qty,
        SUM(verify_sale_amt)                                         AS verify_sale_amt,
        SUM(verify_cost_amt)                                         AS verify_cost_amt,
        CAST(0 AS BIGINT)                                            AS cancel_order_qty,
        CAST(0 AS BIGINT)                                            AS cancel_ticket_qty,
        CAST(0 AS DECIMAL(18,2))                                     AS cancel_sale_amt,
        CAST(0 AS DECIMAL(18,2))                                     AS cancel_cost_amt
    FROM dwd.dwd_ord_verify_di
    WHERE travel_date = '${bizdate}'
      AND test_flag = 0
    GROUP BY COALESCE(scenic_id, CAST(-1 AS BIGINT)), COALESCE(ticket_id, CAST(-1 AS BIGINT)), COALESCE(order_mode, CAST(-1 AS INT)), order_role, COALESCE(HOUR(verify_time), CAST(-1 AS INT))
) u
GROUP BY scenic_id, ticket_id, order_mode, order_role, stat_hour
