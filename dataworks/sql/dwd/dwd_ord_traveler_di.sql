-- ================================================================================================
-- dwd.dwd_ord_traveler_di  订单游客明细
-- 粒度：1行=1张订单×1位游客
-- 分区：travel_date（YYYYMMDD）
-- 调度：每日，依赖上游 ODS 当日分区与相关维表
-- 上游：ods_ord_order_traveler_di、ods_ord_order_traveler_ext_di、dim_opr_idcard_area_f、dim_opr_phone_area_f
-- 替代旧任务 4 个（上线对数一致后下线）：
--   · 数据中台/DW/dwd_tourist_info_d_i（EMR_SPARK_SQL，cron 00 00 02 * * ?）
--   · 数据中台/数仓明细层(DWD)/dwd_预定单游客信息/dwd_order_tourist_info_d_i（EMR_SPARK_SQL，cron 00 30 01 * * ?）
--   · 数据平台/DWD/dwd_ord_traveler_booking_details_di（SERVERLESS_SPARK_SQL，cron 00 35 01 * * ?）
--   · 数据平台/DWS/dws_ord_traveler_booking_wide_di（SERVERLESS_SPARK_SQL，cron 00 00 12 * * ?）
-- 业务规则 / 修正：
--   · 替代 28 个透视列的游客画像中间表：画像维度（性别 / 年龄段 / 客源地）在明细上算一次
-- 性能：
--   · 归属地按证件前 6 位 / 号段等值 BROADCAST 关联
--   · 同一游客记录多次变更取最新
--   · 关联订单带下单日分区条件（动态分区裁剪）
-- ================================================================================================
WITH tr AS (
    SELECT orderid, idx, lid, tourist, idcard, voucher_type, mobile, check_time,
           FROM_UNIXTIME(CAST(order_time AS BIGINT), 'yyyyMMdd') AS order_date,
           -- ODS 证件号前缀 11 位 = 地区 6 + 出生年 4 + 性别位 1（仅 18 位身份证）
           -- 年龄按下单日计算（不随跑批日期变化）
           IF(
               LENGTH(SUBSTRING_INDEX(idcard, '#', 1)) = 11,
               YEAR(FROM_UNIXTIME(CAST(order_time AS BIGINT))) - CAST(SUBSTR(idcard, 7, 4) AS INT),
               NULL
           ) AS age,                                                              -- 年龄
           IF(LENGTH(SUBSTRING_INDEX(idcard, '#', 1)) = 11, IF(
               CAST(SUBSTR(idcard, 11, 1) AS INT) % 2 = 1,
               'M',
               'F'
           ), 'U') AS gender                                                      -- 性别
    FROM (SELECT *, ROW_NUMBER() OVER (PARTITION BY orderid, idx ORDER BY update_time DESC) AS rn  -- 同一主键多次变更，按 binlog 时间倒序编号
          FROM ods.ods_ord_order_traveler_di WHERE travel_date = '${bizdate}') t
    WHERE rn = 1
),
fellow AS (SELECT orderid, COUNT(1) AS fellow_qty FROM tr GROUP BY orderid)       -- 同行人数 = 同订单游客数
INSERT OVERWRITE TABLE dwd.dwd_ord_traveler_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT /*+ BROADCAST(ic, ph) */
    tr.orderid                                                       AS order_no,  -- 订单号
    CAST(tr.idx AS INT)                                              AS traveler_seq,  -- 订单内游客序号
    CAST(tr.lid AS BIGINT)                                           AS scenic_id,  -- 景区ID
    o.ticket_id,                                                                  -- 票ID
    o.order_role,                                                                 -- 主子单
    COALESCE(o.team_flag, 0)                                         AS team_flag,  -- 是否团队订单（订单退化维度）
    o.order_mode,                                                                 -- 下单渠道编码（订单退化维度）｜下单渠道（订单带出，画像按渠道拆分用）
    o.pay_mode,                                                                   -- 支付方式编码（订单退化维度）｜支付方式（订单带出）
    CONCAT(SUBSTR(tr.tourist, 1, 1), '**')                           AS traveler_name_mask,  -- 游客姓名（掩码）
    SUBSTRING_INDEX(tr.idcard, '#', -1)                                   AS id_card_hash,  -- 证件号哈希
    tr.voucher_type                                                  AS id_card_type,  -- 证件类型
    SUBSTRING_INDEX(tr.mobile, '#', -1)                                   AS phone_hash,  -- 手机号哈希
    tr.gender,                                                                    -- 性别
    tr.age,                                                                       -- 年龄
    CASE
        WHEN tr.age IS NULL THEN '未知'
        WHEN tr.age <= 7 THEN '0-7'
        WHEN tr.age <= 17 THEN '8-17'
        WHEN tr.age <= 27 THEN '18-27'
         WHEN tr.age <= 40 THEN '28-40' WHEN tr.age <= 60 THEN '41-60' ELSE '61+' END AS age_group,  -- 年龄段
    COALESCE(ic.province_code, ph.province_code)                     AS province_code,  -- 客源省（证件优先、手机号次之）｜证件地区优先，手机号段次之
    COALESCE(ic.city_code, ph.city_code)                             AS city_code,  -- 客源市
    ic.area_code                                                     AS district_code,  -- 客源区县
    IF(ic.area_code IS NOT NULL OR ph.province_code IS NOT NULL, 'CN', NULL) AS country_code,  -- 国家（境外游客）
    f.fellow_qty,                                                                 -- 同行人数（同订单游客数）
    o.order_time,                                                                 -- 下单时间
    NULLIF(tr.check_time, '0')                                       AS verify_time,  -- 核销时间（未核销为空）
    COALESCE(o.test_flag, 0)                                         AS test_flag,  -- 是否测试订单
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time           -- ETL 加载时间
FROM tr
LEFT JOIN fellow f ON f.orderid = tr.orderid
LEFT JOIN (
    SELECT order_no,                                                              -- 订单号
    travel_date,                                                                  -- 数据日期
    ticket_id,                                                                    -- 票ID
    order_role,                                                                   -- 主子单
    team_flag,                                                                    -- 是否团队订单（订单退化维度）
    order_mode,                                                                   -- 下单渠道编码（订单退化维度）
    pay_mode,                                                                     -- 支付方式编码（订单退化维度）
    order_time,                                                                   -- 下单时间
    test_flag FROM dwd.dwd_ord_order_di
) o
       ON o.travel_date = tr.order_date AND o.order_no = tr.orderid               -- 按 order_date→travel_date、orderid→order_no 关联
LEFT JOIN (SELECT area_code, province_code, city_code FROM dim.dim_opr_idcard_area_f) ic  -- 关联「身份证地区维度」按键聚合
  ON ic.area_code = SUBSTR(tr.idcard, 1, 6)
LEFT JOIN (
    SELECT phone_prefix,
    province_code,                                                                -- 客源省（证件优先、手机号次之）
    city_code FROM dim.dim_opr_phone_area_f WHERE phone_prefix_type = 'SEGMENT'
) ph
  ON ph.phone_prefix = SUBSTRING_INDEX(tr.mobile, '#', 1)
