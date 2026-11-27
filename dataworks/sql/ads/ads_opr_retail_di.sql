-- ================================================================================================
-- ads.ads_opr_retail_di  二消零售经营
-- 粒度：1行=1天×景区×门店×商品×支付方式
-- 分区：travel_date（YYYYMMDD）
-- 调度：每日，依赖上游 DWS 当日分区；完成后回流 / 服务层读取
-- 上游：dws_opr_retail_di
-- 替代旧任务 15 个（上线对数一致后下线）：
--   · 业务工厂/业态通/二次消费/思讯零售/思迅零售汇总工作流/ads_daily_retail_sixun_product_d_i（EMR_SPARK_SQL，cron 00 14 00 * * ?）
--   · 业务工厂/业态通/二次消费/思讯零售/思迅零售汇总工作流/ads_daily_retail_sixun_summary_d_i（EMR_SPARK_SQL，cron 00 14 00 * * ?）
--   · 业务工厂/业态通/二次消费/银豹零售/银豹零售汇总工作流/ads_daily_retail_yinbao_pay_channel_d_i（SERVERLESS_SPARK_SQL，cron 00 00 00 * * ?）
--   · 业务工厂/业态通/二次消费/银豹零售/银豹零售汇总工作流/ads_daily_retail_yinbao_product_d_i（SERVERLESS_SPARK_SQL，cron 00 00 00 * * ?）
--   · 业务工厂/业态通/二次消费/银豹零售/银豹零售汇总工作流/ads_daily_retail_yinbao_summary_d_i（SERVERLESS_SPARK_SQL，cron 00 00 00 * * ?）
--   · 业务工厂/业态通/二次消费/思讯零售/思迅零售汇总工作流/ads_monthly_retail_sixun_product_d_i（EMR_SPARK_SQL，cron 00 14 00 * * ?）
--   · 业务工厂/业态通/二次消费/思讯零售/思迅零售汇总工作流/ads_monthly_retail_sixun_summary_d_i（EMR_SPARK_SQL，cron 00 14 00 * * ?）
--   · 业务工厂/业态通/二次消费/银豹零售/银豹零售汇总工作流/ads_monthly_retail_yinbao_pay_channel_d_i（SERVERLESS_SPARK_SQL，cron 00 00 00 * * ?）
--   · 业务工厂/业态通/二次消费/银豹零售/银豹零售汇总工作流/ads_monthly_retail_yinbao_product_d_i（SERVERLESS_SPARK_SQL，cron 00 00 00 * * ?）
--   · 业务工厂/业态通/二次消费/银豹零售/银豹零售汇总工作流/ads_monthly_retail_yinbao_summary_d_i（SERVERLESS_SPARK_SQL，cron 00 00 00 * * ?）
--   · 业务工厂/业态通/二次消费/思讯零售/思迅零售汇总工作流/ads_yearly_retail_sixun_product_d_i（EMR_SPARK_SQL，cron 00 14 00 * * ?）
--   · 业务工厂/业态通/二次消费/思讯零售/思迅零售汇总工作流/ads_yearly_retail_sixun_summary_d_i（EMR_SPARK_SQL，cron 00 14 00 * * ?）
--   · … 另 3 个
-- 性能：
--   · ADS 只存日粒度：周 / 月 / 年 / 节假日 / 自定义区间与同比环比在查询时关联 dim_opr_period_f（见「指标口径 · ADS 业务指标」）
--   · 比率类不落比率值，只存分子分母；去重类存位图；快照类取日终值
-- ================================================================================================
INSERT OVERWRITE TABLE ads.ads_opr_retail_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
    scenic_id,                                                                    -- 景区ID
    shop_code,                                                                    -- 门店编码
    goods_code,                                                                   -- 商品编码
    pay_mode,                                                                     -- 支付方式编码
    SUM(retail_order_qty)                                        AS retail_order_qty,  -- 零售单数（日）
    SUM(retail_item_qty)                                         AS retail_item_qty,  -- 零售件数（日）
    SUM(retail_sale_amt)                                         AS retail_sale_amt,  -- 零售销售额（日）
    SUM(retail_refund_amt)                                       AS retail_refund_amt,  -- 零售退款额（日）
    SUM(retail_pay_amt)                                          AS retail_pay_amt,  -- 零售实付金额（日）
    SUM(retail_discount_amt)                                     AS retail_discount_amt,  -- 零售优惠金额（日）
    SUM(retail_refund_item_qty)                                  AS retail_refund_item_qty,  -- 零售退货件数（日）
    SUM(retail_customer_qty)                                     AS retail_customer_qty,  -- 零售客流人数（日）
    SUM(retail_profit_amt)                                       AS retail_profit_amt,  -- 零售利润金额（日）
    SUM(retail_refund_profit_amt)                                AS retail_refund_profit_amt,  -- 零售退货利润金额（日）
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time           -- ETL 加载时间
FROM (
    -- dws_opr_retail_di
    SELECT
        scenic_id,                                                                -- 景区ID
        shop_code,                                                                -- 门店编码
        goods_code,                                                               -- 商品编码
        pay_mode,                                                                 -- 支付方式编码
        SUM(retail_order_qty)                                        AS retail_order_qty,  -- 零售单数（日）
        SUM(retail_item_qty)                                         AS retail_item_qty,  -- 零售件数（日）
        SUM(retail_sale_amt)                                         AS retail_sale_amt,  -- 零售销售额（日）
        SUM(retail_refund_amt)                                       AS retail_refund_amt,  -- 零售退款额（日）
        SUM(retail_pay_amt)                                          AS retail_pay_amt,  -- 零售实付金额（日）
        SUM(retail_discount_amt)                                     AS retail_discount_amt,  -- 零售优惠金额（日）
        SUM(retail_refund_item_qty)                                  AS retail_refund_item_qty,  -- 零售退货件数（日）
        SUM(retail_customer_qty)                                     AS retail_customer_qty,  -- 零售客流人数（日）
        SUM(retail_profit_amt)                                       AS retail_profit_amt,  -- 零售利润金额（日）
        SUM(retail_refund_profit_amt)                                AS retail_refund_profit_amt  -- 零售退货利润金额（日）
    FROM dws.dws_opr_retail_di
    WHERE travel_date = '${bizdate}'                                              -- 只取当日分区
    GROUP BY scenic_id, shop_code, goods_code, pay_mode                           -- 按粒度键汇总
) u                                                                               -- 各来源合并后的明细
GROUP BY scenic_id, shop_code, goods_code, pay_mode                               -- 按粒度键汇总
