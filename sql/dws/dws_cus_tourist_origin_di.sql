-- dws.dws_cus_tourist_origin_di  游客客源画像日汇总
-- 粒度：travel_date × seller_tenant_id × sku_id × origin_province_code × origin_city_code × age_band_code × gender_type
-- 来源：dwd_ord_ticket_person_di, dwd_ord_verify_di, dwd_ord_ticket_di
-- 生成方式：Spark SQL / Hive；字段 19 个：直接翻译 6 · 规则翻译 13 · 待确认 0
-- 多来源：每个来源先按粒度键预聚合，UNION ALL 后再汇总

WITH
src_ticket_person AS (                            -- 来源「票游客明细」按粒度键预聚合
  SELECT
    seller_tenant_id AS seller_tenant_id,         -- 卖家租户ID
    sku_id AS sku_id,                             -- SKU ID
    origin_province_code AS origin_province_code,  -- 客源省份编码
    origin_city_code AS origin_city_code,         -- 客源城市编码
    age_band_code AS age_band_code,               -- 年龄段
    gender_type AS gender_type,                   -- 性别
    COUNT(ticket_no||person_id) AS tourist_qty,   -- 游客人数
    NULL AS verify_person_qty,                    -- 核销人次（入园人次）：本来源无，补空对齐 UNION ALL
    COUNT(CASE WHEN global_customer_id>0 THEN 1 END) AS person_linked_qty,  -- 已关联会员的游客数
    COUNT(CASE WHEN person_qty>0 THEN ticket_no END) AS realname_ticket_qty,  -- 实名票数
    NULL AS issue_ticket_qty                      -- 出票张数：本来源无，补空对齐 UNION ALL
  FROM dwd.dwd_ord_ticket_person_di s             -- 来源表「票游客明细」
  WHERE s.travel_date = '${bizdate}'              -- 只取当日分区
  GROUP BY seller_tenant_id, sku_id, origin_province_code, origin_city_code, age_band_code, gender_type  -- 按粒度键汇总
),
src_verify AS (                                   -- 来源「核销明细（权益级）」按粒度键预聚合
  SELECT
    seller_tenant_id AS seller_tenant_id,         -- 卖家租户ID
    sku_id AS sku_id,                             -- SKU ID
    CAST(NULL AS STRING) AS origin_province_code,  -- 客源省份编码：本来源无，补空对齐 UNION ALL
    CAST(NULL AS STRING) AS origin_city_code,     -- 客源城市编码：本来源无，补空对齐 UNION ALL
    CAST(NULL AS STRING) AS age_band_code,        -- 年龄段：本来源无，补空对齐 UNION ALL
    CAST(NULL AS STRING) AS gender_type,          -- 性别：本来源无，补空对齐 UNION ALL
    NULL AS tourist_qty,                          -- 游客人数：本来源无，补空对齐 UNION ALL
    COUNT(CASE WHEN verify_result_type = 'SUCCESS' THEN verify_no END) AS verify_person_qty,  -- 核销人次（入园人次）
    NULL AS person_linked_qty,                    -- 已关联会员的游客数：本来源无，补空对齐 UNION ALL
    NULL AS realname_ticket_qty,                  -- 实名票数：本来源无，补空对齐 UNION ALL
    NULL AS issue_ticket_qty                      -- 出票张数：本来源无，补空对齐 UNION ALL
  FROM dwd.dwd_ord_verify_di s                    -- 来源表「核销明细（权益级）」
  WHERE s.travel_date = '${bizdate}'              -- 只取当日分区
  GROUP BY seller_tenant_id, sku_id               -- 按粒度键汇总
),
src_ticket AS (                                   -- 来源「票明细（出票）」按粒度键预聚合
  SELECT
    seller_tenant_id AS seller_tenant_id,         -- 卖家租户ID
    sku_id AS sku_id,                             -- SKU ID
    CAST(NULL AS STRING) AS origin_province_code,  -- 客源省份编码：本来源无，补空对齐 UNION ALL
    CAST(NULL AS STRING) AS origin_city_code,     -- 客源城市编码：本来源无，补空对齐 UNION ALL
    CAST(NULL AS STRING) AS age_band_code,        -- 年龄段：本来源无，补空对齐 UNION ALL
    CAST(NULL AS STRING) AS gender_type,          -- 性别：本来源无，补空对齐 UNION ALL
    NULL AS tourist_qty,                          -- 游客人数：本来源无，补空对齐 UNION ALL
    NULL AS verify_person_qty,                    -- 核销人次（入园人次）：本来源无，补空对齐 UNION ALL
    NULL AS person_linked_qty,                    -- 已关联会员的游客数：本来源无，补空对齐 UNION ALL
    NULL AS realname_ticket_qty,                  -- 实名票数：本来源无，补空对齐 UNION ALL
    COUNT(ticket_no) AS issue_ticket_qty          -- 出票张数
  FROM dwd.dwd_ord_ticket_di s                    -- 来源表「票明细（出票）」
  WHERE s.travel_date = '${bizdate}'              -- 只取当日分区
  GROUP BY seller_tenant_id, sku_id               -- 按粒度键汇总
),
all_src AS (                                      -- 各来源字段已对齐，UNION ALL 合并（比多表 FULL JOIN 少 shuffle）
  SELECT * FROM src_ticket_person
  UNION ALL
  SELECT * FROM src_verify
  UNION ALL
  SELECT * FROM src_ticket
)
INSERT OVERWRITE TABLE dws.dws_cus_tourist_origin_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  u.seller_tenant_id,                             -- 卖家租户ID
  u.sku_id,                                       -- SKU ID
  u.origin_province_code,                         -- 客源省份编码
  u.origin_city_code,                             -- 客源城市编码
  u.age_band_code,                                -- 年龄段
  u.gender_type,                                  -- 性别
  SUM(u.tourist_qty) AS tourist_qty,              -- 游客人数
  SUM(u.verify_person_qty) AS verify_person_qty,  -- 核销人次（入园人次）
  SUM(u.person_linked_qty) AS person_linked_qty,  -- 已关联会员的游客数
  SUM(u.realname_ticket_qty) AS realname_ticket_qty,  -- 实名票数
  SUM(u.issue_ticket_qty) AS issue_ticket_qty,    -- 出票张数
  CURRENT_TIMESTAMP() AS etl_time                 -- ETL 加载时间
FROM all_src u
GROUP BY u.seller_tenant_id,                      -- 按粒度键汇总
         u.sku_id,                                -- SKU ID
         u.origin_province_code,                  -- 客源省份编码
         u.origin_city_code,                      -- 客源城市编码
         u.age_band_code,                         -- 年龄段
         u.gender_type;
