-- ================================================================================================
-- dim.dim_prd_ticket_df  票维度
-- 粒度：1行=1张票（tid）
-- 分区：无分区
-- 调度：每日，ODS 全部完成后；维表之间按上游顺序
-- 上游：ods_prd_ticket_df、ods_prd_package_tickets_df、dim_prd_scenic_df
-- 替代旧任务 4 个（上线对数一致后下线）：
--   · 数据中台/数据维度(DIM)/dim_商品域/dim_prod_d_f（EMR_SPARK_SQL，cron 00 30 00 * * ?）
--   · 数据平台/DIM/dim_attr_ticket_info_df（SERVERLESS_SPARK_SQL，cron 00 25 00 * * ?）
--   · 数据平台/DIM/dim_attr_product_info_df（SERVERLESS_SPARK_SQL，cron 00 25 00 * * ?）
--   · 数据平台/ADS/数据集成_导入/数字大脑_数据同步/sync_dim_prd_scenic_supplier_relation_f_from_mysql（DI，cron 00 05 00 * * ?）
-- 业务规则 / 修正：
--   · 替代 dim_prod_d_f、dim_attr_ticket_info_df 等；套票角色原来在 6 个下游脚本里各自用 pft_package_tickets 判断
-- 性能：
--   · 套票关系先聚合成「票 → 角色」一行一票，再关联
-- ================================================================================================
WITH ticket AS (
    SELECT CAST(id AS BIGINT) AS ticket_id, title, CAST(pid AS BIGINT) AS product_id, CAST(landid AS BIGINT) AS scenic_id,
           CAST(apply_did AS BIGINT) AS supplier_id, CAST(gid AS BIGINT) AS goods_id, tprice, status, delaydays, max_expiration_date,
           order_start, order_end, buy_limit_low, buy_limit_up, refund_rule, refund_audit, update_time
    FROM ods.ods_prd_ticket_df
    WHERE travel_date = '${bizdate}'
),
package_role AS (   -- 1 = 套票主票（作为 parent_tid 出现），2 = 套票子票；同时出现按主票
    SELECT ticket_id, MIN(role) AS package_role
    FROM (
        SELECT CAST(parent_tid AS BIGINT) AS ticket_id, 1 AS role FROM ods.ods_prd_package_tickets_df WHERE travel_date = '${bizdate}'
        UNION ALL
        SELECT CAST(tid AS BIGINT), 2 FROM ods.ods_prd_package_tickets_df WHERE travel_date = '${bizdate}'
    ) t
    GROUP BY ticket_id
)
INSERT OVERWRITE TABLE dim.dim_prd_ticket_df
SELECT /*+ BROADCAST(pr) */
    t.ticket_id,
    t.title                                                          AS ticket_name,
    CONCAT_WS('-', s.scenic_name, t.title)                           AS ticket_full_name,
    t.product_id,
    t.scenic_id,
    t.supplier_id,
    t.goods_id,
    CAST(t.tprice AS DECIMAL(18,2)) / 100                            AS market_price_amt,     -- 分 → 元
    t.status                                                         AS ticket_status,        -- 1-上架 2-下架 6-删除
    COALESCE(pr.package_role, 0)                                     AS package_role,
    CAST(t.delaydays AS INT)                                         AS valid_day_qty,
    t.max_expiration_date,
    t.order_start                                                    AS order_start_time,
    t.order_end                                                      AS order_end_time,
    CAST(t.buy_limit_low AS INT)                                     AS buy_limit_low_qty,
    CAST(t.buy_limit_up AS INT)                                      AS buy_limit_up_qty,
    t.refund_rule,
    CAST(t.refund_audit AS INT)                                      AS refund_audit_flag,
    FROM_UNIXTIME(CAST(t.update_time AS BIGINT))                     AS update_time,
    IF(t.title LIKE '%测试%' OR s.test_flag = 1, 1, 0)               AS test_flag,
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time
FROM ticket t
LEFT JOIN (SELECT scenic_id, scenic_name, test_flag FROM dim.dim_prd_scenic_df) s ON s.scenic_id = t.scenic_id
LEFT JOIN package_role pr ON pr.ticket_id = t.ticket_id
