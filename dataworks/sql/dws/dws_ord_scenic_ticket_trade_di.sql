-- ================================================================================================
-- dws.dws_ord_scenic_ticket_trade_di  景区门票交易日汇总
-- 粒度：1行=1天×景区×门票×供应商×分销商×下单渠道×支付方式×主子单×团散
-- 分区：travel_date（YYYYMMDD）
-- 调度：每日，依赖上游 DWD 当日分区
-- 上游：dwd_ord_order_di、dwd_ord_order_track_di、dwd_ord_verify_di、dwd_ord_order_distribution_di
-- 替代旧任务 28 个（上线对数一致后下线）：
--   · 业务工厂/报表数据/预定验证报表/预定验证报表工作流/dws_daily_report_summary_d_i（EMR_SPARK_SQL，cron 00 22 00 * * ?）
--   · 业务工厂/报表数据/预定验证报表/预定验证报表工作流/dws_daily_report_summary_full_d_i（EMR_SPARK_SQL，cron 00 22 00 * * ?）
--   · 业务工厂/报表数据/预定验证报表/预定验证报表工作流_小时维度/dws_daily_report_summary_hour_d_i（EMR_SPARK_SQL，cron 00 01 00 * * ?）
--   · 业务工厂/报表数据/预定验证报表/预定验证报表工作流_小时维度/dws_daily_report_summary_hour_full_d_i（EMR_SPARK_SQL，cron 00 01 00 * * ?）
--   · 业务工厂/报表数据/预定验证报表/预定验证报表工作流_小时维度/dws_daily_report_summary_hour_remain_d_i（EMR_SPARK_SQL，cron 00 01 00 * * ?）
--   · 业务工厂/报表数据/预定验证报表/预定验证报表工作流/dws_daily_report_summary_remain_d_i（EMR_SPARK_SQL，cron 00 22 00 * * ?）
--   · 业务工厂/报表数据/预定验证报表/预定验证报表工作流/dws_daily_report_ticket_summary_d_i（EMR_SPARK_SQL，cron 00 22 00 * * ?）
--   · 业务工厂/报表数据/预定验证报表/预定验证报表工作流_小时维度/dws_daily_report_ticket_summary_hour_d_i（EMR_SPARK_SQL，cron 00 01 00 * * ?）
--   · 业务工厂/报表数据/预定验证报表/预定验证报表工作流/dws_daily_report_ticket_summary_remain_d_i（EMR_SPARK_SQL，cron 00 22 00 * * ?）
--   · 业务工厂/报表数据/预定验证报表/预定验证报表工作流_小时维度_全维度2selectdb/dws_hourly_report_full_summary_d_i（EMR_SPARK_SQL，cron 00 00 05 * * ?）
--   · 业务工厂/报表数据/预定验证报表/预定验证报表工作流/dws_monthly_report_summary_d_i（EMR_SPARK_SQL，cron 00 22 00 * * ?）
--   · 业务工厂/报表数据/预定验证报表/预定验证报表工作流/dws_monthly_report_summary_remain_d_i（EMR_SPARK_SQL，cron 00 22 00 * * ?）
--   · … 另 16 个
-- 性能：
--   · 同一来源的指标在一个子查询里预聚合（一次扫描），各来源 UNION ALL 后按粒度汇总，不做明细级 JOIN
--   · 去重类指标存位图（TO_BITMAP / BITMAP_UNION，UDF 与 PFT3.0 同一套），任意周期 BITMAP_UNION_COUNT
--   · order_avg_ticket_price 为表内派生，下游按分子分母重算，不直接 SUM
--   · 来源：ord = dwd.dwd_ord_order_di（预订：下单日分区 = bizdate，已支付（含现场支付、含之后取消））；trk = dwd.dwd_ord_order_track_di（订单操作：操作日分区 = bizdate）；vfy = dwd.dwd_ord_verify_di（核销：验证日分区 = bizdate）
-- ================================================================================================
INSERT OVERWRITE TABLE dws.dws_ord_scenic_ticket_trade_di PARTITION (travel_date = '${bizdate}')
SELECT
    scenic_id,
    ticket_id,
    supplier_id,
    distributor_id,
    order_mode,
    pay_mode,
    order_role,
    team_type,
    province_code,
    city_code,
    district_code,
    SUM(order_order_qty)                                         AS order_order_qty,
    SUM(order_ticket_qty)                                        AS order_ticket_qty,
    SUM(order_sale_amt)                                          AS order_sale_amt,
    SUM(order_cost_amt)                                          AS order_cost_amt,
    SUM(pay_order_qty)                                           AS pay_order_qty,
    SUM(pay_ticket_qty)                                          AS pay_ticket_qty,
    SUM(pay_sale_amt)                                            AS pay_sale_amt,
    SUM(cancel_order_qty)                                        AS cancel_order_qty,
    SUM(cancel_ticket_qty)                                       AS cancel_ticket_qty,
    SUM(cancel_sale_amt)                                         AS cancel_sale_amt,
    SUM(cancel_cost_amt)                                         AS cancel_cost_amt,
    SUM(verify_order_qty)                                        AS verify_order_qty,
    SUM(verify_ticket_qty)                                       AS verify_ticket_qty,
    SUM(verify_sale_amt)                                         AS verify_sale_amt,
    SUM(verify_cost_amt)                                         AS verify_cost_amt,
    SUM(finish_order_qty)                                        AS finish_order_qty,
    SUM(finish_ticket_qty)                                       AS finish_ticket_qty,
    SUM(finish_sale_amt)                                         AS finish_sale_amt,
    SUM(finish_cost_amt)                                         AS finish_cost_amt,
    SUM(revoke_order_qty)                                        AS revoke_order_qty,
    SUM(revoke_ticket_qty)                                       AS revoke_ticket_qty,
    SUM(revoke_sale_amt)                                         AS revoke_sale_amt,
    SUM(revoke_cost_amt)                                         AS revoke_cost_amt,
    SUM(print_order_qty)                                         AS print_order_qty,
    SUM(print_ticket_qty)                                        AS print_ticket_qty,
    SUM(print_sale_amt)                                          AS print_sale_amt,
    SUM(after_sale_ticket_qty)                                   AS after_sale_ticket_qty,
    SUM(after_sale_refund_amt)                                   AS after_sale_refund_amt,
    SUM(after_sale_income_amt)                                   AS after_sale_income_amt,
    BITMAP_UNION(buyer_qty)                                      AS buyer_qty,
    SUM(pay_cost_amt)                                            AS pay_cost_amt,
    SUM(cancel_fee_amt)                                          AS cancel_fee_amt,
    SUM(revoke_fee_amt)                                          AS revoke_fee_amt,
    CAST(SUM(order_sale_amt) / NULLIF(SUM(order_ticket_qty), 0) AS DECIMAL(18,2)) AS order_avg_ticket_price,   -- 表内派生：不可跨行再汇总
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time
FROM (
    -- ord：预订：下单日分区 = bizdate，已支付（含现场支付、含之后取消）
    SELECT
        COALESCE(scenic_id, CAST(-1 AS BIGINT))                      AS scenic_id,
        COALESCE(ticket_id, CAST(-1 AS BIGINT))                      AS ticket_id,
        COALESCE(supplier_id, CAST(-1 AS BIGINT))                    AS supplier_id,
        COALESCE(distributor_id, CAST(-1 AS BIGINT))                 AS distributor_id,
        COALESCE(order_mode, CAST(-1 AS INT))                        AS order_mode,
        COALESCE(pay_mode, CAST(-1 AS INT))                          AS pay_mode,
        order_role,
        IF(team_flag = 1, 'TEAM', 'INDIVIDUAL')                      AS team_type,
        taker_province_code                                          AS province_code,
        taker_city_code                                              AS city_code,
        taker_district_code                                          AS district_code,
        COUNT(1)                                                     AS order_order_qty,
        SUM(origin_ticket_qty)                                       AS order_ticket_qty,
        SUM(origin_ticket_qty * sale_price_amt)                      AS order_sale_amt,
        SUM(origin_ticket_qty * cost_price_amt)                      AS order_cost_amt,
        CAST(0 AS BIGINT)                                            AS pay_order_qty,
        CAST(0 AS BIGINT)                                            AS pay_ticket_qty,
        CAST(0 AS DECIMAL(18,2))                                     AS pay_sale_amt,
        CAST(0 AS BIGINT)                                            AS cancel_order_qty,
        CAST(0 AS BIGINT)                                            AS cancel_ticket_qty,
        CAST(0 AS DECIMAL(18,2))                                     AS cancel_sale_amt,
        CAST(0 AS DECIMAL(18,2))                                     AS cancel_cost_amt,
        CAST(0 AS BIGINT)                                            AS verify_order_qty,
        CAST(0 AS BIGINT)                                            AS verify_ticket_qty,
        CAST(0 AS DECIMAL(18,2))                                     AS verify_sale_amt,
        CAST(0 AS DECIMAL(18,2))                                     AS verify_cost_amt,
        CAST(0 AS BIGINT)                                            AS finish_order_qty,
        CAST(0 AS BIGINT)                                            AS finish_ticket_qty,
        CAST(0 AS DECIMAL(18,2))                                     AS finish_sale_amt,
        CAST(0 AS DECIMAL(18,2))                                     AS finish_cost_amt,
        CAST(0 AS BIGINT)                                            AS revoke_order_qty,
        CAST(0 AS BIGINT)                                            AS revoke_ticket_qty,
        CAST(0 AS DECIMAL(18,2))                                     AS revoke_sale_amt,
        CAST(0 AS DECIMAL(18,2))                                     AS revoke_cost_amt,
        CAST(0 AS BIGINT)                                            AS print_order_qty,
        CAST(0 AS BIGINT)                                            AS print_ticket_qty,
        CAST(0 AS DECIMAL(18,2))                                     AS print_sale_amt,
        CAST(0 AS BIGINT)                                            AS after_sale_ticket_qty,
        CAST(0 AS DECIMAL(18,2))                                     AS after_sale_refund_amt,
        CAST(0 AS DECIMAL(18,2))                                     AS after_sale_income_amt,
        BITMAP_UNION(TO_BITMAP(XXHASH64(taker_id_card_hash)))        AS buyer_qty,
        CAST(0 AS DECIMAL(18,2))                                     AS pay_cost_amt,
        CAST(0 AS DECIMAL(18,2))                                     AS cancel_fee_amt,
        CAST(0 AS DECIMAL(18,2))                                     AS revoke_fee_amt
    FROM dwd.dwd_ord_order_di
    WHERE travel_date = '${bizdate}'
      AND test_flag = 0
      AND pay_status <> '2'
    GROUP BY COALESCE(scenic_id, CAST(-1 AS BIGINT)), COALESCE(ticket_id, CAST(-1 AS BIGINT)), COALESCE(supplier_id, CAST(-1 AS BIGINT)), COALESCE(distributor_id, CAST(-1 AS BIGINT)), COALESCE(order_mode, CAST(-1 AS INT)), COALESCE(pay_mode, CAST(-1 AS INT)), order_role, IF(team_flag = 1, 'TEAM', 'INDIVIDUAL'), taker_province_code, taker_city_code, taker_district_code
    UNION ALL
    -- trk：订单操作：操作日分区 = bizdate
    SELECT
        COALESCE(scenic_id, CAST(-1 AS BIGINT))                      AS scenic_id,
        COALESCE(ticket_id, CAST(-1 AS BIGINT))                      AS ticket_id,
        COALESCE(supplier_id, CAST(-1 AS BIGINT))                    AS supplier_id,
        COALESCE(distributor_id, CAST(-1 AS BIGINT))                 AS distributor_id,
        COALESCE(order_mode, CAST(-1 AS INT))                        AS order_mode,
        COALESCE(pay_mode, CAST(-1 AS INT))                          AS pay_mode,
        order_role,
        IF(team_flag = 1, 'TEAM', 'INDIVIDUAL')                      AS team_type,
        taker_province_code                                          AS province_code,
        taker_city_code                                              AS city_code,
        taker_district_code                                          AS district_code,
        CAST(0 AS BIGINT)                                            AS order_order_qty,
        CAST(0 AS BIGINT)                                            AS order_ticket_qty,
        CAST(0 AS DECIMAL(18,2))                                     AS order_sale_amt,
        CAST(0 AS DECIMAL(18,2))                                     AS order_cost_amt,
        COUNT(DISTINCT IF(track_action IN ('PAY', 'ADD_TICKET'), order_no, NULL)) AS pay_order_qty,
        SUM(IF(track_action IN ('PAY', 'ADD_TICKET'), ticket_qty, 0)) AS pay_ticket_qty,
        SUM(IF(track_action IN ('PAY', 'ADD_TICKET'), sale_amt, 0))  AS pay_sale_amt,
        COUNT(DISTINCT IF(track_action IN ('CANCEL', 'MODIFY'), order_no, NULL)) AS cancel_order_qty,
        SUM(IF(track_action IN ('CANCEL', 'MODIFY'), ticket_qty, 0)) AS cancel_ticket_qty,
        SUM(IF(track_action IN ('CANCEL', 'MODIFY'), sale_amt, 0))   AS cancel_sale_amt,
        SUM(IF(track_action IN ('CANCEL', 'MODIFY'), cost_amt, 0))   AS cancel_cost_amt,
        CAST(0 AS BIGINT)                                            AS verify_order_qty,
        CAST(0 AS BIGINT)                                            AS verify_ticket_qty,
        CAST(0 AS DECIMAL(18,2))                                     AS verify_sale_amt,
        CAST(0 AS DECIMAL(18,2))                                     AS verify_cost_amt,
        COUNT(DISTINCT IF(track_action IN ('FINISH'), order_no, NULL)) AS finish_order_qty,
        SUM(IF(track_action IN ('FINISH'), ticket_qty, 0))           AS finish_ticket_qty,
        SUM(IF(track_action IN ('FINISH'), sale_amt, 0))             AS finish_sale_amt,
        SUM(IF(track_action IN ('FINISH'), cost_amt, 0))             AS finish_cost_amt,
        COUNT(DISTINCT IF(track_action IN ('REVOKE', 'REVOKE_MODIFY'), order_no, NULL)) AS revoke_order_qty,
        SUM(IF(track_action IN ('REVOKE', 'REVOKE_MODIFY'), ticket_qty, 0)) AS revoke_ticket_qty,
        SUM(IF(track_action IN ('REVOKE', 'REVOKE_MODIFY'), sale_amt, 0)) AS revoke_sale_amt,
        SUM(IF(track_action IN ('REVOKE', 'REVOKE_MODIFY'), cost_amt, 0)) AS revoke_cost_amt,
        COUNT(DISTINCT IF(track_action IN ('PRINT'), order_no, NULL)) AS print_order_qty,
        SUM(IF(track_action IN ('PRINT'), ticket_qty, 0))            AS print_ticket_qty,
        SUM(IF(track_action IN ('PRINT'), sale_amt, 0))              AS print_sale_amt,
        SUM(IF(track_action IN ('AFTER_SALE'), ticket_qty, 0))       AS after_sale_ticket_qty,
        SUM(IF(track_action = 'AFTER_SALE', refund_amt, 0))          AS after_sale_refund_amt,
        SUM(IF(track_action = 'AFTER_SALE', service_fee_amt, 0))     AS after_sale_income_amt,
        CAST(NULL AS BINARY)                                         AS buyer_qty,
        SUM(IF(track_action IN ('PAY', 'ADD_TICKET'), cost_amt, 0))  AS pay_cost_amt,
        SUM(IF(track_action IN ('CANCEL', 'MODIFY'), service_fee_amt, 0)) AS cancel_fee_amt,
        SUM(IF(track_action IN ('REVOKE', 'REVOKE_MODIFY'), service_fee_amt, 0)) AS revoke_fee_amt
    FROM dwd.dwd_ord_order_track_di
    WHERE travel_date = '${bizdate}'
      AND test_flag = 0
    GROUP BY COALESCE(scenic_id, CAST(-1 AS BIGINT)), COALESCE(ticket_id, CAST(-1 AS BIGINT)), COALESCE(supplier_id, CAST(-1 AS BIGINT)), COALESCE(distributor_id, CAST(-1 AS BIGINT)), COALESCE(order_mode, CAST(-1 AS INT)), COALESCE(pay_mode, CAST(-1 AS INT)), order_role, IF(team_flag = 1, 'TEAM', 'INDIVIDUAL'), taker_province_code, taker_city_code, taker_district_code
    UNION ALL
    -- vfy：核销：验证日分区 = bizdate
    SELECT
        COALESCE(scenic_id, CAST(-1 AS BIGINT))                      AS scenic_id,
        COALESCE(ticket_id, CAST(-1 AS BIGINT))                      AS ticket_id,
        COALESCE(supplier_id, CAST(-1 AS BIGINT))                    AS supplier_id,
        COALESCE(distributor_id, CAST(-1 AS BIGINT))                 AS distributor_id,
        COALESCE(order_mode, CAST(-1 AS INT))                        AS order_mode,
        COALESCE(pay_mode, CAST(-1 AS INT))                          AS pay_mode,
        order_role,
        IF(team_flag = 1, 'TEAM', 'INDIVIDUAL')                      AS team_type,
        taker_province_code                                          AS province_code,
        taker_city_code                                              AS city_code,
        taker_district_code                                          AS district_code,
        CAST(0 AS BIGINT)                                            AS order_order_qty,
        CAST(0 AS BIGINT)                                            AS order_ticket_qty,
        CAST(0 AS DECIMAL(18,2))                                     AS order_sale_amt,
        CAST(0 AS DECIMAL(18,2))                                     AS order_cost_amt,
        CAST(0 AS BIGINT)                                            AS pay_order_qty,
        CAST(0 AS BIGINT)                                            AS pay_ticket_qty,
        CAST(0 AS DECIMAL(18,2))                                     AS pay_sale_amt,
        CAST(0 AS BIGINT)                                            AS cancel_order_qty,
        CAST(0 AS BIGINT)                                            AS cancel_ticket_qty,
        CAST(0 AS DECIMAL(18,2))                                     AS cancel_sale_amt,
        CAST(0 AS DECIMAL(18,2))                                     AS cancel_cost_amt,
        COUNT(DISTINCT order_no)                                     AS verify_order_qty,
        SUM(verify_ticket_qty)                                       AS verify_ticket_qty,
        SUM(verify_sale_amt)                                         AS verify_sale_amt,
        SUM(verify_cost_amt)                                         AS verify_cost_amt,
        CAST(0 AS BIGINT)                                            AS finish_order_qty,
        CAST(0 AS BIGINT)                                            AS finish_ticket_qty,
        CAST(0 AS DECIMAL(18,2))                                     AS finish_sale_amt,
        CAST(0 AS DECIMAL(18,2))                                     AS finish_cost_amt,
        CAST(0 AS BIGINT)                                            AS revoke_order_qty,
        CAST(0 AS BIGINT)                                            AS revoke_ticket_qty,
        CAST(0 AS DECIMAL(18,2))                                     AS revoke_sale_amt,
        CAST(0 AS DECIMAL(18,2))                                     AS revoke_cost_amt,
        CAST(0 AS BIGINT)                                            AS print_order_qty,
        CAST(0 AS BIGINT)                                            AS print_ticket_qty,
        CAST(0 AS DECIMAL(18,2))                                     AS print_sale_amt,
        CAST(0 AS BIGINT)                                            AS after_sale_ticket_qty,
        CAST(0 AS DECIMAL(18,2))                                     AS after_sale_refund_amt,
        CAST(0 AS DECIMAL(18,2))                                     AS after_sale_income_amt,
        CAST(NULL AS BINARY)                                         AS buyer_qty,
        CAST(0 AS DECIMAL(18,2))                                     AS pay_cost_amt,
        CAST(0 AS DECIMAL(18,2))                                     AS cancel_fee_amt,
        CAST(0 AS DECIMAL(18,2))                                     AS revoke_fee_amt
    FROM dwd.dwd_ord_verify_di
    WHERE travel_date = '${bizdate}'
      AND test_flag = 0
    GROUP BY COALESCE(scenic_id, CAST(-1 AS BIGINT)), COALESCE(ticket_id, CAST(-1 AS BIGINT)), COALESCE(supplier_id, CAST(-1 AS BIGINT)), COALESCE(distributor_id, CAST(-1 AS BIGINT)), COALESCE(order_mode, CAST(-1 AS INT)), COALESCE(pay_mode, CAST(-1 AS INT)), order_role, IF(team_flag = 1, 'TEAM', 'INDIVIDUAL'), taker_province_code, taker_city_code, taker_district_code
) u
GROUP BY scenic_id, ticket_id, supplier_id, distributor_id, order_mode, pay_mode, order_role, team_type, province_code, city_code, district_code
