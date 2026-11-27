-- ================================================================================================
-- ads.ads_trf_digital_brain_di  数字大脑指标
-- 粒度：1行=1天×景区×指标域×指标
-- 分区：travel_date（YYYYMMDD）
-- 调度：每日，依赖上游 DWS 当日分区；完成后回流 / 服务层读取
-- 上游：ads_ord_scenic_trade_overview_di、ads_trf_scenic_passenger_flow_di
-- 替代旧任务 3 个（上线对数一致后下线）：
--   · 数据平台/ADS/ads_数字大脑指标流程/ads_digital_brain_target_merge_draw_di（SERVERLESS_SPARK_SQL，cron 00 00 03 * * ?）
--   · 数据平台/ADS/ads_数字大脑指标流程/ads_digital_brain_target_merge_ota_di（SERVERLESS_SPARK_SQL，cron 00 18 00 * * ?）
--   · 数据平台/ADS/ads_数字大脑指标流程/ads_digital_brain_target_merge_tick_di（SERVERLESS_SPARK_SQL，cron 00 00 03 * * ?）
-- 业务规则 / 修正：
--   · 大屏竖表由标准 ADS 转置得到，口径与报表一致（旧大屏单独一套 SQL，且有写死的模拟数据，见问题清单 D6）
-- ================================================================================================
INSERT OVERWRITE TABLE ads.ads_trf_digital_brain_di PARTITION (travel_date = '${bizdate}')
SELECT scenic_id, data_domain, target_name, data_value AS data_value_qty, DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time
FROM (
    -- 交易：由标准 ADS 转成「指标域 × 指标」竖表，大屏按 target_name 取数
    SELECT scenic_id, 'trade' AS data_domain,
           STACK(4, 'order_ticket_qty', CAST(SUM(order_ticket_qty) AS DECIMAL(20,4)), 'order_sale_amt', CAST(SUM(order_sale_amt) AS DECIMAL(20,4)),
                    'verify_ticket_qty', CAST(SUM(verify_ticket_qty) AS DECIMAL(20,4)), 'cancel_ticket_qty', CAST(SUM(cancel_ticket_qty) AS DECIMAL(20,4))) AS (target_name, data_value)
    FROM ads.ads_ord_scenic_trade_overview_di WHERE travel_date = '${bizdate}'
    GROUP BY scenic_id
    UNION ALL
    -- 客流
    SELECT scenic_id, 'flow',
           STACK(3, 'enter_qty', CAST(SUM(enter_qty) AS DECIMAL(20,4)), 'exit_qty', CAST(SUM(exit_qty) AS DECIMAL(20,4)), 'in_park_qty', CAST(MAX(in_park_qty) AS DECIMAL(20,4))) AS (target_name, data_value)
    FROM ads.ads_trf_scenic_passenger_flow_di WHERE travel_date = '${bizdate}'
    GROUP BY scenic_id
) t
