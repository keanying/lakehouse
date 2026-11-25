-- dwd.dwd_ord_ticket_di  票明细（出票）
-- 粒度：1行=1张票（ticket_no）
-- 来源：ods_ord_ticket_di + dwd_ord_order_di
-- 生成方式：Spark SQL / Hive；字段 27 个：直接翻译 21 · 规则翻译 4 · 待确认 2
-- ODS 增量按主键取最新一条（ROW_NUMBER），剔除删除记录
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT OVERWRITE TABLE dwd.dwd_ord_ticket_di PARTITION (travel_date = '${bizdate}')
SELECT
  a.id                                       AS ticket_id,
  a.ticket_no                                AS ticket_no,
  a.order_no                                 AS order_no,
  a.ticket_status                            AS ticket_status,
  a.valid_start                              AS valid_start_time,
  a.valid_end                                AS valid_end_time,
  a.pass_policy                              AS pass_policy_type,
  a.tenant_id                                AS tenant_id,
  a.create_time                              AS create_time,
  a.update_time                              AS update_time,
  j1.order_group_no                          AS order_group_no,
  j1.seller_tenant_id                        AS seller_tenant_id,
  j1.sku_id                                  AS sku_id,
  j1.spu_id                                  AS spu_id,
  j1.channel_id                              AS channel_id,
  j1.buyer_customer_id                       AS buyer_customer_id,
  j1.play_date                               AS play_date,
  DATE_FORMAT(a.valid_end, 'yyyyMMdd')       AS valid_end_date,
  GET_JSON_OBJECT(a.metadata, '$.seatInfo')  AS seat_no,
  GET_JSON_OBJECT(a.metadata, '$.cabinInfo') AS cabin_no,
  GET_JSON_OBJECT(a.metadata, '$.schedule')  AS schedule_time,
  j1.unit_price_amt                          AS unit_price_amt,
  1                                          AS ticket_qty,
  a.valid_start                              AS delay_active_type,  -- 待确认：ods_ord_ticket_di.valid_start 为空判定
  j2.create_time                             AS first_verify_time,  -- 待确认：dwd_ord_verify_di.create_time 按 ticket_no 取最小
  a.create_time                              AS issue_time,
  CURRENT_TIMESTAMP()                        AS etl_time
FROM (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY id ORDER BY binlog_time DESC) AS rn
  FROM ods.ods_ord_ticket_di
  WHERE travel_date = '${bizdate}'
) a
LEFT JOIN dwd.dwd_ord_order_di j1
  ON j1.order_no = a.order_no
 AND j1.travel_date = '${bizdate}'
LEFT JOIN dwd.dwd_ord_verify_di j2
  ON j2.ticket_no = a.ticket_no
 AND j2.travel_date = '${bizdate}'
WHERE a.rn = 1
  AND a.binlog_op_type <> 'DELETE';
