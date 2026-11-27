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
-- 置空列：多个源表 UNION ALL 归一时，某源表没有的字段置空（各源表字段对照见各分支）
INSERT OVERWRITE TABLE dim.dim_mkt_activity_df                                    -- 整表覆盖写入
-- (1) ods_mkt_seckill_v2_df
SELECT
    'SECKILL'                                                    AS activity_type,  -- 活动类型
    CAST(id AS BIGINT)                                           AS activity_record_id,  -- 活动ID
    CAST(activity_id AS BIGINT)                                  AS main_activity_id,  -- 营销主活动ID
    activity_name,                                                                -- 活动名称
    CAST(sid AS BIGINT)                                          AS supplier_id,  -- 供应商ID（租户ID）
    CAST(NULL AS BIGINT)                                         AS parent_supplier_id,  -- 产品上级供应商ID（租户ID）：此源表无此字段，置空
    CAST(NULL AS BIGINT)                                         AS scenic_id,    -- 景区ID：此源表无此字段，置空
    CAST(NULL AS BIGINT)                                         AS ticket_id,    -- 票ID：此源表无此字段，置空
    CAST(NULL AS BIGINT)                                         AS product_id,   -- 产品ID：此源表无此字段，置空
    CAST(price AS DECIMAL(18,2)) / 100                           AS activity_price_amt,  -- 活动价（元）
    CAST(storage AS BIGINT)                                      AS storage_qty,  -- 活动库存
    CAST(quantity_sold AS BIGINT)                                AS sold_qty,     -- 已售数量（快照）
    FROM_UNIXTIME(`begin`)                                       AS begin_time,   -- 活动开始时间
    FROM_UNIXTIME(`end`)                                         AS end_time,     -- 活动结束时间
    IF(status = 1, 1, 0)                                         AS valid_flag,   -- 是否有效（未删除）
    FROM_UNIXTIME(create_time)                                   AS create_time,  -- 创建时间
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time           -- ETL 加载时间
FROM ods.ods_mkt_seckill_v2_df
WHERE travel_date = '${bizdate}'                                                  -- 只取当日分区
UNION ALL
-- (2) ods_mkt_group_booking_df
SELECT
    'GROUP_BOOKING'                                              AS activity_type,  -- 活动类型
    CAST(id AS BIGINT)                                           AS activity_record_id,  -- 活动ID
    CAST(activity_id AS BIGINT)                                  AS main_activity_id,  -- 营销主活动ID
    CAST(NULL AS STRING)                                         AS activity_name,  -- 活动名称：此源表无此字段，置空
    CAST(sid AS BIGINT)                                          AS supplier_id,  -- 供应商ID（租户ID）
    CAST(aid AS BIGINT)                                          AS parent_supplier_id,  -- 产品上级供应商ID（租户ID）
    CAST(lid AS BIGINT)                                          AS scenic_id,    -- 景区ID
    CAST(tid AS BIGINT)                                          AS ticket_id,    -- 票ID
    CAST(NULL AS BIGINT)                                         AS product_id,   -- 产品ID：此源表无此字段，置空
    CAST(price AS DECIMAL(18,2)) / 100                           AS activity_price_amt,  -- 活动价（元）
    CAST(storage AS BIGINT)                                      AS storage_qty,  -- 活动库存
    CAST(sold_num AS BIGINT)                                     AS sold_qty,     -- 已售数量（快照）
    FROM_UNIXTIME(`begin`)                                       AS begin_time,   -- 活动开始时间
    FROM_UNIXTIME(`end`)                                         AS end_time,     -- 活动结束时间
    IF(status = 1, 1, 0)                                         AS valid_flag,   -- 是否有效（未删除）
    FROM_UNIXTIME(create_time)                                   AS create_time,  -- 创建时间
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time           -- ETL 加载时间
FROM ods.ods_mkt_group_booking_df
WHERE travel_date = '${bizdate}'                                                  -- 只取当日分区
UNION ALL
-- (3) ods_mkt_cut_price_df
SELECT
    'CUT_PRICE'                                                  AS activity_type,  -- 活动类型
    CAST(id AS BIGINT)                                           AS activity_record_id,  -- 活动ID
    CAST(NULL AS BIGINT)                                         AS main_activity_id,  -- 营销主活动ID：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS activity_name,  -- 活动名称：此源表无此字段，置空
    CAST(sid AS BIGINT)                                          AS supplier_id,  -- 供应商ID（租户ID）
    CAST(aid AS BIGINT)                                          AS parent_supplier_id,  -- 产品上级供应商ID（租户ID）
    CAST(NULL AS BIGINT)                                         AS scenic_id,    -- 景区ID：此源表无此字段，置空
    CAST(NULL AS BIGINT)                                         AS ticket_id,    -- 票ID：此源表无此字段，置空
    CAST(pid AS BIGINT)                                          AS product_id,   -- 产品ID
    CAST(price AS DECIMAL(18,2)) / 100                           AS activity_price_amt,  -- 活动价（元）
    CAST(storage AS BIGINT)                                      AS storage_qty,  -- 活动库存
    CAST(quantity_sold AS BIGINT)                                AS sold_qty,     -- 已售数量（快照）
    FROM_UNIXTIME(`begin`)                                       AS begin_time,   -- 活动开始时间
    FROM_UNIXTIME(`end`)                                         AS end_time,     -- 活动结束时间
    IF(status = 0, 1, 0)                                         AS valid_flag,   -- 是否有效（未删除）
    FROM_UNIXTIME(create_time)                                   AS create_time,  -- 创建时间
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time           -- ETL 加载时间
FROM ods.ods_mkt_cut_price_df
WHERE travel_date = '${bizdate}'                                                  -- 只取当日分区
