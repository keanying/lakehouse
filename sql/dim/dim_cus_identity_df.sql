-- dim.dim_cus_identity_df  游客渠道身份维度
-- 粒度：1行=1条渠道身份
-- 来源：ods_cus_customer_identity_di
-- 生成方式：Spark SQL / Hive；字段 10 个：直接翻译 10 · 规则翻译 0 · 待确认 0
-- 主表增量先去重再关联；每个 WITH 逻辑块只取用到的列并先过滤分区

WITH
customer_identity_rn AS (                                            -- 「游客多渠道身份」当日增量，同一主键按 binlog 时间倒序编号
  SELECT bind_channel_id, bind_tenant_id, create_time, customer_id, id, identity_status, identity_type,
         identity_value, update_time, binlog_op_type,
         ROW_NUMBER() OVER (PARTITION BY id ORDER BY binlog_time DESC) AS rn  -- 去重序号（1 = 最新）
  FROM ods.ods_cus_customer_identity_di
  WHERE travel_date = '${bizdate}'                                   -- 只取当日分区
),
customer_identity_latest AS (                                        -- 「游客多渠道身份」每个主键只保留最新一条，剔除已删除记录
  SELECT bind_channel_id, bind_tenant_id, create_time, customer_id, id, identity_status, identity_type,
         identity_value, update_time
  FROM customer_identity_rn
  WHERE rn = 1
    AND binlog_op_type <> 'DELETE'                                   -- 剔除源库已删除的记录
)
INSERT OVERWRITE TABLE dim.dim_cus_identity_df PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  customer_identity_latest.id              AS customer_identity_id,  -- 游客多渠道身份ID（源表主键 id）
  customer_identity_latest.customer_id     AS customer_id,           -- 归属 Customer ID
  customer_identity_latest.identity_type   AS identity_type,         -- 标识类型
  customer_identity_latest.identity_value  AS identity_code,         -- 标识值
  customer_identity_latest.bind_channel_id AS bind_channel_id,       -- 产生该标识的接入端ID
  customer_identity_latest.bind_tenant_id  AS bind_tenant_id,        -- 产生该标识的租户ID
  customer_identity_latest.identity_status AS identity_status,       -- 状态
  customer_identity_latest.create_time     AS create_time,           -- 创建时间
  customer_identity_latest.update_time     AS update_time,           -- 更新时间
  CURRENT_TIMESTAMP()                      AS etl_time               -- ETL 加载时间
FROM customer_identity_latest;
