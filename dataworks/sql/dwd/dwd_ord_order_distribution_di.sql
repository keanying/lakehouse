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
    SELECT orderid,
           buyerid,
           sellerid,
           level,
           pmode,
           cost_money,
           sale_money,
           id,
           FROM_UNIXTIME(order_time, 'yyyyMMdd') AS order_date
    FROM (SELECT *, ROW_NUMBER() OVER (                                           -- 同一主键多次变更，按 binlog 时间倒序编号
        PARTITION BY orderid,
        sellerid,
        buyerid ORDER BY update_time DESC
    ) AS rn                                                                       -- 去重序号（1 = 最新）
          FROM ods.ods_ord_order_distribution_split_di WHERE travel_date = '${bizdate}') t
    WHERE rn = 1
),
ranked AS (                                                                       -- level：1 / 0 为第一级，2 中间，-1 末级 → 排序键 1 < 2 < -1
    SELECT s.*,
           ROW_NUMBER() OVER (PARTITION BY orderid ORDER BY CASE                  -- 同一主键多次变更，按 binlog 时间倒序编号
               WHEN level IN (0, 1) THEN 0 WHEN level = -1 THEN 2 ELSE 1 END, id) AS distribute_level  -- 分销层级
    FROM s
)
INSERT OVERWRITE TABLE dwd.dwd_ord_order_distribution_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
    r.orderid                                                        AS order_no,  -- 订单号
    r.distribute_level,                                                           -- 分销层级
    r.sellerid                                                       AS seller_id,  -- 本级卖方
    r.buyerid                                                        AS buyer_id,  -- 本级买方
    CAST(r.sale_money AS DECIMAL(18,2)) / 100                        AS price_amt,  -- 本级结算单价（元）
    CAST(r.cost_money AS DECIMAL(18,2)) / 100                        AS cost_price_amt,  -- 本级成本单价（元）
    o.ticket_qty,                                                                 -- 票数
    CAST(r.sale_money * o.ticket_qty AS DECIMAL(18,2)) / 100         AS settle_amt,  -- 本级结算金额（元）
    CAST(r.pmode AS INT)                                             AS pay_mode,  -- 本级支付方式
    o.scenic_id,                                                                  -- 景区ID
    o.ticket_id,                                                                  -- 票ID
    o.order_time,                                                                 -- 下单时间
    COALESCE(o.test_flag, 0)                                         AS test_flag,  -- 是否测试订单
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time           -- ETL 加载时间
FROM ranked r
LEFT JOIN (
    SELECT order_no,                                                              -- 订单号
    travel_date,                                                                  -- 数据日期
    scenic_id,                                                                    -- 景区ID
    ticket_id,                                                                    -- 票ID
    ticket_qty,                                                                   -- 票数
    order_time,                                                                   -- 下单时间
    test_flag FROM dwd.dwd_ord_order_di
) o
       ON o.travel_date = r.order_date AND o.order_no = r.orderid                 -- 按 order_date→travel_date、orderid→order_no 关联｜带下单日分区：动态分区裁剪
