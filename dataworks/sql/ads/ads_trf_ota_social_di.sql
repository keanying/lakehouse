-- ================================================================================================
-- ads.ads_trf_ota_social_di  OTA 与舆情（外部）
-- 粒度：1行=1天×景区×来源平台
-- 分区：travel_date（YYYYMMDD）
-- 调度：每日，依赖上游 DWS 当日分区；完成后回流 / 服务层读取
-- 上游：ods_trf_ota_ctrip_trade_df、ods_trf_ota_ctrip_score_df、ods_trf_social_opinion_comment_core_df
-- 替代旧任务 4 个（上线对数一致后下线）：
--   · 数据平台/ADS/数据集成_导入/数字大脑_数据同步/sync_ads_sup_ota_ctrip_score_di_from_mysql（DI，cron 00 20 00 * * ?）
--   · 数据平台/ADS/数据集成_导入/数字大脑_数据同步/sync_ads_sup_ota_ctrip_trade_di_from_mysql（DI，cron 00 20 00 * * ?）
--   · 数据平台/ADS/数据集成_导入/数字大脑_数据同步/sync_ads_trf_social_opinion_comment_core_di_from_mysql（DI，cron 00 05 00 * * ?）
--   · 数据平台/ADS/数据集成_导入/数字大脑_数据同步/sync_ads_trf_social_opinion_macro_gran_metric_di_from_mysql（DI，cron 00 17 00 * * ?）
-- 业务规则 / 修正：
--   · OTA 外部数据只取日粒度原值，周 / 月由时间表汇总（旧系统同时存外部算好的环比，口径不可控）
-- ================================================================================================
INSERT OVERWRITE TABLE ads.ads_trf_ota_social_di PARTITION (travel_date = '${bizdate}')
SELECT scenic_id, platform_code, SUM(ota_order_qty) AS ota_order_qty, DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time
FROM (
    -- 携程交易（外部采集，日粒度）
    SELECT CAST(scenic_id AS BIGINT) AS scenic_id, 'ctrip' AS platform_code, CAST(order_count AS BIGINT) AS ota_order_qty
    FROM ods.ods_trf_ota_ctrip_trade_df
    WHERE travel_date = '${bizdate}' AND DATE_FORMAT(transaction_date, 'yyyyMMdd') = '${bizdate}' AND date_type = 'day'   -- 待确认：date_type / period_type 取值
) t
GROUP BY scenic_id, platform_code
