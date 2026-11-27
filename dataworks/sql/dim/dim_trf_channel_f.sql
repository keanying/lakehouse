-- ================================================================================================
-- dim.dim_trf_channel_f  下单渠道 / 分销平台维度
-- 粒度：1行=1个渠道（下单渠道 / 第三方分销系统 / 第三方采购系统）
-- 分区：无分区
-- 调度：每日，ODS 全部完成后；维表之间按上游顺序
-- 上游：ods_opr_channel_df、ods_opr_distribute_system_type_df、ods_opr_third_purchase_system_df
-- 替代旧任务 1 个（上线对数一致后下线）：
--   · 数据中台/数据维度(DIM)/dim_其他/dim_channel_d_f（EMR_SPARK_SQL，cron 00 16 00 * * ?）
-- 业务规则 / 修正：
--   · 三类渠道 UNION ALL；旧 OTA 渠道配置表的回调地址（loopback_address）为对接配置、target_id 无业务含义，不进维度；stat_date 与分区重复不保留
-- ================================================================================================
-- 置空列：多个源表 UNION ALL 归一时，某源表没有的字段置空（各源表字段对照见各分支）
INSERT OVERWRITE TABLE dim.dim_trf_channel_f                                      -- 整表覆盖写入
-- (1) ods_opr_channel_df
SELECT
    'ORDER_CHANNEL'                                              AS channel_type,  -- 渠道类型
    CAST(order_channel_id AS STRING)                             AS channel_code,  -- 渠道编码
    channel_name,                                                                 -- 渠道名称
    IF(is_line_off = 1, '线下', '线上')                              AS channel_aggregation_name,  -- 渠道大类
    CAST(order_channel_id AS BIGINT)                             AS order_channel_id,  -- 订单表渠道ID（下单渠道）
    CAST(track_source_id AS BIGINT)                              AS track_source_id,  -- 轨迹表来源ID
    CAST(is_line_off AS INT)                                     AS is_line_off,  -- 0-线上 1-线下
    CAST(is_group AS INT)                                        AS is_group,     -- 是否组
    CAST(NULL AS BIGINT)                                         AS member_id,    -- 分销系统对应的平台账号ID：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS account,      -- 分销系统对应的平台账号：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS rule_code,    -- 识别规则：此源表无此字段，置空
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time           -- ETL 加载时间
FROM ods.ods_opr_channel_df
WHERE travel_date = '${bizdate}'                                                  -- 只取当日分区
UNION ALL
-- (2) ods_opr_distribute_system_type_df
SELECT
    'DISTRIBUTE_SYSTEM'                                          AS channel_type,  -- 渠道类型
    distribute_system_type                                       AS channel_code,  -- 渠道编码
    distribute_system_name                                       AS channel_name,  -- 渠道名称
    '第三方分销'                                                      AS channel_aggregation_name,  -- 渠道大类
    CAST(NULL AS BIGINT)                                         AS order_channel_id,  -- 订单表渠道ID（下单渠道）：此源表无此字段，置空
    CAST(NULL AS BIGINT)                                         AS track_source_id,  -- 轨迹表来源ID：此源表无此字段，置空
    CAST(NULL AS INT)                                            AS is_line_off,  -- 0-线上 1-线下：此源表无此字段，置空
    CAST(NULL AS INT)                                            AS is_group,     -- 是否组：此源表无此字段，置空
    CAST(user_id AS BIGINT)                                      AS member_id,    -- 分销系统对应的平台账号ID
    account,                                                                      -- 分销系统对应的平台账号
    dcodeurl_like                                                AS rule_code,    -- 识别规则
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time           -- ETL 加载时间
FROM ods.ods_opr_distribute_system_type_df
WHERE travel_date = '${bizdate}'                                                  -- 只取当日分区
UNION ALL
-- (3) ods_opr_third_purchase_system_df
SELECT
    'PURCHASE_SYSTEM'                                            AS channel_type,  -- 渠道类型
    CAST(coopb AS STRING)                                        AS channel_code,  -- 渠道编码
    system_name                                                  AS channel_name,  -- 渠道名称
    '第三方采购'                                                      AS channel_aggregation_name,  -- 渠道大类
    CAST(NULL AS BIGINT)                                         AS order_channel_id,  -- 订单表渠道ID（下单渠道）：此源表无此字段，置空
    CAST(NULL AS BIGINT)                                         AS track_source_id,  -- 轨迹表来源ID：此源表无此字段，置空
    CAST(NULL AS INT)                                            AS is_line_off,  -- 0-线上 1-线下：此源表无此字段，置空
    CAST(NULL AS INT)                                            AS is_group,     -- 是否组：此源表无此字段，置空
    CAST(NULL AS BIGINT)                                         AS member_id,    -- 分销系统对应的平台账号ID：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS account,      -- 分销系统对应的平台账号：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS rule_code,    -- 识别规则：此源表无此字段，置空
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time           -- ETL 加载时间
FROM ods.ods_opr_third_purchase_system_df
WHERE travel_date = '${bizdate}'                                                  -- 只取当日分区
