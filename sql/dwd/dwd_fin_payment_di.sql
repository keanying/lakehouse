-- dwd.dwd_fin_payment_di  支付明细
-- 粒度：1行=1条支付记录（payment_no）
-- 来源：ods_fin_payment_record_di
-- 生成方式：Spark SQL / Hive；字段 29 个：直接翻译 26 · 规则翻译 3 · 待确认 0
-- ODS 增量按主键取最新一条（ROW_NUMBER），剔除删除记录

INSERT OVERWRITE TABLE dwd.dwd_fin_payment_di PARTITION (travel_date = '${bizdate}')
SELECT
  a.id                                                   AS payment_id,
  a.payment_no                                           AS payment_no,
  a.batch_no                                             AS batch_no,
  a.item_no                                              AS item_no,
  a.depend_on_item                                       AS depend_on_item_no,
  a.order_group_no                                       AS order_group_no,
  a.pay_direction                                        AS pay_direction_type,
  a.pay_method                                           AS pay_method_type,
  a.receive_channel                                      AS receive_channel_type,
  ROUND(a.amount / 100, 2)                               AS pay_amt,
  ROUND(a.settle_amount / 100, 2)                        AS settle_amt,
  a.transaction_no                                       AS transaction_no,
  a.payer_account_no                                     AS payer_account_no,
  a.payee_account_no                                     AS payee_account_no,
  a.ticket_no                                            AS ticket_no,
  a.external_frozen                                      AS external_frozen_type,
  a.pay_time                                             AS pay_time,
  a.pay_status                                           AS pay_status,
  a.tenant_id                                            AS tenant_id,
  a.create_time                                          AS create_time,
  a.update_time                                          AS update_time,
  j1.seller_tenant_id                                    AS seller_tenant_id,
  j2.subject_id                                          AS payer_tenant_id,
  j3.subject_id                                          AS payee_tenant_id,
  j4.sku_id                                              AS sku_id,
  GET_JSON_OBJECT(a.freeze_instructions, '$.freezeType') AS freeze_type,
  ROUND(a.amount - a.settle_amount /100, 2)              AS profit_amt,
  DATE_FORMAT(a.pay_time, 'yyyyMMdd')                    AS pay_date,
  CURRENT_TIMESTAMP()                                    AS etl_time
FROM (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY id ORDER BY binlog_time DESC) AS rn
  FROM ods.ods_fin_payment_record_di
  WHERE travel_date = '${bizdate}'
) a
LEFT JOIN dwd.dwd_ord_order_group_di j1
  ON j1.order_group_no = a.order_group_no
 AND j1.travel_date = '${bizdate}'
LEFT JOIN dim.dim_fin_account_df j2
  ON j2.account_no = a.payer_account_no
 AND j2.travel_date = '${bizdate}'
LEFT JOIN dim.dim_fin_account_df j3
  ON j3.account_no = a.payee_account_no
 AND j3.travel_date = '${bizdate}'
LEFT JOIN dwd.dwd_ord_ticket_di j4
  ON j4.ticket_no = a.ticket_no
 AND j4.travel_date = '${bizdate}'
WHERE a.rn = 1
  AND a.binlog_op_type <> 'DELETE';
