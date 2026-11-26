-- dim.dim_prd_sku_zip  SKU维度
-- 粒度：1行=1个SKU×1个有效区间
-- 来源：ods_prd_sku_df + ods_prd_spu_df, dim_prd_spu_zip, dim_prd_sale_rule_df
-- 生成方式：Spark SQL / Hive（拉链表）；字段 22 个：直接翻译 19 · 规则翻译 3 · 待确认 0
-- 拉链：比对今日源数据与昨日拉链的行哈希，变化的旧版本闭链、新版本开链；源为全量快照，消失的主键闭链

WITH
sku_src AS (                                               -- 主表「SKU」，只取用到的列
  SELECT cost_price, create_time, id, sale_channels, sale_mode, sku_name, sku_no, sku_status, spu_id,
         tags, tenant_id, update_time, version
  FROM ods.ods_prd_sku_df
  WHERE travel_date = '${bizdate}'                         -- 只取当日分区
),
spu_src AS (                                               -- 「SPU」当日数据，只取用到的列
  SELECT id, spu_no
  FROM ods.ods_prd_spu_df
  WHERE travel_date = '${bizdate}'                         -- 只取当日分区
),
spu_src_2 AS (                                             -- 「SPU」当日数据，只取用到的列
  SELECT id, poi_id, product_type, spu_name
  FROM ods.ods_prd_spu_df
  WHERE travel_date = '${bizdate}'                         -- 只取当日分区
),
tenant_cur AS (                                            -- 「租户（商户/供应商/分销商）维度」当前有效版本，只取用到的列
  SELECT tenant_id, tenant_name
  FROM dim.dim_sup_tenant_zip
  WHERE travel_date = '${bizdate}' AND end_date = '9999-12-31'  -- 取当日分区里的拉链当前有效版本
),
sale_rule_count AS (                                       -- 「售卖规则维度」按 sku_id 预聚合
  SELECT sku_id, COUNT(sale_rule_item_id) AS v
  FROM dim.dim_prd_sale_rule_df
  WHERE travel_date = '${bizdate}'                         -- 只取当日分区
  GROUP BY sku_id                                          -- 按粒度键汇总
),
sku_attr_max AS (                                          -- 「SKU票属性维度」按 sku_id 预聚合
  SELECT sku_id, MAX(attribute_value_code) AS v
  FROM dim.dim_prd_sku_attr_df
  WHERE travel_date = '${bizdate}' AND attribute_code = 'REAL_NAME'  -- 只取当日分区，并按条件过滤
  GROUP BY sku_id                                          -- 按粒度键汇总
),
sku_attr_max_2 AS (                                        -- 「SKU票属性维度」按 sku_id 预聚合
  SELECT sku_id, MAX(attribute_value_code) AS v
  FROM dim.dim_prd_sku_attr_df
  WHERE travel_date = '${bizdate}' AND attribute_code = 'REFUND_POLICY'  -- 只取当日分区，并按条件过滤
  GROUP BY sku_id                                          -- 按粒度键汇总
),
src AS (                                                   -- 今日最新状态（与拉链字段一一对应）
  SELECT 
    sku_src.id                         AS sku_id,          -- SKUID（源表主键 id）
    sku_src.sku_no                     AS sku_no,          -- SKU编号
    sku_src.spu_id                     AS spu_id,          -- 归属SPU ID
    sku_src.tenant_id                  AS tenant_id,       -- 归属商户ID
    sku_src.sku_name                   AS sku_name,        -- SKU名称（如"成人票""VIP套票"）
    ROUND(sku_src.cost_price / 100, 2) AS cost_price_amt,  -- 成本价（元）——供应商商品属性
    sku_src.sale_mode                  AS sale_mode_type,  -- 售卖模式
    sku_src.version                    AS version_no,      -- 版本号
    sku_src.sku_status                 AS sku_status,      -- 状态
    sku_src.tags                       AS tag_list_desc,   -- 标签列表（商户自定义）
    sku_src.sale_channels              AS sale_channel_list_desc,  -- 销售渠道列表
    sku_src.create_time                AS create_time,     -- 创建时间
    sku_src.update_time                AS update_time,     -- 更新时间
    spu_src.spu_no                     AS spu_no,          -- SPU 编号
    spu_src_2.spu_name                 AS spu_name,        -- 产品名称
    spu_src_2.product_type             AS product_type,    -- 产品业态
    spu_src_2.poi_id                   AS poi_id,          -- POI ID（景区/场馆）
    tenant_cur.tenant_name             AS tenant_name,     -- 所属商户名称
    COALESCE(sale_rule_count.v, 0)     AS sale_rule_qty,   -- 生效中的售卖规则数
    sku_attr_max.v                     AS real_name_policy_code,  -- 实名制策略
    sku_attr_max_2.v                   AS refund_policy_code  -- 退改策略
  FROM sku_src
  LEFT JOIN spu_src                                        -- 关联「SPU」，取 SPU 编号
    ON spu_src.id = sku_src.spu_id                         -- 按 spu_id→id 关联
  LEFT JOIN spu_src_2                                      -- 关联「SPU」，取 产品名称、产品业态、POI ID（景区/场馆）
    ON spu_src_2.id = sku_src.tenant_id                    -- 按 tenant_id→id 关联
  LEFT JOIN tenant_cur                                     -- 关联「租户（商户/供应商/分销商）维度」，取 所属商户名称
    ON tenant_cur.tenant_id = sku_src.tenant_id            -- 按 tenant_id 关联
  LEFT JOIN sale_rule_count                                -- 关联「售卖规则维度」，取 生效中的售卖规则数
    ON sale_rule_count.sku_id = sku_src.id                 -- 按 id→sku_id 关联
  LEFT JOIN sku_attr_max                                   -- 关联「SKU票属性维度」，取 实名制策略
    ON sku_attr_max.sku_id = sku_src.id                    -- 按 id→sku_id 关联
  LEFT JOIN sku_attr_max_2                                 -- 关联「SKU票属性维度」，取 退改策略
    ON sku_attr_max_2.sku_id = sku_src.id                  -- 按 id→sku_id 关联
),
src_hash AS (                                              -- 今日状态的行哈希（比较是否变化）
  SELECT s.*, MD5(CONCAT_WS('|', CAST(sku_no AS STRING), CAST(spu_id AS STRING), CAST(tenant_id AS STRING), CAST(sku_name AS STRING), CAST(cost_price_amt AS STRING), CAST(sale_mode_type AS STRING), CAST(version_no AS STRING), CAST(sku_status AS STRING), CAST(tag_list_desc AS STRING), CAST(sale_channel_list_desc AS STRING), CAST(create_time AS STRING), CAST(update_time AS STRING), CAST(spu_no AS STRING), CAST(spu_name AS STRING), CAST(product_type AS STRING), CAST(poi_id AS STRING), CAST(tenant_name AS STRING), CAST(sale_rule_qty AS STRING), CAST(real_name_policy_code AS STRING), CAST(refund_policy_code AS STRING))) AS row_hash
  FROM src s
),
his AS (                                                   -- 昨日拉链及其行哈希
  SELECT h.*, MD5(CONCAT_WS('|', CAST(h.sku_no AS STRING), CAST(h.spu_id AS STRING), CAST(h.tenant_id AS STRING), CAST(h.sku_name AS STRING), CAST(h.cost_price_amt AS STRING), CAST(h.sale_mode_type AS STRING), CAST(h.version_no AS STRING), CAST(h.sku_status AS STRING), CAST(h.tag_list_desc AS STRING), CAST(h.sale_channel_list_desc AS STRING), CAST(h.create_time AS STRING), CAST(h.update_time AS STRING), CAST(h.spu_no AS STRING), CAST(h.spu_name AS STRING), CAST(h.product_type AS STRING), CAST(h.poi_id AS STRING), CAST(h.tenant_name AS STRING), CAST(h.sale_rule_qty AS STRING), CAST(h.real_name_policy_code AS STRING), CAST(h.refund_policy_code AS STRING))) AS row_hash
  FROM dim.dim_prd_sku_zip h
  WHERE h.travel_date = '${bizdate_prev}'
)
INSERT OVERWRITE TABLE dim.dim_prd_sku_zip PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
-- ① 历史记录：当前有效版本若有变化或已删除则闭链（结束日 = 昨天）
SELECT h.sku_id, h.sku_no, h.spu_id, h.tenant_id, h.sku_name, h.cost_price_amt, h.sale_mode_type,
       h.version_no, h.sku_status, h.tag_list_desc, h.sale_channel_list_desc, h.create_time,
       h.update_time, h.spu_no, h.spu_name, h.product_type, h.poi_id, h.tenant_name, h.sale_rule_qty,
       h.real_name_policy_code, h.refund_policy_code,
  h.start_date,                                            -- 拉链开始日期
  CASE WHEN h.end_date = '9999-12-31' AND (s.row_hash IS NULL OR s.row_hash <> h.row_hash)
       THEN '${bizdate_prev_dash}' ELSE h.end_date END AS end_date,  -- 拉链结束日期
  CURRENT_TIMESTAMP() AS etl_time                          -- ETL 加载时间
FROM his h
LEFT JOIN src_hash s ON s.sku_id = h.sku_id
UNION ALL
-- ② 新增或变化的记录开新链（开始日 = 今天，结束日 = 9999-12-31）
SELECT s.sku_id, s.sku_no, s.spu_id, s.tenant_id, s.sku_name, s.cost_price_amt, s.sale_mode_type,
       s.version_no, s.sku_status, s.tag_list_desc, s.sale_channel_list_desc, s.create_time,
       s.update_time, s.spu_no, s.spu_name, s.product_type, s.poi_id, s.tenant_name, s.sale_rule_qty,
       s.real_name_policy_code, s.refund_policy_code,
  '${bizdate_dash}' AS start_date,                         -- 拉链开始日期
  '9999-12-31' AS end_date,                                -- 拉链结束日期
  CURRENT_TIMESTAMP() AS etl_time                          -- ETL 加载时间
FROM src_hash s
LEFT JOIN his h ON h.sku_id = s.sku_id AND h.end_date = '9999-12-31'
WHERE h.sku_id IS NULL OR h.row_hash <> s.row_hash;
