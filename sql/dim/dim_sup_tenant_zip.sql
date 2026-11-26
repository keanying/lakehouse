-- dim.dim_sup_tenant_zip  租户（商户/供应商/分销商）维度
-- 粒度：1行=1个租户×1个有效区间
-- 来源：ods_sup_tenant_df + ods_sup_tenant_config_df + ods_opr_package_subscription_di
-- 生成方式：Spark SQL / Hive（拉链表）；字段 22 个：直接翻译 19 · 规则翻译 2 · 待确认 1
-- 拉链：比对今日源数据与昨日拉链的行哈希，变化的旧版本闭链、新版本开链；源为全量快照，消失的主键闭链
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

WITH
tenant_src AS (                                                 -- 主表「租户」，只取用到的列
  SELECT auth_status, business_types, contact_phone, country_code, create_time, id, region_id,
         region_path, register_source, tenant_name, tenant_no, tenant_status, tenant_type, update_time
  FROM ods.ods_sup_tenant_df
  WHERE travel_date = '${bizdate}'                              -- 只取当日分区
),
region_dim AS (                                                 -- 「地区维度」当日数据，只取用到的列
  SELECT country_code, country_name
  FROM dim.dim_opr_region_f
),
region_dim_2 AS (                                               -- 「地区维度」当日数据，只取用到的列
  SELECT city_name, province_name, region_id
  FROM dim.dim_opr_region_f
),
tenant_config_max AS (                                          -- 「租户配置KV」按 tenant_id 预聚合
  SELECT tenant_id, MAX(config_value) AS v
  FROM ods.ods_sup_tenant_config_df
  WHERE travel_date = '${bizdate}' AND config_key = 'CURRENCY'  -- 只取当日分区，并按条件过滤
  GROUP BY tenant_id                                            -- 按粒度键汇总
),
tenant_config_max_2 AS (                                        -- 「租户配置KV」按 tenant_id 预聚合
  SELECT tenant_id, MAX(config_value) AS v
  FROM ods.ods_sup_tenant_config_df
  WHERE travel_date = '${bizdate}' AND config_key = 'LOCALE'    -- 只取当日分区，并按条件过滤
  GROUP BY tenant_id                                            -- 按粒度键汇总
),
package_subscription_rn AS (                                    -- 「套餐订购」当日增量，同一主键按 binlog 时间倒序编号
  SELECT expire_at, id, package_id, tenant_id, binlog_op_type,
         ROW_NUMBER() OVER (PARTITION BY id ORDER BY binlog_time DESC) AS rn  -- 同一主键多次变更，按 binlog 时间倒序编号
  FROM ods.ods_opr_package_subscription_di
  WHERE travel_date = '${bizdate}'                              -- 只取当日分区
),
package_subscription_latest AS (                                -- 「套餐订购」每个主键只保留最新一条，剔除已删除记录
  SELECT expire_at, id, package_id, tenant_id
  FROM package_subscription_rn
  WHERE rn = 1
    AND binlog_op_type <> 'DELETE'                              -- 剔除源库已删除的记录
),
src AS (                                                        -- 今日最新状态（与拉链字段一一对应）
  SELECT /*+ BROADCAST(region_dim, region_dim_2) */ 
    tenant_src.id                          AS tenant_id,        -- 租户ID（源表主键 id）
    tenant_src.tenant_no                   AS tenant_no,        -- 租户编号
    tenant_src.tenant_name                 AS tenant_name,      -- 租户名称
    tenant_src.tenant_type                 AS tenant_type,      -- 租户类型
    tenant_src.contact_phone               AS contact_phone_no,  -- 联系人手机号（脱敏）
    tenant_src.country_code                AS country_code,     -- 国家码 ISO 3166-1(如 CN
    tenant_src.region_id                   AS region_id,        -- 最末级地区ID
    tenant_src.region_path                 AS region_path_desc,  -- 行政区划完整路径(冗余
    tenant_src.business_types              AS business_type_list_desc,  -- 业态列表(多选)
    tenant_src.auth_status                 AS auth_status,      -- 认证状态
    tenant_src.register_source             AS register_source_code,  -- 租户来源
    tenant_src.tenant_status               AS tenant_status,    -- 状态
    tenant_src.create_time                 AS create_time,      -- 创建时间
    tenant_src.update_time                 AS update_time,      -- 更新时间
    region_dim.country_name                AS country_name,     -- 国家名称
    region_dim_2.province_name             AS province_name,    -- 省份名称
    region_dim_2.city_name                 AS city_name,        -- 城市名称
    tenant_config_max.v                    AS currency_code,    -- 结算币种
    tenant_config_max_2.v                  AS locale_code,      -- 默认语言
    package_subscription_latest.package_id AS package_id,       -- 当前生效套餐ID｜待确认：ods_opr_package_subscription_di.package_id 取生效中最新一笔
    package_subscription_latest.expire_at  AS package_expire_time  -- 当前套餐到期时间
  FROM tenant_src
  LEFT JOIN region_dim                                          -- 关联「地区维度」，取 国家名称
    ON region_dim.country_code = tenant_src.country_code        -- 按 country_code 关联
  LEFT JOIN region_dim_2                                        -- 关联「地区维度」，取 省份名称、城市名称
    ON region_dim_2.region_id = tenant_src.region_id            -- 按 region_id 关联
  LEFT JOIN tenant_config_max                                   -- 关联「租户配置KV」，取 结算币种
    ON tenant_config_max.tenant_id = tenant_src.id              -- 按 id→tenant_id 关联
  LEFT JOIN tenant_config_max_2                                 -- 关联「租户配置KV」，取 默认语言
    ON tenant_config_max_2.tenant_id = tenant_src.id            -- 按 id→tenant_id 关联
  LEFT JOIN package_subscription_latest                         -- 关联「套餐订购」，取 当前生效套餐ID、当前套餐到期时间
    ON package_subscription_latest.tenant_id = tenant_src.id    -- 按 id→tenant_id 关联
),
src_hash AS (                                                   -- 今日状态的行哈希（比较是否变化）
  SELECT s.*, MD5(CONCAT_WS('|', CAST(tenant_no AS STRING), CAST(tenant_name AS STRING), CAST(tenant_type AS STRING), CAST(contact_phone_no AS STRING), CAST(country_code AS STRING), CAST(region_id AS STRING), CAST(region_path_desc AS STRING), CAST(business_type_list_desc AS STRING), CAST(auth_status AS STRING), CAST(register_source_code AS STRING), CAST(tenant_status AS STRING), CAST(create_time AS STRING), CAST(update_time AS STRING), CAST(country_name AS STRING), CAST(province_name AS STRING), CAST(city_name AS STRING), CAST(currency_code AS STRING), CAST(locale_code AS STRING), CAST(package_id AS STRING), CAST(package_expire_time AS STRING))) AS row_hash
  FROM src s
),
his AS (                                                        -- 昨日拉链及其行哈希
  SELECT h.*, MD5(CONCAT_WS('|', CAST(h.tenant_no AS STRING), CAST(h.tenant_name AS STRING), CAST(h.tenant_type AS STRING), CAST(h.contact_phone_no AS STRING), CAST(h.country_code AS STRING), CAST(h.region_id AS STRING), CAST(h.region_path_desc AS STRING), CAST(h.business_type_list_desc AS STRING), CAST(h.auth_status AS STRING), CAST(h.register_source_code AS STRING), CAST(h.tenant_status AS STRING), CAST(h.create_time AS STRING), CAST(h.update_time AS STRING), CAST(h.country_name AS STRING), CAST(h.province_name AS STRING), CAST(h.city_name AS STRING), CAST(h.currency_code AS STRING), CAST(h.locale_code AS STRING), CAST(h.package_id AS STRING), CAST(h.package_expire_time AS STRING))) AS row_hash
  FROM dim.dim_sup_tenant_zip h
  WHERE h.travel_date = '${bizdate_prev}'
)
INSERT OVERWRITE TABLE dim.dim_sup_tenant_zip PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
-- ① 历史记录：当前有效版本若有变化或已删除则闭链（结束日 = 昨天）
SELECT h.tenant_id, h.tenant_no, h.tenant_name, h.tenant_type, h.contact_phone_no, h.country_code,
       h.region_id, h.region_path_desc, h.business_type_list_desc, h.auth_status,
       h.register_source_code, h.tenant_status, h.create_time, h.update_time, h.country_name,
       h.province_name, h.city_name, h.currency_code, h.locale_code, h.package_id,
       h.package_expire_time,                                   -- 当前套餐到期时间
  h.start_date,                                                 -- 拉链开始日期
  CASE WHEN h.end_date = '9999-12-31' AND (s.row_hash IS NULL OR s.row_hash <> h.row_hash)
       THEN '${bizdate_prev_dash}' ELSE h.end_date END AS end_date,  -- 拉链结束日期
  CURRENT_TIMESTAMP() AS etl_time                               -- ETL 加载时间
FROM his h
LEFT JOIN src_hash s ON s.tenant_id = h.tenant_id
UNION ALL
-- ② 新增或变化的记录开新链（开始日 = 今天，结束日 = 9999-12-31）
SELECT s.tenant_id, s.tenant_no, s.tenant_name, s.tenant_type, s.contact_phone_no, s.country_code,
       s.region_id, s.region_path_desc, s.business_type_list_desc, s.auth_status,
       s.register_source_code, s.tenant_status, s.create_time, s.update_time, s.country_name,
       s.province_name, s.city_name, s.currency_code, s.locale_code, s.package_id,
       s.package_expire_time,                                   -- 当前套餐到期时间
  '${bizdate_dash}' AS start_date,                              -- 拉链开始日期
  '9999-12-31' AS end_date,                                     -- 拉链结束日期
  CURRENT_TIMESTAMP() AS etl_time                               -- ETL 加载时间
FROM src_hash s
LEFT JOIN his h ON h.tenant_id = s.tenant_id AND h.end_date = '9999-12-31'
WHERE h.tenant_id IS NULL OR h.row_hash <> s.row_hash;
