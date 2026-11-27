-- ================================================================================================
-- ads.ads_opr_parking_di  停车经营
-- 粒度：1行=1天×景区×停车场
-- 分区：travel_date（YYYYMMDD）
-- 调度：每日，依赖上游 DWS 当日分区；完成后回流 / 服务层读取
-- 上游：dws_opr_parking_hrs
-- 性能：
--   · ADS 只存日粒度：周 / 月 / 年 / 节假日 / 自定义区间与同比环比在查询时关联 dim_opr_period_f（见「指标口径 · ADS 业务指标」）
--   · 比率类不落比率值，只存分子分母；去重类存位图；快照类取日终值
-- ================================================================================================
INSERT OVERWRITE TABLE ads.ads_opr_parking_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
    scenic_id,                                                                    -- 景区ID
    parking_lot_code,                                                             -- 停车场编码
    SUM(park_entry_qty)                                          AS park_entry_qty,  -- 入场车次（日）
    SUM(park_exit_qty)                                           AS park_exit_qty,  -- 出场车次（日）
    SUM(park_fee_amt)                                            AS park_fee_amt,  -- 停车收费金额（日）
    SUM(park_minute_qty)                                         AS park_minute_qty,  -- 停车总时长（日）
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time           -- ETL 加载时间
FROM (
    -- dws_opr_parking_hrs
    SELECT
        scenic_id,                                                                -- 景区ID
        parking_lot_code,                                                         -- 停车场编码
        SUM(park_entry_qty)                                          AS park_entry_qty,  -- 入场车次（日）
        SUM(park_exit_qty)                                           AS park_exit_qty,  -- 出场车次（日）
        SUM(park_fee_amt)                                            AS park_fee_amt,  -- 停车收费金额（日）
        SUM(park_minute_qty)                                         AS park_minute_qty  -- 停车总时长（日）
    FROM dws.dws_opr_parking_hrs
    WHERE travel_date = '${bizdate}'                                              -- 只取当日分区
    GROUP BY scenic_id, parking_lot_code                                          -- 按粒度键汇总
) u                                                                               -- 各来源合并后的明细
GROUP BY scenic_id, parking_lot_code                                              -- 按粒度键汇总
