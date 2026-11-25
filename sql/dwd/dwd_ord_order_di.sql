-- dwd.dwd_ord_order_di  子单明细
-- 粒度：1行=1个子单（order_no）
-- 来源：ods_ord_order_di + ods_ord_order_group_di
-- 生成方式：Spark SQL / Hive；字段 36 个：直接翻译 28 · 规则翻译 8 · 待确认 0
-- ODS 增量按主键取最新一条（ROW_NUMBER），剔除删除记录

INSERT OVERWRITE TABLE dwd.dwd_ord_order_di PARTITION (travel_date = '${bizdate}')
SELECT
  a.id                                                         AS order_id,
  a.order_no                                                   AS order_no,
  a.order_group_no                                             AS order_group_no,
  a.parent_order_no                                            AS parent_order_no,
  a.combo_flag                                                 AS combo_type,
  a.seller_tenant_id                                           AS seller_tenant_id,
  a.sku_id                                                     AS sku_id,
  a.sku_name                                                   AS sku_name,
  a.sku_version                                                AS sku_version_no,
  a.quantity                                                   AS buy_ticket_qty,
  ROUND(a.unit_price / 100, 2)                                 AS unit_price_amt,
  a.order_status                                               AS order_status,
  a.tenant_id                                                  AS tenant_id,
  a.create_time                                                AS create_time,
  a.update_time                                                AS update_time,
  j1.channel_id                                                AS channel_id,
  j2.channel_type                                              AS channel_type,
  j1.app_id                                                    AS app_code,
  j1.app_ref                                                   AS app_ref_code,
  j1.operator_type                                             AS operator_type,
  j1.operator_id                                               AS operator_id,
  j1.buyer_type                                                AS buyer_type,
  j1.buyer_customer_id                                         AS buyer_customer_id,
  j1.currency                                                  AS currency_code,
  j3.spu_id                                                    AS spu_id,
  j3.product_type                                              AS product_type,
  GET_JSON_OBJECT(a.sale_dims, '$.date')                       AS play_date,
  GET_JSON_OBJECT(a.sale_dims, '$.timeSlot')                   AS time_slot_code,
  GET_JSON_OBJECT(a.sale_dims, '$.seatZone')                   AS seat_zone_code,
  ROUND(a.unit_price * a.quantity /100, 2)                     AS order_amt,
  j4.cost_price_amt                                            AS cost_price_amt,
  DATE_FORMAT(a.create_time, 'yyyyMMdd')                       AS order_date,
  CASE WHEN a.order_status = 'PAID' THEN a.binlog_time END     AS pay_time,
  CASE WHEN a.order_status = 'CANCELLED' THEN a.binlog_time END AS cancel_time,
  DATEDIFF(TO_DATE(GET_JSON_OBJECT(a.sale_dims, '$.date'), 'yyyyMMdd'), TO_DATE(DATE_FORMAT(a.create_time, 'yyyyMMdd'), 'yyyyMMdd')) AS advance_book_day_qty,
  CURRENT_TIMESTAMP()                                          AS etl_time
FROM (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY id ORDER BY binlog_time DESC) AS rn
  FROM ods.ods_ord_order_di
  WHERE travel_date = '${bizdate}'
) a
LEFT JOIN ods.ods_ord_order_group_di j1
  ON j1.order_group_no = a.order_group_no
 AND j1.travel_date = '${bizdate}'
LEFT JOIN dim.dim_trf_channel_df j2
  ON j2.channel_id = j1.channel_id
 AND j2.travel_date = '${bizdate}'
LEFT JOIN dim.dim_prd_sku_zip j3
  ON j3.sku_id = a.sku_id
 AND j3.travel_date = '${bizdate}' AND j3.end_date = '9999-12-31'
LEFT JOIN dim.dim_prd_sku_zip j4
  ON j4.sku_id = a.sku_id
 AND j4.travel_date = '${bizdate}'
 AND TO_DATE(a.create_time) BETWEEN j4.start_date AND j4.end_date   -- 按时间点取拉链历史版本
WHERE a.rn = 1
  AND a.binlog_op_type <> 'DELETE';
