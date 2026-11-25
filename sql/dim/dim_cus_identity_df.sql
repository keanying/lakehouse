-- dim.dim_cus_identity_df  游客渠道身份维度
-- 粒度：1行=1条渠道身份
-- 来源：ods_cus_customer_identity_di
-- 生成方式：Spark SQL / Hive；字段 10 个：直接翻译 10 · 规则翻译 0 · 待确认 0
-- ODS 增量按主键取最新一条（ROW_NUMBER），剔除删除记录

INSERT OVERWRITE TABLE dim.dim_cus_identity_df PARTITION (travel_date = '${bizdate}')
SELECT
  a.id                AS customer_identity_id,
  a.customer_id       AS customer_id,
  a.identity_type     AS identity_type,
  a.identity_value    AS identity_code,
  a.bind_channel_id   AS bind_channel_id,
  a.bind_tenant_id    AS bind_tenant_id,
  a.identity_status   AS identity_status,
  a.create_time       AS create_time,
  a.update_time       AS update_time,
  CURRENT_TIMESTAMP() AS etl_time
FROM (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY id ORDER BY binlog_time DESC) AS rn
  FROM ods.ods_cus_customer_identity_di
  WHERE travel_date = '${bizdate}'
) a
WHERE a.rn = 1
  AND a.binlog_op_type <> 'DELETE';
