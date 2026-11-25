-- dwd.dwd_ord_entitlement_binding_di  人-权益绑定明细
-- 粒度：1行=1条绑定（ticket_no+person_id+entitlement_no）
-- 来源：ods_ord_person_entitlement_binding_di
-- 生成方式：Spark SQL / Hive；字段 13 个：直接翻译 13 · 规则翻译 0 · 待确认 0
-- ODS 增量按主键取最新一条（ROW_NUMBER），剔除删除记录

INSERT OVERWRITE TABLE dwd.dwd_ord_entitlement_binding_di PARTITION (travel_date = '${bizdate}')
SELECT
  a.id                AS binding_id,
  a.ticket_no         AS ticket_no,
  a.person_id         AS person_code,
  a.entitlement_no    AS entitlement_no,
  a.binding_type      AS binding_type,
  a.tenant_id         AS tenant_id,
  a.create_time       AS create_time,
  a.update_time       AS update_time,
  j1.seller_tenant_id AS seller_tenant_id,
  j1.sku_id           AS sku_id,
  j2.entitlement_type AS entitlement_type,
  a.create_time       AS bind_time,
  CURRENT_TIMESTAMP() AS etl_time
FROM (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY id ORDER BY binlog_time DESC) AS rn
  FROM ods.ods_ord_person_entitlement_binding_di
  WHERE travel_date = '${bizdate}'
) a
LEFT JOIN dwd.dwd_ord_ticket_di j1
  ON j1.ticket_no = a.ticket_no
 AND j1.travel_date = '${bizdate}'
LEFT JOIN dwd.dwd_ord_entitlement_di j2
  ON j2.entitlement_no = a.entitlement_no
 AND j2.travel_date = '${bizdate}'
WHERE a.rn = 1
  AND a.binlog_op_type <> 'DELETE';
