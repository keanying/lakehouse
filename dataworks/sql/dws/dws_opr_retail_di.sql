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
--   · 来源：retail = dwd.dwd_opr_retail_order_di（零售订单（3 系统已在 DWD 归一））
-- ================================================================================================
INSERT OVERWRITE TABLE dws.dws_opr_retail_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
    scenic_id,                                                                    -- 景区ID
    shop_code,                                                                    -- 门店编码
    retail_vendor,                                                                -- 零售系统
    goods_code,                                                                   -- 商品编码
    pay_mode,                                                                     -- 支付方式编码
    SUM(retail_order_qty)                                        AS retail_order_qty,  -- 零售单数
    SUM(retail_item_qty)                                         AS retail_item_qty,  -- 零售件数
    SUM(retail_sale_amt)                                         AS retail_sale_amt,  -- 零售销售额
    SUM(retail_refund_amt)                                       AS retail_refund_amt,  -- 零售退款额
    SUM(retail_pay_amt)                                          AS retail_pay_amt,  -- 零售实付金额
    SUM(retail_discount_amt)                                     AS retail_discount_amt,  -- 零售优惠金额
    SUM(retail_refund_item_qty)                                  AS retail_refund_item_qty,  -- 零售退货件数
    SUM(retail_customer_qty)                                     AS retail_customer_qty,  -- 零售客流人数
    SUM(retail_profit_amt)                                       AS retail_profit_amt,  -- 零售利润金额
    SUM(retail_refund_profit_amt)                                AS retail_refund_profit_amt,  -- 零售退货利润金额
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time           -- ETL 加载时间
FROM (
    -- retail：零售订单（3 系统已在 DWD 归一）
    SELECT
        CAST(-1 AS BIGINT)                                           AS scenic_id,  -- 景区ID｜该来源无此维度，取默认值
        shop_code,                                                                -- 门店编码
        retail_vendor,                                                            -- 零售系统
        goods_code,                                                               -- 商品编码
        CAST(-1 AS INT)                                              AS pay_mode,  -- 支付方式编码｜该来源无此维度，取默认值
        COUNT(DISTINCT IF(refund_flag = 0, order_no, NULL))          AS retail_order_qty,  -- 零售单数
        SUM(IF(refund_flag = 0, COALESCE(item_qty, 0), 0))           AS retail_item_qty,  -- 零售件数
        SUM(IF(refund_flag = 0, sale_amt, 0))                        AS retail_sale_amt,  -- 零售销售额
        SUM(IF(refund_flag = 1, sale_amt, 0))                        AS retail_refund_amt,  -- 零售退款额
        SUM(IF(refund_flag = 0, COALESCE(pay_amt, sale_amt), 0))     AS retail_pay_amt,  -- 零售实付金额
        SUM(IF(refund_flag = 0, sale_amt - COALESCE(pay_amt, sale_amt), 0)) AS retail_discount_amt,  -- 零售优惠金额
        SUM(IF(refund_flag = 1, COALESCE(item_qty, 0), 0))           AS retail_refund_item_qty,  -- 零售退货件数
        SUM(IF(refund_flag = 0, COALESCE(number_of_people, 0), 0))   AS retail_customer_qty,  -- 零售客流人数
        SUM(IF(refund_flag = 0, COALESCE(profit_amt, 0), 0))         AS retail_profit_amt,  -- 零售利润金额
        SUM(IF(refund_flag = 1, COALESCE(profit_amt, 0), 0))         AS retail_refund_profit_amt  -- 零售退货利润金额
    FROM dwd.dwd_opr_retail_order_di
    WHERE travel_date = '${bizdate}'                                              -- 只取当日分区
    GROUP BY shop_code, retail_vendor, goods_code                                 -- 按粒度键汇总
) u                                                                               -- 各来源合并后的明细
GROUP BY scenic_id, shop_code, retail_vendor, goods_code, pay_mode                -- 按粒度键汇总
