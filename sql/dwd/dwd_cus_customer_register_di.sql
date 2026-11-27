-- dwd.dwd_cus_customer_register_di  游客注册明细
-- 粒度：1行=1个新注册游客
-- 来源：ods_cus_customer_di
-- 生成方式：Spark SQL / Hive；字段 15 个：直接翻译 14 · 规则翻译 1 · 待确认 0
-- 主表增量先去重再关联；每个 WITH 逻辑块只取用到的列并先过滤分区；小维表广播关联

WITH
customer_rn AS (                                               -- 「C端游客主账号」当日增量，同一主键按 binlog 时间倒序编号
  SELECT auth_status, birthday, create_time, customer_kind, customer_no, customer_status, gender, id,
         register_source, register_tenant_id, update_time, binlog_op_type,
         ROW_NUMBER() OVER (PARTITION BY id ORDER BY binlog_time DESC) AS rn  -- 去重序号（1 = 最新）
  FROM ods.ods_cus_customer_di
  WHERE travel_date = '${bizdate}'                             -- 只取当日分区
),
customer_latest AS (                                           -- 「C端游客主账号」每个主键只保留最新一条，剔除已删除记录
  SELECT auth_status, birthday, create_time, customer_kind, customer_no, customer_status, gender, id,
         register_source, register_tenant_id, update_time
  FROM customer_rn
  WHERE rn = 1
    AND binlog_op_type <> 'DELETE'                             -- 剔除源库已删除的记录
),
channel_dim AS (                                               -- 「渠道/接入端维度」当日数据，只取用到的列
  SELECT channel_code, channel_id
  FROM dim.dim_trf_channel_df
  WHERE travel_date = '${bizdate}'                             -- 只取当日分区
)
INSERT OVERWRITE TABLE dwd.dwd_cus_customer_register_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT  /*+ BROADCAST(channel_dim) */
  customer_latest.id                 AS customer_id,           -- C端游客主账号ID（源表主键 id）
  customer_latest.customer_no        AS customer_no,           -- 客户编号
  customer_latest.customer_kind      AS customer_type,         -- 账号类型
  customer_latest.gender             AS gender_type,           -- 性别
  customer_latest.auth_status        AS auth_status,           -- 认证状态
  customer_latest.customer_status    AS customer_status,       -- 状态
  customer_latest.register_source    AS register_source_code,  -- 注册来源渠道编码
  customer_latest.register_tenant_id AS register_tenant_id,    -- 所属租户ID
  customer_latest.create_time        AS create_time,           -- 创建时间
  customer_latest.update_time        AS update_time,           -- 更新时间
  channel_dim.channel_id             AS register_channel_id,   -- 注册渠道ID
  CASE                                                         -- 注册时年龄段｜口径：按生日算注册时年龄后分段
      WHEN FLOOR(MONTHS_BETWEEN(TO_DATE(customer_latest.create_time), TO_DATE(customer_latest.birthday)) / 12) IS NULL THEN 'UNKNOWN'
      WHEN FLOOR(MONTHS_BETWEEN(TO_DATE(customer_latest.create_time), TO_DATE(customer_latest.birthday)) / 12) < 18 THEN '0_17'
      WHEN FLOOR(MONTHS_BETWEEN(TO_DATE(customer_latest.create_time), TO_DATE(customer_latest.birthday)) / 12) <= 25 THEN '18_25'
      WHEN FLOOR(MONTHS_BETWEEN(TO_DATE(customer_latest.create_time), TO_DATE(customer_latest.birthday)) / 12) <= 35 THEN '26_35'
      WHEN FLOOR(MONTHS_BETWEEN(TO_DATE(customer_latest.create_time), TO_DATE(customer_latest.birthday)) / 12) <= 45 THEN '36_45'
      WHEN FLOOR(MONTHS_BETWEEN(TO_DATE(customer_latest.create_time), TO_DATE(customer_latest.birthday)) / 12) <= 60 THEN '46_60'
      ELSE '60_PLUS'
  END AS age_band_code,                                        -- 注册时年龄段
  customer_latest.create_time        AS register_time,         -- 注册时间
  1                                  AS register_qty,          -- 注册人数
  CURRENT_TIMESTAMP()                AS etl_time               -- ETL 加载时间
FROM customer_latest
LEFT JOIN channel_dim                                          -- 关联「渠道/接入端维度」，取 注册渠道ID
  ON channel_dim.channel_code = customer_latest.register_source;  -- 按 register_source→channel_code 关联
