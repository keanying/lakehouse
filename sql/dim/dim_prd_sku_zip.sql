-- dim.dim_prd_sku_zip  SKU维度
-- 粒度：1行=1个SKU×1个有效区间
-- 来源：ods_prd_sku_df + ods_prd_spu_df, dim_prd_spu_zip, dim_prd_sale_rule_df
-- 生成方式：Spark SQL / Hive（拉链表）；字段 22 个：直接翻译 19 · 规则翻译 3 · 待确认 0
-- 拉链：比对今日源数据与昨日拉链的行哈希，变化的旧版本闭链、新版本开链；源为全量快照，消失的主键闭链

WITH src AS (                                   -- 今日最新状态
  SELECT
    a.id AS sku_id,                             -- SKUID（源表主键 id）
    a.sku_no AS sku_no,                         -- SKU编号
    a.spu_id AS spu_id,                         -- 归属SPU ID
    a.tenant_id AS tenant_id,                   -- 归属商户ID
    a.sku_name AS sku_name,                     -- SKU名称（如"成人票""VIP套票"）
    ROUND(a.cost_price / 100, 2) AS cost_price_amt,  -- 成本价（元）——供应商商品属性
    a.sale_mode AS sale_mode_type,              -- 售卖模式
    a.version AS version_no,                    -- 版本号
    a.sku_status AS sku_status,                 -- 状态
    a.tags AS tag_list_desc,                    -- 标签列表（商户自定义）
    a.sale_channels AS sale_channel_list_desc,  -- 销售渠道列表
    a.create_time AS create_time,               -- 创建时间
    a.update_time AS update_time,               -- 更新时间
    j1.spu_no AS spu_no,                        -- SPU 编号
    j1.spu_name AS spu_name,                    -- 产品名称
    j1.product_type AS product_type,            -- 产品业态
    j1.poi_id AS poi_id,                        -- POI ID（景区/场馆）
    j2.tenant_name AS tenant_name,              -- 所属商户名称
    COALESCE(j3.v, 0) AS sale_rule_qty,         -- 生效中的售卖规则数
    j5.v AS real_name_policy_code,              -- 实名制策略
    j6.v AS refund_policy_code                  -- 退改策略
  FROM ods.ods_prd_sku_df a                     -- 主表「SKU」
  LEFT JOIN ods.ods_prd_spu_df j1               -- 关联「SPU」，取 SPU 编号、产品名称、产品业态、POI ID（景区/场馆）
    ON j1.id = a.spu_id                         -- 按 spu_id→id 关联
   AND j1.travel_date = '${bizdate}'            -- 只取当日分区
  LEFT JOIN dim.dim_sup_tenant_zip j2           -- 关联「租户（商户/供应商/分销商）维度」，取 所属商户名称
    ON j2.tenant_id = a.tenant_id               -- 按 tenant_id 关联
   AND j2.travel_date = '${bizdate}' AND j2.end_date = '9999-12-31'  -- 取当日分区里的拉链当前有效版本
  LEFT JOIN (SELECT sku_id, COUNT(sale_rule_item_id) AS v FROM dim.dim_prd_sale_rule_df WHERE travel_date = '${bizdate}' GROUP BY sku_id) j3  -- 关联「售卖规则维度」按键聚合，得到 生效中的售卖规则数
    ON j3.sku_id = a.id                         -- 按 id→sku_id 关联
  LEFT JOIN dim.dim_prd_sku_attr_df j4          -- 关联「SKU票属性维度」
    ON j4.sku_id = a.id                         -- 按 id→sku_id 关联
   AND j4.travel_date = '${bizdate}'            -- 只取当日分区
  LEFT JOIN (SELECT sku_id, MAX(attribute_value_code) AS v FROM dim.dim_prd_sku_attr_df WHERE travel_date = '${bizdate}' AND attribute_code = 'REAL_NAME' GROUP BY sku_id) j5  -- 关联「SKU票属性维度」按键聚合，得到 实名制策略
    ON j5.sku_id = a.id                         -- 按 id→sku_id 关联
  LEFT JOIN (SELECT sku_id, MAX(attribute_value_code) AS v FROM dim.dim_prd_sku_attr_df WHERE travel_date = '${bizdate}' AND attribute_code = 'REFUND_POLICY' GROUP BY sku_id) j6  -- 关联「SKU票属性维度」按键聚合，得到 退改策略
    ON j6.sku_id = a.id                         -- 按 id→sku_id 关联
  WHERE a.travel_date = '${bizdate}'            -- 只取当日分区
),
src_h AS (SELECT s.*, MD5(CONCAT_WS('|', CAST(sku_no AS STRING), CAST(spu_id AS STRING), CAST(tenant_id AS STRING), CAST(sku_name AS STRING), CAST(cost_price_amt AS STRING), CAST(sale_mode_type AS STRING), CAST(version_no AS STRING), CAST(sku_status AS STRING), CAST(tag_list_desc AS STRING), CAST(sale_channel_list_desc AS STRING), CAST(create_time AS STRING), CAST(update_time AS STRING), CAST(spu_no AS STRING), CAST(spu_name AS STRING), CAST(product_type AS STRING), CAST(poi_id AS STRING), CAST(tenant_name AS STRING), CAST(sale_rule_qty AS STRING), CAST(real_name_policy_code AS STRING), CAST(refund_policy_code AS STRING))) AS row_hash FROM src s),
his AS (                                        -- 昨日拉链
  SELECT h.*, MD5(CONCAT_WS('|', CAST(h.sku_no AS STRING), CAST(h.spu_id AS STRING), CAST(h.tenant_id AS STRING), CAST(h.sku_name AS STRING), CAST(h.cost_price_amt AS STRING), CAST(h.sale_mode_type AS STRING), CAST(h.version_no AS STRING), CAST(h.sku_status AS STRING), CAST(h.tag_list_desc AS STRING), CAST(h.sale_channel_list_desc AS STRING), CAST(h.create_time AS STRING), CAST(h.update_time AS STRING), CAST(h.spu_no AS STRING), CAST(h.spu_name AS STRING), CAST(h.product_type AS STRING), CAST(h.poi_id AS STRING), CAST(h.tenant_name AS STRING), CAST(h.sale_rule_qty AS STRING), CAST(h.real_name_policy_code AS STRING), CAST(h.refund_policy_code AS STRING))) AS row_hash
  FROM dim.dim_prd_sku_zip h
  WHERE h.travel_date = '${bizdate_prev}'
)
INSERT OVERWRITE TABLE dim.dim_prd_sku_zip PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
-- ① 历史记录：当前有效版本若有变化或已删除则闭链（结束日 = 昨天）
SELECT h.sku_id, h.sku_no, h.spu_id, h.tenant_id, h.sku_name, h.cost_price_amt, h.sale_mode_type, h.version_no, h.sku_status, h.tag_list_desc, h.sale_channel_list_desc, h.create_time, h.update_time, h.spu_no, h.spu_name, h.product_type, h.poi_id, h.tenant_name, h.sale_rule_qty, h.real_name_policy_code, h.refund_policy_code,
  h.start_date,
  CASE WHEN h.end_date = '9999-12-31' AND (s.row_hash IS NULL OR s.row_hash <> h.row_hash)
       THEN '${bizdate_prev_dash}' ELSE h.end_date END AS end_date,  -- 拉链结束日期
  CURRENT_TIMESTAMP() AS etl_time               -- ETL 加载时间
FROM his h
LEFT JOIN src_h s ON s.sku_id = h.sku_id
UNION ALL                                       -- 合并各来源
-- ② 新增或变化的记录开新链（开始日 = 今天，结束日 = 9999-12-31）
SELECT s.sku_id, s.sku_no, s.spu_id, s.tenant_id, s.sku_name, s.cost_price_amt, s.sale_mode_type, s.version_no, s.sku_status, s.tag_list_desc, s.sale_channel_list_desc, s.create_time, s.update_time, s.spu_no, s.spu_name, s.product_type, s.poi_id, s.tenant_name, s.sale_rule_qty, s.real_name_policy_code, s.refund_policy_code,
  '${bizdate_dash}' AS start_date,              -- 拉链开始日期
  '9999-12-31' AS end_date,                     -- 拉链结束日期
  CURRENT_TIMESTAMP() AS etl_time               -- ETL 加载时间
FROM src_h s
LEFT JOIN his h ON h.sku_id = s.sku_id AND h.end_date = '9999-12-31'
WHERE h.sku_id IS NULL OR h.row_hash <> s.row_hash;
