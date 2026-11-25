-- dwd.dwd_ord_ticket_credential_di  凭证发码/撤销明细
-- 粒度：1行=1个凭证（credential_no）
-- 来源：ods_ord_ticket_credential_di
-- 生成方式：Spark SQL / Hive；字段 17 个：直接翻译 16 · 规则翻译 1 · 待确认 0
-- ODS 增量按主键取最新一条（ROW_NUMBER），剔除删除记录

INSERT OVERWRITE TABLE dwd.dwd_ord_ticket_credential_di PARTITION (travel_date = '${bizdate}')
SELECT
  a.id                                                  AS credential_id,
  a.credential_no                                       AS credential_no,
  a.ticket_no                                           AS ticket_no,
  a.credential_type                                     AS credential_type,
  a.code_value                                          AS credential_code,
  a.code_pool_id                                        AS code_pool_id,
  a.status                                              AS credential_status,
  a.tenant_id                                           AS tenant_id,
  a.create_time                                         AS create_time,
  a.update_time                                         AS update_time,
  j1.order_no                                           AS order_no,
  j1.seller_tenant_id                                   AS seller_tenant_id,
  j1.sku_id                                             AS sku_id,
  a.create_time                                         AS issue_time,
  CASE WHEN a.status = 'REVOKED' THEN a.binlog_time END AS revoke_time,
  1                                                     AS credential_qty,
  CURRENT_TIMESTAMP()                                   AS etl_time
FROM (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY id ORDER BY binlog_time DESC) AS rn
  FROM ods.ods_ord_ticket_credential_di
  WHERE travel_date = '${bizdate}'
) a
LEFT JOIN dwd.dwd_ord_ticket_di j1
  ON j1.ticket_no = a.ticket_no
 AND j1.travel_date = '${bizdate}'
WHERE a.rn = 1
  AND a.binlog_op_type <> 'DELETE';
