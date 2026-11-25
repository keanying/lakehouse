-- ads.ads_cus_tourist_portrait_di  游客客源画像
-- 粒度：travel_date × seller_tenant_id × origin_province_code × age_band_code × gender_type
-- 来源：dws_cus_tourist_origin_di
-- 生成方式：Spark SQL / Hive；字段 14 个：直接翻译 14 · 规则翻译 0 · 待确认 0

INSERT OVERWRITE TABLE ads.ads_cus_tourist_portrait_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  x.seller_tenant_id,                                                 -- 卖家租户ID
  x.origin_province_code,                                             -- 客源省份编码
  x.age_band_code,                                                    -- 年龄段
  x.gender_type,                                                      -- 性别
  d1.tenant_name AS seller_tenant_name,                               -- 卖家租户名称
  d2.province_name AS origin_province_name,                           -- 客源省份名称
  x.tourist_qty,                                                      -- 游客人数（日）
  x.verify_person_qty,                                                -- 核销人次（入园人次）（日）
  x.tourist_origin_share_numerator_qty,                               -- 客源地占比分子（日）
  x.tourist_origin_share_denominator_qty,                             -- 客源地占比分母（日）
  x.realname_numerator_qty,                                           -- 实名率分子（日）
  x.realname_denominator_qty,                                         -- 实名率分母（日）
  x.person_link_numerator_qty,                                        -- 游客会员关联率分子（日）
  x.person_link_denominator_qty,                                      -- 游客会员关联率分母（日）
  x.etl_time                                                          -- ETL 加载时间
FROM (
SELECT
  u.seller_tenant_id,                                                 -- 卖家租户ID
  u.origin_province_code,                                             -- 客源省份编码
  u.age_band_code,                                                    -- 年龄段
  u.gender_type,                                                      -- 性别
  SUM(u.tourist_qty) AS tourist_qty,                                  -- 游客人数（日）
  SUM(u.verify_person_qty) AS verify_person_qty,                      -- 核销人次（入园人次）（日）
  SUM(u.tourist_origin_share_numerator_qty) AS tourist_origin_share_numerator_qty,  -- 客源地占比分子（日）
  SUM(u.tourist_origin_share_denominator_qty) AS tourist_origin_share_denominator_qty,  -- 客源地占比分母（日）
  SUM(u.realname_numerator_qty) AS realname_numerator_qty,            -- 实名率分子（日）
  SUM(u.realname_denominator_qty) AS realname_denominator_qty,        -- 实名率分母（日）
  SUM(u.person_link_numerator_qty) AS person_link_numerator_qty,      -- 游客会员关联率分子（日）
  SUM(u.person_link_denominator_qty) AS person_link_denominator_qty,  -- 游客会员关联率分母（日）
  CURRENT_TIMESTAMP() AS etl_time                                     -- ETL 加载时间
FROM (
  -- 来源：dws_cus_tourist_origin_di
  SELECT
    seller_tenant_id AS seller_tenant_id,                             -- 卖家租户ID
    origin_province_code AS origin_province_code,                     -- 客源省份编码
    age_band_code AS age_band_code,                                   -- 年龄段
    gender_type AS gender_type,                                       -- 性别
    SUM(tourist_qty) AS tourist_qty,                                  -- 游客人数（日）
    SUM(verify_person_qty) AS verify_person_qty,                      -- 核销人次（入园人次）（日）
    SUM(tourist_qty) AS tourist_origin_share_numerator_qty,           -- 客源地占比分子（日）
    SUM(tourist_qty) AS tourist_origin_share_denominator_qty,         -- 客源地占比分母（日）
    SUM(realname_ticket_qty) AS realname_numerator_qty,               -- 实名率分子（日）
    SUM(issue_ticket_qty) AS realname_denominator_qty,                -- 实名率分母（日）
    SUM(person_linked_qty) AS person_link_numerator_qty,              -- 游客会员关联率分子（日）
    SUM(tourist_qty) AS person_link_denominator_qty                   -- 游客会员关联率分母（日）
  FROM dws.dws_cus_tourist_origin_di s                                -- 来源表「游客客源画像日汇总」
  WHERE s.travel_date = '${bizdate}'                                  -- 只取当日分区
  GROUP BY seller_tenant_id, origin_province_code, age_band_code, gender_type  -- 按粒度键汇总
) u                                                                   -- 各来源合并后的明细
GROUP BY u.seller_tenant_id, u.origin_province_code, u.age_band_code, u.gender_type  -- 按粒度键汇总
) x                                                                   -- 汇总结果，外层再补维度名称
LEFT JOIN dim.dim_sup_tenant_zip d1 ON d1.tenant_id = x.seller_tenant_id AND d1.travel_date = '${bizdate}' AND d1.end_date = '9999-12-31'  -- 关联「租户（商户/供应商/分销商）维度」，取维度名称
LEFT JOIN dim.dim_opr_region_f d2 ON d2.region_id = x.origin_province_code;  -- 关联「地区维度」，取维度名称
