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
INSERT OVERWRITE TABLE ads.ads_trf_digital_brain_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
    MD5(CONCAT_WS('|', '${bizdate}', data_domain, CAST(scenic_id AS STRING), target_name)) AS key_id,  -- 指标行键｜行键（旧表同规则：日期 | 指标域 | 景区 | 指标）
    scenic_id,                                                                    -- 景区ID
    data_domain,                                                                  -- 指标域编码
    CASE data_domain WHEN 'trade' THEN '交易' WHEN 'flow' THEN '客流' ELSE data_domain END AS indicator_domain,  -- 指标域中文名（大屏分组标题）
    target_name,                                                                  -- 指标名称
    target_desc,                                                                  -- 指标说明
    data_value AS data_value_qty,                                                 -- 指标值（日）
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time           -- ETL 加载时间
FROM (
    -- 交易：由标准 ADS 转成「指标域 × 指标」竖表，大屏按 target_name 取数；STACK 每组 = (指标名, 指标说明, 值)
    SELECT scenic_id, 'trade' AS data_domain,                                     -- 指标域编码
           STACK(4,
               'order_ticket_qty', '预订票数（张）', CAST(SUM(order_ticket_qty) AS DECIMAL(20,4)),
               'order_sale_amt', '预订金额（元）', CAST(SUM(order_sale_amt) AS DECIMAL(20,4)),
               'verify_ticket_qty', '核销票数（张）', CAST(SUM(verify_ticket_qty) AS DECIMAL(20,4)),
               'cancel_ticket_qty', '取消票数（张）', CAST(SUM(cancel_ticket_qty) AS DECIMAL(20,4))
           ) AS (target_name, target_desc, data_value)
    FROM ads.ads_ord_scenic_trade_overview_di WHERE travel_date = '${bizdate}'
    GROUP BY scenic_id                                                            -- 按粒度键汇总
    UNION ALL
    -- 客流
    SELECT scenic_id, 'flow',
           STACK(3,
               'enter_qty', '入园人次（人）', CAST(SUM(enter_qty) AS DECIMAL(20,4)),
               'exit_qty', '离园人次（人）', CAST(SUM(exit_qty) AS DECIMAL(20,4)),
               'in_park_qty', '在园峰值人数（人）', CAST(MAX(in_park_qty) AS DECIMAL(20,4))
           ) AS (target_name, target_desc, data_value)
    FROM ads.ads_trf_scenic_passenger_flow_di WHERE travel_date = '${bizdate}'
    GROUP BY scenic_id                                                            -- 按粒度键汇总
) t
