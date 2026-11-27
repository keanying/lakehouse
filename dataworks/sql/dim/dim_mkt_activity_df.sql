-- ================================================================================================
-- dim.dim_mkt_activity_df  营销活动维度
-- 粒度：1行=1个营销活动（抢购 / 拼团 / 砍价）
-- 分区：无分区
-- 调度：每日，ODS 全部完成后；维表之间按上游顺序
-- 上游：ods_mkt_seckill_v2_df、ods_mkt_group_booking_df、ods_mkt_cut_price_df
-- 业务规则 / 修正：
--   · 三类活动表状态码相反（抢购 0 删 1 正常；拼团 1 正常 2 删；砍价 0 正常 1 删），统一为 valid_flag
--   · 海报 / 物料中心为营销素材配置，未被在用报表使用，保留 ODS 不进维度
-- ================================================================================================
INSERT OVERWRITE TABLE dim.dim_mkt_activity_df
-- (1) ods_mkt_seckill_v2_df
SELECT
    'SECKILL'                                                    AS activity_type,
    CAST(id AS BIGINT)                                           AS activity_record_id,
    CAST(activity_id AS BIGINT)                                  AS main_activity_id,
    activity_name,
    CAST(sid AS BIGINT)                                          AS supplier_id,
    CAST(NULL AS BIGINT)                                         AS parent_supplier_id,
    CAST(NULL AS BIGINT)                                         AS scenic_id,
    CAST(NULL AS BIGINT)                                         AS ticket_id,
    CAST(NULL AS BIGINT)                                         AS product_id,
    CAST(price AS DECIMAL(18,2)) / 100                           AS activity_price_amt,
    CAST(storage AS BIGINT)                                      AS storage_qty,
    CAST(quantity_sold AS BIGINT)                                AS sold_qty,
    FROM_UNIXTIME(`begin`)                                       AS begin_time,
    FROM_UNIXTIME(`end`)                                         AS end_time,
    IF(status = 1, 1, 0)                                         AS valid_flag,
    FROM_UNIXTIME(create_time)                                   AS create_time,
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time
FROM ods.ods_mkt_seckill_v2_df
WHERE travel_date = '${bizdate}'
UNION ALL
-- (2) ods_mkt_group_booking_df
SELECT
    'GROUP_BOOKING'                                              AS activity_type,
    CAST(id AS BIGINT)                                           AS activity_record_id,
    CAST(activity_id AS BIGINT)                                  AS main_activity_id,
    CAST(NULL AS STRING)                                         AS activity_name,
    CAST(sid AS BIGINT)                                          AS supplier_id,
    CAST(aid AS BIGINT)                                          AS parent_supplier_id,
    CAST(lid AS BIGINT)                                          AS scenic_id,
    CAST(tid AS BIGINT)                                          AS ticket_id,
    CAST(NULL AS BIGINT)                                         AS product_id,
    CAST(price AS DECIMAL(18,2)) / 100                           AS activity_price_amt,
    CAST(storage AS BIGINT)                                      AS storage_qty,
    CAST(sold_num AS BIGINT)                                     AS sold_qty,
    FROM_UNIXTIME(`begin`)                                       AS begin_time,
    FROM_UNIXTIME(`end`)                                         AS end_time,
    IF(status = 1, 1, 0)                                         AS valid_flag,
    FROM_UNIXTIME(create_time)                                   AS create_time,
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time
FROM ods.ods_mkt_group_booking_df
WHERE travel_date = '${bizdate}'
UNION ALL
-- (3) ods_mkt_cut_price_df
SELECT
    'CUT_PRICE'                                                  AS activity_type,
    CAST(id AS BIGINT)                                           AS activity_record_id,
    CAST(NULL AS BIGINT)                                         AS main_activity_id,
    CAST(NULL AS STRING)                                         AS activity_name,
    CAST(sid AS BIGINT)                                          AS supplier_id,
    CAST(aid AS BIGINT)                                          AS parent_supplier_id,
    CAST(NULL AS BIGINT)                                         AS scenic_id,
    CAST(NULL AS BIGINT)                                         AS ticket_id,
    CAST(pid AS BIGINT)                                          AS product_id,
    CAST(price AS DECIMAL(18,2)) / 100                           AS activity_price_amt,
    CAST(storage AS BIGINT)                                      AS storage_qty,
    CAST(quantity_sold AS BIGINT)                                AS sold_qty,
    FROM_UNIXTIME(`begin`)                                       AS begin_time,
    FROM_UNIXTIME(`end`)                                         AS end_time,
    IF(status = 0, 1, 0)                                         AS valid_flag,
    FROM_UNIXTIME(create_time)                                   AS create_time,
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time
FROM ods.ods_mkt_cut_price_df
WHERE travel_date = '${bizdate}'
