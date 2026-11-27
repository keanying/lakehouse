-- ================================================================================================
-- dwd.dwd_mkt_cut_price_di  砍价参与明细
-- 粒度：1行=1次发起砍价（当日新增）
-- 分区：travel_date（YYYYMMDD）
-- 调度：每日，依赖上游 ODS 当日分区与相关维表
-- 上游：ods_mkt_cut_price_join_df、ods_mkt_cut_price_df
-- 业务规则 / 修正：
--   · 按发起时间 = bizdate 取当日；发起后的状态变化（砍成 / 下单）看次日快照或按 update_time 补
-- ================================================================================================
INSERT OVERWRITE TABLE dwd.dwd_mkt_cut_price_di PARTITION (travel_date = '${bizdate}')
SELECT
    CAST(id AS BIGINT)                                           AS cut_join_id,
    CAST(cut_id AS BIGINT)                                       AS cut_id,
    CAST(sid AS BIGINT)                                          AS supplier_id,
    CAST(mid AS BIGINT)                                          AS member_id,
    CAST(pid AS BIGINT)                                          AS product_id,
    ordernum                                                     AS order_no,
    CAST(status AS INT)                                          AS cut_status,
    CAST(cut_money AS DECIMAL(18,2)) / 100                       AS cut_amt,
    CAST(cut_times AS BIGINT)                                    AS cut_times_qty,
    FROM_UNIXTIME(create_time)                                   AS join_time,
    FROM_UNIXTIME(update_time)                                   AS update_time,
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time
FROM (
        SELECT j.*, c.pid
        FROM ods.ods_mkt_cut_price_join_df j
        LEFT JOIN ods.ods_mkt_cut_price_df c ON c.id = j.cut_id AND c.travel_date = '${bizdate}'
        WHERE j.travel_date = '${bizdate}' AND FROM_UNIXTIME(j.create_time, 'yyyyMMdd') = '${bizdate}'
    ) t
