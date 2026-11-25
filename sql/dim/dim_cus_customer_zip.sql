-- dim.dim_cus_customer_zip  游客维度
-- 粒度：1行=1个游客×1个有效区间
-- 来源：ods_cus_customer_di
-- 生成方式：Spark SQL / Hive（拉链表）；字段 17 个：直接翻译 14 · 规则翻译 2 · 待确认 1
-- 拉链：比对今日源数据与昨日拉链的行哈希，变化的旧版本闭链、新版本开链；源为增量表，未出现的主键保持不变
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

WITH src AS (                       -- 今日最新状态
  SELECT
    a.id AS customer_id,
    a.customer_no AS customer_no,
    a.customer_kind AS customer_type,
    a.phone AS phone_no,
    a.name AS customer_name,
    a.gender AS gender_type,
    a.auth_status AS auth_status,
    a.customer_status AS customer_status,
    a.register_source AS register_source_code,
    a.register_tenant_id AS register_tenant_id,
    a.create_time AS create_time,
    a.update_time AS update_time,
    j1.channel_id AS register_channel_id,
    a.birthday AS age_band_code,  -- 待确认：ods_cus_customer_di.birthday 计算
    CASE WHEN a.wechat_unionid IS NOT NULL AND a.wechat_unionid <> '' THEN 1 ELSE 0 END AS wechat_bind_type,
    CASE WHEN a.alipay_user_id IS NOT NULL AND a.alipay_user_id <> '' THEN 1 ELSE 0 END AS alipay_bind_type
  FROM (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY id ORDER BY binlog_time DESC) AS rn
    FROM ods.ods_cus_customer_di WHERE travel_date = '${bizdate}'
  ) a
  LEFT JOIN dim.dim_trf_channel_df j1
    ON j1.channel_code = a.register_source
   AND j1.travel_date = '${bizdate}'
  WHERE a.rn = 1
),
src_h AS (SELECT s.*, MD5(CONCAT_WS('|', CAST(customer_no AS STRING), CAST(customer_type AS STRING), CAST(phone_no AS STRING), CAST(customer_name AS STRING), CAST(gender_type AS STRING), CAST(auth_status AS STRING), CAST(customer_status AS STRING), CAST(register_source_code AS STRING), CAST(register_tenant_id AS STRING), CAST(create_time AS STRING), CAST(update_time AS STRING), CAST(register_channel_id AS STRING), CAST(age_band_code AS STRING), CAST(wechat_bind_type AS STRING), CAST(alipay_bind_type AS STRING))) AS row_hash FROM src s),
his AS (                               -- 昨日拉链
  SELECT h.*, MD5(CONCAT_WS('|', CAST(h.customer_no AS STRING), CAST(h.customer_type AS STRING), CAST(h.phone_no AS STRING), CAST(h.customer_name AS STRING), CAST(h.gender_type AS STRING), CAST(h.auth_status AS STRING), CAST(h.customer_status AS STRING), CAST(h.register_source_code AS STRING), CAST(h.register_tenant_id AS STRING), CAST(h.create_time AS STRING), CAST(h.update_time AS STRING), CAST(h.register_channel_id AS STRING), CAST(h.age_band_code AS STRING), CAST(h.wechat_bind_type AS STRING), CAST(h.alipay_bind_type AS STRING))) AS row_hash
  FROM dim.dim_cus_customer_zip h
  WHERE h.travel_date = '${bizdate_prev}'
)
INSERT OVERWRITE TABLE dim.dim_cus_customer_zip PARTITION (travel_date = '${bizdate}')
-- ① 历史记录：当前有效版本若有变化则闭链（结束日 = 昨天）
SELECT h.customer_id, h.customer_no, h.customer_type, h.phone_no, h.customer_name, h.gender_type, h.auth_status, h.customer_status, h.register_source_code, h.register_tenant_id, h.create_time, h.update_time, h.register_channel_id, h.age_band_code, h.wechat_bind_type, h.alipay_bind_type,
  h.start_date,
  CASE WHEN h.end_date = '9999-12-31' AND s.row_hash IS NOT NULL AND (s.row_hash IS NULL OR s.row_hash <> h.row_hash)
       THEN '${bizdate_prev_dash}' ELSE h.end_date END AS end_date,
  CURRENT_TIMESTAMP() AS etl_time
FROM his h
LEFT JOIN src_h s ON s.customer_id = h.customer_id
UNION ALL
-- ② 新增或变化的记录开新链（开始日 = 今天，结束日 = 9999-12-31）
SELECT s.customer_id, s.customer_no, s.customer_type, s.phone_no, s.customer_name, s.gender_type, s.auth_status, s.customer_status, s.register_source_code, s.register_tenant_id, s.create_time, s.update_time, s.register_channel_id, s.age_band_code, s.wechat_bind_type, s.alipay_bind_type,
  '${bizdate_dash}' AS start_date,
  '9999-12-31' AS end_date,
  CURRENT_TIMESTAMP() AS etl_time
FROM src_h s
LEFT JOIN his h ON h.customer_id = s.customer_id AND h.end_date = '9999-12-31'
WHERE h.customer_id IS NULL OR h.row_hash <> s.row_hash;
