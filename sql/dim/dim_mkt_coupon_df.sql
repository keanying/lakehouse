-- dim.dim_mkt_coupon_df  优惠券维度
-- 粒度：1行=1张券模板
-- 来源：ods_mkt_coupon_df
-- 生成方式：Spark SQL / Hive；字段 15 个：直接翻译 15 · 规则翻译 0 · 待确认 0

INSERT OVERWRITE TABLE dim.dim_mkt_coupon_df PARTITION (travel_date = '${bizdate}')
SELECT
  a.id                 AS coupon_id,
  a.coupon_no          AS coupon_no,
  a.tenant_id          AS tenant_id,
  a.coupon_name        AS coupon_name,
  a.coupon_type        AS coupon_type,
  a.coupon_value       AS coupon_value_num,
  a.applicable_sku_ids AS applicable_sku_list_desc,
  a.total_count        AS total_qty,
  a.used_count         AS used_qty,
  a.effective_from     AS effective_start_time,
  a.effective_to       AS effective_end_time,
  a.coupon_status      AS coupon_status,
  a.create_time        AS create_time,
  a.update_time        AS update_time,
  CURRENT_TIMESTAMP()  AS etl_time
FROM ods.ods_mkt_coupon_df a
WHERE a.travel_date = '${bizdate}';
