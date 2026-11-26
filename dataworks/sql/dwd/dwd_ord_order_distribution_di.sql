-- ================================================================================================
-- dwd.dwd_ord_order_distribution_di  订单分销链明细
-- 粒度：1行=1张订单×1级分销
-- 分区：travel_date（YYYYMMDD）
-- 调度：每日，依赖上游 ODS 当日分区与相关维表
-- 上游：ods_ord_order_distribution_split_di、ods_ord_order_distribution_detail_di、dwd_ord_order_di
-- 替代旧任务 7 个（上线对数一致后下线）：
--   · 数据中台/DW/dwd_split_d_i（EMR_SPARK_SQL，cron 00 30 00 * * ?）
--   · 数据中台/DW/dwd_order_split_d_i（EMR_SPARK_SQL，cron 00 00 03 * * ?）
--   · 数据平台/DWD/dwd_ord_split_order_details_di（SERVERLESS_SPARK_SQL，cron 00 25 01 * * ?）
--   · 数据平台/平台湖仓工作流/经营数据/dwd_ord_order_distribute_detail_di（SERVERLESS_SPARK_SQL，cron 00 00 00 * * ?）
--   · 数据平台/平台湖仓工作流/经营数据/dwd_ord_order_distribute_summary_di（SERVERLESS_SPARK_SQL，cron 00 00 00 * * ?）
--   · 数据中台/DW/dwd_order_track_split_d_i（EMR_SPARK_SQL，cron 00 00 02 * * ?）
--   · 数据中台/DW/dws_distribution_aggregation_d_i（EMR_SPARK_SQL，cron 00 00 01 * * ?）
-- 业务规则 / 修正：
--   · 替代 dwd_split_d_i、dwd_order_split_d_i 等 7 张拆单表
--   · 旧「本层具体分销层级」用 4 层嵌套 IF 推算，改为按链上顺序 ROW_NUMBER
-- 性能：
--   · 一次窗口排序得到层级，去掉旧任务对同一张拆单表的 4 次自关联
--   · 关联订单带下单日分区条件（动态分区裁剪）
-- ================================================================================================
WITH s AS (
    SELECT orderid, buyerid, sellerid, level, pmode, cost_money, sale_money, id, FROM_UNIXTIME(order_time, 'yyyyMMdd') AS order_date
    FROM (SELECT *, ROW_NUMBER() OVER (PARTITION BY orderid, sellerid, buyerid ORDER BY update_time DESC) AS rn
          FROM ods.ods_ord_order_distribution_split_di WHERE travel_date = '${bizdate}') t
    WHERE rn = 1
),
ranked AS (   -- level：1 / 0 为第一级，2 中间，-1 末级 → 排序键 1 < 2 < -1
    SELECT s.*, ROW_NUMBER() OVER (PARTITION BY orderid ORDER BY CASE WHEN level IN (0, 1) THEN 0 WHEN level = -1 THEN 2 ELSE 1 END, id) AS distribute_level
    FROM s
)
INSERT OVERWRITE TABLE dwd.dwd_ord_order_distribution_di PARTITION (travel_date = '${bizdate}')
SELECT
    r.orderid                                                        AS order_no,
    r.distribute_level,
    r.sellerid                                                       AS seller_id,
    r.buyerid                                                        AS buyer_id,
    CAST(r.sale_money AS DECIMAL(18,2)) / 100                        AS price_amt,
    CAST(r.cost_money AS DECIMAL(18,2)) / 100                        AS cost_price_amt,
    o.ticket_qty,
    CAST(r.sale_money * o.ticket_qty AS DECIMAL(18,2)) / 100         AS settle_amt,
    CAST(r.pmode AS INT)                                             AS pay_mode,
    o.scenic_id,
    o.ticket_id,
    o.order_time,
    COALESCE(o.test_flag, 0)                                         AS test_flag,
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time
FROM ranked r
LEFT JOIN (SELECT order_no, travel_date, scenic_id, ticket_id, ticket_qty, order_time, test_flag FROM dwd.dwd_ord_order_di) o
       ON o.travel_date = r.order_date AND o.order_no = r.orderid      -- 带下单日分区：动态分区裁剪
