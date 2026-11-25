-- ads.ads_trf_distributor_rank_di  分销商业绩排行
-- 粒度：travel_date × supplier_tenant_id × distributor_tenant_id
-- 来源：dws_trf_distributor_trade_di, dws_trf_distributor_credit_df
-- 生成方式：Spark SQL / Hive；字段 13 个：直接翻译 11 · 规则翻译 0 · 待确认 2
-- 多来源：每个来源表按粒度键先汇总，UNION ALL 后再合并
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT OVERWRITE TABLE ads.ads_trf_distributor_rank_di PARTITION (travel_date = '${bizdate}')
SELECT
  x.supplier_tenant_id,
  x.distributor_tenant_id,
  d1.tenant_name AS supplier_tenant_name,
  d2.tenant_name AS distributor_tenant_name,
  x.distribution_ticket_qty,
  x.distribution_sale_amt,
  x.distribution_profit_amt,
  x.distribution_profit_numerator_amt,
  x.distribution_profit_denominator_amt,
  x.active_distributor_bitmap,
  x.new_distribution_relation_qty,
  x.etl_time
FROM (
SELECT
  u.supplier_tenant_id,
  u.distributor_tenant_id,
  SUM(u.distribution_ticket_qty) AS distribution_ticket_qty,
  SUM(u.distribution_sale_amt) AS distribution_sale_amt,
  SUM(u.distribution_profit_amt) AS distribution_profit_amt,
  SUM(u.distribution_profit_numerator_amt) AS distribution_profit_numerator_amt,
  SUM(u.distribution_profit_denominator_amt) AS distribution_profit_denominator_amt,
  BITMAP_UNION(u.active_distributor_bitmap) AS active_distributor_bitmap,
  SUM(u.new_distribution_relation_qty) AS new_distribution_relation_qty,
  CURRENT_TIMESTAMP() AS etl_time
FROM (
  -- 来源：dws_trf_distributor_trade_di
  SELECT
    supplier_tenant_id AS supplier_tenant_id,
    distributor_tenant_id AS distributor_tenant_id,
    SUM(distribution_ticket_qty) AS distribution_ticket_qty,
    SUM(distribution_sale_amt) AS distribution_sale_amt,
    SUM(distribution_profit_amt) AS distribution_profit_amt,
    SUM(distribution_profit_amt) AS distribution_profit_numerator_amt,
    SUM(distribution_sale_amt) AS distribution_profit_denominator_amt,
    BITMAP_UNION(active_distributor_bitmap) AS active_distributor_bitmap,
    NULL AS new_distribution_relation_qty
  FROM dws.dws_trf_distributor_trade_di s
  WHERE s.travel_date = '${bizdate}'
  GROUP BY supplier_tenant_id, distributor_tenant_id
  UNION ALL
  -- 来源：dws_trf_distributor_credit_df
  SELECT
    CAST(NULL AS BIGINT) AS supplier_tenant_id,
    CAST(NULL AS BIGINT) AS distributor_tenant_id,
    NULL AS distribution_ticket_qty,
    NULL AS distribution_sale_amt,
    NULL AS distribution_profit_amt,
    NULL AS distribution_profit_numerator_amt,
    NULL AS distribution_profit_denominator_amt,
    CAST(NULL AS BINARY) AS active_distributor_bitmap,
    SUM(new_distribution_relation_qty) AS new_distribution_relation_qty
  FROM dws.dws_trf_distributor_credit_df s
  WHERE s.travel_date = '${bizdate}'
) u
GROUP BY u.supplier_tenant_id, u.distributor_tenant_id
) x
LEFT JOIN dim.dim_sup_tenant_zip d1 ON d1.tenant_id = x.supplier_tenant_id AND d1.travel_date = '${bizdate}' AND d1.end_date = '9999-12-31'
LEFT JOIN dim.dim_sup_tenant_zip d2 ON d2.tenant_id = x.distributor_tenant_id AND d2.travel_date = '${bizdate}' AND d2.end_date = '9999-12-31';
