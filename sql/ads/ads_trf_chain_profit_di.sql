-- ads.ads_trf_chain_profit_di  分销链利润分配
-- 粒度：travel_date × supplier_tenant_id × sku_id
-- 来源：dws_trf_distributor_trade_di
-- 生成方式：Spark SQL / Hive；字段 22 个：直接翻译 6 · 规则翻译 16 · 待确认 0

INSERT OVERWRITE TABLE ads.ads_trf_chain_profit_di PARTITION (travel_date = '${bizdate}')
SELECT
  x.supplier_tenant_id,
  x.sku_id,
  d1.tenant_name AS supplier_tenant_name,
  d2.sku_name AS sku_name,
  x.l1_distribution_purchase_amt,
  x.l2_distribution_purchase_amt,
  x.l3_distribution_purchase_amt,
  x.l4_distribution_purchase_amt,
  x.l1_distribution_profit_amt,
  x.l2_distribution_profit_amt,
  x.l3_distribution_profit_amt,
  x.l4_distribution_profit_amt,
  x.l1_distribution_profit_numerator_amt,
  x.l1_distribution_profit_denominator_amt,
  x.l2_distribution_profit_numerator_amt,
  x.l2_distribution_profit_denominator_amt,
  x.l3_distribution_profit_numerator_amt,
  x.l3_distribution_profit_denominator_amt,
  x.l4_distribution_profit_numerator_amt,
  x.l4_distribution_profit_denominator_amt,
  x.avg_chain_level_numerator_qty,
  x.avg_chain_level_denominator_qty,
  x.etl_time
FROM (
SELECT
  u.supplier_tenant_id,
  u.sku_id,
  SUM(u.l1_distribution_purchase_amt) AS l1_distribution_purchase_amt,
  SUM(u.l2_distribution_purchase_amt) AS l2_distribution_purchase_amt,
  SUM(u.l3_distribution_purchase_amt) AS l3_distribution_purchase_amt,
  SUM(u.l4_distribution_purchase_amt) AS l4_distribution_purchase_amt,
  SUM(u.l1_distribution_profit_amt) AS l1_distribution_profit_amt,
  SUM(u.l2_distribution_profit_amt) AS l2_distribution_profit_amt,
  SUM(u.l3_distribution_profit_amt) AS l3_distribution_profit_amt,
  SUM(u.l4_distribution_profit_amt) AS l4_distribution_profit_amt,
  SUM(u.l1_distribution_profit_numerator_amt) AS l1_distribution_profit_numerator_amt,
  SUM(u.l1_distribution_profit_denominator_amt) AS l1_distribution_profit_denominator_amt,
  SUM(u.l2_distribution_profit_numerator_amt) AS l2_distribution_profit_numerator_amt,
  SUM(u.l2_distribution_profit_denominator_amt) AS l2_distribution_profit_denominator_amt,
  SUM(u.l3_distribution_profit_numerator_amt) AS l3_distribution_profit_numerator_amt,
  SUM(u.l3_distribution_profit_denominator_amt) AS l3_distribution_profit_denominator_amt,
  SUM(u.l4_distribution_profit_numerator_amt) AS l4_distribution_profit_numerator_amt,
  SUM(u.l4_distribution_profit_denominator_amt) AS l4_distribution_profit_denominator_amt,
  SUM(u.avg_chain_level_numerator_qty) AS avg_chain_level_numerator_qty,
  SUM(u.avg_chain_level_denominator_qty) AS avg_chain_level_denominator_qty,
  CURRENT_TIMESTAMP() AS etl_time
FROM (
  -- 来源：dws_trf_distributor_trade_di
  SELECT
    supplier_tenant_id AS supplier_tenant_id,
    sku_id AS sku_id,
    SUM(CASE WHEN chain_level_no = '1' THEN distribution_purchase_amt END) AS l1_distribution_purchase_amt,
    SUM(CASE WHEN chain_level_no = '2' THEN distribution_purchase_amt END) AS l2_distribution_purchase_amt,
    SUM(CASE WHEN chain_level_no = '3' THEN distribution_purchase_amt END) AS l3_distribution_purchase_amt,
    SUM(CASE WHEN chain_level_no = '4' THEN distribution_purchase_amt END) AS l4_distribution_purchase_amt,
    SUM(CASE WHEN chain_level_no = '1' THEN distribution_profit_amt END) AS l1_distribution_profit_amt,
    SUM(CASE WHEN chain_level_no = '2' THEN distribution_profit_amt END) AS l2_distribution_profit_amt,
    SUM(CASE WHEN chain_level_no = '3' THEN distribution_profit_amt END) AS l3_distribution_profit_amt,
    SUM(CASE WHEN chain_level_no = '4' THEN distribution_profit_amt END) AS l4_distribution_profit_amt,
    SUM(CASE WHEN chain_level_no = '1' THEN distribution_profit_amt END) AS l1_distribution_profit_numerator_amt,
    SUM(CASE WHEN chain_level_no = '1' THEN distribution_sale_amt END) AS l1_distribution_profit_denominator_amt,
    SUM(CASE WHEN chain_level_no = '2' THEN distribution_profit_amt END) AS l2_distribution_profit_numerator_amt,
    SUM(CASE WHEN chain_level_no = '2' THEN distribution_sale_amt END) AS l2_distribution_profit_denominator_amt,
    SUM(CASE WHEN chain_level_no = '3' THEN distribution_profit_amt END) AS l3_distribution_profit_numerator_amt,
    SUM(CASE WHEN chain_level_no = '3' THEN distribution_sale_amt END) AS l3_distribution_profit_denominator_amt,
    SUM(CASE WHEN chain_level_no = '4' THEN distribution_profit_amt END) AS l4_distribution_profit_numerator_amt,
    SUM(CASE WHEN chain_level_no = '4' THEN distribution_sale_amt END) AS l4_distribution_profit_denominator_amt,
    SUM(chain_level_qty) AS avg_chain_level_numerator_qty,
    SUM(distribution_ticket_qty) AS avg_chain_level_denominator_qty
  FROM dws.dws_trf_distributor_trade_di s
  WHERE s.travel_date = '${bizdate}'
  GROUP BY supplier_tenant_id, sku_id
) u
GROUP BY u.supplier_tenant_id, u.sku_id
) x
LEFT JOIN dim.dim_sup_tenant_zip d1 ON d1.tenant_id = x.supplier_tenant_id AND d1.travel_date = '${bizdate}' AND d1.end_date = '9999-12-31'
LEFT JOIN dim.dim_prd_sku_zip d2 ON d2.sku_id = x.sku_id AND d2.travel_date = '${bizdate}' AND d2.end_date = '9999-12-31';
