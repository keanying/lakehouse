-- ads.ads_cus_customer_growth_di  游客增长
-- 粒度：travel_date × tenant_id × register_channel_id
-- 来源：dws_cus_tenant_growth_di
-- 生成方式：Spark SQL / Hive；字段 16 个：直接翻译 16 · 规则翻译 0 · 待确认 0

INSERT OVERWRITE TABLE ads.ads_cus_customer_growth_di PARTITION (travel_date = '${bizdate}')
SELECT
  x.tenant_id,
  x.register_channel_id,
  d1.tenant_name AS tenant_name,
  d2.channel_name AS register_channel_name,
  x.new_customer_qty,
  x.first_pay_customer_qty,
  x.face_register_qty,
  x.certified_customer_qty,
  x.register_pay_conversion_numerator_qty,
  x.register_pay_conversion_denominator_qty,
  x.new_buyer_share_numerator_qty,
  x.new_buyer_share_denominator_bitmap,
  x.face_register_numerator_qty,
  x.face_register_denominator_qty,
  x.repeat_buyer_bitmap,
  x.identity_bind_qty,
  x.etl_time
FROM (
SELECT
  u.tenant_id,
  u.register_channel_id,
  SUM(u.new_customer_qty) AS new_customer_qty,
  SUM(u.first_pay_customer_qty) AS first_pay_customer_qty,
  SUM(u.face_register_qty) AS face_register_qty,
  SUM(u.certified_customer_qty) AS certified_customer_qty,
  SUM(u.register_pay_conversion_numerator_qty) AS register_pay_conversion_numerator_qty,
  SUM(u.register_pay_conversion_denominator_qty) AS register_pay_conversion_denominator_qty,
  SUM(u.new_buyer_share_numerator_qty) AS new_buyer_share_numerator_qty,
  BITMAP_UNION(u.new_buyer_share_denominator_bitmap) AS new_buyer_share_denominator_bitmap,
  SUM(u.face_register_numerator_qty) AS face_register_numerator_qty,
  SUM(u.face_register_denominator_qty) AS face_register_denominator_qty,
  BITMAP_UNION(u.repeat_buyer_bitmap) AS repeat_buyer_bitmap,
  SUM(u.identity_bind_qty) AS identity_bind_qty,
  CURRENT_TIMESTAMP() AS etl_time
FROM (
  -- 来源：dws_cus_tenant_growth_di
  SELECT
    tenant_id AS tenant_id,
    register_channel_id AS register_channel_id,
    SUM(new_customer_qty) AS new_customer_qty,
    SUM(first_pay_customer_qty) AS first_pay_customer_qty,
    SUM(face_register_qty) AS face_register_qty,
    SUM(certified_customer_qty) AS certified_customer_qty,
    SUM(register_pay_customer_qty) AS register_pay_conversion_numerator_qty,
    SUM(new_customer_qty) AS register_pay_conversion_denominator_qty,
    SUM(first_pay_customer_qty) AS new_buyer_share_numerator_qty,
    BITMAP_UNION(pay_buyer_bitmap) AS new_buyer_share_denominator_bitmap,
    SUM(face_register_qty) AS face_register_numerator_qty,
    SUM(new_customer_qty) AS face_register_denominator_qty,
    BITMAP_UNION(repeat_buyer_bitmap) AS repeat_buyer_bitmap,
    SUM(identity_bind_qty) AS identity_bind_qty
  FROM dws.dws_cus_tenant_growth_di s
  WHERE s.travel_date = '${bizdate}'
  GROUP BY tenant_id, register_channel_id
) u
GROUP BY u.tenant_id, u.register_channel_id
) x
LEFT JOIN dim.dim_sup_tenant_zip d1 ON d1.tenant_id = x.tenant_id AND d1.travel_date = '${bizdate}' AND d1.end_date = '9999-12-31'
LEFT JOIN dim.dim_trf_channel_df d2 ON d2.channel_id = x.register_channel_id AND d2.travel_date = '${bizdate}';
