-- dwd.dwd_ord_refund_di  退款单明细
-- 粒度：1行=1个退款单（refund_no）
-- 来源：ods_ord_refund_order_di
-- 生成方式：Spark SQL / Hive；字段 21 个：直接翻译 18 · 规则翻译 3 · 待确认 0
-- ODS 增量按主键取最新一条（ROW_NUMBER），剔除删除记录

INSERT OVERWRITE TABLE dwd.dwd_ord_refund_di PARTITION (travel_date = '${bizdate}')
SELECT
  a.id                                                         AS refund_id,
  a.refund_no                                                  AS refund_no,
  a.order_group_no                                             AS order_group_no,
  a.refund_type                                                AS refund_type,
  a.refund_reason                                              AS refund_reason_desc,
  ROUND(a.refund_amount / 100, 2)                              AS refund_amt,
  a.refund_status                                              AS refund_status,
  a.initiator_type                                             AS initiator_type,
  a.initiator_id                                               AS initiator_id,
  a.approver_id                                                AS approver_id,
  a.approve_time                                               AS approve_time,
  a.tenant_id                                                  AS tenant_id,
  a.create_time                                                AS create_time,
  a.update_time                                                AS update_time,
  j1.seller_tenant_id                                          AS seller_tenant_id,
  j1.channel_id                                                AS channel_id,
  a.create_time                                                AS apply_time,
  CASE WHEN a.refund_status = 'COMPLETED' THEN a.binlog_time END AS finish_time,
  (CASE WHEN a.refund_status = 'COMPLETED' THEN a.binlog_time END) - (a.create_time) AS process_hour_qty,
  GET_JSON_OBJECT(a.refund_items, '$.ticketNos')               AS refund_ticket_qty,
  CURRENT_TIMESTAMP()                                          AS etl_time
FROM (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY id ORDER BY binlog_time DESC) AS rn
  FROM ods.ods_ord_refund_order_di
  WHERE travel_date = '${bizdate}'
) a
LEFT JOIN dwd.dwd_ord_order_group_di j1
  ON j1.order_group_no = a.order_group_no
 AND j1.travel_date = '${bizdate}'
WHERE a.rn = 1
  AND a.binlog_op_type <> 'DELETE';
