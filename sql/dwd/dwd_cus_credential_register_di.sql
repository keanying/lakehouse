-- dwd.dwd_cus_credential_register_di  个人凭证注册明细
-- 粒度：1行=1条个人凭证
-- 来源：ods_cus_customer_credential_di
-- 生成方式：Spark SQL / Hive；字段 10 个：直接翻译 10 · 规则翻译 0 · 待确认 0
-- 主表增量先去重再关联；每个 WITH 逻辑块只取用到的列并先过滤分区

WITH
customer_credential_rn AS (                                                 -- 「游客个人凭证」当日增量，同一主键按 binlog 时间倒序编号
  SELECT create_time, credential_no, credential_type, customer_id, id, register_tenant_id, update_time,
         binlog_op_type,
         ROW_NUMBER() OVER (PARTITION BY id ORDER BY binlog_time DESC) AS rn  -- 去重序号（1 = 最新）
  FROM ods.ods_cus_customer_credential_di
  WHERE travel_date = '${bizdate}'                                          -- 只取当日分区
),
customer_credential_latest AS (                                             -- 「游客个人凭证」每个主键只保留最新一条，剔除已删除记录
  SELECT create_time, credential_no, credential_type, customer_id, id, register_tenant_id, update_time
  FROM customer_credential_rn
  WHERE rn = 1
    AND binlog_op_type <> 'DELETE'                                          -- 剔除源库已删除的记录
)
INSERT OVERWRITE TABLE dwd.dwd_cus_credential_register_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  customer_credential_latest.id                 AS customer_credential_id,  -- 游客个人凭证ID（源表主键 id）
  customer_credential_latest.credential_no      AS credential_no,           -- 凭证编号
  customer_credential_latest.customer_id        AS customer_id,             -- 归属 Customer ID
  customer_credential_latest.register_tenant_id AS register_tenant_id,      -- 注册租户ID
  customer_credential_latest.credential_type    AS credential_type,         -- 凭证类型
  customer_credential_latest.create_time        AS create_time,             -- 创建时间
  customer_credential_latest.update_time        AS update_time,             -- 更新时间
  customer_credential_latest.create_time        AS register_time,           -- 凭证注册时间
  1                                             AS register_qty,            -- 注册凭证数
  CURRENT_TIMESTAMP()                           AS etl_time                 -- ETL 加载时间
FROM customer_credential_latest;
