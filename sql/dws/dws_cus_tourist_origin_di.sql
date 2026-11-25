-- dws.dws_cus_tourist_origin_di  游客客源画像日汇总
-- 粒度：travel_date × seller_tenant_id × sku_id × origin_province_code × origin_city_code × age_band_code × gender_type
-- 来源：dwd_ord_ticket_person_di, dwd_ord_verify_di, dwd_ord_ticket_di
-- 生成方式：Spark SQL / Hive；字段 19 个：直接翻译 6 · 规则翻译 4 · 待确认 9
-- 多来源：每个来源表按粒度键先汇总，UNION ALL 后再合并
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT OVERWRITE TABLE dws.dws_cus_tourist_origin_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  u.seller_tenant_id,                              -- 卖家租户ID
  u.sku_id,                                        -- SKU ID
  u.origin_province_code,                          -- 客源省份编码
  u.origin_city_code,                              -- 客源城市编码
  u.age_band_code,                                 -- 年龄段
  u.gender_type,                                   -- 性别
  SUM(u.tourist_qty) AS tourist_qty,               -- 游客人数
  SUM(u.verify_person_qty) AS verify_person_qty,   -- 核销人次（入园人次）
  SUM(u.person_linked_qty) AS person_linked_qty,   -- 已关联会员的游客数
  SUM(u.realname_ticket_qty) AS realname_ticket_qty,  -- 实名票数
  SUM(u.issue_ticket_qty) AS issue_ticket_qty,     -- 出票张数
  CURRENT_TIMESTAMP() AS etl_time                  -- ETL 加载时间
FROM (
  -- 来源：dwd_ord_ticket_person_di
  SELECT
    seller_tenant_id AS seller_tenant_id,          -- 卖家租户ID
    sku_id AS sku_id,                              -- SKU ID
    origin_province_code AS origin_province_code,  -- 客源省份编码
    origin_city_code AS origin_city_code,          -- 客源城市编码
    age_band_code AS age_band_code,                -- 年龄段
    gender_type AS gender_type,                    -- 性别
    COUNT(ticket_no||person_id) AS tourist_qty,    -- 游客人数
    NULL AS verify_person_qty,                     -- 核销人次（入园人次）
    COUNT(CASE WHEN global_customer_id>0 THEN 1 END) AS person_linked_qty,  -- 已关联会员的游客数
    COUNT(CASE WHEN person_qty>0 THEN ticket_no END) AS realname_ticket_qty,  -- 实名票数
    NULL AS issue_ticket_qty                       -- 出票张数
  FROM dwd.dwd_ord_ticket_person_di s              -- 来源表「票游客明细」
  WHERE s.travel_date = '${bizdate}'               -- 只取当日分区
  GROUP BY seller_tenant_id, sku_id, origin_province_code, origin_city_code, age_band_code, gender_type  -- 按粒度键汇总
  UNION ALL                                        -- 合并各来源
  -- 来源：dwd_ord_verify_di
  SELECT
    seller_tenant_id AS seller_tenant_id,          -- 卖家租户ID
    sku_id AS sku_id,                              -- SKU ID
    CAST(NULL AS STRING) AS origin_province_code,  -- 客源省份编码
    CAST(NULL AS STRING) AS origin_city_code,      -- 客源城市编码
    CAST(NULL AS STRING) AS age_band_code,         -- 年龄段
    CAST(NULL AS STRING) AS gender_type,           -- 性别
    NULL AS tourist_qty,                           -- 游客人数
    COUNT(CASE WHEN 1 = 1 THEN verify_no END) AS verify_person_qty,  -- 核销人次（入园人次）｜待确认：SUCCESS（待补放行人数后改 sum(pass_count)）
    NULL AS person_linked_qty,                     -- 已关联会员的游客数
    NULL AS realname_ticket_qty,                   -- 实名票数
    NULL AS issue_ticket_qty                       -- 出票张数
  FROM dwd.dwd_ord_verify_di s                     -- 来源表「核销明细（权益级）」
  WHERE s.travel_date = '${bizdate}'               -- 只取当日分区
  GROUP BY seller_tenant_id, sku_id                -- 按粒度键汇总
  UNION ALL                                        -- 合并各来源
  -- 来源：dwd_ord_ticket_di
  SELECT
    seller_tenant_id AS seller_tenant_id,          -- 卖家租户ID
    sku_id AS sku_id,                              -- SKU ID
    CAST(NULL AS STRING) AS origin_province_code,  -- 客源省份编码
    CAST(NULL AS STRING) AS origin_city_code,      -- 客源城市编码
    CAST(NULL AS STRING) AS age_band_code,         -- 年龄段
    CAST(NULL AS STRING) AS gender_type,           -- 性别
    NULL AS tourist_qty,                           -- 游客人数
    NULL AS verify_person_qty,                     -- 核销人次（入园人次）
    NULL AS person_linked_qty,                     -- 已关联会员的游客数
    NULL AS realname_ticket_qty,                   -- 实名票数
    COUNT(ticket_no) AS issue_ticket_qty           -- 出票张数
  FROM dwd.dwd_ord_ticket_di s                     -- 来源表「票明细（出票）」
  WHERE s.travel_date = '${bizdate}'               -- 只取当日分区
  GROUP BY seller_tenant_id, sku_id                -- 按粒度键汇总
) u                                                -- 各来源合并后的明细
GROUP BY u.seller_tenant_id, u.sku_id, u.origin_province_code, u.origin_city_code, u.age_band_code, u.gender_type;  -- 按粒度键汇总
