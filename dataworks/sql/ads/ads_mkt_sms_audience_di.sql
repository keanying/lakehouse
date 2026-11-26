-- ================================================================================================
-- ads.ads_mkt_sms_audience_di  营销短信人群
-- 粒度：1行=1天×景区×取票人（哈希）
-- 分区：travel_date（YYYYMMDD）
-- 调度：每日，依赖上游 DWS 当日分区；完成后回流 / 服务层读取
-- 上游：dwd_ord_order_di、dwd_ord_traveler_di
-- 替代旧任务 2 个（上线对数一致后下线）：
--   · 数据中台/应用数据层(ADS)/营销短信/ads_order_draw_d_i（EMR_SPARK_SQL，cron 00 15 00 * * ?）
--   · 数据中台/应用数据层(ADS)/营销短信/ads_order_draw_new_user_d_f（EMR_SPARK_SQL，cron 00 00 01 * * ?）
-- 业务规则 / 修正：
--   · 短信营销人群：只出哈希，不出明文手机号；发送时由营销系统按哈希回查（旧 ads 直接导出明文手机号）
-- ================================================================================================
INSERT OVERWRITE TABLE ads.ads_mkt_sms_audience_di PARTITION (travel_date = '${bizdate}')
SELECT
    o.scenic_id,
    o.taker_phone_hash,
    -- 新客：此前没有在该景区下过单（按游客维度的首单日判定，避免回扫全部历史订单）
    MAX(IF(t.first_order_date IS NULL OR t.first_order_date >= DATE_FORMAT(TO_DATE('${bizdate}', 'yyyyMMdd'), 'yyyy-MM-dd'), 1, 0)) AS new_user_flag,
    COUNT(1)                                                         AS order_order_qty,
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time
FROM (SELECT scenic_id, taker_phone_hash, taker_id_card_hash FROM dwd.dwd_ord_order_di
      WHERE travel_date = '${bizdate}' AND test_flag = 0 AND pay_status <> '2' AND taker_phone_hash IS NOT NULL) o
LEFT JOIN (SELECT tourist_key, first_order_date FROM dim.dim_cus_tourist_df) t ON t.tourist_key = o.taker_id_card_hash
GROUP BY o.scenic_id, o.taker_phone_hash
