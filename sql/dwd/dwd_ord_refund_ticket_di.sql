-- dwd.dwd_ord_refund_ticket_di  退款票明细
-- 粒度：1行=1个退款单里的1张票
-- 来源：ods_ord_refund_order_di（refund_items JSON 展开）+ dwd_ord_ticket_di
-- 生成方式：Spark SQL / Hive；字段 18 个：直接翻译 14 · 规则翻译 3 · 待确认 1
-- ODS 增量按主键取最新一条（ROW_NUMBER），剔除删除记录
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT OVERWRITE TABLE dwd.dwd_ord_refund_ticket_di PARTITION (travel_date = '${bizdate}')
SELECT
  a.refund_no                                    AS refund_no,
  a.order_group_no                               AS order_group_no,
  GET_JSON_OBJECT(a.refund_items, '$.orderNo')   AS order_no,
  GET_JSON_OBJECT(a.refund_items, '$.ticketNos') AS ticket_no,
  j1.seller_tenant_id                            AS seller_tenant_id,
  j1.sku_id                                      AS sku_id,
  j1.play_date                                   AS play_date,
  a.refund_type                                  AS refund_type,
  a.refund_status                                AS refund_status,
  a.initiator_type                               AS initiator_type,
  a.refund_reason                                AS refund_reason_desc,
  j2.after_status                                AS before_ticket_status,  -- 待确认：dwd_ord_ticket_status_log_di.after_status 取退款申请前最后一条
  1                                              AS refund_ticket_qty,
  GET_JSON_OBJECT(a.refund_items, '$.amount')    AS refund_amt,
  a.create_time                                  AS apply_time,
  j3.finish_time                                 AS finish_time,
  a.tenant_id                                    AS tenant_id,
  CURRENT_TIMESTAMP()                            AS etl_time
FROM (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY id ORDER BY binlog_time DESC) AS rn
  FROM ods.ods_ord_refund_order_di
  WHERE travel_date = '${bizdate}'
) a
LEFT JOIN dwd.dwd_ord_ticket_di j1
  ON j1.order_group_no = a.order_group_no
 AND j1.travel_date = '${bizdate}'
LEFT JOIN dwd.dwd_ord_ticket_status_log_di j2
  ON j2.order_group_no = a.order_group_no
 AND j2.travel_date = '${bizdate}'
LEFT JOIN dwd.dwd_ord_refund_di j3
  ON j3.refund_no = a.refund_no
 AND j3.travel_date = '${bizdate}'
WHERE a.rn = 1
  AND a.binlog_op_type <> 'DELETE';
