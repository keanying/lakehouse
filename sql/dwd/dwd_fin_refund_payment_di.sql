-- dwd.dwd_fin_refund_payment_di  退款资金明细
-- 粒度：1行=1条退款明细（refund_detail_no）
-- 来源：ods_ord_refund_detail_di
-- 生成方式：Spark SQL / Hive；字段 16 个：直接翻译 15 · 规则翻译 1 · 待确认 0
-- ODS 增量按主键取最新一条（ROW_NUMBER），剔除删除记录

INSERT OVERWRITE TABLE dwd.dwd_fin_refund_payment_di PARTITION (travel_date = '${bizdate}')
SELECT
  a.id                                                         AS refund_detail_id,
  a.refund_detail_no                                           AS refund_detail_no,
  a.refund_no                                                  AS refund_no,
  a.payment_no                                                 AS payment_no,
  ROUND(a.refund_amount / 100, 2)                              AS refund_amt,
  a.refund_channel                                             AS refund_channel_type,
  a.refund_transaction_no                                      AS refund_transaction_no,
  a.refund_detail_status                                       AS refund_detail_status,
  a.tenant_id                                                  AS tenant_id,
  a.create_time                                                AS create_time,
  a.update_time                                                AS update_time,
  j1.order_group_no                                            AS order_group_no,
  j1.pay_method_type                                           AS pay_method_type,
  j1.pay_direction_type                                        AS pay_direction_type,
  CASE WHEN a.refund_detail_status = 'SUCCESS' THEN a.binlog_time END AS finish_time,
  CURRENT_TIMESTAMP()                                          AS etl_time
FROM (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY id ORDER BY binlog_time DESC) AS rn
  FROM ods.ods_ord_refund_detail_di
  WHERE travel_date = '${bizdate}'
) a
LEFT JOIN dwd.dwd_fin_payment_di j1
  ON j1.payment_no = a.payment_no
 AND j1.travel_date = '${bizdate}'
WHERE a.rn = 1
  AND a.binlog_op_type <> 'DELETE';
