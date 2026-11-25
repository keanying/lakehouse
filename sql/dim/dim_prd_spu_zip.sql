-- dim.dim_prd_spu_zip  产品(SPU)维度
-- 粒度：1行=1个SPU×1个有效区间
-- 来源：ods_prd_spu_df
-- 生成方式：Spark SQL / Hive（拉链表）；字段 12 个：直接翻译 12 · 规则翻译 0 · 待确认 0
-- 拉链：比对今日源数据与昨日拉链的行哈希，变化的旧版本闭链、新版本开链；源为全量快照，消失的主键闭链

WITH src AS (                               -- 今日最新状态
  SELECT
    a.id AS spu_id,                         -- SPUID（源表主键 id）
    a.spu_no AS spu_no,                     -- SPU编号
    a.tenant_id AS tenant_id,               -- 归属商户ID
    a.product_type AS product_type,         -- 产品类型（平台字典）
    a.spu_name AS spu_name,                 -- 产品名称
    a.poi_id AS poi_id,                     -- 关联POI ID
    a.cover_image AS cover_image_url_desc,  -- 封面图URL
    a.spu_status AS spu_status,             -- 状态
    a.create_time AS create_time,           -- 创建时间
    a.update_time AS update_time,           -- 更新时间
    j1.tenant_name AS tenant_name           -- 所属商户名称
  FROM ods.ods_prd_spu_df a                 -- 主表「SPU」
  LEFT JOIN dim.dim_sup_tenant_zip j1       -- 关联「租户（商户/供应商/分销商）维度」，取 所属商户名称
    ON j1.tenant_id = a.tenant_id           -- 按 tenant_id 关联
   AND j1.travel_date = '${bizdate}' AND j1.end_date = '9999-12-31'  -- 取当日分区里的拉链当前有效版本
  WHERE a.travel_date = '${bizdate}'        -- 只取当日分区
),
src_h AS (SELECT s.*, MD5(CONCAT_WS('|', CAST(spu_no AS STRING), CAST(tenant_id AS STRING), CAST(product_type AS STRING), CAST(spu_name AS STRING), CAST(poi_id AS STRING), CAST(cover_image_url_desc AS STRING), CAST(spu_status AS STRING), CAST(create_time AS STRING), CAST(update_time AS STRING), CAST(tenant_name AS STRING))) AS row_hash FROM src s),
his AS (                                    -- 昨日拉链
  SELECT h.*, MD5(CONCAT_WS('|', CAST(h.spu_no AS STRING), CAST(h.tenant_id AS STRING), CAST(h.product_type AS STRING), CAST(h.spu_name AS STRING), CAST(h.poi_id AS STRING), CAST(h.cover_image_url_desc AS STRING), CAST(h.spu_status AS STRING), CAST(h.create_time AS STRING), CAST(h.update_time AS STRING), CAST(h.tenant_name AS STRING))) AS row_hash
  FROM dim.dim_prd_spu_zip h
  WHERE h.travel_date = '${bizdate_prev}'
)
INSERT OVERWRITE TABLE dim.dim_prd_spu_zip PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
-- ① 历史记录：当前有效版本若有变化或已删除则闭链（结束日 = 昨天）
SELECT h.spu_id, h.spu_no, h.tenant_id, h.product_type, h.spu_name, h.poi_id, h.cover_image_url_desc, h.spu_status, h.create_time, h.update_time, h.tenant_name,
  h.start_date,
  CASE WHEN h.end_date = '9999-12-31' AND (s.row_hash IS NULL OR s.row_hash <> h.row_hash)
       THEN '${bizdate_prev_dash}' ELSE h.end_date END AS end_date,  -- 拉链结束日期
  CURRENT_TIMESTAMP() AS etl_time           -- ETL 加载时间
FROM his h
LEFT JOIN src_h s ON s.spu_id = h.spu_id
UNION ALL                                   -- 合并各来源
-- ② 新增或变化的记录开新链（开始日 = 今天，结束日 = 9999-12-31）
SELECT s.spu_id, s.spu_no, s.tenant_id, s.product_type, s.spu_name, s.poi_id, s.cover_image_url_desc, s.spu_status, s.create_time, s.update_time, s.tenant_name,
  '${bizdate_dash}' AS start_date,          -- 拉链开始日期
  '9999-12-31' AS end_date,                 -- 拉链结束日期
  CURRENT_TIMESTAMP() AS etl_time           -- ETL 加载时间
FROM src_h s
LEFT JOIN his h ON h.spu_id = s.spu_id AND h.end_date = '9999-12-31'
WHERE h.spu_id IS NULL OR h.row_hash <> s.row_hash;
