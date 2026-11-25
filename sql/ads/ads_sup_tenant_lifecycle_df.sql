-- ads.ads_sup_tenant_lifecycle_df  商户生命周期（活跃/沉默/流失）
-- 粒度：travel_date × tenant_lifecycle_stage_code
-- 来源：dws_sup_tenant_lifetime_df
-- 生成方式：Spark SQL / Hive；字段 7 个：直接翻译 6 · 规则翻译 0 · 待确认 1
-- 快照/累计表：增量来源取截至统计日的全部分区
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT OVERWRITE TABLE ads.ads_sup_tenant_lifecycle_df PARTITION (travel_date = '${bizdate}')
SELECT
  u.tenant_lifecycle_stage_code,
  BITMAP_UNION(u.active_tenant_bitmap) AS active_tenant_bitmap,
  BITMAP_UNION(u.tenant_active_numerator_bitmap) AS tenant_active_numerator_bitmap,
  SUM(u.tenant_active_denominator_qty) AS tenant_active_denominator_qty,
  SUM(u.silent_tenant_qty) AS silent_tenant_qty,
  SUM(u.churn_tenant_qty) AS churn_tenant_qty,
  CURRENT_TIMESTAMP() AS etl_time
FROM (
  -- 来源：dws_sup_tenant_lifetime_df
  SELECT
    CAST(NULL AS STRING) AS tenant_lifecycle_stage_code,
    BITMAP_UNION(active_tenant_bitmap) AS active_tenant_bitmap,
    BITMAP_UNION(active_tenant_bitmap) AS tenant_active_numerator_bitmap,
    SUM(active_tenant_qty) AS tenant_active_denominator_qty,
    SUM(pay_30d_amt) AS silent_tenant_qty,
    SUM(last_pay_date) AS churn_tenant_qty
  FROM dws.dws_sup_tenant_lifetime_df s
  WHERE s.travel_date = '${bizdate}'
) u
GROUP BY u.tenant_lifecycle_stage_code;
