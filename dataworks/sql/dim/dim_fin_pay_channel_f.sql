-- ================================================================================================
-- dim.dim_fin_pay_channel_f  支付方式码表
-- 粒度：1行=1种支付方式
-- 分区：无分区
-- 调度：每日，ODS 全部完成后；维表之间按上游顺序
-- 上游：ods_fin_merchant_payment_method_df
-- 替代旧任务 1 个（上线对数一致后下线）：
--   · 数据中台/数据维度(DIM)/dim_pay_channel_o_f（EMR_SPARK_SQL，cron 00 14 00 * * ?）
-- 业务规则 / 修正：
--   · 支付渠道码表：商户支付方式去重得到渠道清单；待确认：订单 paymode 与 channel_id 的对应关系
-- ================================================================================================
INSERT OVERWRITE TABLE dim.dim_fin_pay_channel_f
SELECT pay_mode, pay_mode_name, pay_channel_id, pay_channel_mapping_id, pay_channel_name, pay_channel_mapping_name, etl_time
FROM (
    SELECT u.*, ROW_NUMBER() OVER (PARTITION BY pay_channel_id ORDER BY pay_channel_id) AS rn
    FROM (
        SELECT
            CAST(channel_id AS STRING)                                   AS pay_mode,
            channel_name                                                 AS pay_mode_name,
            CAST(channel_id AS BIGINT)                                   AS pay_channel_id,
            CAST(NULL AS BIGINT)                                         AS pay_channel_mapping_id,   -- 待确认：来源未同步（旧字段 dim_pay_channel_o_f.pay_channel_mapping_id）
            channel_name                                                 AS pay_channel_name,
            CAST(NULL AS STRING)                                         AS pay_channel_mapping_name,   -- 冗余维度属性：查询时关联维表，建议从明细移除
            DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time
        FROM ods.ods_fin_merchant_payment_method_df
        WHERE travel_date = '${bizdate}'
    ) u
) t
WHERE rn = 1
