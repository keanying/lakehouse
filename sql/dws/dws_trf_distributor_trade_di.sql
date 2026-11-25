-- dws.dws_trf_distributor_trade_di  分销商×供应商×SKU×层级 分销日汇总
-- 粒度：travel_date × distributor_tenant_id × supplier_tenant_id × sku_id × chain_level_no
-- 来源：dwd_trf_distribution_settle_di, dwd_ord_refund_ticket_di
-- 生成方式：Spark SQL / Hive；字段 13 个：直接翻译 4 · 规则翻译 1 · 待确认 8
-- 多来源：每个来源表按粒度键先汇总，UNION ALL 后再合并
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT OVERWRITE TABLE dws.dws_trf_distributor_trade_di PARTITION (travel_date = '${bizdate}')
SELECT
  u.distributor_tenant_id,
  u.supplier_tenant_id,
  u.sku_id,
  u.chain_level_no,
  SUM(u.distribution_ticket_qty) AS distribution_ticket_qty,
  SUM(u.distribution_sale_amt) AS distribution_sale_amt,
  SUM(u.distribution_purchase_amt) AS distribution_purchase_amt,
  SUM(u.distribution_profit_amt) AS distribution_profit_amt,
  SUM(u.refund_ticket_qty) AS refund_ticket_qty,
  SUM(u.chain_level_qty) AS chain_level_qty,
  SUM(u.active_distributor_qty) AS active_distributor_qty,
  BITMAP_UNION(u.active_distributor_bitmap) AS active_distributor_bitmap,
  CURRENT_TIMESTAMP() AS etl_time
FROM (
  -- 来源：dwd_trf_distribution_settle_di
  SELECT
    distributor_tenant_id AS distributor_tenant_id,
    supplier_tenant_id AS supplier_tenant_id,
    sku_id AS sku_id,
    chain_level_no AS chain_level_no,
    COUNT(DISTINCT ticket_no) AS distribution_ticket_qty,
    NULL AS distribution_sale_amt,  -- 待确认：sum(amount) by chain_level
    NULL AS distribution_purchase_amt,  -- 待确认：sum(settle_amount) by chain_level
    NULL AS distribution_profit_amt,  -- 待确认：sum(amount - settle_amount)
    NULL AS refund_ticket_qty,
    NULL AS chain_level_qty,  -- 待确认：sum(max(chain_level)) by ticket
    NULL AS active_distributor_qty,
    CAST(NULL AS BINARY) AS active_distributor_bitmap
  FROM dwd.dwd_trf_distribution_settle_di s
  WHERE s.travel_date = '${bizdate}'
  GROUP BY distributor_tenant_id, supplier_tenant_id, sku_id, chain_level_no
  UNION ALL
  -- 来源：dwd_ord_refund_ticket_di
  SELECT
    tenant_id AS distributor_tenant_id,
    tenant_id AS supplier_tenant_id,
    sku_id AS sku_id,
    CAST(NULL AS INT) AS chain_level_no,
    NULL AS distribution_ticket_qty,
    NULL AS distribution_sale_amt,
    NULL AS distribution_purchase_amt,
    NULL AS distribution_profit_amt,
    COUNT(DISTINCT CASE WHEN 1 = 1 THEN ticket_no END) AS refund_ticket_qty,  -- 待确认：of completed refunds
    NULL AS chain_level_qty,
    NULL AS active_distributor_qty,
    CAST(NULL AS BINARY) AS active_distributor_bitmap
  FROM dwd.dwd_ord_refund_ticket_di s
  WHERE s.travel_date = '${bizdate}'
  GROUP BY tenant_id, tenant_id, sku_id
  UNION ALL
  -- 来源：dws_trf_distributor_trade_di
  SELECT
    distributor_tenant_id AS distributor_tenant_id,
    supplier_tenant_id AS supplier_tenant_id,
    sku_id AS sku_id,
    chain_level_no AS chain_level_no,
    NULL AS distribution_ticket_qty,
    NULL AS distribution_sale_amt,
    NULL AS distribution_purchase_amt,
    NULL AS distribution_profit_amt,
    NULL AS refund_ticket_qty,
    NULL AS chain_level_qty,
    NULL AS active_distributor_qty,  -- 待确认：引用本表（count(distinct distributor_tenant_id)），需拆成两步计算
    NULL AS active_distributor_bitmap  -- 待确认：引用本表（BITMAP_UNION(TO_BITMAP(distributor_tenant_id))），需拆成两步计算
  FROM dws.dws_trf_distributor_trade_di s
  WHERE s.travel_date = '${bizdate}'
  GROUP BY distributor_tenant_id, supplier_tenant_id, sku_id, chain_level_no
) u
GROUP BY u.distributor_tenant_id, u.supplier_tenant_id, u.sku_id, u.chain_level_no;
