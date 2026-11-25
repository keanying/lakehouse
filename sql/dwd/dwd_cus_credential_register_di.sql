-- dwd.dwd_cus_credential_register_di  个人凭证注册明细
-- 粒度：1行=1条个人凭证
-- 来源：ods_cus_customer_credential_di
-- 生成方式：Spark SQL / Hive；字段 10 个：直接翻译 10 · 规则翻译 0 · 待确认 0
-- ODS 增量按主键取最新一条（ROW_NUMBER），剔除删除记录

INSERT OVERWRITE TABLE dwd.dwd_cus_credential_register_di PARTITION (travel_date = '${bizdate}')
SELECT
  a.id                 AS customer_credential_id,
  a.credential_no      AS credential_no,
  a.customer_id        AS customer_id,
  a.register_tenant_id AS register_tenant_id,
  a.credential_type    AS credential_type,
  a.create_time        AS create_time,
  a.update_time        AS update_time,
  a.create_time        AS register_time,
  1                    AS register_qty,
  CURRENT_TIMESTAMP()  AS etl_time
FROM (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY id ORDER BY binlog_time DESC) AS rn
  FROM ods.ods_cus_customer_credential_di
  WHERE travel_date = '${bizdate}'
) a
WHERE a.rn = 1
  AND a.binlog_op_type <> 'DELETE';
