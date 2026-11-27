-- ================================================================================================
-- dwd.dwd_ord_order_di  订单明细
-- 粒度：1行=1张子订单（ordernum）
-- 分区：travel_date（YYYYMMDD）
-- 调度：每日，依赖上游 ODS 当日分区与相关维表
-- 上游：ods_ord_order_di、ods_ord_order_addon_di、ods_ord_order_apply_di、ods_ord_order_ticket_taker_di、dim_prd_ticket_df、dim_prd_scenic_df、dim_sup_member_df
-- 替代旧任务 25 个（上线对数一致后下线）：
--   · 数据中台/DW/dwd_order_d_i（EMR_SPARK_SQL，cron 00 00 03 * * ?）
--   · 数据平台/DWD/dwd_ord_order_details_di（SERVERLESS_SPARK_SQL，cron 00 11 01 * * ?）
--   · 数据平台/平台湖仓工作流/经营数据/dwd_ord_order_detail_di（SERVERLESS_SPARK_SQL，cron 00 00 00 * * ?）
--   · 业务工厂/经营数据/预定单表/dwd_order_forck_d_i（EMR_SPARK_SQL，cron 00 00 01 * * ?）
--   · 数据平台/平台湖仓工作流/经营数据/dwd_ord_order_item_wide_di（SERVERLESS_SPARK_SQL，cron 00 00 00 * * ?）
--   · 数据中台/DW/dim_order_d_i（EMR_SPARK_SQL，cron 00 00 01 * * ?）
--   · 数据中台/DW/dim_order_d_i_dev（SERVERLESS_SPARK_SQL，cron 00 30 12 * * ?）
--   · 数据中台/DW/dim_order_d_i_dev_刷数（SERVERLESS_SPARK_SQL，cron 00 00 10 * * ?）
--   · 数据平台/DWD/dwd_ord_group_sub_order_details_di（SERVERLESS_SPARK_SQL，cron 00 00 01 * * ?）
--   · 数据平台/DWD/dwd_ord_package_sub_order_details_di（SERVERLESS_SPARK_SQL，cron 00 20 01 * * ?）
--   · 数据平台/DWS/dws_ord_order_detail_wide_di（SERVERLESS_SPARK_SQL，cron 00 30 06 * * ?）
--   · 数据平台/平台湖仓工作流/商户数据中心/dwd_order_boss_cockpit_instance_workflow（EMR_SPARK_SQL，cron 00 00 00 * * ?）
--   · … 另 13 个
-- 业务规则 / 修正：
--   · 替代 dwd_order_d_i、dwd_order_split_d_i、dim_order_d_i 等 17 张：旧系统同一张订单在 8 个任务里各算一遍
--   · 旧同步按 ordertime 只取当日下单，下单后的支付 / 取消 / 验证变化漏采；改为按 update_time 采变更
--   · 修正：测试订单两种判定（group_id=2 / 名称含“测试”）不一致，统一为 票 / 景区 / 供应商任一为测试
--   · 保留旧规则：年卡特权支付（ordermode=18 AND paymode=13）单价置零，负单价置零；原始票数取 下单 + 加票
-- 性能：
--   · 只重算当日有变更的下单日分区（动态分区覆盖），不再全量重跑
--   · 变更订单先按 update_time 取最新一条；附加表 / 价格表 / 分销表只读当日增量，没变的字段沿用 DWD 旧值
--   · 票、景区、渠道、归属地等维表 BROADCAST；归属地按号段 / 证件前 6 位等值关联（ODS 脱敏时保留了前缀）
--   · Spark 不允许同表边读边覆盖：先落临时表再写回
-- ================================================================================================
-- 参数：spark.sql.sources.partitionOverwriteMode=dynamic（只覆盖本次写到的下单日分区）
DROP TABLE IF EXISTS tmp.dwd_ord_order_di_${bizdate};

CREATE TABLE tmp.dwd_ord_order_di_${bizdate} STORED AS ORC AS
WITH changed AS (                                                                 -- ① 今日变更的订单（ODS 按 update_time 增量），同一订单多次变更取最新
    SELECT *
    FROM (
        SELECT o.*, ROW_NUMBER() OVER (PARTITION BY ordernum ORDER BY update_time DESC, id DESC) AS rn  -- 去重序号（1 = 最新）
        FROM ods.ods_ord_order_di o
        WHERE travel_date = '${bizdate}'                                          -- 只取当日分区
    ) t
    WHERE rn = 1
),
touched AS (                                                                      -- ② 受影响的下单日分区（通常只有近几天 + 少量历史日）
    SELECT DISTINCT DATE_FORMAT(ordertime, 'yyyyMMdd') AS order_date FROM changed
),
prev AS (                                                                         -- ③ 变更订单在 DWD 的现有行：附加表当天没变时沿用旧值
    SELECT d.*
    FROM dwd.dwd_ord_order_di d
    LEFT SEMI JOIN changed c ON c.ordernum = d.order_no
    WHERE d.travel_date IN (SELECT order_date FROM touched)
),
addon AS (                                                                        -- 套票主子关系
    SELECT orderid, pack_order, ifpack
    FROM (SELECT orderid, pack_order, CAST(ifpack AS BIGINT) AS ifpack, ROW_NUMBER() OVER (PARTITION BY orderid ORDER BY update_time DESC) AS rn  -- 同一主键多次变更，按 binlog 时间倒序编号
          FROM ods.ods_ord_order_addon_di WHERE travel_date = '${bizdate}') t
    WHERE rn = 1
),
apply AS (                                                                        -- 实际售价、原始 / 已验证 / 已退票数
    SELECT orderid, sale_price, aprice, origin_num, verified_num, refund_num
    FROM (SELECT orderid, sale_price, aprice, origin_num, verified_num, refund_num, ROW_NUMBER()
        OVER (PARTITION BY orderid ORDER BY update_time DESC) AS rn               -- 去重序号（1 = 最新）
          FROM ods.ods_ord_order_apply_di WHERE travel_date = '${bizdate}') t
    WHERE rn = 1
),
dist AS (                                                                         -- 分销链：总级数、一级分销商（level IN (0,1) 为第一级）
    SELECT orderid,
           COUNT(1)                                         AS distribute_level_qty,  -- 分销链层级数
           MAX(IF(level IN (0, 1), buyerid, NULL))          AS distributor_id,    -- 一级分销商ID
           MAX(IF(level IN (0, 1), cost_money, NULL))       AS first_cost_money
    FROM ods.ods_ord_order_distribution_split_di
    WHERE travel_date = '${bizdate}'                                              -- 只取当日分区
    GROUP BY orderid                                                              -- 按粒度键汇总
),
track_qty AS (                                                                    -- 原始票数 = 下单 + 加票（旧 dim_order_d_i 规则）
    SELECT ordernum, SUM(tnum) AS booking_qty                                     -- 预定票数
    FROM ods.ods_ord_order_track_di
    WHERE travel_date = '${bizdate}' AND action IN (0, 16)                        -- 只取当日分区，并按条件过滤
    GROUP BY ordernum                                                             -- 按粒度键汇总
),
team AS (                                                                         -- 团队单子单 → 团单号（团单客源地优先）
    SELECT son_ordernum, main_ordernum
    FROM (SELECT son_ordernum, main_ordernum, ROW_NUMBER() OVER (PARTITION BY son_ordernum ORDER BY update_time DESC) AS rn  -- 同一主键多次变更，按 binlog 时间倒序编号
          FROM ods.ods_ord_team_order_link_df WHERE travel_date = '${bizdate}') t
    WHERE rn = 1
),
team_area AS (
    SELECT ordernum,
    province_code,
    city_code,
    county_code FROM ods.ods_ord_team_order_df WHERE travel_date = '${bizdate}'
),
taker AS (                                                                        -- 独立取票人表（有则优先）
    SELECT ordernum, ordertel, personid
    FROM (SELECT ordernum, ordertel, personid, ROW_NUMBER() OVER (PARTITION BY ordernum ORDER BY id DESC) AS rn  -- 同一主键多次变更，按 binlog 时间倒序编号
          FROM ods.ods_ord_order_ticket_taker_di WHERE travel_date = '${bizdate}') t
    WHERE rn = 1
),
base AS (
    SELECT
        o.*,
        a.pack_order, a.ifpack,
        ap.sale_price, ap.aprice, ap.origin_num, ap.verified_num, ap.refund_num,
        ds.distribute_level_qty, ds.distributor_id, ds.first_cost_money,
        tq.booking_qty,
        tm.main_ordernum                             AS team_order_no,            -- 团队订单号
        COALESCE(tk.ordertel, o.ordertel)            AS taker_tel,
        COALESCE(tk.personid, o.personid)            AS taker_idcard,
        ta.province_code AS team_province_code,
        ta.city_code AS team_city_code,
        ta.county_code AS team_district_code,
        -- 单价规则（旧 ods_order_update_d_i）：年卡特权支付置零；负数置零
        IF(o.ordermode = 18 AND o.paymode = 13, 0, GREATEST(o.tprice, 0)) AS unit_price_fen,
        p.order_role AS p_order_role,
        p.main_order_no AS p_main_order_no,
        p.sale_price_amt AS p_sale_price_amt,
        p.cost_price_amt AS p_cost_price_amt,
        p.origin_ticket_qty AS p_origin_ticket_qty,
        p.verified_ticket_qty AS p_verified_ticket_qty,
        p.refund_ticket_qty AS p_refund_ticket_qty,
        p.distributor_id AS p_distributor_id,
        p.distribute_level_qty AS p_distribute_level_qty
    FROM changed o
    LEFT JOIN prev p        ON p.order_no      = o.ordernum
    LEFT JOIN addon a       ON a.orderid       = o.ordernum
    LEFT JOIN apply ap      ON ap.orderid      = o.ordernum
    LEFT JOIN dist ds       ON ds.orderid      = o.ordernum
    LEFT JOIN track_qty tq  ON tq.ordernum     = o.ordernum
    LEFT JOIN team tm       ON tm.son_ordernum = o.ordernum
    LEFT JOIN team_area ta  ON ta.ordernum     = tm.main_ordernum
    LEFT JOIN taker tk      ON tk.ordernum     = o.ordernum
)
SELECT /*+ BROADCAST(t, s, mb, ms, ph, ic) */
    b.ordernum                                                       AS order_no,  -- 订单号（子单号 ordernum）
    COALESCE(b.pack_order, b.p_main_order_no, b.ordernum)            AS main_order_no,  -- 主票订单号
    CASE                                                                          -- ifpack：1 主票，>1 子票
        WHEN b.ifpack > 1 THEN 'SUB'
        WHEN b.ifpack IS NOT NULL THEN 'MAIN'
        ELSE COALESCE(b.p_order_role, 'MAIN')
    END AS order_role,                                                            -- 主子单
    b.team_order_no,                                                              -- 团队订单号
    IF(b.team_order_no IS NOT NULL, 1, 0)                            AS team_flag,  -- 是否团队订单
    b.trade_order_id                                                 AS trade_order_no,  -- 交易订单号（支付单）
    b.remotenum                                                      AS remote_order_no,  -- 远端（OTA / API）订单号
    b.lid                                                            AS scenic_id,  -- 景区ID
    b.tid                                                            AS ticket_id,  -- 票ID
    b.pid                                                            AS product_id,  -- 产品ID
    s.scenic_type_code                                               AS product_type,  -- 产品类型
    b.aid                                                            AS supplier_id,  -- 供应商ID（租户ID）
    b.apply_did                                                      AS origin_supplier_id,  -- 原始（顶级）供应商ID（租户ID）
    b.member                                                         AS buyer_id,  -- 购买者ID（直接下单的商户 / 会员）
    mb.member_type_code                                              AS buyer_type,  -- 购买者身份
    b.salerid                                                        AS seller_id,  -- 销售者（收款方）ID
    COALESCE(b.distributor_id, b.p_distributor_id)                   AS distributor_id,  -- 一级分销商ID
    COALESCE(b.distribute_level_qty, b.p_distribute_level_qty)       AS distribute_level_qty,  -- 分销链层级数
    b.ordermode                                                      AS order_mode,  -- 下单渠道编码
    IF(b.ordermode = 17, 'OTA', mb.distribute_system_code)           AS distribute_system_code,  -- 对接分销平台（OTA / API）编码｜17 = 淘宝 / 飞猪
    CAST(NULL AS STRING)                                             AS purchase_system_code,  -- 对接采购平台编码｜待确认：采购平台订单表（旧 ods_third_purchase_order_d_f）未纳入同步
    b.paymode                                                        AS pay_mode,  -- 支付方式编码
    CAST(NULL AS STRING)                                             AS pay_account_type,  -- 付款资金账户类型｜待确认：资金账户类型不在订单表
    CAST(b.status AS STRING)                                         AS order_status,  -- 订单状态
    CAST(b.pay_status AS STRING)                                     AS pay_status,  -- 支付状态
    b.tnum                                                           AS ticket_qty,  -- 当前票数
    COALESCE(b.origin_num,
             b.p_origin_ticket_qty,
             GREATEST(COALESCE(b.booking_qty, 0), b.tnum)) AS origin_ticket_qty,  -- 下单时原始票数
    COALESCE(b.verified_num, b.p_verified_ticket_qty, 0)             AS verified_ticket_qty,  -- 已验证票数（快照）
    COALESCE(b.refund_num, b.p_refund_ticket_qty, 0)                 AS refund_ticket_qty,  -- 已退票数（快照）
    CAST(b.unit_price_fen AS DECIMAL(18,2)) / 100                    AS ticket_price_amt,  -- 销售单价（元）
    COALESCE(CAST(IF(
        b.ordermode = 18 AND b.paymode = 13,
        0,
        GREATEST(b.sale_price, 0)
    ) AS DECIMAL(18,2)) / 100,
             b.p_sale_price_amt, CAST(b.unit_price_fen AS DECIMAL(18,2)) / 100) AS sale_price_amt,  -- 实际售价
    COALESCE(CAST(COALESCE(b.first_cost_money, b.aprice) AS DECIMAL(18,2)) / 100,
             b.p_cost_price_amt) AS cost_price_amt,                               -- 结算（供应）单价（元）
    CAST(b.totalmoney AS DECIMAL(18,2)) / 100                        AS order_amt,  -- 订单金额（元）
    -- 已支付金额：未支付（2）或 取消（3）/ 撤销（6）/ 删除（9）为 0
    IF(
        b.pay_status = 2 OR b.status IN (3, 6, 9),
        0,
        CAST(b.unit_price_fen * b.tnum AS DECIMAL(18,2)) / 100
    ) AS pay_amt,                                                                 -- 订单支付金额（元）
    IF(b.onsale = 1, 1, 0)                                           AS use_coupon_flag,  -- 是否使用优惠
    IF(b.unioncheck = 1, 1, 0)                                       AS non_refundable_flag,  -- 是否不可退可提现
    b.ordertime                                                      AS order_time,  -- 下单时间 yyyy-MM-dd HH
    IF(b.pay_time > 0, FROM_UNIXTIME(b.pay_time), NULL)              AS pay_time,  -- 支付时间
    SUBSTR(b.playtime, 1, 10)                                        AS play_date,  -- 计划游玩日期 yyyy-MM-dd
    DATEDIFF(TO_DATE(b.playtime), TO_DATE(b.ordertime))              AS advance_day_qty,  -- 提前预订天数 = 游玩日 − 下单日
    b.begintime                                                      AS valid_start_time,  -- 有效期开始
    b.endtime                                                        AS valid_end_time,  -- 有效期结束
    NULLIF(b.dtime, '0000-00-00 00:00:00')                           AS first_verify_time,  -- 首次验证时间（快照）
    NULLIF(b.ctime, '0000-00-00 00:00:00')                           AS cancel_time,  -- 取消时间（快照）
    CAST(b.code AS STRING)                                           AS voucher_code,  -- 凭证码
    CONCAT(SUBSTR(b.ordername, 1, 1), '**')                          AS taker_name_mask,  -- 取票人姓名（掩码）
    SUBSTRING_INDEX(b.taker_tel, '#', -1)                          AS taker_phone_hash,  -- 取票人手机号哈希（营销触达时再解密关联）
    SUBSTRING_INDEX(b.taker_idcard, '#', -1)                       AS taker_id_card_hash,  -- 取票人证件号哈希（去重统计用）
    -- 证件号第 17 位（ODS 前缀第 11 位）奇男偶女；年龄 = 下单年 − 出生年
    IF(LENGTH(SUBSTRING_INDEX(b.taker_idcard, '#', 1)) = 11, IF(
        CAST(SUBSTR(b.taker_idcard, 11, 1) AS INT) % 2 = 1,
        'M',
        'F'
    ), 'U') AS taker_gender,                                                      -- 取票人性别（证件号解析）
    IF(
        LENGTH(SUBSTRING_INDEX(b.taker_idcard, '#', 1)) = 11,
        YEAR(TO_DATE(b.ordertime)) - CAST(SUBSTR(b.taker_idcard, 7, 4) AS INT),
        NULL
    ) AS taker_age,                                                               -- 取票人年龄（证件号解析）
    -- 客源地：团单 > 手机号段 > 证件地区（旧 ticket_taker_province 规则）
    COALESCE(b.team_province_code, ph.province_code, ic.province_code) AS taker_province_code,  -- 取票人客源省（证件优先、手机号次之）
    COALESCE(b.team_city_code, ph.city_code, ic.city_code)           AS taker_city_code,  -- 取票人客源市
    COALESCE(b.team_district_code, ic.area_code)                     AS taker_district_code,  -- 取票人客源区县
    b.certnum                                                        AS resource_id,  -- 资源中心资源ID
    CAST(NULL AS BIGINT)                                             AS resource_center_supplier_id,  -- 资源中心供应商ID（租户ID）｜资源中心订单见 dwd_prd_resource_order_di
    CAST(NULL AS BIGINT)                                             AS resource_center_purchase_id,  -- 资源中心采购商户
    CAST(NULL AS BIGINT)                                             AS mall_supplier_id,  -- 微商城供应商ID（租户ID）
    IF(t.test_flag = 1 OR s.test_flag = 1 OR ms.test_flag = 1, 1, 0) AS test_flag,  -- 是否测试订单
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time,          -- ETL 加载时间
    DATE_FORMAT(b.ordertime, 'yyyyMMdd')                             AS travel_date  -- 数据日期｜分区 = 下单日
FROM base b
LEFT JOIN (SELECT ticket_id, test_flag FROM dim.dim_prd_ticket_df) t ON t.ticket_id = b.tid
LEFT JOIN (SELECT scenic_id, scenic_type_code, test_flag FROM dim.dim_prd_scenic_df) s ON s.scenic_id = b.lid
LEFT JOIN (SELECT member_id, member_type_code, distribute_system_code FROM dim.dim_sup_member_df) mb  -- 关联「会员（平台账号）维度」按键聚合
  ON mb.member_id = b.member                                                      -- 按 member→member_id 关联
LEFT JOIN (SELECT member_id, test_flag FROM dim.dim_sup_member_df) ms ON ms.member_id = b.aid
LEFT JOIN (SELECT phone_prefix, province_code, city_code FROM dim.dim_opr_phone_area_f) ph  -- 关联「手机号归属地」按键聚合
  ON ph.phone_prefix = SUBSTRING_INDEX(b.taker_tel, '#', 1)
LEFT JOIN (SELECT area_code, province_code, city_code FROM dim.dim_opr_idcard_area_f) ic  -- 关联「身份证地区码」按键聚合
  ON ic.area_code = SUBSTR(b.taker_idcard, 1, 6)
UNION ALL
-- ④ 受影响分区里今天没变的订单：原样写回（动态分区覆盖会整分区替换）
SELECT d.*
FROM dwd.dwd_ord_order_di d
LEFT ANTI JOIN changed c ON c.ordernum = d.order_no
WHERE d.travel_date IN (SELECT DISTINCT DATE_FORMAT(ordertime, 'yyyyMMdd') FROM changed);

INSERT OVERWRITE TABLE dwd.dwd_ord_order_di PARTITION (travel_date)               -- 写入当日分区
SELECT * FROM tmp.dwd_ord_order_di_${bizdate};

DROP TABLE IF EXISTS tmp.dwd_ord_order_di_${bizdate};
