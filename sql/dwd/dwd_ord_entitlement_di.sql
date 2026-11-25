-- dwd.dwd_ord_entitlement_di  权益明细
-- 粒度：1行=1个权益（entitlement_no）
-- 来源：ods_ord_entitlement_di + dwd_ord_ticket_di
-- 生成方式：Spark SQL / Hive；字段 23 个：直接翻译 17 · 规则翻译 6 · 待确认 0
-- ODS 增量按主键取最新一条（ROW_NUMBER），剔除删除记录

INSERT OVERWRITE TABLE dwd.dwd_ord_entitlement_di PARTITION (travel_date = '${bizdate}')
SELECT
  a.id                                                         AS entitlement_id,
  a.entitlement_no                                             AS entitlement_no,
  a.ticket_no                                                  AS ticket_no,
  a.entitlement_type                                           AS entitlement_type,
  a.entitlement_name                                           AS entitlement_name,
  a.status                                                     AS entitlement_status,
  a.used_count                                                 AS used_qty,
  a.valid_start                                                AS valid_start_time,
  a.valid_end                                                  AS valid_end_time,
  a.tenant_id                                                  AS tenant_id,
  a.create_time                                                AS create_time,
  a.update_time                                                AS update_time,
  j1.order_no                                                  AS order_no,
  j1.seller_tenant_id                                          AS seller_tenant_id,
  j1.sku_id                                                    AS sku_id,
  GET_JSON_OBJECT(a.entitlement_detail, '$.projectId')         AS project_id,
  GET_JSON_OBJECT(a.entitlement_detail, '$.maxCount')          AS max_qty,
  JSON_ARRAY_LENGTH(GET_JSON_OBJECT(a.entitlement_detail, '$.candidateRefs')) AS candidate_qty,
  GET_JSON_OBJECT(a.entitlement_detail, '$.durationMinutes')   AS duration_minute_qty,
  GET_JSON_OBJECT(a.entitlement_detail, '$.quotaAmount')       AS quota_amt,
  (GET_JSON_OBJECT(a.entitlement_detail, '$.maxCount')) - (a.used_count) AS remain_qty,
  a.create_time                                                AS issue_time,
  CURRENT_TIMESTAMP()                                          AS etl_time
FROM (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY id ORDER BY binlog_time DESC) AS rn
  FROM ods.ods_ord_entitlement_di
  WHERE travel_date = '${bizdate}'
) a
LEFT JOIN dwd.dwd_ord_ticket_di j1
  ON j1.ticket_no = a.ticket_no
 AND j1.travel_date = '${bizdate}'
WHERE a.rn = 1
  AND a.binlog_op_type <> 'DELETE';
