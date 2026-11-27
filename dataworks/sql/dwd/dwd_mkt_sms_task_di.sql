-- ================================================================================================
-- dwd.dwd_mkt_sms_task_di  营销短信任务明细
-- 粒度：1行=1个营销短信任务
-- 分区：travel_date（YYYYMMDD）
-- 调度：每日，依赖上游 ODS 当日分区与相关维表
-- 上游：ods_mkt_marketing_sms_task_df
-- 业务规则 / 修正：
--   · 按创建日 = bizdate 取当日任务；发送人数 / 成功数不在任务表，按条数需接入营销短信发送流水（待确认）
-- ================================================================================================
INSERT OVERWRITE TABLE dwd.dwd_mkt_sms_task_di PARTITION (travel_date = '${bizdate}')
SELECT
    CAST(id AS BIGINT)                                           AS task_id,
    CAST(uid AS BIGINT)                                          AS supplier_id,
    CAST(p_type AS INT)                                          AS push_target_type,
    CAST(push_type_id AS BIGINT)                                 AS push_type_id,
    CAST(state AS INT)                                           AS send_state,
    CAST(is_send AS INT)                                         AS sendable_flag,
    CAST(is_timing AS INT)                                       AS timing_flag,
    CAST(operater_id AS BIGINT)                                  AS operator_id,
    FROM_UNIXTIME(send_time)                                     AS send_time,
    FROM_UNIXTIME(finish_time)                                   AS finish_time,
    FROM_UNIXTIME(create_time)                                   AS create_time,
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time
FROM ods.ods_mkt_marketing_sms_task_df
WHERE travel_date = '${bizdate}'
  AND FROM_UNIXTIME(create_time, 'yyyyMMdd') = '${bizdate}'   -- 全量快照取当日事件
