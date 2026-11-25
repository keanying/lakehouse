-- dwd.dwd_ord_order_group_di  聚合单明细
-- 粒度：1行=1个聚合单（order_group_no）
-- 来源：ods_ord_order_group_di
-- 生成方式：Spark SQL / Hive；字段 29 个：直接翻译 25 · 规则翻译 2 · 待确认 2
-- ODS 增量按主键取最新一条（ROW_NUMBER），剔除删除记录
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT OVERWRITE TABLE dwd.dwd_ord_order_group_di PARTITION (travel_date = '${bizdate}')
SELECT
  a.id                                   AS order_group_id,
  a.order_group_no                       AS order_group_no,
  a.seller_tenant_id                     AS seller_tenant_id,
  a.channel_id                           AS channel_id,
  a.app_id                               AS app_code,
  a.app_ref                              AS app_ref_code,
  a.operator_type                        AS operator_type,
  a.operator_id                          AS operator_id,
  a.operator_tenant_id                   AS operator_tenant_id,
  a.buyer_type                           AS buyer_type,
  a.buyer_id                             AS buyer_id,
  a.buyer_customer_id                    AS buyer_customer_id,
  a.contact_name                         AS contact_name,
  a.contact_phone                        AS contact_phone_no,
  a.contact_id_type                      AS contact_cert_type,
  a.contact_id_number                    AS contact_cert_no,
  ROUND(a.total_amount / 100, 2)         AS total_amt,
  a.currency                             AS currency_code,
  a.pay_status                           AS pay_status,
  a.pay_timeout_at                       AS pay_timeout_time,
  a.tenant_id                            AS tenant_id,
  a.create_time                          AS create_time,
  a.update_time                          AS update_time,
  DATE_FORMAT(a.create_time, 'yyyyMMdd') AS order_date,
  j1.pay_time                            AS first_pay_time,  -- 待确认：ods_fin_payment_record_di.pay_time 按 order_group_no 取 INBOUND 且 PAID 的最小值
  j2.quantity                            AS order_ticket_qty,  -- 待确认：ods_ord_order_di.quantity 按 order_group_no 汇总
  COALESCE(j3.v, 0)                      AS sub_order_qty,
  j4.channel_type                        AS channel_type,
  CURRENT_TIMESTAMP()                    AS etl_time
FROM (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY id ORDER BY binlog_time DESC) AS rn
  FROM ods.ods_ord_order_group_di
  WHERE travel_date = '${bizdate}'
) a
LEFT JOIN ods.ods_fin_payment_record_di j1
  ON j1.order_group_no = a.order_group_no
 AND j1.travel_date = '${bizdate}'
LEFT JOIN ods.ods_ord_order_di j2
  ON j2.order_group_no = a.order_group_no
 AND j2.travel_date = '${bizdate}'
LEFT JOIN (SELECT order_group_no, COUNT(order_no) AS v FROM ods.ods_ord_order_di WHERE travel_date = '${bizdate}' GROUP BY order_group_no) j3
  ON j3.order_group_no = a.order_group_no
LEFT JOIN dim.dim_trf_channel_df j4
  ON j4.channel_id = a.channel_id
 AND j4.travel_date = '${bizdate}'
WHERE a.rn = 1
  AND a.binlog_op_type <> 'DELETE';
