-- dwd.dwd_fin_payment_rt  实时支付明细
-- 粒度：1行=1条支付记录（payment_no）
-- 来源：ods_fin_payment_record_rt
-- 生成方式：Flink SQL（CDC 源表 → StarRocks 主键模型表；维表 Lookup Join）；字段 30 个：直接翻译 26 · 规则翻译 4 · 待确认 0
-- 源表 ods.*_rt 为 Flink CDC 表（含 proc_time AS PROCTIME()），目标表在 StarRocks catalog 中

INSERT INTO dwd.dwd_fin_payment_rt
SELECT
  DATE_FORMAT(a.create_time, 'yyyyMMdd')                 AS travel_date,
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
  CURRENT_TIMESTAMP                                      AS event_time
FROM ods.ods_fin_payment_record_rt a
LEFT JOIN dwd.dwd_ord_order_group_di j1
  ON j1.order_group_no = a.order_group_no
 AND j1.travel_date = '${bizdate}'
LEFT JOIN dim.dim_fin_account_df FOR SYSTEM_TIME AS OF a.proc_time AS j2
  ON j2.account_no = a.payer_account_no
LEFT JOIN dim.dim_fin_account_df FOR SYSTEM_TIME AS OF a.proc_time AS j3
  ON j3.account_no = a.payee_account_no
LEFT JOIN dwd.dwd_ord_ticket_di j4
  ON j4.ticket_no = a.ticket_no
 AND j4.travel_date = '${bizdate}';
