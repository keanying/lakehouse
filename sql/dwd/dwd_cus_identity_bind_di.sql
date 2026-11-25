-- dwd.dwd_cus_identity_bind_di  渠道身份绑定明细
-- 粒度：1行=1条身份绑定
-- 来源：ods_cus_customer_identity_di
-- 生成方式：Spark SQL / Hive；字段 12 个：直接翻译 12 · 规则翻译 0 · 待确认 0
-- ODS 增量按主键取最新一条（ROW_NUMBER），剔除删除记录

INSERT OVERWRITE TABLE dwd.dwd_cus_identity_bind_di PARTITION (travel_date = '${bizdate}')
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
  a.create_time       AS bind_time,
  1                   AS bind_qty,
  CURRENT_TIMESTAMP() AS etl_time
FROM (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY id ORDER BY binlog_time DESC) AS rn
  FROM ods.ods_cus_customer_identity_di
  WHERE travel_date = '${bizdate}'
) a
WHERE a.rn = 1
  AND a.binlog_op_type <> 'DELETE';
