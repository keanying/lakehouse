-- ================================================================================================
-- dwd.dwd_prd_resource_operation_di  资源变更与操作明细
-- 粒度：1行=1条资源操作（产品上下架 / 修改、业务员变更、保证金 / 金额操作）
-- 分区：travel_date（YYYYMMDD）
-- 调度：每日，依赖上游 ODS 当日分区与相关维表
-- 上游：ods_prd_resource_product_record_df、ods_prd_resource_salesman_log_df、ods_prd_resource_amount_operation_track_df
-- 业务规则 / 修正：
--   · 3 张操作记录表（均为全量快照）按各自操作时间取当日事件后 UNION ALL
-- ================================================================================================
INSERT OVERWRITE TABLE dwd.dwd_prd_resource_operation_di PARTITION (travel_date = '${bizdate}')
-- (1) ods_prd_resource_product_record_df
SELECT
    'PRODUCT'                                                    AS operation_source,
    CAST(id AS BIGINT)                                           AS record_id,
    CAST(sid AS BIGINT)                                          AS supplier_id,
    CAST(pid AS BIGINT)                                          AS product_id,
    CAST(NULL AS BIGINT)                                         AS scenic_id,
    CAST(NULL AS BIGINT)                                         AS salesman_id,
    CAST(operate_type AS STRING)                                 AS operation_type,
    daction                                                      AS operation_content,
    CAST(NULL AS BIGINT)                                         AS counterparty_member_id,
    CAST(NULL AS STRING)                                         AS order_no,
    CAST(NULL AS STRING)                                         AS serial_no,
    CAST(NULL AS DECIMAL(18,2))                                  AS operation_amt,
    CAST(NULL AS DECIMAL(18,2))                                  AS balance_amt,
    CAST(operator_id AS BIGINT)                                  AS operator_id,
    record_time                                                  AS operation_time,
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time
FROM ods.ods_prd_resource_product_record_df
WHERE travel_date = '${bizdate}'
  AND DATE_FORMAT(record_time, 'yyyyMMdd') = '${bizdate}'   -- 全量快照取当日事件
UNION ALL
-- (2) ods_prd_resource_salesman_log_df
SELECT
    'SALESMAN'                                                   AS operation_source,
    CAST(id AS BIGINT)                                           AS record_id,
    CAST(sid AS BIGINT)                                          AS supplier_id,
    CAST(NULL AS BIGINT)                                         AS product_id,
    CAST(lid AS BIGINT)                                          AS scenic_id,
    CAST(salesman_id AS BIGINT)                                  AS salesman_id,
    CAST(resource_type AS STRING)                                AS operation_type,
    CAST(NULL AS STRING)                                         AS operation_content,
    CAST(NULL AS BIGINT)                                         AS counterparty_member_id,
    CAST(NULL AS STRING)                                         AS order_no,
    CAST(NULL AS STRING)                                         AS serial_no,
    CAST(NULL AS DECIMAL(18,2))                                  AS operation_amt,
    CAST(NULL AS DECIMAL(18,2))                                  AS balance_amt,
    CAST(NULL AS BIGINT)                                         AS operator_id,
    FROM_UNIXTIME(update_time)                                   AS operation_time,
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time
FROM ods.ods_prd_resource_salesman_log_df
WHERE travel_date = '${bizdate}'
  AND FROM_UNIXTIME(update_time, 'yyyyMMdd') = '${bizdate}'   -- 全量快照取当日事件
UNION ALL
-- (3) ods_prd_resource_amount_operation_track_df
SELECT
    'AMOUNT'                                                     AS operation_source,
    CAST(id AS BIGINT)                                           AS record_id,
    CAST(member_id AS BIGINT)                                    AS supplier_id,
    CAST(NULL AS BIGINT)                                         AS product_id,
    CAST(NULL AS BIGINT)                                         AS scenic_id,
    CAST(NULL AS BIGINT)                                         AS salesman_id,
    CONCAT(CAST(track_type AS STRING), '-', CAST(op_type AS STRING)) AS operation_type,
    msg                                                          AS operation_content,
    CAST(trad_member_id AS BIGINT)                               AS counterparty_member_id,
    ordernum                                                     AS order_no,
    serial_num                                                   AS serial_no,
    CAST(money AS DECIMAL(18,2)) / 100                           AS operation_amt,
    CAST(balance AS DECIMAL(18,2)) / 100                         AS balance_amt,
    CAST(opid AS BIGINT)                                         AS operator_id,
    FROM_UNIXTIME(add_time)                                      AS operation_time,
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time
FROM ods.ods_prd_resource_amount_operation_track_df
WHERE travel_date = '${bizdate}'
  AND FROM_UNIXTIME(add_time, 'yyyyMMdd') = '${bizdate}'   -- 全量快照取当日事件
