-- dim.dim_prd_spu_zip  产品(SPU)维度
-- 粒度：1行=1个SPU×1个有效区间
-- 来源：ods_prd_spu_df
-- 生成方式：Spark SQL / Hive（拉链表）；字段 12 个：直接翻译 12 · 规则翻译 0 · 待确认 0
-- 拉链：比对今日源数据与昨日拉链的行哈希，变化的旧版本闭链、新版本开链；源为全量快照，消失的主键闭链

WITH src AS (                       -- 今日最新状态
  SELECT
    a.id AS spu_id,
    a.spu_no AS spu_no,
    a.tenant_id AS tenant_id,
    a.product_type AS product_type,
    a.spu_name AS spu_name,
    a.poi_id AS poi_id,
    a.cover_image AS cover_image_url_desc,
    a.spu_status AS spu_status,
    a.create_time AS create_time,
    a.update_time AS update_time,
    j1.tenant_name AS tenant_name
  FROM ods.ods_prd_spu_df a
  LEFT JOIN dim.dim_sup_tenant_zip j1
    ON j1.tenant_id = a.tenant_id
   AND j1.travel_date = '${bizdate}' AND j1.end_date = '9999-12-31'
  WHERE a.travel_date = '${bizdate}'
),
src_h AS (SELECT s.*, MD5(CONCAT_WS('|', CAST(spu_no AS STRING), CAST(tenant_id AS STRING), CAST(product_type AS STRING), CAST(spu_name AS STRING), CAST(poi_id AS STRING), CAST(cover_image_url_desc AS STRING), CAST(spu_status AS STRING), CAST(create_time AS STRING), CAST(update_time AS STRING), CAST(tenant_name AS STRING))) AS row_hash FROM src s),
his AS (                               -- 昨日拉链
  SELECT h.*, MD5(CONCAT_WS('|', CAST(h.spu_no AS STRING), CAST(h.tenant_id AS STRING), CAST(h.product_type AS STRING), CAST(h.spu_name AS STRING), CAST(h.poi_id AS STRING), CAST(h.cover_image_url_desc AS STRING), CAST(h.spu_status AS STRING), CAST(h.create_time AS STRING), CAST(h.update_time AS STRING), CAST(h.tenant_name AS STRING))) AS row_hash
  FROM dim.dim_prd_spu_zip h
  WHERE h.travel_date = '${bizdate_prev}'
)
INSERT OVERWRITE TABLE dim.dim_prd_spu_zip PARTITION (travel_date = '${bizdate}')
-- ① 历史记录：当前有效版本若有变化或已删除则闭链（结束日 = 昨天）
SELECT h.spu_id, h.spu_no, h.tenant_id, h.product_type, h.spu_name, h.poi_id, h.cover_image_url_desc, h.spu_status, h.create_time, h.update_time, h.tenant_name,
  h.start_date,
  CASE WHEN h.end_date = '9999-12-31' AND (s.row_hash IS NULL OR s.row_hash <> h.row_hash)
       THEN '${bizdate_prev_dash}' ELSE h.end_date END AS end_date,
  CURRENT_TIMESTAMP() AS etl_time
FROM his h
LEFT JOIN src_h s ON s.spu_id = h.spu_id
UNION ALL
-- ② 新增或变化的记录开新链（开始日 = 今天，结束日 = 9999-12-31）
SELECT s.spu_id, s.spu_no, s.tenant_id, s.product_type, s.spu_name, s.poi_id, s.cover_image_url_desc, s.spu_status, s.create_time, s.update_time, s.tenant_name,
  '${bizdate_dash}' AS start_date,
  '9999-12-31' AS end_date,
  CURRENT_TIMESTAMP() AS etl_time
FROM src_h s
LEFT JOIN his h ON h.spu_id = s.spu_id AND h.end_date = '9999-12-31'
WHERE h.spu_id IS NULL OR h.row_hash <> s.row_hash;
