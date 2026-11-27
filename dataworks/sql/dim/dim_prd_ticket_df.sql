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
    SELECT CAST(id AS BIGINT) AS ticket_id,                                       -- 票ID
           title,
           CAST(pid AS BIGINT) AS product_id,                                     -- 产品ID
           CAST(landid AS BIGINT) AS scenic_id,                                   -- 景区ID
           CAST(apply_did AS BIGINT) AS supplier_id,                              -- 供应商ID（租户ID）
           CAST(gid AS BIGINT) AS goods_id,                                       -- 商品ID
           tprice,
           status,
           delaydays,
           max_expiration_date,                                                   -- 最晚有效日期
           order_start, order_end, buy_limit_low, buy_limit_up, refund_rule, refund_audit, update_time
    FROM ods.ods_prd_ticket_df
    WHERE travel_date = '${bizdate}'                                              -- 只取当日分区
),
package_role AS (                                                                 -- 1 = 套票主票（作为 parent_tid 出现），2 = 套票子票；同时出现按主票
    SELECT ticket_id, MIN(role) AS package_role                                   -- 套票角色
    FROM (
        SELECT CAST(parent_tid AS BIGINT) AS ticket_id,                           -- 票ID
               1 AS role FROM ods.ods_prd_package_tickets_df WHERE travel_date = '${bizdate}'
        UNION ALL
        SELECT CAST(tid AS BIGINT), 2 FROM ods.ods_prd_package_tickets_df WHERE travel_date = '${bizdate}'
    ) t
    GROUP BY ticket_id                                                            -- 按粒度键汇总
)
INSERT OVERWRITE TABLE dim.dim_prd_ticket_df                                      -- 整表覆盖写入
SELECT /*+ BROADCAST(pr) */
    t.ticket_id,                                                                  -- 票ID
    t.title                                                          AS ticket_name,  -- 票名称
    CONCAT_WS('-', s.scenic_name, t.title)                           AS ticket_full_name,  -- 票全称 = 景区名称-票名称
    t.product_id,                                                                 -- 产品ID
    t.scenic_id,                                                                  -- 景区ID
    t.supplier_id,                                                                -- 供应商ID（租户ID）
    t.goods_id,                                                                   -- 商品ID
    CAST(t.tprice AS DECIMAL(18,2)) / 100                            AS market_price_amt,  -- 门市价（元）｜分 → 元
    t.status                                                         AS ticket_status,  -- 票状态｜1-上架 2-下架 6-删除
    COALESCE(pr.package_role, 0)                                     AS package_role,  -- 套票角色
    CAST(t.delaydays AS INT)                                         AS valid_day_qty,  -- 购买后有效天数
    t.max_expiration_date,                                                        -- 最晚有效日期
    t.order_start                                                    AS order_start_time,  -- 开售时间
    t.order_end                                                      AS order_end_time,  -- 停售时间
    CAST(t.buy_limit_low AS INT)                                     AS buy_limit_low_qty,  -- 单次最少购买张数
    CAST(t.buy_limit_up AS INT)                                      AS buy_limit_up_qty,  -- 单次最多购买张数
    t.refund_rule,                                                                -- 退票规则
    CAST(t.refund_audit AS INT)                                      AS refund_audit_flag,  -- 退票是否需审核
    FROM_UNIXTIME(CAST(t.update_time AS BIGINT))                     AS update_time,  -- 票最近更新时间
    IF(t.title LIKE '%测试%' OR s.test_flag = 1, 1, 0)               AS test_flag,  -- 是否测试票
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time           -- ETL 加载时间
FROM ticket t
LEFT JOIN (SELECT scenic_id, scenic_name, test_flag FROM dim.dim_prd_scenic_df) s ON s.scenic_id = t.scenic_id
LEFT JOIN package_role pr ON pr.ticket_id = t.ticket_id
