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
-- 置空列：多个源表 UNION ALL 归一时，某源表没有的字段置空（各源表字段对照见各分支）
INSERT OVERWRITE TABLE dwd.dwd_trf_promoter_order_df PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
-- (1) ods_trf_all_dis_orders_df
SELECT
    'ALL_DIS'                                                    AS promote_source,  -- 来源
    CAST(id AS BIGINT)                                           AS promote_order_id,  -- 推广订单记录ID（与来源联合唯一）
    order_id                                                     AS order_no,     -- 平台订单号
    CAST(sid AS BIGINT)                                          AS supplier_id,  -- 供应商ID（租户ID）
    CAST(NULL AS BIGINT)                                         AS scenic_id,    -- 景区ID：此源表无此字段，置空
    CAST(NULL AS BIGINT)                                         AS ticket_id,    -- 票ID：此源表无此字段，置空
    CAST(pid AS BIGINT)                                          AS product_id,   -- 产品ID
    CAST(dis_id AS BIGINT)                                       AS promoter_id,  -- 推广员（一级 / 直推分销员）ID
    CAST(member_id AS BIGINT)                                    AS buyer_member_id,  -- 下单用户ID
    CAST(all_dis_type AS INT)                                    AS promote_type,  -- 全民营销类型
    CAST(is_self AS INT)                                         AS self_buy_flag,  -- 是否自购订单
    CAST(tnum AS BIGINT)                                         AS ticket_qty,   -- 票数
    CAST(total_money AS DECIMAL(18,2)) / 100                     AS order_amt,    -- 订单金额（元）
    CAST(develop_money AS DECIMAL(18,2)) / 100 + CAST(recommend_money AS DECIMAL(18,2)) / 100 AS commission_amt,  -- 佣金（元）
    CAST(profit AS DECIMAL(18,2)) / 100                          AS profit_amt,   -- 订单利润（元）
    CAST(order_status AS STRING)                                 AS order_status,  -- 订单状态
    CAST(last_status AS STRING)                                  AS commission_status,  -- 佣金发放状态
    0                                                            AS delete_flag,  -- 是否删除：此源表无此字段，置空
    FROM_UNIXTIME(create_time)                                   AS order_time,   -- 下单时间
    FROM_UNIXTIME(complete_time)                                 AS settle_time,  -- 佣金发放 / 结算时间
    CAST(NULL AS STRING)                                         AS verify_time,  -- 核销时间：此源表无此字段，置空
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time           -- ETL 加载时间
FROM ods.ods_trf_all_dis_orders_df
WHERE travel_date = '${bizdate}'                                                  -- 只取当日分区
UNION ALL
-- (2) ods_trf_distribute_order_df
SELECT
    'DISTRIBUTE'                                                 AS promote_source,  -- 来源
    CAST(id AS BIGINT)                                           AS promote_order_id,  -- 推广订单记录ID（与来源联合唯一）
    order_num                                                    AS order_no,     -- 平台订单号
    CAST(sid AS BIGINT)                                          AS supplier_id,  -- 供应商ID（租户ID）
    CAST(land_id AS BIGINT)                                      AS scenic_id,    -- 景区ID
    CAST(ticket_id AS BIGINT)                                    AS ticket_id,    -- 票ID
    CAST(NULL AS BIGINT)                                         AS product_id,   -- 产品ID：此源表无此字段，置空
    CAST(seller_id AS BIGINT)                                    AS promoter_id,  -- 推广员（一级 / 直推分销员）ID
    CAST(order_member_id AS BIGINT)                              AS buyer_member_id,  -- 下单用户ID
    CAST(NULL AS INT)                                            AS promote_type,  -- 全民营销类型：此源表无此字段，置空
    CAST(NULL AS INT)                                            AS self_buy_flag,  -- 是否自购订单：此源表无此字段，置空
    CAST(ticket_num AS BIGINT)                                   AS ticket_qty,   -- 票数
    CAST(real_pay_money AS DECIMAL(18,2)) / 100                  AS order_amt,    -- 订单金额（元）
    CAST(total_reward AS DECIMAL(18,2)) / 100                    AS commission_amt,  -- 佣金（元）
    CAST(NULL AS DECIMAL(18,2))                                  AS profit_amt,   -- 订单利润（元）：此源表无此字段，置空
    order_status,                                                                 -- 订单状态
    reward_status                                                AS commission_status,  -- 佣金发放状态
    CAST(is_delete AS INT)                                       AS delete_flag,  -- 是否删除
    order_time,                                                                   -- 下单时间
    settle_time,                                                                  -- 佣金发放 / 结算时间
    write_off_time                                               AS verify_time,  -- 核销时间
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time           -- ETL 加载时间
FROM ods.ods_trf_distribute_order_df
WHERE travel_date = '${bizdate}'                                                  -- 只取当日分区
