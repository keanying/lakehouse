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
INSERT OVERWRITE TABLE dwd.dwd_opr_hotel_order_df PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
    CAST(id AS BIGINT)                                           AS hotel_order_id,  -- 绿云订单记录ID
    CAST(member_id AS BIGINT)                                    AS supplier_id,  -- 供应商ID（租户ID）
    CAST(con_sys_bind AS BIGINT)                                 AS con_sys_bind_id,  -- 对接系统绑定ID
    hotel_code,                                                                   -- 酒店代码
    hotel_name,                                                                   -- 酒店名称
    accnt                                                        AS account_no,   -- 绿云账号（一间房一个账号）
    sta                                                          AS order_status,  -- 订单状态
    rsv_no                                                       AS reserve_no,   -- 预订号
    ota_rsv_no                                                   AS ota_order_no,  -- OTA 订单号
    grp_accnt                                                    AS group_account_no,  -- 团队账号
    CAST(compan_id AS BIGINT)                                    AS company_id,   -- 协议单位ID
    CAST(source_id AS BIGINT)                                    AS source_id,    -- 订房中心ID
    CAST(agent_id AS BIGINT)                                     AS agent_id,     -- 旅行社ID
    market                                                       AS market_code,  -- 市场码
    src                                                          AS source_code,  -- 来源码
    rate_code,                                                                    -- 房价码
    channel                                                      AS channel_code,  -- 渠道代码
    rsv_type                                                     AS reserve_type,  -- 预订类型
    rmtype                                                       AS room_type_code,  -- 房型
    rmno                                                         AS room_no,      -- 房号
    CAST(rmnum AS BIGINT)                                        AS room_qty,     -- 房数
    CAST(DATEDIFF(TO_DATE(dep), TO_DATE(arr)) AS BIGINT)         AS night_qty,    -- 入住晚数 = 离日 − 到日
    CAST(real_rate AS DECIMAL(18,2))                             AS room_rate_amt,  -- 房价（元 / 间夜）
    CAST(charge AS DECIMAL(18,2))                                AS charge_amt,   -- 消费合计（元）
    CAST(pay AS DECIMAL(18,2))                                   AS pay_amt,      -- 付款合计（元）
    CAST(deposit AS DECIMAL(18,2))                               AS deposit_amt,  -- 预付款（元）
    CAST(adult AS BIGINT)                                        AS adult_qty,    -- 成人数
    CAST(children AS BIGINT)                                     AS child_qty,    -- 儿童数
    TO_DATE(arr)                                                 AS arrive_date,  -- 到店日期
    TO_DATE(dep)                                                 AS depart_date,  -- 离店日期
    rsv_date                                                     AS reserve_time,  -- 预订时间
    create_date                                                  AS create_time,  -- 创建时间
    modify_date                                                  AS modify_time,  -- 修改时间
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time           -- ETL 加载时间
FROM ods.ods_opr_hotel_lvyun_hotel_master_df
WHERE travel_date = '${bizdate}'                                                  -- 只取当日分区
