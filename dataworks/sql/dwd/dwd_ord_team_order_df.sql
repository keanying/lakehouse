-- ================================================================================================
-- dwd.dwd_ord_team_order_df  团队订单
-- 粒度：1行=1张团队单（当日最新状态）
-- 分区：travel_date（YYYYMMDD）
-- 调度：每日，依赖上游 ODS 当日分区与相关维表
-- 上游：ods_ord_team_order_df、ods_ord_team_order_link_df
-- 替代旧任务 1 个（上线对数一致后下线）：
--   · 数据中台/原始数据层(ODS)/ods_订单/ods_team_order_d_f（EMR_SPARK_SQL，cron 00 30 00 * * ?）
-- 业务规则 / 修正：
--   · 团单是有状态的单据（确认 / 验证 / 激活会变）：存全量快照（_df），每日一份最新状态；按下单日 / 游玩日统计时过滤 order_time / play_date
--   · 子订单数先在 team_order_link 按团单号聚合再关联（一个团单多张子订单，直接关联会放大团单）
-- ================================================================================================
INSERT OVERWRITE TABLE dwd.dwd_ord_team_order_df PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
    ordernum                                                     AS team_order_no,  -- 团队订单号
    CAST(aid AS BIGINT)                                          AS supplier_id,  -- 供应商ID（租户ID）
    CAST(fid AS BIGINT)                                          AS distributor_id,  -- 下单分销商（旅行社）ID
    CAST(group_id AS BIGINT)                                     AS distributor_group_id,  -- 分销商分组ID
    CAST(guide AS BIGINT)                                        AS guide_id,     -- 导游ID
    CAST(team_type_id AS BIGINT)                                 AS team_type_id,  -- 团单类型ID（团队规则）
    CAST(ordertype AS INT)                                       AS order_type,   -- 报团下单方式
    CAST(status AS INT)                                          AS team_status,  -- 团单状态
    CAST(pay_status AS INT)                                      AS pay_status,   -- 支付状态
    CAST(active_status AS INT)                                   AS active_status,  -- 激活状态
    CAST(is_lodging AS INT)                                      AS lodging_flag,  -- 是否住宿
    CAST(tnum AS BIGINT)                                         AS team_person_qty,  -- 团队人数
    COALESCE(sub_order_qty, 0)                                   AS sub_order_qty,  -- 子订单数（团单关联的门票订单）
    COALESCE(scenic_qty, 0)                                      AS scenic_qty,   -- 涉及景区数
    province_code,                                                                -- 客源省编码
    city_code,                                                                    -- 客源市编码
    county_code                                                  AS district_code,  -- 客源区县编码
    playtime                                                     AS play_date,    -- 游玩日期
    ordertime                                                    AS order_time,   -- 下单时间
    first_check_time                                             AS first_verify_time,  -- 团单首次验证时间
    FROM_UNIXTIME(active_time)                                   AS active_time,  -- 激活时间
    FROM_UNIXTIME(updatetime)                                    AS update_time,  -- 最近更新时间
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time           -- ETL 加载时间
FROM (
        SELECT o.*, l.sub_order_qty, l.scenic_qty
        FROM ods.ods_ord_team_order_df o
        LEFT JOIN (SELECT main_ordernum, COUNT(1) AS sub_order_qty, COUNT(DISTINCT lid) AS scenic_qty
                   FROM ods.ods_ord_team_order_link_df WHERE travel_date = '${bizdate}' GROUP BY main_ordernum) l
          ON l.main_ordernum = o.ordernum                                         -- 按 ordernum→main_ordernum 关联｜先聚合再关联，团单不放大
        WHERE o.travel_date = '${bizdate}'                                        -- 只取当日分区
    ) t
