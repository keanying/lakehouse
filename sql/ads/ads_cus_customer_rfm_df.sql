-- ads.ads_cus_customer_rfm_df  会员RFM与复购
-- 粒度：travel_date × seller_tenant_id × rfm_segment_code
-- 来源：dws_cus_customer_lifetime_df
-- 生成方式：Spark SQL / Hive；字段 10 个：直接翻译 9 · 规则翻译 0 · 待确认 1
-- 快照/累计表：增量来源取截至统计日的全部分区
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT OVERWRITE TABLE ads.ads_cus_customer_rfm_df PARTITION (travel_date = '${bizdate}')
SELECT
  x.seller_tenant_id,
  x.rfm_segment_code,
  d1.tenant_name AS seller_tenant_name,
  x.pay_buyer_bitmap,
  x.repeat_buyer_bitmap,
  x.repurchase_numerator_qty,
  x.repurchase_denominator_bitmap,
  x.per_customer_numerator_amt,
  x.per_customer_denominator_bitmap,
  x.etl_time
FROM (
SELECT
  u.seller_tenant_id,
  u.rfm_segment_code,
  BITMAP_UNION(u.pay_buyer_bitmap) AS pay_buyer_bitmap,
  BITMAP_UNION(u.repeat_buyer_bitmap) AS repeat_buyer_bitmap,
  SUM(u.repurchase_numerator_qty) AS repurchase_numerator_qty,
  BITMAP_UNION(u.repurchase_denominator_bitmap) AS repurchase_denominator_bitmap,
  SUM(u.per_customer_numerator_amt) AS per_customer_numerator_amt,
  BITMAP_UNION(u.per_customer_denominator_bitmap) AS per_customer_denominator_bitmap,
  CURRENT_TIMESTAMP() AS etl_time
FROM (
  -- 来源：dws_cus_customer_lifetime_df
  SELECT
    seller_tenant_id AS seller_tenant_id,
    CAST(NULL AS STRING) AS rfm_segment_code,
    BITMAP_UNION(pay_buyer_bitmap) AS pay_buyer_bitmap,
    BITMAP_UNION(repeat_buyer_bitmap) AS repeat_buyer_bitmap,
    SUM(buyer_type) AS repurchase_numerator_qty,
    BITMAP_UNION(pay_buyer_bitmap) AS repurchase_denominator_bitmap,
    SUM(pay_buyer_qty) AS per_customer_numerator_amt,
    BITMAP_UNION(pay_buyer_bitmap) AS per_customer_denominator_bitmap
  FROM dws.dws_cus_customer_lifetime_df s
  WHERE s.travel_date = '${bizdate}'
  GROUP BY seller_tenant_id
) u
GROUP BY u.seller_tenant_id, u.rfm_segment_code
) x
LEFT JOIN dim.dim_sup_tenant_zip d1 ON d1.tenant_id = x.seller_tenant_id AND d1.travel_date = '${bizdate}' AND d1.end_date = '9999-12-31';
