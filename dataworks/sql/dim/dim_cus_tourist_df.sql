-- ================================================================================================
-- dim.dim_cus_tourist_df  游客维度
-- 粒度：1行=1位游客（证件号哈希）
-- 分区：无分区
-- 调度：每日，ODS 全部完成后；维表之间按上游顺序
-- 上游：dwd_ord_traveler_di、dwd_ord_order_di、ods_cus_tourist_info_df、ods_cus_tourist_auth_info_df、dim_opr_idcard_area_f、dim_opr_phone_area_f
-- 业务规则 / 修正：
--   · 旧系统没有游客维度，复购 / 首游等在各 ADS 里临时 COUNT DISTINCT personid
-- 性能：
--   · 增量累计：当前维表 + 今日新增明细合并，不再每天扫全部历史订单
--   · Spark 不允许同表边读边覆盖：先落临时表再写回
-- ================================================================================================
DROP TABLE IF EXISTS tmp.dim_cus_tourist_df_${bizdate};

CREATE TABLE tmp.dim_cus_tourist_df_${bizdate} STORED AS ORC AS
WITH today AS (                                                                   -- 今日新增的游客明细（排除测试订单）
    SELECT id_card_hash AS tourist_key,                                           -- 游客键 = SHA256(证件类型 + 证件号)
           id_card_type,                                                          -- 证件类型
           gender,                                                                -- 性别
           YEAR(CURRENT_DATE()) - age AS birth_year,                              -- 出生年份
           province_code,
           city_code,
           phone_hash,                                                            -- 最近手机号哈希
           SUBSTR(order_time, 1, 10) AS order_date,
           SUBSTR(verify_time, 1, 10) AS visit_date,                              -- 游览日期
           order_no,
           scenic_id
    FROM dwd.dwd_ord_traveler_di
    WHERE travel_date = '${bizdate}' AND id_card_hash IS NOT NULL AND test_flag = 0  -- 只取当日分区，并按条件过滤
),
n AS (
    SELECT tourist_key,                                                           -- 游客键 = SHA256(证件类型 + 证件号)
           MAX(id_card_type) AS id_card_type,                                     -- 证件类型
           MAX(gender) AS gender,                                                 -- 性别
           MAX(birth_year) AS birth_year,                                         -- 出生年份
           MAX(province_code) AS source_province_code,                            -- 客源省（证件地区）
           MAX(city_code) AS source_city_code,                                    -- 客源市（证件地区）
           MAX(phone_hash) AS phone_hash,                                         -- 最近手机号哈希
           MIN(order_date) AS first_order_date,                                   -- 首次下单日期
           MAX(order_date) AS last_order_date,                                    -- 最近下单日期
           MIN(visit_date) AS first_visit_date,                                   -- 首次到访（核销）日期
           MAX(visit_date) AS last_visit_date,                                    -- 最近到访日期
           COUNT(DISTINCT order_no) AS order_qty,                                 -- 累计订单数
           COUNT(visit_date) AS visit_qty,                                        -- 累计到访次数
           COUNT(DISTINCT IF(visit_date IS NOT NULL, scenic_id, NULL)) AS visit_scenic_qty  -- 累计到访景区数
    FROM today
    GROUP BY tourist_key                                                          -- 按粒度键汇总
),
auth AS (                                                                         -- 实名认证：tourist_info 证件号在 ODS 已哈希，取哈希段关联
    SELECT SUBSTRING_INDEX(i.certificate_no, '#', -1) AS tourist_key,             -- 游客键 = SHA256(证件类型 + 证件号)
           MAX(IF(a.status = '1', 1, 0)) AS real_name_flag                        -- 是否实名认证
    FROM ods.ods_cus_tourist_info_df i
    JOIN ods.ods_cus_tourist_auth_info_df a ON a.tourist_id = i.id AND a.travel_date = '${bizdate}'
    WHERE i.travel_date = '${bizdate}'                                            -- 只取当日分区
    GROUP BY SUBSTRING_INDEX(i.certificate_no, '#', -1)                           -- 按粒度键汇总
),
m AS (
    SELECT
        COALESCE(n.tourist_key, h.tourist_key)                         AS tourist_key,  -- 游客键 = SHA256(证件类型 + 证件号)
        COALESCE(n.id_card_type, h.id_card_type)                       AS id_card_type,  -- 证件类型
        COALESCE(h.gender, n.gender)                                   AS gender,  -- 性别
        COALESCE(h.birth_year, n.birth_year)                           AS birth_year,  -- 出生年份
        COALESCE(h.source_province_code, n.source_province_code)       AS source_province_code,  -- 客源省（证件地区）
        COALESCE(h.source_city_code, n.source_city_code)               AS source_city_code,  -- 客源市（证件地区）
        h.phone_province_code,                                                    -- 手机号归属省（最近一次）｜待确认：维表只存手机号哈希，号段归属需在 DWD 单独带出后再累计
        COALESCE(n.phone_hash, h.phone_hash)                           AS phone_hash,  -- 最近手机号哈希｜取最近一次
        GREATEST(COALESCE(h.real_name_flag, 0), COALESCE(au.real_name_flag, 0)) AS real_name_flag,  -- 是否实名认证
        CASE
            WHEN h.first_order_date IS NULL OR n.first_order_date < h.first_order_date THEN n.first_order_date
            ELSE h.first_order_date
        END AS first_order_date,                                                  -- 首次下单日期
        CASE
            WHEN h.last_order_date IS NULL OR n.last_order_date > h.last_order_date THEN n.last_order_date
            ELSE h.last_order_date
        END AS last_order_date,                                                   -- 最近下单日期
        CASE
            WHEN h.first_visit_date IS NULL OR n.first_visit_date < h.first_visit_date THEN n.first_visit_date
            ELSE h.first_visit_date
        END AS first_visit_date,                                                  -- 首次到访（核销）日期
        CASE
            WHEN h.last_visit_date IS NULL OR n.last_visit_date > h.last_visit_date THEN n.last_visit_date
            ELSE h.last_visit_date
        END AS last_visit_date,                                                   -- 最近到访日期
        COALESCE(h.order_qty, 0) + COALESCE(n.order_qty, 0)            AS order_qty,  -- 累计订单数
        COALESCE(h.visit_qty, 0) + COALESCE(n.visit_qty, 0)            AS visit_qty,  -- 累计到访次数
        -- 近似：跨日同一景区会重复计；精确去重需按 游客 × 景区 累计表
        COALESCE(h.visit_scenic_qty, 0) + COALESCE(n.visit_scenic_qty, 0) AS visit_scenic_qty  -- 累计到访景区数
    FROM n
    FULL OUTER JOIN dim.dim_cus_tourist_df h ON h.tourist_key = n.tourist_key     -- 当前维表（昨日结果）
    LEFT JOIN auth au ON au.tourist_key = COALESCE(n.tourist_key, h.tourist_key)
)
SELECT
    tourist_key, id_card_type, gender, birth_year,
    CASE
        WHEN birth_year IS NULL THEN '未知'
        WHEN YEAR(CURRENT_DATE()) - birth_year <= 7 THEN '0-7'
        WHEN YEAR(CURRENT_DATE()) - birth_year <= 17 THEN '8-17'
        WHEN YEAR(CURRENT_DATE()) - birth_year <= 27 THEN '18-27'
         WHEN YEAR(CURRENT_DATE()) - birth_year <= 40 THEN '28-40'
             WHEN YEAR(CURRENT_DATE()) - birth_year <= 60 THEN '41-60' ELSE '61+' END AS age_group,  -- 年龄段（按统计日）
    source_province_code, source_city_code, phone_province_code, phone_hash, real_name_flag,
    first_order_date,                                                             -- 首次下单日期
    last_order_date,                                                              -- 最近下单日期
    first_visit_date,                                                             -- 首次到访（核销）日期
    last_visit_date,                                                              -- 最近到访日期
    order_qty,                                                                    -- 累计订单数
    visit_qty,                                                                    -- 累计到访次数
    visit_scenic_qty,                                                             -- 累计到访景区数
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time           -- ETL 加载时间
FROM m;

INSERT OVERWRITE TABLE dim.dim_cus_tourist_df                                     -- 整表覆盖写入
SELECT * FROM tmp.dim_cus_tourist_df_${bizdate};

DROP TABLE IF EXISTS tmp.dim_cus_tourist_df_${bizdate};
