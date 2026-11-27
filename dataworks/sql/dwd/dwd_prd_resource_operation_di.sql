-- ================================================================================================
-- dwd.dwd_prd_resource_operation_di  资源变更与操作明细
-- 粒度：1行=1条资源操作（产品上下架 / 修改、业务员变更、保证金 / 金额操作）
-- 分区：travel_date（YYYYMMDD）
-- 调度：每日，依赖上游 ODS 当日分区与相关维表
-- 上游：ods_prd_resource_product_record_df、ods_prd_resource_salesman_log_df、ods_prd_resource_amount_operation_track_df
-- 业务规则 / 修正：
--   · 3 张操作记录表（均为全量快照）按各自操作时间取当日事件后 UNION ALL
-- ================================================================================================
-- 置空列：多个源表 UNION ALL 归一时，某源表没有的字段置空（各源表字段对照见各分支）
INSERT OVERWRITE TABLE dwd.dwd_prd_resource_operation_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
-- (1) ods_prd_resource_product_record_df
SELECT
    'PRODUCT'                                                    AS operation_source,  -- 操作来源
    CAST(id AS BIGINT)                                           AS record_id,    -- 记录ID
    CAST(sid AS BIGINT)                                          AS supplier_id,  -- 供应商ID（租户ID）
    CAST(pid AS BIGINT)                                          AS product_id,   -- 产品ID
    CAST(NULL AS BIGINT)                                         AS scenic_id,    -- 景区ID：此源表无此字段，置空
    CAST(NULL AS BIGINT)                                         AS salesman_id,  -- 业务员ID：此源表无此字段，置空
    CAST(operate_type AS STRING)                                 AS operation_type,  -- 操作类型
    daction                                                      AS operation_content,  -- 操作内容
    CAST(NULL AS BIGINT)                                         AS counterparty_member_id,  -- 交易对方用户ID：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS order_no,     -- 订单号：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS serial_no,    -- 流水号：此源表无此字段，置空
    CAST(NULL AS DECIMAL(18,2))                                  AS operation_amt,  -- 操作金额（元）：此源表无此字段，置空
    CAST(NULL AS DECIMAL(18,2))                                  AS balance_amt,  -- 操作后余额（元）：此源表无此字段，置空
    CAST(operator_id AS BIGINT)                                  AS operator_id,  -- 操作人ID
    record_time                                                  AS operation_time,  -- 操作时间
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time           -- ETL 加载时间
FROM ods.ods_prd_resource_product_record_df
WHERE travel_date = '${bizdate}'                                                  -- 只取当日分区
  AND DATE_FORMAT(record_time, 'yyyyMMdd') = '${bizdate}'                         -- 全量快照取当日事件
UNION ALL
-- (2) ods_prd_resource_salesman_log_df
SELECT
    'SALESMAN'                                                   AS operation_source,  -- 操作来源
    CAST(id AS BIGINT)                                           AS record_id,    -- 记录ID
    CAST(sid AS BIGINT)                                          AS supplier_id,  -- 供应商ID（租户ID）
    CAST(NULL AS BIGINT)                                         AS product_id,   -- 产品ID：此源表无此字段，置空
    CAST(lid AS BIGINT)                                          AS scenic_id,    -- 景区ID
    CAST(salesman_id AS BIGINT)                                  AS salesman_id,  -- 业务员ID
    CAST(resource_type AS STRING)                                AS operation_type,  -- 操作类型
    CAST(NULL AS STRING)                                         AS operation_content,  -- 操作内容：此源表无此字段，置空
    CAST(NULL AS BIGINT)                                         AS counterparty_member_id,  -- 交易对方用户ID：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS order_no,     -- 订单号：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS serial_no,    -- 流水号：此源表无此字段，置空
    CAST(NULL AS DECIMAL(18,2))                                  AS operation_amt,  -- 操作金额（元）：此源表无此字段，置空
    CAST(NULL AS DECIMAL(18,2))                                  AS balance_amt,  -- 操作后余额（元）：此源表无此字段，置空
    CAST(NULL AS BIGINT)                                         AS operator_id,  -- 操作人ID：此源表无此字段，置空
    FROM_UNIXTIME(update_time)                                   AS operation_time,  -- 操作时间
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time           -- ETL 加载时间
FROM ods.ods_prd_resource_salesman_log_df
WHERE travel_date = '${bizdate}'                                                  -- 只取当日分区
  AND FROM_UNIXTIME(update_time, 'yyyyMMdd') = '${bizdate}'                       -- 全量快照取当日事件
UNION ALL
-- (3) ods_prd_resource_amount_operation_track_df
SELECT
    'AMOUNT'                                                     AS operation_source,  -- 操作来源
    CAST(id AS BIGINT)                                           AS record_id,    -- 记录ID
    CAST(member_id AS BIGINT)                                    AS supplier_id,  -- 供应商ID（租户ID）
    CAST(NULL AS BIGINT)                                         AS product_id,   -- 产品ID：此源表无此字段，置空
    CAST(NULL AS BIGINT)                                         AS scenic_id,    -- 景区ID：此源表无此字段，置空
    CAST(NULL AS BIGINT)                                         AS salesman_id,  -- 业务员ID：此源表无此字段，置空
    CONCAT(CAST(track_type AS STRING), '-', CAST(op_type AS STRING)) AS operation_type,  -- 操作类型
    msg                                                          AS operation_content,  -- 操作内容
    CAST(trad_member_id AS BIGINT)                               AS counterparty_member_id,  -- 交易对方用户ID
    ordernum                                                     AS order_no,     -- 订单号
    serial_num                                                   AS serial_no,    -- 流水号
    CAST(money AS DECIMAL(18,2)) / 100                           AS operation_amt,  -- 操作金额（元）
    CAST(balance AS DECIMAL(18,2)) / 100                         AS balance_amt,  -- 操作后余额（元）
    CAST(opid AS BIGINT)                                         AS operator_id,  -- 操作人ID
    FROM_UNIXTIME(add_time)                                      AS operation_time,  -- 操作时间
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time           -- ETL 加载时间
FROM ods.ods_prd_resource_amount_operation_track_df
WHERE travel_date = '${bizdate}'                                                  -- 只取当日分区
  AND FROM_UNIXTIME(add_time, 'yyyyMMdd') = '${bizdate}'                          -- 全量快照取当日事件
