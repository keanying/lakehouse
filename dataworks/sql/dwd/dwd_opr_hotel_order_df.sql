-- ================================================================================================
-- dwd.dwd_opr_hotel_order_df  酒店订单
-- 粒度：1行=1张酒店订单（绿云账号，当日最新状态）
-- 分区：travel_date（YYYYMMDD）
-- 调度：每日，依赖上游 ODS 当日分区与相关维表
-- 上游：ods_opr_hotel_lvyun_hotel_master_df
-- 业务规则 / 修正：
--   · 酒店订单状态会变（预订 → 在住 → 离店 / 取消），存全量快照；在住间夜按「到日 ≤ 统计日 < 离日」取当日在住订单
--   · 预订人姓名 / 电话、会员卡、备注不进 DWD（ODS 已脱敏，事实表不需要）
-- ================================================================================================
INSERT OVERWRITE TABLE dwd.dwd_opr_hotel_order_df PARTITION (travel_date = '${bizdate}')
SELECT
    CAST(id AS BIGINT)                                           AS hotel_order_id,
    CAST(member_id AS BIGINT)                                    AS supplier_id,
    CAST(con_sys_bind AS BIGINT)                                 AS con_sys_bind_id,
    hotel_code,
    hotel_name,
    accnt                                                        AS account_no,
    sta                                                          AS order_status,
    rsv_no                                                       AS reserve_no,
    ota_rsv_no                                                   AS ota_order_no,
    grp_accnt                                                    AS group_account_no,
    CAST(compan_id AS BIGINT)                                    AS company_id,
    CAST(source_id AS BIGINT)                                    AS source_id,
    CAST(agent_id AS BIGINT)                                     AS agent_id,
    market                                                       AS market_code,
    src                                                          AS source_code,
    rate_code,
    channel                                                      AS channel_code,
    rsv_type                                                     AS reserve_type,
    rmtype                                                       AS room_type_code,
    rmno                                                         AS room_no,
    CAST(rmnum AS BIGINT)                                        AS room_qty,
    CAST(DATEDIFF(TO_DATE(dep), TO_DATE(arr)) AS BIGINT)         AS night_qty,
    CAST(real_rate AS DECIMAL(18,2))                             AS room_rate_amt,
    CAST(charge AS DECIMAL(18,2))                                AS charge_amt,
    CAST(pay AS DECIMAL(18,2))                                   AS pay_amt,
    CAST(deposit AS DECIMAL(18,2))                               AS deposit_amt,
    CAST(adult AS BIGINT)                                        AS adult_qty,
    CAST(children AS BIGINT)                                     AS child_qty,
    TO_DATE(arr)                                                 AS arrive_date,
    TO_DATE(dep)                                                 AS depart_date,
    rsv_date                                                     AS reserve_time,
    create_date                                                  AS create_time,
    modify_date                                                  AS modify_time,
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time
FROM ods.ods_opr_hotel_lvyun_hotel_master_df
WHERE travel_date = '${bizdate}'
