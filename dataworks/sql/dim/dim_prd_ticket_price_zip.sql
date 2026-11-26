-- ================================================================================================
-- dim.dim_prd_ticket_price_zip  门票价格拉链
-- 粒度：1行=1张门票×1个价格生效区间
-- 分区：无分区
-- 调度：每日，ODS 全部完成后；维表之间按上游顺序
-- 上游：ods_prd_ticket_price_df
-- 替代旧任务 2 个（上线对数一致后下线）：
--   · 数据中台/数据维度(DIM)/dim_商品域/dim_prod_price_d_f（EMR_SPARK_SQL，cron 00 30 00 * * ?）
--   · 数据平台/DWS/dws_scenic_ticket_price_zipper_di（SERVERLESS_SPARK_SQL，cron 00 26 00 * * ?）
-- 业务规则 / 修正：
--   · 主表 ods.ods_prd_ticket_price_df（同名字段命中最多）；仍无来源的字段标「待确认」
-- ================================================================================================
INSERT OVERWRITE TABLE dim.dim_prd_ticket_price_zip
SELECT
    ticket_id,
    start_date,
    end_date,
    CAST(NULL AS STRING)                                         AS stat_date,   -- 待确认：来源未同步（旧字段 dim_prod_price_d_f.stat_date）
    ptype,
    CAST(NULL AS STRING)                                         AS cost_price,   -- 待确认：来源未同步（旧字段 dim_prod_price_d_f.cost_price）
    CAST(NULL AS STRING)                                         AS sale_price,   -- 待确认：来源未同步（旧字段 dim_prod_price_d_f.sale_price）
    CAST(status AS BIGINT)                                       AS order_status,
    weekdays,
    update_time,
    CAST(NULL AS BIGINT)                                         AS curr_price_rank,   -- 待确认：来源未同步（旧字段 dim_prod_price_d_f.curr_price_rank）
    CAST(NULL AS BIGINT)                                         AS scenic_id,   -- 待确认：来源未同步（旧字段 dws_scenic_ticket_price_zipper_di.scenic_id）
    CAST(NULL AS BIGINT)                                         AS price,   -- 待确认：来源未同步（旧字段 dws_scenic_ticket_price_zipper_di.price）
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time
FROM ods.ods_prd_ticket_price_df
WHERE travel_date = '${bizdate}'
