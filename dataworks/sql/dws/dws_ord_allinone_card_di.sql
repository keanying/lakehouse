-- ================================================================================================
-- dws.dws_ord_allinone_card_di  园区一卡通日汇总
-- 粒度：1行=1天×供应商×流水来源×交易类型×支付方式
-- 分区：travel_date（YYYYMMDD）
-- 调度：每日，依赖上游 DWD 当日分区
-- 上游：dwd_ord_allinone_card_trade_di
-- 替代旧任务 3 个（上线对数一致后下线）：
--   · 数据平台/平台湖仓工作流/一卡通/dws_tps_aioc_summary_di（SERVERLESS_SPARK_SQL，cron 00 00 07 * * ?）
--   · 数据平台/平台湖仓工作流/一卡通/dws_tps_aioc_summary_mo（SERVERLESS_SPARK_SQL，cron 00 00 07 * * ?）
--   · 数据平台/平台湖仓工作流/一卡通/dws_tps_aioc_summary_yr（SERVERLESS_SPARK_SQL，cron 00 00 07 * * ?）
-- 性能：
--   · 同一来源的指标在一个子查询里预聚合（一次扫描），各来源 UNION ALL 后按粒度汇总，不做明细级 JOIN
--   · 来源：aio = dwd.dwd_ord_allinone_card_trade_di（一卡通有效流水：卡操作 + 已支付消费 + 成功退款）
-- ================================================================================================
INSERT OVERWRITE TABLE dws.dws_ord_allinone_card_di PARTITION (travel_date = '${bizdate}')
SELECT
    supplier_id,
    trade_source,
    trade_type,
    aio_pay_type,
    aio_channel,
    scenic_id,
    ticket_id,
    pay_mode,
    SUM(aio_trade_qty)                                           AS aio_trade_qty,
    SUM(aio_trade_amt)                                           AS aio_trade_amt,
    SUM(aio_principal_amt)                                       AS aio_principal_amt,
    SUM(aio_bonus_amt)                                           AS aio_bonus_amt,
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time
FROM (
    -- aio：一卡通有效流水：卡操作 + 已支付消费 + 成功退款
    SELECT
        COALESCE(supplier_id, CAST(-1 AS BIGINT))                    AS supplier_id,
        trade_source,
        trade_type,
        COALESCE(pay_type, CAST(-1 AS INT))                          AS aio_pay_type,
        COALESCE(channel, CAST(-1 AS INT))                           AS aio_channel,
        COALESCE(scenic_id, CAST(-1 AS BIGINT))                      AS scenic_id,
        COALESCE(ticket_id, CAST(-1 AS BIGINT))                      AS ticket_id,
        COALESCE(order_pay_mode, CAST(-1 AS INT))                    AS pay_mode,
        COUNT(1)                                                     AS aio_trade_qty,
        SUM(trade_amt)                                               AS aio_trade_amt,
        SUM(principal_amt)                                           AS aio_principal_amt,
        SUM(bonus_amt)                                               AS aio_bonus_amt
    FROM dwd.dwd_ord_allinone_card_trade_di
    WHERE travel_date = '${bizdate}'
      AND (trade_source IN ('CARD_OP', 'IC_ORDER') OR (trade_source = 'PAY' AND pay_status <> 3 AND trade_no NOT LIKE 'CMB%' AND prepaid_dup_flag = 0) OR (trade_source = 'REFUND' AND refund_status = 2))
    GROUP BY COALESCE(supplier_id, CAST(-1 AS BIGINT)), trade_source, trade_type, COALESCE(pay_type, CAST(-1 AS INT)), COALESCE(channel, CAST(-1 AS INT)), COALESCE(scenic_id, CAST(-1 AS BIGINT)), COALESCE(ticket_id, CAST(-1 AS BIGINT)), COALESCE(order_pay_mode, CAST(-1 AS INT))
) u
GROUP BY supplier_id, trade_source, trade_type, aio_pay_type, aio_channel, scenic_id, ticket_id, pay_mode
