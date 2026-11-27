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
INSERT OVERWRITE TABLE dws.dws_ord_scenic_ticket_trade_hrs PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
    scenic_id,                                                                    -- 景区ID
    ticket_id,                                                                    -- 票ID
    order_mode,                                                                   -- 下单渠道编码
    order_role,                                                                   -- 主子单
    stat_hour,                                                                    -- 小时
    SUM(order_order_qty)                                         AS order_order_qty,  -- 预订订单数
    SUM(order_ticket_qty)                                        AS order_ticket_qty,  -- 预订票数
    SUM(order_sale_amt)                                          AS order_sale_amt,  -- 预订金额
    SUM(order_cost_amt)                                          AS order_cost_amt,  -- 预订成本金额
    SUM(verify_order_qty)                                        AS verify_order_qty,  -- 验证订单数
    SUM(verify_ticket_qty)                                       AS verify_ticket_qty,  -- 验证票数
    SUM(verify_sale_amt)                                         AS verify_sale_amt,  -- 验证金额
    SUM(verify_cost_amt)                                         AS verify_cost_amt,  -- 验证成本金额
    SUM(cancel_order_qty)                                        AS cancel_order_qty,  -- 取消订单数
    SUM(cancel_ticket_qty)                                       AS cancel_ticket_qty,  -- 取消票数
    SUM(cancel_sale_amt)                                         AS cancel_sale_amt,  -- 取消金额
    SUM(cancel_cost_amt)                                         AS cancel_cost_amt,  -- 取消成本金额
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time           -- ETL 加载时间
FROM (
    -- ord：预订：下单日分区 = bizdate，已支付（含现场支付、含之后取消）
    SELECT
        COALESCE(scenic_id, CAST(-1 AS BIGINT))                      AS scenic_id,  -- 景区ID
        COALESCE(ticket_id, CAST(-1 AS BIGINT))                      AS ticket_id,  -- 票ID
        COALESCE(order_mode, CAST(-1 AS INT))                        AS order_mode,  -- 下单渠道编码
        order_role,                                                               -- 主子单
        COALESCE(HOUR(order_time), CAST(-1 AS INT))                  AS stat_hour,  -- 小时
        COUNT(1)                                                     AS order_order_qty,  -- 预订订单数
        SUM(origin_ticket_qty)                                       AS order_ticket_qty,  -- 预订票数
        SUM(origin_ticket_qty * sale_price_amt)                      AS order_sale_amt,  -- 预订金额
        SUM(origin_ticket_qty * cost_price_amt)                      AS order_cost_amt,  -- 预订成本金额
        CAST(0 AS BIGINT)                                            AS verify_order_qty,  -- 验证订单数
        CAST(0 AS BIGINT)                                            AS verify_ticket_qty,  -- 验证票数
        CAST(0 AS DECIMAL(18,2))                                     AS verify_sale_amt,  -- 验证金额
        CAST(0 AS DECIMAL(18,2))                                     AS verify_cost_amt,  -- 验证成本金额
        CAST(0 AS BIGINT)                                            AS cancel_order_qty,  -- 取消订单数
        CAST(0 AS BIGINT)                                            AS cancel_ticket_qty,  -- 取消票数
        CAST(0 AS DECIMAL(18,2))                                     AS cancel_sale_amt,  -- 取消金额
        CAST(0 AS DECIMAL(18,2))                                     AS cancel_cost_amt  -- 取消成本金额
    FROM dwd.dwd_ord_order_di
    WHERE travel_date = '${bizdate}'                                              -- 只取当日分区
      AND test_flag = 0
      AND pay_status <> '2'
    GROUP BY COALESCE(scenic_id, CAST(-1 AS BIGINT)),                             -- 按粒度键汇总
             COALESCE(ticket_id, CAST(-1 AS BIGINT)),
             COALESCE(order_mode, CAST(-1 AS INT)),
             order_role,                                                          -- 主子单
             COALESCE(HOUR(order_time), CAST(-1 AS INT))
    UNION ALL
    -- trk：订单操作：操作日分区 = bizdate
    SELECT
        COALESCE(scenic_id, CAST(-1 AS BIGINT))                      AS scenic_id,  -- 景区ID
        COALESCE(ticket_id, CAST(-1 AS BIGINT))                      AS ticket_id,  -- 票ID
        COALESCE(order_mode, CAST(-1 AS INT))                        AS order_mode,  -- 下单渠道编码
        order_role,                                                               -- 主子单
        COALESCE(HOUR(action_time), CAST(-1 AS INT))                 AS stat_hour,  -- 小时
        CAST(0 AS BIGINT)                                            AS order_order_qty,  -- 预订订单数
        CAST(0 AS BIGINT)                                            AS order_ticket_qty,  -- 预订票数
        CAST(0 AS DECIMAL(18,2))                                     AS order_sale_amt,  -- 预订金额
        CAST(0 AS DECIMAL(18,2))                                     AS order_cost_amt,  -- 预订成本金额
        CAST(0 AS BIGINT)                                            AS verify_order_qty,  -- 验证订单数
        CAST(0 AS BIGINT)                                            AS verify_ticket_qty,  -- 验证票数
        CAST(0 AS DECIMAL(18,2))                                     AS verify_sale_amt,  -- 验证金额
        CAST(0 AS DECIMAL(18,2))                                     AS verify_cost_amt,  -- 验证成本金额
        COUNT(DISTINCT IF(track_action IN ('CANCEL', 'MODIFY'), order_no, NULL)) AS cancel_order_qty,  -- 取消订单数
        SUM(IF(track_action IN ('CANCEL', 'MODIFY'), ticket_qty, 0)) AS cancel_ticket_qty,  -- 取消票数
        SUM(IF(track_action IN ('CANCEL', 'MODIFY'), sale_amt, 0))   AS cancel_sale_amt,  -- 取消金额
        SUM(IF(track_action IN ('CANCEL', 'MODIFY'), cost_amt, 0))   AS cancel_cost_amt  -- 取消成本金额
    FROM dwd.dwd_ord_order_track_di
    WHERE travel_date = '${bizdate}'                                              -- 只取当日分区
      AND test_flag = 0
    GROUP BY COALESCE(scenic_id, CAST(-1 AS BIGINT)),                             -- 按粒度键汇总
             COALESCE(ticket_id, CAST(-1 AS BIGINT)),
             COALESCE(order_mode, CAST(-1 AS INT)),
             order_role,                                                          -- 主子单
             COALESCE(HOUR(action_time), CAST(-1 AS INT))
    UNION ALL
    -- vfy：核销：验证日分区 = bizdate
    SELECT
        COALESCE(scenic_id, CAST(-1 AS BIGINT))                      AS scenic_id,  -- 景区ID
        COALESCE(ticket_id, CAST(-1 AS BIGINT))                      AS ticket_id,  -- 票ID
        COALESCE(order_mode, CAST(-1 AS INT))                        AS order_mode,  -- 下单渠道编码
        order_role,                                                               -- 主子单
        COALESCE(HOUR(verify_time), CAST(-1 AS INT))                 AS stat_hour,  -- 小时
        CAST(0 AS BIGINT)                                            AS order_order_qty,  -- 预订订单数
        CAST(0 AS BIGINT)                                            AS order_ticket_qty,  -- 预订票数
        CAST(0 AS DECIMAL(18,2))                                     AS order_sale_amt,  -- 预订金额
        CAST(0 AS DECIMAL(18,2))                                     AS order_cost_amt,  -- 预订成本金额
        COUNT(DISTINCT order_no)                                     AS verify_order_qty,  -- 验证订单数
        SUM(verify_ticket_qty)                                       AS verify_ticket_qty,  -- 验证票数
        SUM(verify_sale_amt)                                         AS verify_sale_amt,  -- 验证金额
        SUM(verify_cost_amt)                                         AS verify_cost_amt,  -- 验证成本金额
        CAST(0 AS BIGINT)                                            AS cancel_order_qty,  -- 取消订单数
        CAST(0 AS BIGINT)                                            AS cancel_ticket_qty,  -- 取消票数
        CAST(0 AS DECIMAL(18,2))                                     AS cancel_sale_amt,  -- 取消金额
        CAST(0 AS DECIMAL(18,2))                                     AS cancel_cost_amt  -- 取消成本金额
    FROM dwd.dwd_ord_verify_di
    WHERE travel_date = '${bizdate}'                                              -- 只取当日分区
      AND test_flag = 0
    GROUP BY COALESCE(scenic_id, CAST(-1 AS BIGINT)),                             -- 按粒度键汇总
             COALESCE(ticket_id, CAST(-1 AS BIGINT)),
             COALESCE(order_mode, CAST(-1 AS INT)),
             order_role,                                                          -- 主子单
             COALESCE(HOUR(verify_time), CAST(-1 AS INT))
) u                                                                               -- 各来源合并后的明细
GROUP BY scenic_id, ticket_id, order_mode, order_role, stat_hour                  -- 按粒度键汇总
