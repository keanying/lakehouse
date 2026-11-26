-- ================================================================================================
-- dws.dws_opr_retail_di  零售日汇总
-- 粒度：1行=1天×景区×门店×零售系统×商品×支付方式
-- 分区：travel_date（YYYYMMDD）
-- 调度：每日，依赖上游 DWD 当日分区
-- 上游：dwd_opr_retail_order_di
-- 替代旧任务 6 个（上线对数一致后下线）：
--   · 数据平台/平台湖仓工作流/小岛零售/dws_prd_xisland_retail_summary_di（SERVERLESS_SPARK_SQL，cron 00 30 06 * * ?）
--   · 数据平台/平台湖仓工作流/小岛零售/dws_prd_xisland_retail_summary_mo（SERVERLESS_SPARK_SQL，cron 00 30 06 * * ?）
--   · 数据平台/平台湖仓工作流/小岛零售/dws_prd_xisland_retail_summary_yr（SERVERLESS_SPARK_SQL，cron 00 30 06 * * ?）
--   · 数据平台/平台湖仓工作流/小岛零售/dws_sup_xisland_retail_summary_di（SERVERLESS_SPARK_SQL，cron 00 30 06 * * ?）
--   · 数据平台/平台湖仓工作流/小岛零售/dws_sup_xisland_retail_summary_mo（SERVERLESS_SPARK_SQL，cron 00 30 06 * * ?）
--   · 数据平台/平台湖仓工作流/小岛零售/dws_sup_xisland_retail_summary_yr（SERVERLESS_SPARK_SQL，cron 00 30 06 * * ?）
-- 性能：
--   · 同一来源的指标在一个子查询里预聚合（一次扫描），各来源 UNION ALL 后按粒度汇总，不做明细级 JOIN
--   · 待确认（无来源）：cancel_profit_amt、order_profit_amt
--   · 来源：retail = dwd.dwd_opr_retail_order_di（零售订单（3 系统已在 DWD 归一））
-- ================================================================================================
INSERT OVERWRITE TABLE dws.dws_opr_retail_di PARTITION (travel_date = '${bizdate}')
SELECT
    scenic_id,
    shop_code,
    retail_vendor,
    goods_code,
    pay_mode,
    SUM(retail_order_qty)                                        AS retail_order_qty,
    SUM(retail_item_qty)                                         AS retail_item_qty,
    SUM(retail_sale_amt)                                         AS retail_sale_amt,
    SUM(retail_refund_amt)                                       AS retail_refund_amt,
    CAST(NULL AS DECIMAL(18,2))                                  AS cancel_profit_amt,   -- 待确认：没有可用来源
    CAST(NULL AS DECIMAL(18,2))                                  AS order_profit_amt,   -- 待确认：没有可用来源
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time
FROM (
    -- retail：零售订单（3 系统已在 DWD 归一）
    SELECT
        CAST(-1 AS BIGINT)                                           AS scenic_id,   -- 该来源无此维度，取默认值
        shop_code,
        retail_vendor,
        goods_code,
        CAST(-1 AS INT)                                              AS pay_mode,   -- 该来源无此维度，取默认值
        COUNT(DISTINCT IF(refund_flag = 0, order_no, NULL))          AS retail_order_qty,
        SUM(IF(refund_flag = 0, COALESCE(item_qty, 0), 0))           AS retail_item_qty,
        SUM(IF(refund_flag = 0, sale_amt, 0))                        AS retail_sale_amt,
        SUM(IF(refund_flag = 1, sale_amt, 0))                        AS retail_refund_amt,
        CAST(0 AS DECIMAL(18,2))                                     AS cancel_profit_amt,
        CAST(0 AS DECIMAL(18,2))                                     AS order_profit_amt
    FROM dwd.dwd_opr_retail_order_di
    WHERE travel_date = '${bizdate}'
    GROUP BY shop_code, retail_vendor, goods_code
) u
GROUP BY scenic_id, shop_code, retail_vendor, goods_code, pay_mode
