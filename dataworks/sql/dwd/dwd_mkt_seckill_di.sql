-- ================================================================================================
-- dwd.dwd_mkt_seckill_di  抢购参与明细
-- 粒度：1行=1次抢购下单任务（成功 / 失败）
-- 分区：travel_date（YYYYMMDD）
-- 调度：每日，依赖上游 ODS 当日分区与相关维表
-- 上游：ods_mkt_seckill_log_df、ods_mkt_seckill_v2_df
-- 业务规则 / 修正：
--   · 抢购日志为全量快照，按抢购时间 = bizdate 取当日；供应商取自抢购活动表（日志表没有）
-- ================================================================================================
INSERT OVERWRITE TABLE dwd.dwd_mkt_seckill_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
    CAST(id AS BIGINT)                                           AS seckill_log_id,  -- 抢购记录ID
    CAST(seckill_id AS BIGINT)                                   AS seckill_id,   -- 抢购活动ID
    CAST(activity_id AS BIGINT)                                  AS activity_id,  -- 营销主活动ID
    CAST(sid AS BIGINT)                                          AS supplier_id,  -- 供应商ID（租户ID）
    CAST(tid AS BIGINT)                                          AS ticket_id,    -- 票ID
    CAST(member_id AS BIGINT)                                    AS member_id,    -- 下单用户ID
    ordernum                                                     AS order_no,     -- 成功订单号
    IF(COALESCE(ordernum, '') <> '', 1, 0)                       AS success_flag,  -- 是否抢购成功
    CAST(is_new AS INT)                                          AS new_customer_flag,  -- 是否新客
    CAST(sale_channel AS INT)                                    AS sale_channel,  -- 销售渠道
    cycle_key,                                                                    -- 周期标识
    CAST(tnum AS BIGINT)                                         AS ticket_qty,   -- 票数
    CAST(money AS DECIMAL(18,2)) / 100                           AS order_amt,    -- 订单总价（元）
    FROM_UNIXTIME(play_time, 'yyyy-MM-dd')                       AS play_date,    -- 游玩日期
    FROM_UNIXTIME(create_time)                                   AS join_time,    -- 抢购时间
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time           -- ETL 加载时间
FROM (
        SELECT l.*, s.sid
        FROM ods.ods_mkt_seckill_log_df l
        LEFT JOIN (SELECT id, MAX(sid) AS sid FROM ods.ods_mkt_seckill_v2_df WHERE travel_date = '${bizdate}' GROUP BY id) s  -- 关联「抢购活动表」按键聚合
          ON s.id = l.seckill_id                                                  -- 按 seckill_id→id 关联
        WHERE l.travel_date = '${bizdate}' AND FROM_UNIXTIME(l.create_time, 'yyyyMMdd') = '${bizdate}'  -- 只取当日分区，并按条件过滤｜全量快照取当日
    ) t
