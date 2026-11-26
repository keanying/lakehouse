-- ================================================================================================
-- ads.ads_cus_scenic_customer_insight_mo  景区客群洞察（外部）
-- 粒度：1行=1月×景区×洞察类型×指标
-- 分区：travel_month
-- 调度：每日，依赖上游 DWS 当日分区；完成后回流 / 服务层读取
-- 上游：ods_cus_scenic_customer_insight_basic_profile_df、ods_cus_scenic_customer_insight_hot_poi_df、ods_cus_scenic_customer_insight_hot_visits_df、ods_cus_scenic_customer_insight_kpi_df、ods_cus_scenic_customer_insight_source_distribution_df、ods_cus_scenic_customer_insight_source_ranking_df、ods_cus_scenic_customer_insight_travel_behavior_df、ods_cus_scenic_customer_insight_visit_preference_df、ods_cus_scenic_customer_insight_wealth_consume_df、ods_cus_scenic_customer_insight_work_live_df
-- 替代旧任务 10 个（上线对数一致后下线）：
--   · 数据平台/ADS/数据集成_导入/数字大脑_数据同步/sync_ads_scenic_customer_insight_basic_profile_mo_from_mysql（DI，cron 00 05 00 * * ?）
--   · 数据平台/ADS/数据集成_导入/数字大脑_数据同步/sync_ads_scenic_customer_insight_hot_poi_mo_from_mysql（DI，cron 00 05 00 * * ?）
--   · 数据平台/ADS/数据集成_导入/数字大脑_数据同步/sync_ads_scenic_customer_insight_hot_visits_mo_from_mysql（DI，cron 00 05 00 * * ?）
--   · 数据平台/ADS/数据集成_导入/数字大脑_数据同步/sync_ads_scenic_customer_insight_kpi_mo_from_mysql（DI，cron 00 05 00 * * ?）
--   · 数据平台/ADS/数据集成_导入/数字大脑_数据同步/sync_ads_scenic_customer_insight_source_distribution_mo_from_mysql（DI，cron 00 05 00 * * ?）
--   · 数据平台/ADS/数据集成_导入/数字大脑_数据同步/sync_ads_scenic_customer_insight_source_ranking_mo_from_mysql（DI，cron 00 05 00 * * ?）
--   · 数据平台/ADS/数据集成_导入/数字大脑_数据同步/sync_ads_scenic_customer_insight_travel_behavior_mo_from_mysql（DI，cron 00 05 00 * * ?）
--   · 数据平台/ADS/数据集成_导入/数字大脑_数据同步/sync_ads_scenic_customer_insight_visit_preference_mo_from_mysql（DI，cron 00 05 00 * * ?）
--   · 数据平台/ADS/数据集成_导入/数字大脑_数据同步/sync_ads_scenic_customer_insight_wealth_consume_mo_from_mysql（DI，cron 00 05 00 * * ?）
--   · 数据平台/ADS/数据集成_导入/数字大脑_数据同步/sync_ads_scenic_customer_insight_work_live_mo_from_mysql（DI，cron 00 05 00 * * ?）
-- 业务规则 / 修正：
--   · 客户洞察为外部（运营商 / 第三方）按月预计算的 10 类结果，统一成「洞察类型 × 指标项 × 值」竖表；旧系统 10 张 ADS 各一套导出
--   · 待确认：period_granularity 取值（month）与外部接口核对
-- ================================================================================================
INSERT OVERWRITE TABLE ads.ads_cus_scenic_customer_insight_mo PARTITION (travel_month = SUBSTR('${bizdate}', 1, 6))
SELECT scenic_id, insight_type, item_name, item_value_qty, DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time
FROM (
    SELECT CAST(scenic_id AS BIGINT) AS scenic_id, 'basic_profile' AS insight_type, CAST(tag_value AS STRING) AS item_name, CAST(proportion AS DECIMAL(20,4)) AS item_value_qty
    FROM ods.ods_cus_scenic_customer_insight_basic_profile_df
    WHERE travel_date = '${bizdate}' AND period_granularity = 'month'
    UNION ALL
    SELECT CAST(scenic_id AS BIGINT) AS scenic_id, 'travel_behavior' AS insight_type, CAST(tag_value AS STRING) AS item_name, CAST(proportion AS DECIMAL(20,4)) AS item_value_qty
    FROM ods.ods_cus_scenic_customer_insight_travel_behavior_df
    WHERE travel_date = '${bizdate}' AND period_granularity = 'month'
    UNION ALL
    SELECT CAST(scenic_id AS BIGINT) AS scenic_id, 'wealth_consume' AS insight_type, CAST(tag_value AS STRING) AS item_name, CAST(proportion AS DECIMAL(20,4)) AS item_value_qty
    FROM ods.ods_cus_scenic_customer_insight_wealth_consume_df
    WHERE travel_date = '${bizdate}' AND period_granularity = 'month'
    UNION ALL
    SELECT CAST(scenic_id AS BIGINT) AS scenic_id, 'visit_preference' AS insight_type, CAST(preference_object AS STRING) AS item_name, CAST(proportion AS DECIMAL(20,4)) AS item_value_qty
    FROM ods.ods_cus_scenic_customer_insight_visit_preference_df
    WHERE travel_date = '${bizdate}' AND period_granularity = 'month'
    UNION ALL
    SELECT CAST(scenic_id AS BIGINT) AS scenic_id, 'source_distribution' AS insight_type, CAST(name AS STRING) AS item_name, CAST(proportion AS DECIMAL(20,4)) AS item_value_qty
    FROM ods.ods_cus_scenic_customer_insight_source_distribution_df
    WHERE travel_date = '${bizdate}' AND period_granularity = 'month'
    UNION ALL
    SELECT CAST(scenic_id AS BIGINT) AS scenic_id, 'source_ranking' AS insight_type, CAST(name AS STRING) AS item_name, CAST(proportion AS DECIMAL(20,4)) AS item_value_qty
    FROM ods.ods_cus_scenic_customer_insight_source_ranking_df
    WHERE travel_date = '${bizdate}' AND period_granularity = 'month'
    UNION ALL
    SELECT CAST(scenic_id AS BIGINT) AS scenic_id, 'work_live' AS insight_type, CAST(name AS STRING) AS item_name, CAST(proportion AS DECIMAL(20,4)) AS item_value_qty
    FROM ods.ods_cus_scenic_customer_insight_work_live_df
    WHERE travel_date = '${bizdate}' AND period_granularity = 'month'
    UNION ALL
    SELECT CAST(scenic_id AS BIGINT) AS scenic_id, 'hot_poi' AS insight_type, CAST(poi_name AS STRING) AS item_name, CAST(popularity AS DECIMAL(20,4)) AS item_value_qty
    FROM ods.ods_cus_scenic_customer_insight_hot_poi_df
    WHERE travel_date = '${bizdate}' AND period_granularity = 'month'
    UNION ALL
    SELECT CAST(scenic_id AS BIGINT) AS scenic_id, 'hot_visits' AS insight_type, CAST(poi_name AS STRING) AS item_name, CAST(popularity AS DECIMAL(20,4)) AS item_value_qty
    FROM ods.ods_cus_scenic_customer_insight_hot_visits_df
    WHERE travel_date = '${bizdate}' AND period_granularity = 'month'
    UNION ALL
    SELECT CAST(scenic_id AS BIGINT) AS scenic_id, 'kpi' AS insight_type, CAST(metric_name AS STRING) AS item_name, CAST(metric_value AS DECIMAL(20,4)) AS item_value_qty
    FROM ods.ods_cus_scenic_customer_insight_kpi_df
    WHERE travel_date = '${bizdate}' AND period_granularity = 'month'
) t
