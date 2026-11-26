-- ads.ads_cus_tourist_portrait_di  游客客源画像
-- 粒度：travel_date × seller_tenant_id × origin_province_code × age_band_code × gender_type
-- 来源：dws_cus_tourist_origin_di
-- 生成方式：Spark SQL / Hive；字段 14 个：直接翻译 14 · 规则翻译 0 · 待确认 0
-- 来源先按粒度键预聚合

WITH
src_tourist_origin AS (                                  -- 来源「游客客源画像日汇总」按粒度键预聚合
  SELECT
    seller_tenant_id AS seller_tenant_id,                -- 卖家租户ID
    origin_province_code AS origin_province_code,        -- 客源省份编码
    age_band_code AS age_band_code,                      -- 年龄段
    gender_type AS gender_type,                          -- 性别
    SUM(tourist_qty) AS tourist_qty,                     -- 游客人数（日）
    SUM(verify_person_qty) AS verify_person_qty,         -- 核销人次（入园人次）（日）
    SUM(tourist_qty) AS tourist_origin_share_numerator_qty,  -- 客源地占比分子（日）
    SUM(tourist_qty) AS tourist_origin_share_denominator_qty,  -- 客源地占比分母（日）
    SUM(realname_ticket_qty) AS realname_numerator_qty,  -- 实名率分子（日）
    SUM(issue_ticket_qty) AS realname_denominator_qty,   -- 实名率分母（日）
    SUM(person_linked_qty) AS person_link_numerator_qty,  -- 游客会员关联率分子（日）
    SUM(tourist_qty) AS person_link_denominator_qty      -- 游客会员关联率分母（日）
  FROM dws.dws_cus_tourist_origin_di s                   -- 来源表「游客客源画像日汇总」
  WHERE s.travel_date = '${bizdate}'                     -- 只取当日分区
  GROUP BY seller_tenant_id, origin_province_code, age_band_code, gender_type  -- 按粒度键汇总
),
merged AS (                                              -- 按粒度键汇总，计算派生指标
  SELECT
    u.seller_tenant_id,                                  -- 卖家租户ID
    u.origin_province_code,                              -- 客源省份编码
    u.age_band_code,                                     -- 年龄段
    u.gender_type,                                       -- 性别
    u.tourist_qty,                                       -- 游客人数（日）
    u.verify_person_qty,                                 -- 核销人次（入园人次）（日）
    u.tourist_origin_share_numerator_qty,                -- 客源地占比分子（日）
    u.tourist_origin_share_denominator_qty,              -- 客源地占比分母（日）
    u.realname_numerator_qty,                            -- 实名率分子（日）
    u.realname_denominator_qty,                          -- 实名率分母（日）
    u.person_link_numerator_qty,                         -- 游客会员关联率分子（日）
    u.person_link_denominator_qty,                       -- 游客会员关联率分母（日）
    CURRENT_TIMESTAMP() AS etl_time                      -- ETL 加载时间
  FROM src_tourist_origin u
),
tenant_cur AS (                                          -- 「租户（商户/供应商/分销商）维度」当前有效版本，只取名称类字段
  SELECT tenant_id, tenant_name
  FROM dim.dim_sup_tenant_zip
  WHERE travel_date = '${bizdate}' AND end_date = '9999-12-31'  -- 取当日分区里的拉链当前有效版本
),
region_dim AS (                                          -- 「地区维度」当日数据，只取名称类字段
  SELECT region_id, province_name
  FROM dim.dim_opr_region_f
)
INSERT OVERWRITE TABLE ads.ads_cus_tourist_portrait_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT  /*+ BROADCAST(region_dim) */
  merged.seller_tenant_id,                               -- 卖家租户ID
  merged.origin_province_code,                           -- 客源省份编码
  merged.age_band_code,                                  -- 年龄段
  merged.gender_type,                                    -- 性别
  tenant_cur.tenant_name AS seller_tenant_name,          -- 卖家租户名称
  region_dim.province_name AS origin_province_name,      -- 客源省份名称
  merged.tourist_qty,                                    -- 游客人数（日）
  merged.verify_person_qty,                              -- 核销人次（入园人次）（日）
  merged.tourist_origin_share_numerator_qty,             -- 客源地占比分子（日）
  merged.tourist_origin_share_denominator_qty,           -- 客源地占比分母（日）
  merged.realname_numerator_qty,                         -- 实名率分子（日）
  merged.realname_denominator_qty,                       -- 实名率分母（日）
  merged.person_link_numerator_qty,                      -- 游客会员关联率分子（日）
  merged.person_link_denominator_qty,                    -- 游客会员关联率分母（日）
  merged.etl_time                                        -- ETL 加载时间
FROM merged
LEFT JOIN tenant_cur                                     -- 关联「租户（商户/供应商/分销商）维度」，补 seller_tenant_name
  ON tenant_cur.tenant_id = merged.seller_tenant_id      -- 按 seller_tenant_id→tenant_id 关联
LEFT JOIN region_dim                                     -- 关联「地区维度」，补 origin_province_name
  ON region_dim.region_id = merged.origin_province_code;  -- 按 origin_province_code→region_id 关联
