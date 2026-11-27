-- ================================================================================================
-- dws.dws_ord_annual_card_di  年卡日汇总
-- 粒度：1行=1天×景区×年卡产品
-- 分区：travel_date（YYYYMMDD）
-- 调度：每日，依赖上游 DWD 当日分区
-- 上游：dwd_ord_annual_card_trade_di、dwd_ord_verify_di
-- 替代旧任务 6 个（上线对数一致后下线）：
--   · 业务工厂/报表数据/年卡特权/年卡特权报表统计工作流/dws_daily_report_annual_card_ticket_summary_d_i（EMR_SPARK_SQL，cron 00 26 00 * * ?）
--   · 业务工厂/报表数据/年卡特权/年卡特权报表统计工作流/dws_daily_report_annual_card_ticket_verify_summary_d_i（EMR_SPARK_SQL，cron 00 26 00 * * ?）
--   · 业务工厂/报表数据/年卡特权/年卡特权报表统计工作流/dws_monthly_report_annual_card_ticket_summary_d_i（EMR_SPARK_SQL，cron 00 26 00 * * ?）
--   · 业务工厂/报表数据/年卡特权/年卡特权报表统计工作流/dws_monthly_report_annual_card_ticket_verify_summary_d_i（EMR_SPARK_SQL，cron 00 26 00 * * ?）
--   · 业务工厂/报表数据/年卡特权/年卡特权报表统计工作流/dws_yearly_report_annual_card_ticket_summary_d_i（EMR_SPARK_SQL，cron 00 26 00 * * ?）
--   · 业务工厂/报表数据/年卡特权/年卡特权报表统计工作流/dws_yearly_report_annual_card_ticket_verify_summary_d_i（EMR_SPARK_SQL，cron 00 26 00 * * ?）
-- 性能：
--   · 同一来源的指标在一个子查询里预聚合（一次扫描），各来源 UNION ALL 后按粒度汇总，不做明细级 JOIN
--   · 来源：card = dwd.dwd_ord_annual_card_trade_di（年卡交易）；vfy = dwd.dwd_ord_verify_di（核销：验证日分区 = bizdate）
-- ================================================================================================
INSERT OVERWRITE TABLE dws.dws_ord_annual_card_di PARTITION (travel_date = '${bizdate}')
SELECT
    scenic_id,
    card_product_id,
    SUM(card_sale_qty)                                           AS card_sale_qty,
    SUM(card_sale_amt)                                           AS card_sale_amt,
    SUM(card_active_qty)                                         AS card_active_qty,
    SUM(card_verify_qty)                                         AS card_verify_qty,
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time
FROM (
    -- card：年卡交易
    SELECT
        CAST(-1 AS BIGINT)                                           AS scenic_id,   -- 该来源无此维度，取默认值
        COALESCE(card_product_id, CAST(-1 AS BIGINT))                AS card_product_id,
        SUM(IF(trade_type = 'SELL', 1, 0))                           AS card_sale_qty,
        SUM(IF(trade_type = 'SELL', trade_amt, 0))                   AS card_sale_amt,
        SUM(IF(trade_type = 'ACTIVE', 1, 0))                         AS card_active_qty,
        CAST(0 AS BIGINT)                                            AS card_verify_qty
    FROM dwd.dwd_ord_annual_card_trade_di
    WHERE travel_date = '${bizdate}'
    GROUP BY COALESCE(card_product_id, CAST(-1 AS BIGINT))
    UNION ALL
    -- vfy：核销：验证日分区 = bizdate
    SELECT
        COALESCE(scenic_id, CAST(-1 AS BIGINT))                      AS scenic_id,
        CAST(-1 AS BIGINT)                                           AS card_product_id,   -- 该来源无此维度，取默认值
        CAST(0 AS BIGINT)                                            AS card_sale_qty,
        CAST(0 AS DECIMAL(18,2))                                     AS card_sale_amt,
        CAST(0 AS BIGINT)                                            AS card_active_qty,
        SUM(annual_card_flag)                                        AS card_verify_qty
    FROM dwd.dwd_ord_verify_di
    WHERE travel_date = '${bizdate}'
      AND test_flag = 0
    GROUP BY COALESCE(scenic_id, CAST(-1 AS BIGINT))
) u
GROUP BY scenic_id, card_product_id
