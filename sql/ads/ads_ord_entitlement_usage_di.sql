-- ads.ads_ord_entitlement_usage_di  权益使用分析（年卡/次卡/计时/额度）
-- 粒度：travel_date × seller_tenant_id × sku_id
-- 来源：dws_ord_tenant_entitlement_di, dws_ord_tenant_ticket_stock_df
-- 生成方式：Spark SQL / Hive；字段 34 个：直接翻译 16 · 规则翻译 18 · 待确认 0
-- 多来源：每个来源表按粒度键先汇总，UNION ALL 后再合并

INSERT OVERWRITE TABLE ads.ads_ord_entitlement_usage_di PARTITION (travel_date = '${bizdate}')
SELECT
  x.seller_tenant_id,
  x.sku_id,
  d1.tenant_name AS seller_tenant_name,
  d2.sku_name AS sku_name,
  x.fixed_entitlement_used_qty,
  x.selectable_entitlement_used_qty,
  x.counted_entitlement_used_qty,
  x.timed_entitlement_used_qty,
  x.unlimited_entitlement_used_qty,
  x.quota_entitlement_used_qty,
  x.fixed_entitlement_usage_numerator_qty,
  x.fixed_entitlement_usage_denominator_qty,
  x.selectable_entitlement_usage_numerator_qty,
  x.selectable_entitlement_usage_denominator_qty,
  x.counted_entitlement_usage_numerator_qty,
  x.counted_entitlement_usage_denominator_qty,
  x.timed_entitlement_usage_numerator_qty,
  x.timed_entitlement_usage_denominator_qty,
  x.unlimited_entitlement_usage_numerator_qty,
  x.unlimited_entitlement_usage_denominator_qty,
  x.quota_entitlement_usage_numerator_qty,
  x.quota_entitlement_usage_denominator_qty,
  x.activate_ticket_qty,
  x.activate_numerator_qty,
  x.activate_denominator_qty,
  x.avg_activate_delay_day_numerator_qty,
  x.avg_activate_delay_day_denominator_qty,
  x.expire_ticket_qty,
  x.expire_numerator_qty,
  x.expire_denominator_qty,
  x.unverified_ticket_qty,
  x.unverified_amt,
  x.pending_activate_ticket_qty,
  x.quota_total_amt,
  x.etl_time
FROM (
SELECT
  u.seller_tenant_id,
  u.sku_id,
  SUM(u.fixed_entitlement_used_qty) AS fixed_entitlement_used_qty,
  SUM(u.selectable_entitlement_used_qty) AS selectable_entitlement_used_qty,
  SUM(u.counted_entitlement_used_qty) AS counted_entitlement_used_qty,
  SUM(u.timed_entitlement_used_qty) AS timed_entitlement_used_qty,
  SUM(u.unlimited_entitlement_used_qty) AS unlimited_entitlement_used_qty,
  SUM(u.quota_entitlement_used_qty) AS quota_entitlement_used_qty,
  SUM(u.fixed_entitlement_usage_numerator_qty) AS fixed_entitlement_usage_numerator_qty,
  SUM(u.fixed_entitlement_usage_denominator_qty) AS fixed_entitlement_usage_denominator_qty,
  SUM(u.selectable_entitlement_usage_numerator_qty) AS selectable_entitlement_usage_numerator_qty,
  SUM(u.selectable_entitlement_usage_denominator_qty) AS selectable_entitlement_usage_denominator_qty,
  SUM(u.counted_entitlement_usage_numerator_qty) AS counted_entitlement_usage_numerator_qty,
  SUM(u.counted_entitlement_usage_denominator_qty) AS counted_entitlement_usage_denominator_qty,
  SUM(u.timed_entitlement_usage_numerator_qty) AS timed_entitlement_usage_numerator_qty,
  SUM(u.timed_entitlement_usage_denominator_qty) AS timed_entitlement_usage_denominator_qty,
  SUM(u.unlimited_entitlement_usage_numerator_qty) AS unlimited_entitlement_usage_numerator_qty,
  SUM(u.unlimited_entitlement_usage_denominator_qty) AS unlimited_entitlement_usage_denominator_qty,
  SUM(u.quota_entitlement_usage_numerator_qty) AS quota_entitlement_usage_numerator_qty,
  SUM(u.quota_entitlement_usage_denominator_qty) AS quota_entitlement_usage_denominator_qty,
  SUM(u.activate_ticket_qty) AS activate_ticket_qty,
  SUM(u.activate_numerator_qty) AS activate_numerator_qty,
  SUM(u.activate_denominator_qty) AS activate_denominator_qty,
  SUM(u.avg_activate_delay_day_numerator_qty) AS avg_activate_delay_day_numerator_qty,
  SUM(u.avg_activate_delay_day_denominator_qty) AS avg_activate_delay_day_denominator_qty,
  SUM(u.expire_ticket_qty) AS expire_ticket_qty,
  SUM(u.expire_numerator_qty) AS expire_numerator_qty,
  SUM(u.expire_denominator_qty) AS expire_denominator_qty,
  SUM(u.unverified_ticket_qty) AS unverified_ticket_qty,
  SUM(u.unverified_amt) AS unverified_amt,
  SUM(u.pending_activate_ticket_qty) AS pending_activate_ticket_qty,
  SUM(u.quota_total_amt) AS quota_total_amt,
  CURRENT_TIMESTAMP() AS etl_time
FROM (
  -- 来源：dws_ord_tenant_entitlement_di
  SELECT
    seller_tenant_id AS seller_tenant_id,
    sku_id AS sku_id,
    SUM(CASE WHEN entitlement_type = 'FIXED' THEN entitlement_used_qty END) AS fixed_entitlement_used_qty,
    SUM(CASE WHEN entitlement_type = 'SELECTABLE' THEN entitlement_used_qty END) AS selectable_entitlement_used_qty,
    SUM(CASE WHEN entitlement_type = 'COUNTED' THEN entitlement_used_qty END) AS counted_entitlement_used_qty,
    SUM(CASE WHEN entitlement_type = 'TIMED' THEN entitlement_used_qty END) AS timed_entitlement_used_qty,
    SUM(CASE WHEN entitlement_type = 'UNLIMITED' THEN entitlement_used_qty END) AS unlimited_entitlement_used_qty,
    SUM(CASE WHEN entitlement_type = 'QUOTA' THEN entitlement_used_qty END) AS quota_entitlement_used_qty,
    SUM(CASE WHEN entitlement_type = 'FIXED' THEN entitlement_used_qty END) AS fixed_entitlement_usage_numerator_qty,
    SUM(CASE WHEN entitlement_type = 'FIXED' THEN entitlement_total_qty END) AS fixed_entitlement_usage_denominator_qty,
    SUM(CASE WHEN entitlement_type = 'SELECTABLE' THEN entitlement_used_qty END) AS selectable_entitlement_usage_numerator_qty,
    SUM(CASE WHEN entitlement_type = 'SELECTABLE' THEN entitlement_total_qty END) AS selectable_entitlement_usage_denominator_qty,
    SUM(CASE WHEN entitlement_type = 'COUNTED' THEN entitlement_used_qty END) AS counted_entitlement_usage_numerator_qty,
    SUM(CASE WHEN entitlement_type = 'COUNTED' THEN entitlement_total_qty END) AS counted_entitlement_usage_denominator_qty,
    SUM(CASE WHEN entitlement_type = 'TIMED' THEN entitlement_used_qty END) AS timed_entitlement_usage_numerator_qty,
    SUM(CASE WHEN entitlement_type = 'TIMED' THEN entitlement_total_qty END) AS timed_entitlement_usage_denominator_qty,
    SUM(CASE WHEN entitlement_type = 'UNLIMITED' THEN entitlement_used_qty END) AS unlimited_entitlement_usage_numerator_qty,
    SUM(CASE WHEN entitlement_type = 'UNLIMITED' THEN entitlement_total_qty END) AS unlimited_entitlement_usage_denominator_qty,
    SUM(CASE WHEN entitlement_type = 'QUOTA' THEN entitlement_used_qty END) AS quota_entitlement_usage_numerator_qty,
    SUM(CASE WHEN entitlement_type = 'QUOTA' THEN entitlement_total_qty END) AS quota_entitlement_usage_denominator_qty,
    SUM(activate_ticket_qty) AS activate_ticket_qty,
    SUM(activate_ticket_qty) AS activate_numerator_qty,
    SUM(pending_activate_ticket_qty) AS activate_denominator_qty,
    SUM(activate_delay_day_qty) AS avg_activate_delay_day_numerator_qty,
    SUM(activate_ticket_qty) AS avg_activate_delay_day_denominator_qty,
    NULL AS expire_ticket_qty,
    NULL AS expire_numerator_qty,
    NULL AS expire_denominator_qty,
    NULL AS unverified_ticket_qty,
    NULL AS unverified_amt,
    SUM(pending_activate_ticket_qty) AS pending_activate_ticket_qty,
    SUM(quota_total_amt) AS quota_total_amt
  FROM dws.dws_ord_tenant_entitlement_di s
  WHERE s.travel_date = '${bizdate}'
  GROUP BY seller_tenant_id, sku_id
  UNION ALL
  -- 来源：dws_ord_tenant_ticket_stock_df
  SELECT
    seller_tenant_id AS seller_tenant_id,
    sku_id AS sku_id,
    NULL AS fixed_entitlement_used_qty,
    NULL AS selectable_entitlement_used_qty,
    NULL AS counted_entitlement_used_qty,
    NULL AS timed_entitlement_used_qty,
    NULL AS unlimited_entitlement_used_qty,
    NULL AS quota_entitlement_used_qty,
    NULL AS fixed_entitlement_usage_numerator_qty,
    NULL AS fixed_entitlement_usage_denominator_qty,
    NULL AS selectable_entitlement_usage_numerator_qty,
    NULL AS selectable_entitlement_usage_denominator_qty,
    NULL AS counted_entitlement_usage_numerator_qty,
    NULL AS counted_entitlement_usage_denominator_qty,
    NULL AS timed_entitlement_usage_numerator_qty,
    NULL AS timed_entitlement_usage_denominator_qty,
    NULL AS unlimited_entitlement_usage_numerator_qty,
    NULL AS unlimited_entitlement_usage_denominator_qty,
    NULL AS quota_entitlement_usage_numerator_qty,
    NULL AS quota_entitlement_usage_denominator_qty,
    NULL AS activate_ticket_qty,
    NULL AS activate_numerator_qty,
    NULL AS activate_denominator_qty,
    NULL AS avg_activate_delay_day_numerator_qty,
    NULL AS avg_activate_delay_day_denominator_qty,
    SUM(expire_ticket_qty) AS expire_ticket_qty,
    SUM(expire_ticket_qty) AS expire_numerator_qty,
    SUM(issue_ticket_qty) AS expire_denominator_qty,
    SUM(unverified_ticket_qty) AS unverified_ticket_qty,
    SUM(unverified_amt) AS unverified_amt,
    NULL AS pending_activate_ticket_qty,
    NULL AS quota_total_amt
  FROM dws.dws_ord_tenant_ticket_stock_df s
  WHERE s.travel_date = '${bizdate}'
  GROUP BY seller_tenant_id, sku_id
) u
GROUP BY u.seller_tenant_id, u.sku_id
) x
LEFT JOIN dim.dim_sup_tenant_zip d1 ON d1.tenant_id = x.seller_tenant_id AND d1.travel_date = '${bizdate}' AND d1.end_date = '9999-12-31'
LEFT JOIN dim.dim_prd_sku_zip d2 ON d2.sku_id = x.sku_id AND d2.travel_date = '${bizdate}' AND d2.end_date = '9999-12-31';
