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
-- 补 0 / 补空列：多来源 UNION ALL 时，某来源不产出的指标补 0 或空，外层按粒度 SUM 后即为各来源之和，不影响结果
-- 取 -1 的维度列：该来源没有这个维度（如核销来源没有下单渠道），用 -1 表示「不适用」，按该维度分析时只看产出它的来源
INSERT OVERWRITE TABLE dws.dws_ord_annual_card_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
    scenic_id,                                                                    -- 景区ID
    card_product_id,                                                              -- 年卡产品ID
    ticket_id,                                                                    -- 票ID
    SUM(card_sale_qty)                                           AS card_sale_qty,  -- 年卡售卡数
    SUM(card_sale_amt)                                           AS card_sale_amt,  -- 年卡售卡金额
    SUM(card_active_qty)                                         AS card_active_qty,  -- 年卡激活数
    SUM(card_verify_qty)                                         AS card_verify_qty,  -- 年卡核销次数
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time           -- ETL 加载时间
FROM (
    -- card：年卡交易
    SELECT
        COALESCE(scenic_id, CAST(-1 AS BIGINT))                      AS scenic_id,  -- 景区ID
        COALESCE(card_product_id, CAST(-1 AS BIGINT))                AS card_product_id,  -- 年卡产品ID
        COALESCE(ticket_id, CAST(-1 AS BIGINT))                      AS ticket_id,  -- 票ID
        SUM(IF(trade_type = 'SELL', 1, 0))                           AS card_sale_qty,  -- 年卡售卡数
        SUM(IF(trade_type = 'SELL', trade_amt, 0))                   AS card_sale_amt,  -- 年卡售卡金额
        SUM(IF(trade_type = 'ACTIVE', 1, 0))                         AS card_active_qty,  -- 年卡激活数
        CAST(0 AS BIGINT)                                            AS card_verify_qty  -- 年卡核销次数：此来源不产出，补0
    FROM dwd.dwd_ord_annual_card_trade_di
    WHERE travel_date = '${bizdate}'                                              -- 只取当日分区
    GROUP BY COALESCE(scenic_id, CAST(-1 AS BIGINT)),                             -- 按粒度键汇总
             COALESCE(card_product_id, CAST(-1 AS BIGINT)),
             COALESCE(ticket_id, CAST(-1 AS BIGINT))
    UNION ALL
    -- vfy：核销：验证日分区 = bizdate
    SELECT
        COALESCE(scenic_id, CAST(-1 AS BIGINT))                      AS scenic_id,  -- 景区ID
        CAST(-1 AS BIGINT)                                           AS card_product_id,  -- 年卡产品ID：此来源不区分，取 -1（不适用）
        COALESCE(ticket_id, CAST(-1 AS BIGINT))                      AS ticket_id,  -- 票ID
        CAST(0 AS BIGINT)                                            AS card_sale_qty,  -- 年卡售卡数：此来源不产出，补0
        CAST(0 AS DECIMAL(18,2))                                     AS card_sale_amt,  -- 年卡售卡金额：此来源不产出，补0
        CAST(0 AS BIGINT)                                            AS card_active_qty,  -- 年卡激活数：此来源不产出，补0
        SUM(annual_card_flag)                                        AS card_verify_qty  -- 年卡核销次数
    FROM dwd.dwd_ord_verify_di
    WHERE travel_date = '${bizdate}'                                              -- 只取当日分区
      AND test_flag = 0
    GROUP BY COALESCE(scenic_id, CAST(-1 AS BIGINT)), COALESCE(ticket_id, CAST(-1 AS BIGINT))  -- 按粒度键汇总
) u                                                                               -- 各来源合并后的明细
GROUP BY scenic_id, card_product_id, ticket_id                                    -- 按粒度键汇总
