-- ================================================================================================
-- ads.ads_ord_annual_card_di  年卡 / 一卡通经营
-- 粒度：1行=1天×景区×年卡产品
-- 分区：travel_date（YYYYMMDD）
-- 调度：每日，依赖上游 DWS 当日分区；完成后回流 / 服务层读取
-- 上游：dws_ord_annual_card_di
-- 性能：
--   · ADS 只存日粒度：周 / 月 / 年 / 节假日 / 自定义区间与同比环比在查询时关联 dim_opr_period_f（见「指标口径 · ADS 业务指标」）
--   · 比率类不落比率值，只存分子分母；去重类存位图；快照类取日终值
-- ================================================================================================
INSERT OVERWRITE TABLE ads.ads_ord_annual_card_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
    scenic_id,                                                                    -- 景区ID
    card_product_id,                                                              -- 年卡产品ID
    SUM(card_sale_qty)                                           AS card_sale_qty,  -- 年卡售卡数（日）
    SUM(card_sale_amt)                                           AS card_sale_amt,  -- 年卡售卡金额（日）
    SUM(card_active_qty)                                         AS card_active_qty,  -- 年卡激活数（日）
    SUM(card_verify_qty)                                         AS card_verify_qty,  -- 年卡核销次数（日）
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time           -- ETL 加载时间
FROM (
    -- dws_ord_annual_card_di
    SELECT
        scenic_id,                                                                -- 景区ID
        card_product_id,                                                          -- 年卡产品ID
        SUM(card_sale_qty)                                           AS card_sale_qty,  -- 年卡售卡数（日）
        SUM(card_sale_amt)                                           AS card_sale_amt,  -- 年卡售卡金额（日）
        SUM(card_active_qty)                                         AS card_active_qty,  -- 年卡激活数（日）
        SUM(card_verify_qty)                                         AS card_verify_qty  -- 年卡核销次数（日）
    FROM dws.dws_ord_annual_card_di
    WHERE travel_date = '${bizdate}'                                              -- 只取当日分区
    GROUP BY scenic_id, card_product_id                                           -- 按粒度键汇总
) u                                                                               -- 各来源合并后的明细
GROUP BY scenic_id, card_product_id                                               -- 按粒度键汇总
