-- dim.dim_cus_customer_zip  游客维度
-- 粒度：1行=1个游客×1个有效区间
-- 来源：ods_cus_customer_di
-- 生成方式：Spark SQL / Hive（拉链表）；字段 17 个：直接翻译 14 · 规则翻译 3 · 待确认 0
-- 拉链：比对今日源数据与昨日拉链的行哈希，变化的旧版本闭链、新版本开链；源为增量表，未出现的主键保持不变

WITH
customer_rn AS (                                                                  -- 「C端游客主账号」当日增量，同一主键按 binlog 时间倒序编号
  SELECT alipay_user_id, auth_status, birthday, create_time, customer_kind, customer_no, customer_status,
         gender, id, name, phone, register_source, register_tenant_id, update_time, wechat_unionid,
         binlog_op_type,
         ROW_NUMBER() OVER (PARTITION BY id ORDER BY binlog_time DESC) AS rn      -- 去重序号（1 = 最新）
  FROM ods.ods_cus_customer_di
  WHERE travel_date = '${bizdate}'                                                -- 只取当日分区
),
customer_latest AS (                                                              -- 「C端游客主账号」每个主键只保留最新一条，剔除已删除记录
  SELECT alipay_user_id, auth_status, birthday, create_time, customer_kind, customer_no, customer_status,
         gender, id, name, phone, register_source, register_tenant_id, update_time, wechat_unionid
  FROM customer_rn
  WHERE rn = 1
    AND binlog_op_type <> 'DELETE'                                                -- 剔除源库已删除的记录
),
channel_dim AS (                                                                  -- 「渠道/接入端维度」当日数据，只取用到的列
  SELECT channel_code, channel_id
  FROM dim.dim_trf_channel_df
  WHERE travel_date = '${bizdate}'                                                -- 只取当日分区
),
src AS (                                                                          -- 今日最新状态（与拉链字段一一对应）
  SELECT /*+ BROADCAST(channel_dim) */ 
    customer_latest.id                                           AS customer_id,  -- C端游客主账号ID（源表主键 id）
    customer_latest.customer_no                                  AS customer_no,  -- 客户编号
    customer_latest.customer_kind                                AS customer_type,  -- 账号类型
    customer_latest.phone                                        AS phone_no,     -- 联系电话+登录句柄
    customer_latest.name                                         AS customer_name,  -- 姓名/昵称（脱敏）
    customer_latest.gender                                       AS gender_type,  -- 性别
    customer_latest.auth_status                                  AS auth_status,  -- 认证状态
    customer_latest.customer_status                              AS customer_status,  -- 状态
    customer_latest.register_source                              AS register_source_code,  -- 注册来源渠道编码
    customer_latest.register_tenant_id                           AS register_tenant_id,  -- 所属租户ID
    customer_latest.create_time                                  AS create_time,  -- 创建时间
    customer_latest.update_time                                  AS update_time,  -- 更新时间
    channel_dim.channel_id                                       AS register_channel_id,  -- 注册渠道ID
    CASE                                                                          -- 年龄段｜口径：按生日算统计日年龄后分段
        WHEN FLOOR(MONTHS_BETWEEN(TO_DATE('${bizdate_dash}'), TO_DATE(customer_latest.birthday)) / 12) IS NULL THEN 'UNKNOWN'
        WHEN FLOOR(MONTHS_BETWEEN(TO_DATE('${bizdate_dash}'), TO_DATE(customer_latest.birthday)) / 12) < 18 THEN '0_17'
        WHEN FLOOR(MONTHS_BETWEEN(TO_DATE('${bizdate_dash}'), TO_DATE(customer_latest.birthday)) / 12) <= 25 THEN '18_25'
        WHEN FLOOR(MONTHS_BETWEEN(TO_DATE('${bizdate_dash}'), TO_DATE(customer_latest.birthday)) / 12) <= 35 THEN '26_35'
        WHEN FLOOR(MONTHS_BETWEEN(TO_DATE('${bizdate_dash}'), TO_DATE(customer_latest.birthday)) / 12) <= 45 THEN '36_45'
        WHEN FLOOR(MONTHS_BETWEEN(TO_DATE('${bizdate_dash}'), TO_DATE(customer_latest.birthday)) / 12) <= 60 THEN '46_60'
        ELSE '60_PLUS'
    END AS age_band_code,                                                         -- 年龄段
    CASE                                                                          -- 是否绑定微信
        WHEN customer_latest.wechat_unionid IS NOT NULL AND customer_latest.wechat_unionid <> '' THEN 1
        ELSE 0
    END AS wechat_bind_type,                                                      -- 是否绑定微信
    CASE                                                                          -- 是否绑定支付宝
        WHEN customer_latest.alipay_user_id IS NOT NULL AND customer_latest.alipay_user_id <> '' THEN 1
        ELSE 0
    END AS alipay_bind_type                                                       -- 是否绑定支付宝
  FROM customer_latest
  LEFT JOIN channel_dim                                                           -- 关联「渠道/接入端维度」，取 注册渠道ID
    ON channel_dim.channel_code = customer_latest.register_source                 -- 按 register_source→channel_code 关联
),
src_hash AS (                                                                     -- 今日状态的行哈希（比较是否变化）
  SELECT s.*,
         MD5(CONCAT_WS(                                                           -- 行哈希：除拉链键外全部属性拼接后 MD5，判断是否变化
             '|',
             CAST(customer_no AS STRING),
             CAST(customer_type AS STRING),
             CAST(phone_no AS STRING),
             CAST(customer_name AS STRING),
             CAST(gender_type AS STRING),
             CAST(auth_status AS STRING),
             CAST(customer_status AS STRING),
             CAST(register_source_code AS STRING),
             CAST(register_tenant_id AS STRING),
             CAST(create_time AS STRING),
             CAST(update_time AS STRING),
             CAST(register_channel_id AS STRING),
             CAST(age_band_code AS STRING),
             CAST(wechat_bind_type AS STRING),
             CAST(alipay_bind_type AS STRING)
         )) AS row_hash                                                           -- 行哈希：除拉链键外全部属性拼接后 MD5，判断是否变化
  FROM src s
),
his AS (                                                                          -- 昨日拉链及其行哈希
  SELECT h.*,
         MD5(CONCAT_WS(                                                           -- 行哈希：除拉链键外全部属性拼接后 MD5，判断是否变化
             '|',
             CAST(h.customer_no AS STRING),
             CAST(h.customer_type AS STRING),
             CAST(h.phone_no AS STRING),
             CAST(h.customer_name AS STRING),
             CAST(h.gender_type AS STRING),
             CAST(h.auth_status AS STRING),
             CAST(h.customer_status AS STRING),
             CAST(h.register_source_code AS STRING),
             CAST(h.register_tenant_id AS STRING),
             CAST(h.create_time AS STRING),
             CAST(h.update_time AS STRING),
             CAST(h.register_channel_id AS STRING),
             CAST(h.age_band_code AS STRING),
             CAST(h.wechat_bind_type AS STRING),
             CAST(h.alipay_bind_type AS STRING)
         )) AS row_hash                                                           -- 行哈希：除拉链键外全部属性拼接后 MD5，判断是否变化
  FROM dim.dim_cus_customer_zip h
  WHERE h.travel_date = '${bizdate_prev}'
)
INSERT OVERWRITE TABLE dim.dim_cus_customer_zip PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
-- ① 历史记录：当前有效版本若有变化则闭链（结束日 = 昨天）
SELECT h.customer_id, h.customer_no, h.customer_type, h.phone_no, h.customer_name, h.gender_type,
       h.auth_status, h.customer_status, h.register_source_code, h.register_tenant_id, h.create_time,
       h.update_time, h.register_channel_id, h.age_band_code, h.wechat_bind_type, h.alipay_bind_type,
  h.start_date,                                                                   -- 拉链开始日期
  CASE WHEN h.end_date = '9999-12-31' AND s.row_hash IS NOT NULL AND (s.row_hash IS NULL OR s.row_hash <> h.row_hash)
       THEN '${bizdate_prev_dash}' ELSE h.end_date END AS end_date,               -- 拉链结束日期
  CURRENT_TIMESTAMP() AS etl_time                                                 -- ETL 加载时间
FROM his h
LEFT JOIN src_hash s ON s.customer_id = h.customer_id
UNION ALL
-- ② 新增或变化的记录开新链（开始日 = 今天，结束日 = 9999-12-31）
SELECT s.customer_id, s.customer_no, s.customer_type, s.phone_no, s.customer_name, s.gender_type,
       s.auth_status, s.customer_status, s.register_source_code, s.register_tenant_id, s.create_time,
       s.update_time, s.register_channel_id, s.age_band_code, s.wechat_bind_type, s.alipay_bind_type,
  '${bizdate_dash}' AS start_date,                                                -- 拉链开始日期
  '9999-12-31' AS end_date,                                                       -- 拉链结束日期
  CURRENT_TIMESTAMP() AS etl_time                                                 -- ETL 加载时间
FROM src_hash s
LEFT JOIN his h ON h.customer_id = s.customer_id AND h.end_date = '9999-12-31'
WHERE h.customer_id IS NULL OR h.row_hash <> s.row_hash;
