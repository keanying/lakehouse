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
INSERT OVERWRITE TABLE ads.ads_ord_annual_card_di PARTITION (travel_date = '${bizdate}')
SELECT
    scenic_id,
    card_product_id,
    SUM(card_sale_qty)                                           AS card_sale_qty,
    SUM(card_sale_amt)                                           AS card_sale_amt,
    SUM(card_active_qty)                                         AS card_active_qty,
    SUM(card_verify_qty)                                         AS card_verify_qty,
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time
FROM (
    -- dws_ord_annual_card_di
    SELECT
        scenic_id,
        card_product_id,
        SUM(card_sale_qty)                                           AS card_sale_qty,
        SUM(card_sale_amt)                                           AS card_sale_amt,
        SUM(card_active_qty)                                         AS card_active_qty,
        SUM(card_verify_qty)                                         AS card_verify_qty
    FROM dws.dws_ord_annual_card_di
    WHERE travel_date = '${bizdate}'
    GROUP BY scenic_id, card_product_id
) u
GROUP BY scenic_id, card_product_id
