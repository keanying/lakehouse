-- dwd.dwd_ord_refund_rt  实时退款明细
-- 粒度：1行=1个退款单（refund_no）
-- 来源：ods_ord_refund_order_rt
-- 生成方式：Flink SQL（CDC 源表 → StarRocks 主键模型表；维表 Lookup Join）；字段 22 个：直接翻译 18 · 规则翻译 4 · 待确认 0
-- 源表 ods.*_rt 为 Flink CDC 表（含 proc_time AS PROCTIME()），目标表在 StarRocks catalog 中

INSERT INTO dwd.dwd_ord_refund_rt
SELECT
  DATE_FORMAT(a.create_time, 'yyyyMMdd')                       AS travel_date,
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
  CURRENT_TIMESTAMP                                            AS event_time
FROM ods.ods_ord_refund_order_rt a
LEFT JOIN dwd.dwd_ord_order_group_di j1
  ON j1.order_group_no = a.order_group_no
 AND j1.travel_date = '${bizdate}';
