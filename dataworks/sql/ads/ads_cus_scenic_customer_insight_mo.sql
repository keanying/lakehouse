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
INSERT OVERWRITE TABLE ads.ads_cus_scenic_customer_insight_mo PARTITION (travel_month = SUBSTR('${bizdate}', 1, 6))  -- 写入当日分区
SELECT scenic_id,                                                      -- 景区ID
       insight_type,                                                   -- 洞察类型
       item_name,                                                      -- 指标项
       item_value_qty,                                                 -- 指标值（日）
       DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time  -- ETL 加载时间
FROM (
    SELECT CAST(scenic_id AS BIGINT) AS scenic_id,                     -- 景区ID
           'basic_profile' AS insight_type,                            -- 洞察类型
           CAST(tag_value AS STRING) AS item_name,                     -- 指标项
           CAST(proportion AS DECIMAL(20,4)) AS item_value_qty         -- 指标值（日）
    FROM ods.ods_cus_scenic_customer_insight_basic_profile_df
    WHERE travel_date = '${bizdate}' AND period_granularity = 'month'  -- 只取当日分区，并按条件过滤
    UNION ALL
    SELECT CAST(scenic_id AS BIGINT) AS scenic_id,                     -- 景区ID
           'travel_behavior' AS insight_type,                          -- 洞察类型
           CAST(tag_value AS STRING) AS item_name,                     -- 指标项
           CAST(proportion AS DECIMAL(20,4)) AS item_value_qty         -- 指标值（日）
    FROM ods.ods_cus_scenic_customer_insight_travel_behavior_df
    WHERE travel_date = '${bizdate}' AND period_granularity = 'month'  -- 只取当日分区，并按条件过滤
    UNION ALL
    SELECT CAST(scenic_id AS BIGINT) AS scenic_id,                     -- 景区ID
           'wealth_consume' AS insight_type,                           -- 洞察类型
           CAST(tag_value AS STRING) AS item_name,                     -- 指标项
           CAST(proportion AS DECIMAL(20,4)) AS item_value_qty         -- 指标值（日）
    FROM ods.ods_cus_scenic_customer_insight_wealth_consume_df
    WHERE travel_date = '${bizdate}' AND period_granularity = 'month'  -- 只取当日分区，并按条件过滤
    UNION ALL
    SELECT CAST(scenic_id AS BIGINT) AS scenic_id,                     -- 景区ID
           'visit_preference' AS insight_type,                         -- 洞察类型
           CAST(preference_object AS STRING) AS item_name,             -- 指标项
           CAST(proportion AS DECIMAL(20,4)) AS item_value_qty         -- 指标值（日）
    FROM ods.ods_cus_scenic_customer_insight_visit_preference_df
    WHERE travel_date = '${bizdate}' AND period_granularity = 'month'  -- 只取当日分区，并按条件过滤
    UNION ALL
    SELECT CAST(scenic_id AS BIGINT) AS scenic_id,                     -- 景区ID
           'source_distribution' AS insight_type,                      -- 洞察类型
           CAST(name AS STRING) AS item_name,                          -- 指标项
           CAST(proportion AS DECIMAL(20,4)) AS item_value_qty         -- 指标值（日）
    FROM ods.ods_cus_scenic_customer_insight_source_distribution_df
    WHERE travel_date = '${bizdate}' AND period_granularity = 'month'  -- 只取当日分区，并按条件过滤
    UNION ALL
    SELECT CAST(scenic_id AS BIGINT) AS scenic_id,                     -- 景区ID
           'source_ranking' AS insight_type,                           -- 洞察类型
           CAST(name AS STRING) AS item_name,                          -- 指标项
           CAST(proportion AS DECIMAL(20,4)) AS item_value_qty         -- 指标值（日）
    FROM ods.ods_cus_scenic_customer_insight_source_ranking_df
    WHERE travel_date = '${bizdate}' AND period_granularity = 'month'  -- 只取当日分区，并按条件过滤
    UNION ALL
    SELECT CAST(scenic_id AS BIGINT) AS scenic_id,                     -- 景区ID
           'work_live' AS insight_type,                                -- 洞察类型
           CAST(name AS STRING) AS item_name,                          -- 指标项
           CAST(proportion AS DECIMAL(20,4)) AS item_value_qty         -- 指标值（日）
    FROM ods.ods_cus_scenic_customer_insight_work_live_df
    WHERE travel_date = '${bizdate}' AND period_granularity = 'month'  -- 只取当日分区，并按条件过滤
    UNION ALL
    SELECT CAST(scenic_id AS BIGINT) AS scenic_id,                     -- 景区ID
           'hot_poi' AS insight_type,                                  -- 洞察类型
           CAST(poi_name AS STRING) AS item_name,                      -- 指标项
           CAST(popularity AS DECIMAL(20,4)) AS item_value_qty         -- 指标值（日）
    FROM ods.ods_cus_scenic_customer_insight_hot_poi_df
    WHERE travel_date = '${bizdate}' AND period_granularity = 'month'  -- 只取当日分区，并按条件过滤
    UNION ALL
    SELECT CAST(scenic_id AS BIGINT) AS scenic_id,                     -- 景区ID
           'hot_visits' AS insight_type,                               -- 洞察类型
           CAST(poi_name AS STRING) AS item_name,                      -- 指标项
           CAST(popularity AS DECIMAL(20,4)) AS item_value_qty         -- 指标值（日）
    FROM ods.ods_cus_scenic_customer_insight_hot_visits_df
    WHERE travel_date = '${bizdate}' AND period_granularity = 'month'  -- 只取当日分区，并按条件过滤
    UNION ALL
    SELECT CAST(scenic_id AS BIGINT) AS scenic_id,                     -- 景区ID
           'kpi' AS insight_type,                                      -- 洞察类型
           CAST(metric_name AS STRING) AS item_name,                   -- 指标项
           CAST(metric_value AS DECIMAL(20,4)) AS item_value_qty       -- 指标值（日）
    FROM ods.ods_cus_scenic_customer_insight_kpi_df
    WHERE travel_date = '${bizdate}' AND period_granularity = 'month'  -- 只取当日分区，并按条件过滤
) t
