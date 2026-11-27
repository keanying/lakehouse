-- ================================================================================================
-- dwd.dwd_mkt_cut_price_di  砍价参与明细
-- 粒度：1行=1次发起砍价（当日新增）
-- 分区：travel_date（YYYYMMDD）
-- 调度：每日，依赖上游 ODS 当日分区与相关维表
-- 上游：ods_mkt_cut_price_join_df、ods_mkt_cut_price_df
-- 业务规则 / 修正：
--   · 按发起时间 = bizdate 取当日；发起后的状态变化（砍成 / 下单）看次日快照或按 update_time 补
-- ================================================================================================
INSERT OVERWRITE TABLE dwd.dwd_mkt_cut_price_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
    CAST(id AS BIGINT)                                           AS cut_join_id,  -- 发起砍价记录ID
    CAST(cut_id AS BIGINT)                                       AS cut_id,       -- 砍价活动ID
    CAST(sid AS BIGINT)                                          AS supplier_id,  -- 供应商ID（租户ID）
    CAST(mid AS BIGINT)                                          AS member_id,    -- 发起用户ID
    CAST(pid AS BIGINT)                                          AS product_id,   -- 产品ID
    ordernum                                                     AS order_no,     -- 下单订单号
    CAST(status AS INT)                                          AS cut_status,   -- 状态
    CAST(cut_money AS DECIMAL(18,2)) / 100                       AS cut_amt,      -- 已砍金额（元）
    CAST(cut_times AS BIGINT)                                    AS cut_times_qty,  -- 被砍次数
    FROM_UNIXTIME(create_time)                                   AS join_time,    -- 发起时间
    FROM_UNIXTIME(update_time)                                   AS update_time,  -- 更新时间
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time           -- ETL 加载时间
FROM (
        SELECT j.*, c.pid
        FROM ods.ods_mkt_cut_price_join_df j
        LEFT JOIN ods.ods_mkt_cut_price_df c ON c.id = j.cut_id AND c.travel_date = '${bizdate}'
        WHERE j.travel_date = '${bizdate}' AND FROM_UNIXTIME(j.create_time, 'yyyyMMdd') = '${bizdate}'  -- 只取当日分区，并按条件过滤
    ) t
