-- ================================================================================================
-- dim.dim_trf_channel_f  渠道码表
-- 粒度：1行=1个下单渠道 / 分销平台
-- 分区：无分区
-- 调度：每日，ODS 全部完成后；维表之间按上游顺序
-- 上游：ods_opr_channel_df、ods_opr_distribute_system_type_df、ods_opr_third_purchase_system_df
-- 替代旧任务 1 个（上线对数一致后下线）：
--   · 数据中台/数据维度(DIM)/dim_其他/dim_channel_d_f（EMR_SPARK_SQL，cron 00 16 00 * * ?）
-- 业务规则 / 修正：
--   · 下单渠道码表；对接分销平台（OTA / API）见 dim_sup_member_df.distribute_system_code
-- ================================================================================================
INSERT OVERWRITE TABLE dim.dim_trf_channel_f                                      -- 整表覆盖写入
SELECT
    channel_name,                                                                 -- 一级渠道名称
    CAST(order_channel_id AS STRING)                             AS channel_code,  -- 渠道编码
    CAST(NULL AS STRING)                                         AS stat_date,    -- 统计日期｜待确认：来源未同步（旧字段 dim_channel_d_f.stat_date）
    CAST(order_channel_id AS BIGINT)                             AS order_channel_id,  -- 订单渠道ID
    CAST(track_source_id AS BIGINT)                              AS track_source_id,  -- 轨迹来源ID
    is_line_off,                                                                  -- 是否线路下
    CAST(is_group AS BIGINT)                                     AS is_group,     -- 是否组
    CAST(NULL AS STRING)                                         AS member_id,    -- 游客ID｜待确认：来源未同步（旧字段 dim_trf_ota_channel_f.member_id）
    CAST(NULL AS STRING)                                         AS loopback_address_mask,  -- loopback地址（掩码）（待确认）｜待确认：来源未同步（旧字段 dim_trf_ota_channel_f.loopback_address）
    CAST(NULL AS STRING)                                         AS channel_aggregation_name,  -- 渠道aggregation名称（待确认）｜冗余维度属性：查询时关联维表，建议从明细移除
    CAST(NULL AS STRING)                                         AS target_id,    -- 目标ID｜待确认：来源未同步（旧字段 dim_trf_ota_channel_f.target_id）
    CAST(NULL AS STRING)                                         AS rule_code,    -- 规则编码｜待确认：来源未同步（旧字段 dim_trf_ota_channel_f.rule_code）
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time           -- ETL 加载时间
FROM ods.ods_opr_channel_df
WHERE travel_date = '${bizdate}'                                                  -- 只取当日分区
