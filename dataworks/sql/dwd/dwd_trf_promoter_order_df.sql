-- ================================================================================================
-- dwd.dwd_trf_promoter_order_df  全民分销推广订单
-- 粒度：1行=1张推广 / 分销订单（当日最新状态）
-- 分区：travel_date（YYYYMMDD）
-- 调度：每日，依赖上游 ODS 当日分区与相关维表
-- 上游：ods_trf_all_dis_orders_df、ods_trf_distribute_order_df
-- 替代旧任务 1 个（上线对数一致后下线）：
--   · 业务工厂/商户数据中心/DWD/dwd_all_dis_orders_d_f（EMR_SPARK_SQL，cron 00 00 03 * * ?）
-- 业务规则 / 修正：
--   · 两套推广订单字段不同，按业务含义对齐后 UNION ALL；推广订单有佣金发放状态变化，存全量快照
--   · 待确认：distribute_order.real_pay_money 为字符串，单位按分处理，上线前核对
-- ================================================================================================
INSERT OVERWRITE TABLE dwd.dwd_trf_promoter_order_df PARTITION (travel_date = '${bizdate}')
-- (1) ods_trf_all_dis_orders_df
SELECT
    'ALL_DIS'                                                    AS promote_source,
    CAST(id AS BIGINT)                                           AS promote_order_id,
    order_id                                                     AS order_no,
    CAST(sid AS BIGINT)                                          AS supplier_id,
    CAST(NULL AS BIGINT)                                         AS scenic_id,
    CAST(NULL AS BIGINT)                                         AS ticket_id,
    CAST(pid AS BIGINT)                                          AS product_id,
    CAST(dis_id AS BIGINT)                                       AS promoter_id,
    CAST(member_id AS BIGINT)                                    AS buyer_member_id,
    CAST(all_dis_type AS INT)                                    AS promote_type,
    CAST(is_self AS INT)                                         AS self_buy_flag,
    CAST(tnum AS BIGINT)                                         AS ticket_qty,
    CAST(total_money AS DECIMAL(18,2)) / 100                     AS order_amt,
    CAST(develop_money AS DECIMAL(18,2)) / 100 + CAST(recommend_money AS DECIMAL(18,2)) / 100 AS commission_amt,
    CAST(profit AS DECIMAL(18,2)) / 100                          AS profit_amt,
    CAST(order_status AS STRING)                                 AS order_status,
    CAST(last_status AS STRING)                                  AS commission_status,
    0                                                            AS delete_flag,
    FROM_UNIXTIME(create_time)                                   AS order_time,
    FROM_UNIXTIME(complete_time)                                 AS settle_time,
    CAST(NULL AS STRING)                                         AS verify_time,
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time
FROM ods.ods_trf_all_dis_orders_df
WHERE travel_date = '${bizdate}'
UNION ALL
-- (2) ods_trf_distribute_order_df
SELECT
    'DISTRIBUTE'                                                 AS promote_source,
    CAST(id AS BIGINT)                                           AS promote_order_id,
    order_num                                                    AS order_no,
    CAST(sid AS BIGINT)                                          AS supplier_id,
    CAST(land_id AS BIGINT)                                      AS scenic_id,
    CAST(ticket_id AS BIGINT)                                    AS ticket_id,
    CAST(NULL AS BIGINT)                                         AS product_id,
    CAST(seller_id AS BIGINT)                                    AS promoter_id,
    CAST(order_member_id AS BIGINT)                              AS buyer_member_id,
    CAST(NULL AS INT)                                            AS promote_type,
    CAST(NULL AS INT)                                            AS self_buy_flag,
    CAST(ticket_num AS BIGINT)                                   AS ticket_qty,
    CAST(real_pay_money AS DECIMAL(18,2)) / 100                  AS order_amt,
    CAST(total_reward AS DECIMAL(18,2)) / 100                    AS commission_amt,
    CAST(NULL AS DECIMAL(18,2))                                  AS profit_amt,
    order_status,
    reward_status                                                AS commission_status,
    CAST(is_delete AS INT)                                       AS delete_flag,
    order_time,
    settle_time,
    write_off_time                                               AS verify_time,
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time
FROM ods.ods_trf_distribute_order_df
WHERE travel_date = '${bizdate}'
