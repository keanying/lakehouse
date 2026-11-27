-- ================================================================================================
-- dwd.dwd_mkt_seckill_di  抢购参与明细
-- 粒度：1行=1次抢购下单任务（成功 / 失败）
-- 分区：travel_date（YYYYMMDD）
-- 调度：每日，依赖上游 ODS 当日分区与相关维表
-- 上游：ods_mkt_seckill_log_df、ods_mkt_seckill_v2_df
-- 业务规则 / 修正：
--   · 抢购日志为全量快照，按抢购时间 = bizdate 取当日；供应商取自抢购活动表（日志表没有）
-- ================================================================================================
INSERT OVERWRITE TABLE dwd.dwd_mkt_seckill_di PARTITION (travel_date = '${bizdate}')
SELECT
    CAST(id AS BIGINT)                                           AS seckill_log_id,
    CAST(seckill_id AS BIGINT)                                   AS seckill_id,
    CAST(activity_id AS BIGINT)                                  AS activity_id,
    CAST(sid AS BIGINT)                                          AS supplier_id,
    CAST(tid AS BIGINT)                                          AS ticket_id,
    CAST(member_id AS BIGINT)                                    AS member_id,
    ordernum                                                     AS order_no,
    IF(COALESCE(ordernum, '') <> '', 1, 0)                       AS success_flag,
    CAST(is_new AS INT)                                          AS new_customer_flag,
    CAST(sale_channel AS INT)                                    AS sale_channel,
    cycle_key,
    CAST(tnum AS BIGINT)                                         AS ticket_qty,
    CAST(money AS DECIMAL(18,2)) / 100                           AS order_amt,
    FROM_UNIXTIME(play_time, 'yyyy-MM-dd')                       AS play_date,
    FROM_UNIXTIME(create_time)                                   AS join_time,
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time
FROM (
        SELECT l.*, s.sid
        FROM ods.ods_mkt_seckill_log_df l
        LEFT JOIN (SELECT id, MAX(sid) AS sid FROM ods.ods_mkt_seckill_v2_df WHERE travel_date = '${bizdate}' GROUP BY id) s
          ON s.id = l.seckill_id
        WHERE l.travel_date = '${bizdate}' AND FROM_UNIXTIME(l.create_time, 'yyyyMMdd') = '${bizdate}'   -- 全量快照取当日
    ) t
