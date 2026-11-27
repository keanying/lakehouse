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
--   · 来源：ord = dwd.dwd_ord_order_di（预订：下单日分区 = bizdate，已支付（含现场支付、含之后取消））；trk = dwd.dwd_ord_order_track_di（订单操作：操作日分区 = bizdate）；vfy = dwd.dwd_ord_verify_di（核销：验证日分区 = bizdate）；mps = dwd.dwd_ord_mps_detail_di（商户视角经营明细（报表库业务明细）：本方商户 = 供应商维度）
-- ================================================================================================
-- 补 0 / 补空列：多来源 UNION ALL 时，某来源不产出的指标补 0 或空，外层按粒度 SUM 后即为各来源之和，不影响结果
-- 取 -1 的维度列：该来源没有这个维度（如核销来源没有下单渠道），用 -1 表示「不适用」，按该维度分析时只看产出它的来源
INSERT OVERWRITE TABLE dws.dws_ord_scenic_ticket_trade_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
    scenic_id,                                                                    -- 景区ID
    ticket_id,                                                                    -- 票ID
    supplier_id,                                                                  -- 供应商ID（租户ID）
    distributor_id,                                                               -- 一级分销商ID
    order_mode,                                                                   -- 下单渠道编码
    pay_mode,                                                                     -- 支付方式编码
    order_role,                                                                   -- 主子单
    team_type,                                                                    -- 团散
    province_code,                                                                -- 客源省编码（取票人证件 / 手机号归属）
    SUM(order_order_qty)                                         AS order_order_qty,  -- 预订订单数
    SUM(order_ticket_qty)                                        AS order_ticket_qty,  -- 预订票数
    SUM(order_sale_amt)                                          AS order_sale_amt,  -- 预订金额
    SUM(order_cost_amt)                                          AS order_cost_amt,  -- 预订成本金额
    SUM(pay_order_qty)                                           AS pay_order_qty,  -- 支付订单数
    SUM(pay_ticket_qty)                                          AS pay_ticket_qty,  -- 支付票数
    SUM(pay_sale_amt)                                            AS pay_sale_amt,  -- 支付金额
    SUM(cancel_order_qty)                                        AS cancel_order_qty,  -- 取消订单数
    SUM(cancel_ticket_qty)                                       AS cancel_ticket_qty,  -- 取消票数
    SUM(cancel_sale_amt)                                         AS cancel_sale_amt,  -- 取消金额
    SUM(cancel_cost_amt)                                         AS cancel_cost_amt,  -- 取消成本金额
    SUM(verify_order_qty)                                        AS verify_order_qty,  -- 验证订单数
    SUM(verify_ticket_qty)                                       AS verify_ticket_qty,  -- 验证票数
    SUM(verify_sale_amt)                                         AS verify_sale_amt,  -- 验证金额
    SUM(verify_cost_amt)                                         AS verify_cost_amt,  -- 验证成本金额
    SUM(finish_order_qty)                                        AS finish_order_qty,  -- 完结订单数
    SUM(finish_ticket_qty)                                       AS finish_ticket_qty,  -- 完结票数
    SUM(finish_sale_amt)                                         AS finish_sale_amt,  -- 完结金额
    SUM(finish_cost_amt)                                         AS finish_cost_amt,  -- 完结成本金额
    SUM(revoke_order_qty)                                        AS revoke_order_qty,  -- 撤销订单数
    SUM(revoke_ticket_qty)                                       AS revoke_ticket_qty,  -- 撤销票数
    SUM(revoke_sale_amt)                                         AS revoke_sale_amt,  -- 撤销金额
    SUM(revoke_cost_amt)                                         AS revoke_cost_amt,  -- 撤销成本金额
    SUM(print_order_qty)                                         AS print_order_qty,  -- 取票订单数
    SUM(print_ticket_qty)                                        AS print_ticket_qty,  -- 取票票数
    SUM(print_sale_amt)                                          AS print_sale_amt,  -- 取票金额
    SUM(after_sale_ticket_qty)                                   AS after_sale_ticket_qty,  -- 售后票数
    SUM(after_sale_refund_amt)                                   AS after_sale_refund_amt,  -- 售后退回金额
    SUM(after_sale_income_amt)                                   AS after_sale_income_amt,  -- 售后收入金额
    BITMAP_UNION(buyer_qty)                                      AS buyer_qty,    -- 购买人数
    SUM(pay_cost_amt)                                            AS pay_cost_amt,  -- 支付成本金额
    SUM(cancel_fee_amt)                                          AS cancel_fee_amt,  -- 取消手续费
    SUM(revoke_fee_amt)                                          AS revoke_fee_amt,  -- 撤销手续费
    SUM(pay_sale_discount_amt)                                   AS pay_sale_discount_amt,  -- 预订销售优惠金额
    SUM(pay_cost_discount_amt)                                   AS pay_cost_discount_amt,  -- 预订采购优惠金额
    SUM(verify_sale_discount_amt)                                AS verify_sale_discount_amt,  -- 核销销售优惠金额
    SUM(verify_cost_discount_amt)                                AS verify_cost_discount_amt,  -- 核销采购优惠金额
    SUM(cancel_sale_discount_amt)                                AS cancel_sale_discount_amt,  -- 取消销售优惠金额
    SUM(cancel_cost_discount_amt)                                AS cancel_cost_discount_amt,  -- 取消采购优惠金额
    SUM(revoke_sale_discount_amt)                                AS revoke_sale_discount_amt,  -- 撤销销售优惠金额
    SUM(revoke_cost_discount_amt)                                AS revoke_cost_discount_amt,  -- 撤销采购优惠金额
    SUM(cancel_cost_fee_amt)                                     AS cancel_cost_fee_amt,  -- 取消采购手续费
    SUM(revoke_cost_fee_amt)                                     AS revoke_cost_fee_amt,  -- 撤销采购手续费
    SUM(after_sale_cost_amt)                                     AS after_sale_cost_amt,  -- 售后支出金额
    SUM(reprint_ticket_qty)                                      AS reprint_ticket_qty,  -- 重打印票数
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time           -- ETL 加载时间
FROM (
    -- ord：预订：下单日分区 = bizdate，已支付（含现场支付、含之后取消）
    SELECT
        COALESCE(scenic_id, CAST(-1 AS BIGINT))                      AS scenic_id,  -- 景区ID
        COALESCE(ticket_id, CAST(-1 AS BIGINT))                      AS ticket_id,  -- 票ID
        COALESCE(supplier_id, CAST(-1 AS BIGINT))                    AS supplier_id,  -- 供应商ID（租户ID）
        COALESCE(distributor_id, CAST(-1 AS BIGINT))                 AS distributor_id,  -- 一级分销商ID
        COALESCE(order_mode, CAST(-1 AS INT))                        AS order_mode,  -- 下单渠道编码
        COALESCE(pay_mode, CAST(-1 AS INT))                          AS pay_mode,  -- 支付方式编码
        order_role,                                                               -- 主子单
        IF(team_flag = 1, 'TEAM', 'INDIVIDUAL')                      AS team_type,  -- 团散
        taker_province_code                                          AS province_code,  -- 客源省编码（取票人证件 / 手机号归属）
        COUNT(1)                                                     AS order_order_qty,  -- 预订订单数
        SUM(origin_ticket_qty)                                       AS order_ticket_qty,  -- 预订票数
        SUM(origin_ticket_qty * sale_price_amt)                      AS order_sale_amt,  -- 预订金额
        SUM(origin_ticket_qty * cost_price_amt)                      AS order_cost_amt,  -- 预订成本金额
        CAST(0 AS BIGINT)                                            AS pay_order_qty,  -- 支付订单数：此来源不产出，补0
        CAST(0 AS BIGINT)                                            AS pay_ticket_qty,  -- 支付票数：此来源不产出，补0
        CAST(0 AS DECIMAL(18,2))                                     AS pay_sale_amt,  -- 支付金额：此来源不产出，补0
        CAST(0 AS BIGINT)                                            AS cancel_order_qty,  -- 取消订单数：此来源不产出，补0
        CAST(0 AS BIGINT)                                            AS cancel_ticket_qty,  -- 取消票数：此来源不产出，补0
        CAST(0 AS DECIMAL(18,2))                                     AS cancel_sale_amt,  -- 取消金额：此来源不产出，补0
        CAST(0 AS DECIMAL(18,2))                                     AS cancel_cost_amt,  -- 取消成本金额：此来源不产出，补0
        CAST(0 AS BIGINT)                                            AS verify_order_qty,  -- 验证订单数：此来源不产出，补0
        CAST(0 AS BIGINT)                                            AS verify_ticket_qty,  -- 验证票数：此来源不产出，补0
        CAST(0 AS DECIMAL(18,2))                                     AS verify_sale_amt,  -- 验证金额：此来源不产出，补0
        CAST(0 AS DECIMAL(18,2))                                     AS verify_cost_amt,  -- 验证成本金额：此来源不产出，补0
        CAST(0 AS BIGINT)                                            AS finish_order_qty,  -- 完结订单数：此来源不产出，补0
        CAST(0 AS BIGINT)                                            AS finish_ticket_qty,  -- 完结票数：此来源不产出，补0
        CAST(0 AS DECIMAL(18,2))                                     AS finish_sale_amt,  -- 完结金额：此来源不产出，补0
        CAST(0 AS DECIMAL(18,2))                                     AS finish_cost_amt,  -- 完结成本金额：此来源不产出，补0
        CAST(0 AS BIGINT)                                            AS revoke_order_qty,  -- 撤销订单数：此来源不产出，补0
        CAST(0 AS BIGINT)                                            AS revoke_ticket_qty,  -- 撤销票数：此来源不产出，补0
        CAST(0 AS DECIMAL(18,2))                                     AS revoke_sale_amt,  -- 撤销金额：此来源不产出，补0
        CAST(0 AS DECIMAL(18,2))                                     AS revoke_cost_amt,  -- 撤销成本金额：此来源不产出，补0
        CAST(0 AS BIGINT)                                            AS print_order_qty,  -- 取票订单数：此来源不产出，补0
        CAST(0 AS BIGINT)                                            AS print_ticket_qty,  -- 取票票数：此来源不产出，补0
        CAST(0 AS DECIMAL(18,2))                                     AS print_sale_amt,  -- 取票金额：此来源不产出，补0
        CAST(0 AS BIGINT)                                            AS after_sale_ticket_qty,  -- 售后票数：此来源不产出，补0
        CAST(0 AS DECIMAL(18,2))                                     AS after_sale_refund_amt,  -- 售后退回金额：此来源不产出，补0
        CAST(0 AS DECIMAL(18,2))                                     AS after_sale_income_amt,  -- 售后收入金额：此来源不产出，补0
        BITMAP_UNION(TO_BITMAP(XXHASH64(taker_id_card_hash)))        AS buyer_qty,  -- 购买人数
        CAST(0 AS DECIMAL(18,2))                                     AS pay_cost_amt,  -- 支付成本金额：此来源不产出，补0
        CAST(0 AS DECIMAL(18,2))                                     AS cancel_fee_amt,  -- 取消手续费：此来源不产出，补0
        CAST(0 AS DECIMAL(18,2))                                     AS revoke_fee_amt,  -- 撤销手续费：此来源不产出，补0
        CAST(0 AS DECIMAL(18,2))                                     AS pay_sale_discount_amt,  -- 预订销售优惠金额：此来源不产出，补0
        CAST(0 AS DECIMAL(18,2))                                     AS pay_cost_discount_amt,  -- 预订采购优惠金额：此来源不产出，补0
        CAST(0 AS DECIMAL(18,2))                                     AS verify_sale_discount_amt,  -- 核销销售优惠金额：此来源不产出，补0
        CAST(0 AS DECIMAL(18,2))                                     AS verify_cost_discount_amt,  -- 核销采购优惠金额：此来源不产出，补0
        CAST(0 AS DECIMAL(18,2))                                     AS cancel_sale_discount_amt,  -- 取消销售优惠金额：此来源不产出，补0
        CAST(0 AS DECIMAL(18,2))                                     AS cancel_cost_discount_amt,  -- 取消采购优惠金额：此来源不产出，补0
        CAST(0 AS DECIMAL(18,2))                                     AS revoke_sale_discount_amt,  -- 撤销销售优惠金额：此来源不产出，补0
        CAST(0 AS DECIMAL(18,2))                                     AS revoke_cost_discount_amt,  -- 撤销采购优惠金额：此来源不产出，补0
        CAST(0 AS DECIMAL(18,2))                                     AS cancel_cost_fee_amt,  -- 取消采购手续费：此来源不产出，补0
        CAST(0 AS DECIMAL(18,2))                                     AS revoke_cost_fee_amt,  -- 撤销采购手续费：此来源不产出，补0
        CAST(0 AS DECIMAL(18,2))                                     AS after_sale_cost_amt,  -- 售后支出金额：此来源不产出，补0
        CAST(0 AS BIGINT)                                            AS reprint_ticket_qty  -- 重打印票数：此来源不产出，补0
    FROM dwd.dwd_ord_order_di
    WHERE travel_date = '${bizdate}'                                              -- 只取当日分区
      AND test_flag = 0
      AND pay_status <> '2'
    GROUP BY COALESCE(scenic_id, CAST(-1 AS BIGINT)),                             -- 按粒度键汇总
             COALESCE(ticket_id, CAST(-1 AS BIGINT)),
             COALESCE(supplier_id, CAST(-1 AS BIGINT)),
             COALESCE(distributor_id, CAST(-1 AS BIGINT)),
             COALESCE(order_mode, CAST(-1 AS INT)),
             COALESCE(pay_mode, CAST(-1 AS INT)),
             order_role,                                                          -- 主子单
             IF(team_flag = 1, 'TEAM', 'INDIVIDUAL'),
             taker_province_code
    UNION ALL
    -- trk：订单操作：操作日分区 = bizdate
    SELECT
        COALESCE(scenic_id, CAST(-1 AS BIGINT))                      AS scenic_id,  -- 景区ID
        COALESCE(ticket_id, CAST(-1 AS BIGINT))                      AS ticket_id,  -- 票ID
        COALESCE(supplier_id, CAST(-1 AS BIGINT))                    AS supplier_id,  -- 供应商ID（租户ID）
        COALESCE(distributor_id, CAST(-1 AS BIGINT))                 AS distributor_id,  -- 一级分销商ID
        COALESCE(order_mode, CAST(-1 AS INT))                        AS order_mode,  -- 下单渠道编码
        COALESCE(pay_mode, CAST(-1 AS INT))                          AS pay_mode,  -- 支付方式编码
        order_role,                                                               -- 主子单
        IF(team_flag = 1, 'TEAM', 'INDIVIDUAL')                      AS team_type,  -- 团散
        taker_province_code                                          AS province_code,  -- 客源省编码（取票人证件 / 手机号归属）
        CAST(0 AS BIGINT)                                            AS order_order_qty,  -- 预订订单数：此来源不产出，补0
        CAST(0 AS BIGINT)                                            AS order_ticket_qty,  -- 预订票数：此来源不产出，补0
        CAST(0 AS DECIMAL(18,2))                                     AS order_sale_amt,  -- 预订金额：此来源不产出，补0
        CAST(0 AS DECIMAL(18,2))                                     AS order_cost_amt,  -- 预订成本金额：此来源不产出，补0
        COUNT(DISTINCT IF(track_action IN ('PAY', 'ADD_TICKET'), order_no, NULL)) AS pay_order_qty,  -- 支付订单数
        SUM(IF(track_action IN ('PAY', 'ADD_TICKET'), ticket_qty, 0)) AS pay_ticket_qty,  -- 支付票数
        SUM(IF(track_action IN ('PAY', 'ADD_TICKET'), sale_amt, 0))  AS pay_sale_amt,  -- 支付金额
        COUNT(DISTINCT IF(track_action IN ('CANCEL', 'MODIFY'), order_no, NULL)) AS cancel_order_qty,  -- 取消订单数
        SUM(IF(track_action IN ('CANCEL', 'MODIFY'), ticket_qty, 0)) AS cancel_ticket_qty,  -- 取消票数
        SUM(IF(track_action IN ('CANCEL', 'MODIFY'), sale_amt, 0))   AS cancel_sale_amt,  -- 取消金额
        SUM(IF(track_action IN ('CANCEL', 'MODIFY'), cost_amt, 0))   AS cancel_cost_amt,  -- 取消成本金额
        CAST(0 AS BIGINT)                                            AS verify_order_qty,  -- 验证订单数：此来源不产出，补0
        CAST(0 AS BIGINT)                                            AS verify_ticket_qty,  -- 验证票数：此来源不产出，补0
        CAST(0 AS DECIMAL(18,2))                                     AS verify_sale_amt,  -- 验证金额：此来源不产出，补0
        CAST(0 AS DECIMAL(18,2))                                     AS verify_cost_amt,  -- 验证成本金额：此来源不产出，补0
        COUNT(DISTINCT IF(track_action IN ('FINISH'), order_no, NULL)) AS finish_order_qty,  -- 完结订单数
        SUM(IF(track_action IN ('FINISH'), ticket_qty, 0))           AS finish_ticket_qty,  -- 完结票数
        SUM(IF(track_action IN ('FINISH'), sale_amt, 0))             AS finish_sale_amt,  -- 完结金额
        SUM(IF(track_action IN ('FINISH'), cost_amt, 0))             AS finish_cost_amt,  -- 完结成本金额
        COUNT(DISTINCT IF(track_action IN ('REVOKE', 'REVOKE_MODIFY'), order_no, NULL)) AS revoke_order_qty,  -- 撤销订单数
        SUM(IF(track_action IN ('REVOKE', 'REVOKE_MODIFY'), ticket_qty, 0)) AS revoke_ticket_qty,  -- 撤销票数
        SUM(IF(track_action IN ('REVOKE', 'REVOKE_MODIFY'), sale_amt, 0)) AS revoke_sale_amt,  -- 撤销金额
        SUM(IF(track_action IN ('REVOKE', 'REVOKE_MODIFY'), cost_amt, 0)) AS revoke_cost_amt,  -- 撤销成本金额
        COUNT(DISTINCT IF(track_action IN ('PRINT'), order_no, NULL)) AS print_order_qty,  -- 取票订单数
        SUM(IF(track_action IN ('PRINT'), ticket_qty, 0))            AS print_ticket_qty,  -- 取票票数
        SUM(IF(track_action IN ('PRINT'), sale_amt, 0))              AS print_sale_amt,  -- 取票金额
        SUM(IF(track_action IN ('AFTER_SALE'), ticket_qty, 0))       AS after_sale_ticket_qty,  -- 售后票数
        SUM(IF(track_action = 'AFTER_SALE', refund_amt, 0))          AS after_sale_refund_amt,  -- 售后退回金额
        SUM(IF(track_action = 'AFTER_SALE', service_fee_amt, 0))     AS after_sale_income_amt,  -- 售后收入金额
        CAST(NULL AS BINARY)                                         AS buyer_qty,  -- 购买人数：此来源不产出，补空
        SUM(IF(track_action IN ('PAY', 'ADD_TICKET'), cost_amt, 0))  AS pay_cost_amt,  -- 支付成本金额
        SUM(IF(track_action IN ('CANCEL', 'MODIFY'), service_fee_amt, 0)) AS cancel_fee_amt,  -- 取消手续费
        SUM(IF(track_action IN ('REVOKE', 'REVOKE_MODIFY'), service_fee_amt, 0)) AS revoke_fee_amt,  -- 撤销手续费
        CAST(0 AS DECIMAL(18,2))                                     AS pay_sale_discount_amt,  -- 预订销售优惠金额：此来源不产出，补0
        CAST(0 AS DECIMAL(18,2))                                     AS pay_cost_discount_amt,  -- 预订采购优惠金额：此来源不产出，补0
        CAST(0 AS DECIMAL(18,2))                                     AS verify_sale_discount_amt,  -- 核销销售优惠金额：此来源不产出，补0
        CAST(0 AS DECIMAL(18,2))                                     AS verify_cost_discount_amt,  -- 核销采购优惠金额：此来源不产出，补0
        CAST(0 AS DECIMAL(18,2))                                     AS cancel_sale_discount_amt,  -- 取消销售优惠金额：此来源不产出，补0
        CAST(0 AS DECIMAL(18,2))                                     AS cancel_cost_discount_amt,  -- 取消采购优惠金额：此来源不产出，补0
        CAST(0 AS DECIMAL(18,2))                                     AS revoke_sale_discount_amt,  -- 撤销销售优惠金额：此来源不产出，补0
        CAST(0 AS DECIMAL(18,2))                                     AS revoke_cost_discount_amt,  -- 撤销采购优惠金额：此来源不产出，补0
        CAST(0 AS DECIMAL(18,2))                                     AS cancel_cost_fee_amt,  -- 取消采购手续费：此来源不产出，补0
        CAST(0 AS DECIMAL(18,2))                                     AS revoke_cost_fee_amt,  -- 撤销采购手续费：此来源不产出，补0
        CAST(0 AS DECIMAL(18,2))                                     AS after_sale_cost_amt,  -- 售后支出金额：此来源不产出，补0
        CAST(0 AS BIGINT)                                            AS reprint_ticket_qty  -- 重打印票数：此来源不产出，补0
    FROM dwd.dwd_ord_order_track_di
    WHERE travel_date = '${bizdate}'                                              -- 只取当日分区
      AND test_flag = 0
    GROUP BY COALESCE(scenic_id, CAST(-1 AS BIGINT)),                             -- 按粒度键汇总
             COALESCE(ticket_id, CAST(-1 AS BIGINT)),
             COALESCE(supplier_id, CAST(-1 AS BIGINT)),
             COALESCE(distributor_id, CAST(-1 AS BIGINT)),
             COALESCE(order_mode, CAST(-1 AS INT)),
             COALESCE(pay_mode, CAST(-1 AS INT)),
             order_role,                                                          -- 主子单
             IF(team_flag = 1, 'TEAM', 'INDIVIDUAL'),
             taker_province_code
    UNION ALL
    -- vfy：核销：验证日分区 = bizdate
    SELECT
        COALESCE(scenic_id, CAST(-1 AS BIGINT))                      AS scenic_id,  -- 景区ID
        COALESCE(ticket_id, CAST(-1 AS BIGINT))                      AS ticket_id,  -- 票ID
        COALESCE(supplier_id, CAST(-1 AS BIGINT))                    AS supplier_id,  -- 供应商ID（租户ID）
        COALESCE(distributor_id, CAST(-1 AS BIGINT))                 AS distributor_id,  -- 一级分销商ID
        COALESCE(order_mode, CAST(-1 AS INT))                        AS order_mode,  -- 下单渠道编码
        COALESCE(pay_mode, CAST(-1 AS INT))                          AS pay_mode,  -- 支付方式编码
        order_role,                                                               -- 主子单
        IF(team_flag = 1, 'TEAM', 'INDIVIDUAL')                      AS team_type,  -- 团散
        taker_province_code                                          AS province_code,  -- 客源省编码（取票人证件 / 手机号归属）
        CAST(0 AS BIGINT)                                            AS order_order_qty,  -- 预订订单数：此来源不产出，补0
        CAST(0 AS BIGINT)                                            AS order_ticket_qty,  -- 预订票数：此来源不产出，补0
        CAST(0 AS DECIMAL(18,2))                                     AS order_sale_amt,  -- 预订金额：此来源不产出，补0
        CAST(0 AS DECIMAL(18,2))                                     AS order_cost_amt,  -- 预订成本金额：此来源不产出，补0
        CAST(0 AS BIGINT)                                            AS pay_order_qty,  -- 支付订单数：此来源不产出，补0
        CAST(0 AS BIGINT)                                            AS pay_ticket_qty,  -- 支付票数：此来源不产出，补0
        CAST(0 AS DECIMAL(18,2))                                     AS pay_sale_amt,  -- 支付金额：此来源不产出，补0
        CAST(0 AS BIGINT)                                            AS cancel_order_qty,  -- 取消订单数：此来源不产出，补0
        CAST(0 AS BIGINT)                                            AS cancel_ticket_qty,  -- 取消票数：此来源不产出，补0
        CAST(0 AS DECIMAL(18,2))                                     AS cancel_sale_amt,  -- 取消金额：此来源不产出，补0
        CAST(0 AS DECIMAL(18,2))                                     AS cancel_cost_amt,  -- 取消成本金额：此来源不产出，补0
        COUNT(DISTINCT order_no)                                     AS verify_order_qty,  -- 验证订单数
        SUM(verify_ticket_qty)                                       AS verify_ticket_qty,  -- 验证票数
        SUM(verify_sale_amt)                                         AS verify_sale_amt,  -- 验证金额
        SUM(verify_cost_amt)                                         AS verify_cost_amt,  -- 验证成本金额
        CAST(0 AS BIGINT)                                            AS finish_order_qty,  -- 完结订单数：此来源不产出，补0
        CAST(0 AS BIGINT)                                            AS finish_ticket_qty,  -- 完结票数：此来源不产出，补0
        CAST(0 AS DECIMAL(18,2))                                     AS finish_sale_amt,  -- 完结金额：此来源不产出，补0
        CAST(0 AS DECIMAL(18,2))                                     AS finish_cost_amt,  -- 完结成本金额：此来源不产出，补0
        CAST(0 AS BIGINT)                                            AS revoke_order_qty,  -- 撤销订单数：此来源不产出，补0
        CAST(0 AS BIGINT)                                            AS revoke_ticket_qty,  -- 撤销票数：此来源不产出，补0
        CAST(0 AS DECIMAL(18,2))                                     AS revoke_sale_amt,  -- 撤销金额：此来源不产出，补0
        CAST(0 AS DECIMAL(18,2))                                     AS revoke_cost_amt,  -- 撤销成本金额：此来源不产出，补0
        CAST(0 AS BIGINT)                                            AS print_order_qty,  -- 取票订单数：此来源不产出，补0
        CAST(0 AS BIGINT)                                            AS print_ticket_qty,  -- 取票票数：此来源不产出，补0
        CAST(0 AS DECIMAL(18,2))                                     AS print_sale_amt,  -- 取票金额：此来源不产出，补0
        CAST(0 AS BIGINT)                                            AS after_sale_ticket_qty,  -- 售后票数：此来源不产出，补0
        CAST(0 AS DECIMAL(18,2))                                     AS after_sale_refund_amt,  -- 售后退回金额：此来源不产出，补0
        CAST(0 AS DECIMAL(18,2))                                     AS after_sale_income_amt,  -- 售后收入金额：此来源不产出，补0
        CAST(NULL AS BINARY)                                         AS buyer_qty,  -- 购买人数：此来源不产出，补空
        CAST(0 AS DECIMAL(18,2))                                     AS pay_cost_amt,  -- 支付成本金额：此来源不产出，补0
        CAST(0 AS DECIMAL(18,2))                                     AS cancel_fee_amt,  -- 取消手续费：此来源不产出，补0
        CAST(0 AS DECIMAL(18,2))                                     AS revoke_fee_amt,  -- 撤销手续费：此来源不产出，补0
        CAST(0 AS DECIMAL(18,2))                                     AS pay_sale_discount_amt,  -- 预订销售优惠金额：此来源不产出，补0
        CAST(0 AS DECIMAL(18,2))                                     AS pay_cost_discount_amt,  -- 预订采购优惠金额：此来源不产出，补0
        CAST(0 AS DECIMAL(18,2))                                     AS verify_sale_discount_amt,  -- 核销销售优惠金额：此来源不产出，补0
        CAST(0 AS DECIMAL(18,2))                                     AS verify_cost_discount_amt,  -- 核销采购优惠金额：此来源不产出，补0
        CAST(0 AS DECIMAL(18,2))                                     AS cancel_sale_discount_amt,  -- 取消销售优惠金额：此来源不产出，补0
        CAST(0 AS DECIMAL(18,2))                                     AS cancel_cost_discount_amt,  -- 取消采购优惠金额：此来源不产出，补0
        CAST(0 AS DECIMAL(18,2))                                     AS revoke_sale_discount_amt,  -- 撤销销售优惠金额：此来源不产出，补0
        CAST(0 AS DECIMAL(18,2))                                     AS revoke_cost_discount_amt,  -- 撤销采购优惠金额：此来源不产出，补0
        CAST(0 AS DECIMAL(18,2))                                     AS cancel_cost_fee_amt,  -- 取消采购手续费：此来源不产出，补0
        CAST(0 AS DECIMAL(18,2))                                     AS revoke_cost_fee_amt,  -- 撤销采购手续费：此来源不产出，补0
        CAST(0 AS DECIMAL(18,2))                                     AS after_sale_cost_amt,  -- 售后支出金额：此来源不产出，补0
        CAST(0 AS BIGINT)                                            AS reprint_ticket_qty  -- 重打印票数：此来源不产出，补0
    FROM dwd.dwd_ord_verify_di
    WHERE travel_date = '${bizdate}'                                              -- 只取当日分区
      AND test_flag = 0
    GROUP BY COALESCE(scenic_id, CAST(-1 AS BIGINT)),                             -- 按粒度键汇总
             COALESCE(ticket_id, CAST(-1 AS BIGINT)),
             COALESCE(supplier_id, CAST(-1 AS BIGINT)),
             COALESCE(distributor_id, CAST(-1 AS BIGINT)),
             COALESCE(order_mode, CAST(-1 AS INT)),
             COALESCE(pay_mode, CAST(-1 AS INT)),
             order_role,                                                          -- 主子单
             IF(team_flag = 1, 'TEAM', 'INDIVIDUAL'),
             taker_province_code
    UNION ALL
    -- mps：商户视角经营明细（报表库业务明细）：本方商户 = 供应商维度
    SELECT
        COALESCE(product_id, CAST(-1 AS BIGINT))                     AS scenic_id,  -- 景区ID
        COALESCE(ticket_id, CAST(-1 AS BIGINT))                      AS ticket_id,  -- 票ID
        COALESCE(member_id, CAST(-1 AS BIGINT))                      AS supplier_id,  -- 供应商ID（租户ID）
        COALESCE(distributor_id, CAST(-1 AS BIGINT))                 AS distributor_id,  -- 一级分销商ID
        COALESCE(order_mode, CAST(-1 AS INT))                        AS order_mode,  -- 下单渠道编码
        COALESCE(pay_mode, CAST(-1 AS INT))                          AS pay_mode,  -- 支付方式编码
        CASE pack_type WHEN 2 THEN 'SUB' ELSE 'MAIN' END             AS order_role,  -- 主子单
        CAST(NULL AS STRING)                                         AS team_type,  -- 团散：此来源不区分，取 -1（不适用）
        CAST(NULL AS STRING)                                         AS province_code,  -- 客源省编码（取票人证件 / 手机号归属）：此来源不区分，取 -1（不适用）
        CAST(0 AS BIGINT)                                            AS order_order_qty,  -- 预订订单数：此来源不产出，补0
        CAST(0 AS BIGINT)                                            AS order_ticket_qty,  -- 预订票数：此来源不产出，补0
        CAST(0 AS DECIMAL(18,2))                                     AS order_sale_amt,  -- 预订金额：此来源不产出，补0
        CAST(0 AS DECIMAL(18,2))                                     AS order_cost_amt,  -- 预订成本金额：此来源不产出，补0
        CAST(0 AS BIGINT)                                            AS pay_order_qty,  -- 支付订单数：此来源不产出，补0
        CAST(0 AS BIGINT)                                            AS pay_ticket_qty,  -- 支付票数：此来源不产出，补0
        CAST(0 AS DECIMAL(18,2))                                     AS pay_sale_amt,  -- 支付金额：此来源不产出，补0
        CAST(0 AS BIGINT)                                            AS cancel_order_qty,  -- 取消订单数：此来源不产出，补0
        CAST(0 AS BIGINT)                                            AS cancel_ticket_qty,  -- 取消票数：此来源不产出，补0
        CAST(0 AS DECIMAL(18,2))                                     AS cancel_sale_amt,  -- 取消金额：此来源不产出，补0
        CAST(0 AS DECIMAL(18,2))                                     AS cancel_cost_amt,  -- 取消成本金额：此来源不产出，补0
        CAST(0 AS BIGINT)                                            AS verify_order_qty,  -- 验证订单数：此来源不产出，补0
        CAST(0 AS BIGINT)                                            AS verify_ticket_qty,  -- 验证票数：此来源不产出，补0
        CAST(0 AS DECIMAL(18,2))                                     AS verify_sale_amt,  -- 验证金额：此来源不产出，补0
        CAST(0 AS DECIMAL(18,2))                                     AS verify_cost_amt,  -- 验证成本金额：此来源不产出，补0
        CAST(0 AS BIGINT)                                            AS finish_order_qty,  -- 完结订单数：此来源不产出，补0
        CAST(0 AS BIGINT)                                            AS finish_ticket_qty,  -- 完结票数：此来源不产出，补0
        CAST(0 AS DECIMAL(18,2))                                     AS finish_sale_amt,  -- 完结金额：此来源不产出，补0
        CAST(0 AS DECIMAL(18,2))                                     AS finish_cost_amt,  -- 完结成本金额：此来源不产出，补0
        CAST(0 AS BIGINT)                                            AS revoke_order_qty,  -- 撤销订单数：此来源不产出，补0
        CAST(0 AS BIGINT)                                            AS revoke_ticket_qty,  -- 撤销票数：此来源不产出，补0
        CAST(0 AS DECIMAL(18,2))                                     AS revoke_sale_amt,  -- 撤销金额：此来源不产出，补0
        CAST(0 AS DECIMAL(18,2))                                     AS revoke_cost_amt,  -- 撤销成本金额：此来源不产出，补0
        CAST(0 AS BIGINT)                                            AS print_order_qty,  -- 取票订单数：此来源不产出，补0
        CAST(0 AS BIGINT)                                            AS print_ticket_qty,  -- 取票票数：此来源不产出，补0
        CAST(0 AS DECIMAL(18,2))                                     AS print_sale_amt,  -- 取票金额：此来源不产出，补0
        CAST(0 AS BIGINT)                                            AS after_sale_ticket_qty,  -- 售后票数：此来源不产出，补0
        CAST(0 AS DECIMAL(18,2))                                     AS after_sale_refund_amt,  -- 售后退回金额：此来源不产出，补0
        CAST(0 AS DECIMAL(18,2))                                     AS after_sale_income_amt,  -- 售后收入金额：此来源不产出，补0
        CAST(NULL AS BINARY)                                         AS buyer_qty,  -- 购买人数：此来源不产出，补空
        CAST(0 AS DECIMAL(18,2))                                     AS pay_cost_amt,  -- 支付成本金额：此来源不产出，补0
        CAST(0 AS DECIMAL(18,2))                                     AS cancel_fee_amt,  -- 取消手续费：此来源不产出，补0
        CAST(0 AS DECIMAL(18,2))                                     AS revoke_fee_amt,  -- 撤销手续费：此来源不产出，补0
        SUM(pay_sale_discount_amt)                                   AS pay_sale_discount_amt,  -- 预订销售优惠金额
        SUM(pay_cost_discount_amt)                                   AS pay_cost_discount_amt,  -- 预订采购优惠金额
        SUM(verify_sale_discount_amt)                                AS verify_sale_discount_amt,  -- 核销销售优惠金额
        SUM(verify_cost_discount_amt)                                AS verify_cost_discount_amt,  -- 核销采购优惠金额
        SUM(cancel_sale_discount_amt)                                AS cancel_sale_discount_amt,  -- 取消销售优惠金额
        SUM(cancel_cost_discount_amt)                                AS cancel_cost_discount_amt,  -- 取消采购优惠金额
        SUM(revoke_sale_discount_amt)                                AS revoke_sale_discount_amt,  -- 撤销销售优惠金额
        SUM(revoke_cost_discount_amt)                                AS revoke_cost_discount_amt,  -- 撤销采购优惠金额
        SUM(cancel_cost_fee_amt)                                     AS cancel_cost_fee_amt,  -- 取消采购手续费
        SUM(revoke_cost_fee_amt)                                     AS revoke_cost_fee_amt,  -- 撤销采购手续费
        SUM(after_sale_cost_amt)                                     AS after_sale_cost_amt,  -- 售后支出金额
        SUM(reprint_qty)                                             AS reprint_ticket_qty  -- 重打印票数
    FROM dwd.dwd_ord_mps_detail_di
    WHERE travel_date = '${bizdate}'                                              -- 只取当日分区
    GROUP BY COALESCE(product_id, CAST(-1 AS BIGINT)),                            -- 按粒度键汇总
             COALESCE(ticket_id, CAST(-1 AS BIGINT)),
             COALESCE(member_id, CAST(-1 AS BIGINT)),
             COALESCE(distributor_id, CAST(-1 AS BIGINT)),
             COALESCE(order_mode, CAST(-1 AS INT)),
             COALESCE(pay_mode, CAST(-1 AS INT)),
             CASE pack_type
        WHEN 2 THEN 'SUB'
        ELSE 'MAIN'
    END
) u                                                                               -- 各来源合并后的明细
GROUP BY scenic_id,                                                               -- 按粒度键汇总
         ticket_id,                                                               -- 票ID
         supplier_id,                                                             -- 供应商ID（租户ID）
         distributor_id,                                                          -- 一级分销商ID
         order_mode,                                                              -- 下单渠道编码
         pay_mode,                                                                -- 支付方式编码
         order_role,                                                              -- 主子单
         team_type,                                                               -- 团散
         province_code                                                            -- 客源省编码（取票人证件 / 手机号归属）
