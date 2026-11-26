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
WITH today AS (   -- 今日新增的游客明细（排除测试订单）
    SELECT id_card_hash AS tourist_key, id_card_type, gender, YEAR(CURRENT_DATE()) - age AS birth_year, province_code, city_code, phone_hash,
           SUBSTR(order_time, 1, 10) AS order_date, SUBSTR(verify_time, 1, 10) AS visit_date, order_no, scenic_id
    FROM dwd.dwd_ord_traveler_di
    WHERE travel_date = '${bizdate}' AND id_card_hash IS NOT NULL AND test_flag = 0
),
n AS (
    SELECT tourist_key, MAX(id_card_type) AS id_card_type, MAX(gender) AS gender, MAX(birth_year) AS birth_year,
           MAX(province_code) AS source_province_code, MAX(city_code) AS source_city_code, MAX(phone_hash) AS phone_hash,
           MIN(order_date) AS first_order_date, MAX(order_date) AS last_order_date,
           MIN(visit_date) AS first_visit_date, MAX(visit_date) AS last_visit_date,
           COUNT(DISTINCT order_no) AS order_qty, COUNT(visit_date) AS visit_qty,
           COUNT(DISTINCT IF(visit_date IS NOT NULL, scenic_id, NULL)) AS visit_scenic_qty
    FROM today
    GROUP BY tourist_key
),
auth AS (   -- 实名认证：tourist_info 证件号在 ODS 已哈希，取哈希段关联
    SELECT SUBSTRING_INDEX(i.certificate_no, '#', -1) AS tourist_key, MAX(IF(a.status = '1', 1, 0)) AS real_name_flag
    FROM ods.ods_cus_tourist_info_df i
    JOIN ods.ods_cus_tourist_auth_info_df a ON a.tourist_id = i.id AND a.travel_date = '${bizdate}'
    WHERE i.travel_date = '${bizdate}'
    GROUP BY SUBSTRING_INDEX(i.certificate_no, '#', -1)
),
m AS (
    SELECT
        COALESCE(n.tourist_key, h.tourist_key)                         AS tourist_key,
        COALESCE(n.id_card_type, h.id_card_type)                       AS id_card_type,
        COALESCE(h.gender, n.gender)                                   AS gender,
        COALESCE(h.birth_year, n.birth_year)                           AS birth_year,
        COALESCE(h.source_province_code, n.source_province_code)       AS source_province_code,
        COALESCE(h.source_city_code, n.source_city_code)               AS source_city_code,
        h.phone_province_code,                                         -- 待确认：维表只存手机号哈希，号段归属需在 DWD 单独带出后再累计
        COALESCE(n.phone_hash, h.phone_hash)                           AS phone_hash,           -- 取最近一次
        GREATEST(COALESCE(h.real_name_flag, 0), COALESCE(au.real_name_flag, 0)) AS real_name_flag,
        CASE WHEN h.first_order_date IS NULL OR n.first_order_date < h.first_order_date THEN n.first_order_date ELSE h.first_order_date END AS first_order_date,
        CASE WHEN h.last_order_date IS NULL OR n.last_order_date > h.last_order_date THEN n.last_order_date ELSE h.last_order_date END AS last_order_date,
        CASE WHEN h.first_visit_date IS NULL OR n.first_visit_date < h.first_visit_date THEN n.first_visit_date ELSE h.first_visit_date END AS first_visit_date,
        CASE WHEN h.last_visit_date IS NULL OR n.last_visit_date > h.last_visit_date THEN n.last_visit_date ELSE h.last_visit_date END AS last_visit_date,
        COALESCE(h.order_qty, 0) + COALESCE(n.order_qty, 0)            AS order_qty,
        COALESCE(h.visit_qty, 0) + COALESCE(n.visit_qty, 0)            AS visit_qty,
        -- 近似：跨日同一景区会重复计；精确去重需按 游客 × 景区 累计表
        COALESCE(h.visit_scenic_qty, 0) + COALESCE(n.visit_scenic_qty, 0) AS visit_scenic_qty
    FROM n
    FULL OUTER JOIN dim.dim_cus_tourist_df h ON h.tourist_key = n.tourist_key      -- 当前维表（昨日结果）
    LEFT JOIN auth au ON au.tourist_key = COALESCE(n.tourist_key, h.tourist_key)
)
SELECT
    tourist_key, id_card_type, gender, birth_year,
    CASE WHEN birth_year IS NULL THEN '未知' WHEN YEAR(CURRENT_DATE()) - birth_year <= 7 THEN '0-7' WHEN YEAR(CURRENT_DATE()) - birth_year <= 17 THEN '8-17' WHEN YEAR(CURRENT_DATE()) - birth_year <= 27 THEN '18-27'
         WHEN YEAR(CURRENT_DATE()) - birth_year <= 40 THEN '28-40' WHEN YEAR(CURRENT_DATE()) - birth_year <= 60 THEN '41-60' ELSE '61+' END AS age_group,
    source_province_code, source_city_code, phone_province_code, phone_hash, real_name_flag,
    first_order_date, last_order_date, first_visit_date, last_visit_date, order_qty, visit_qty, visit_scenic_qty,
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time
FROM m;

INSERT OVERWRITE TABLE dim.dim_cus_tourist_df
SELECT * FROM tmp.dim_cus_tourist_df_${bizdate};

DROP TABLE IF EXISTS tmp.dim_cus_tourist_df_${bizdate};
