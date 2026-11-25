-- ads.ads_trf_chain_profit_di  分销链利润分配
-- 粒度：travel_date × supplier_tenant_id × sku_id
-- 来源：dws_trf_distributor_trade_di
-- 生成方式：Spark SQL / Hive；字段 22 个：直接翻译 6 · 规则翻译 16 · 待确认 0

INSERT OVERWRITE TABLE ads.ads_trf_chain_profit_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  x.supplier_tenant_id,                                                           -- 供应商租户ID
  x.sku_id,                                                                       -- SKU ID
  d1.tenant_name AS supplier_tenant_name,                                         -- 供应商名称
  d2.sku_name AS sku_name,                                                        -- SKU 名称
  x.l1_distribution_purchase_amt,                                                 -- 一级分销采购金额（日）
  x.l2_distribution_purchase_amt,                                                 -- 二级分销采购金额（日）
  x.l3_distribution_purchase_amt,                                                 -- 三级分销采购金额（日）
  x.l4_distribution_purchase_amt,                                                 -- 四级分销采购金额（日）
  x.l1_distribution_profit_amt,                                                   -- 一级分销利润（日）
  x.l2_distribution_profit_amt,                                                   -- 二级分销利润（日）
  x.l3_distribution_profit_amt,                                                   -- 三级分销利润（日）
  x.l4_distribution_profit_amt,                                                   -- 四级分销利润（日）
  x.l1_distribution_profit_numerator_amt,                                         -- 一级分销利润率分子（日）
  x.l1_distribution_profit_denominator_amt,                                       -- 一级分销利润率分母（日）
  x.l2_distribution_profit_numerator_amt,                                         -- 二级分销利润率分子（日）
  x.l2_distribution_profit_denominator_amt,                                       -- 二级分销利润率分母（日）
  x.l3_distribution_profit_numerator_amt,                                         -- 三级分销利润率分子（日）
  x.l3_distribution_profit_denominator_amt,                                       -- 三级分销利润率分母（日）
  x.l4_distribution_profit_numerator_amt,                                         -- 四级分销利润率分子（日）
  x.l4_distribution_profit_denominator_amt,                                       -- 四级分销利润率分母（日）
  x.avg_chain_level_numerator_qty,                                                -- 平均分销层级分子（日）
  x.avg_chain_level_denominator_qty,                                              -- 平均分销层级分母（日）
  x.etl_time                                                                      -- ETL 加载时间
FROM (
SELECT
  u.supplier_tenant_id,                                                           -- 供应商租户ID
  u.sku_id,                                                                       -- SKU ID
  SUM(u.l1_distribution_purchase_amt) AS l1_distribution_purchase_amt,            -- 一级分销采购金额（日）
  SUM(u.l2_distribution_purchase_amt) AS l2_distribution_purchase_amt,            -- 二级分销采购金额（日）
  SUM(u.l3_distribution_purchase_amt) AS l3_distribution_purchase_amt,            -- 三级分销采购金额（日）
  SUM(u.l4_distribution_purchase_amt) AS l4_distribution_purchase_amt,            -- 四级分销采购金额（日）
  SUM(u.l1_distribution_profit_amt) AS l1_distribution_profit_amt,                -- 一级分销利润（日）
  SUM(u.l2_distribution_profit_amt) AS l2_distribution_profit_amt,                -- 二级分销利润（日）
  SUM(u.l3_distribution_profit_amt) AS l3_distribution_profit_amt,                -- 三级分销利润（日）
  SUM(u.l4_distribution_profit_amt) AS l4_distribution_profit_amt,                -- 四级分销利润（日）
  SUM(u.l1_distribution_profit_numerator_amt) AS l1_distribution_profit_numerator_amt,  -- 一级分销利润率分子（日）
  SUM(u.l1_distribution_profit_denominator_amt) AS l1_distribution_profit_denominator_amt,  -- 一级分销利润率分母（日）
  SUM(u.l2_distribution_profit_numerator_amt) AS l2_distribution_profit_numerator_amt,  -- 二级分销利润率分子（日）
  SUM(u.l2_distribution_profit_denominator_amt) AS l2_distribution_profit_denominator_amt,  -- 二级分销利润率分母（日）
  SUM(u.l3_distribution_profit_numerator_amt) AS l3_distribution_profit_numerator_amt,  -- 三级分销利润率分子（日）
  SUM(u.l3_distribution_profit_denominator_amt) AS l3_distribution_profit_denominator_amt,  -- 三级分销利润率分母（日）
  SUM(u.l4_distribution_profit_numerator_amt) AS l4_distribution_profit_numerator_amt,  -- 四级分销利润率分子（日）
  SUM(u.l4_distribution_profit_denominator_amt) AS l4_distribution_profit_denominator_amt,  -- 四级分销利润率分母（日）
  SUM(u.avg_chain_level_numerator_qty) AS avg_chain_level_numerator_qty,          -- 平均分销层级分子（日）
  SUM(u.avg_chain_level_denominator_qty) AS avg_chain_level_denominator_qty,      -- 平均分销层级分母（日）
  CURRENT_TIMESTAMP() AS etl_time                                                 -- ETL 加载时间
FROM (
  -- 来源：dws_trf_distributor_trade_di
  SELECT
    supplier_tenant_id AS supplier_tenant_id,                                     -- 供应商租户ID
    sku_id AS sku_id,                                                             -- SKU ID
    SUM(CASE WHEN chain_level_no = '1' THEN distribution_purchase_amt END) AS l1_distribution_purchase_amt,  -- 一级分销采购金额（日）
    SUM(CASE WHEN chain_level_no = '2' THEN distribution_purchase_amt END) AS l2_distribution_purchase_amt,  -- 二级分销采购金额（日）
    SUM(CASE WHEN chain_level_no = '3' THEN distribution_purchase_amt END) AS l3_distribution_purchase_amt,  -- 三级分销采购金额（日）
    SUM(CASE WHEN chain_level_no = '4' THEN distribution_purchase_amt END) AS l4_distribution_purchase_amt,  -- 四级分销采购金额（日）
    SUM(CASE WHEN chain_level_no = '1' THEN distribution_profit_amt END) AS l1_distribution_profit_amt,  -- 一级分销利润（日）
    SUM(CASE WHEN chain_level_no = '2' THEN distribution_profit_amt END) AS l2_distribution_profit_amt,  -- 二级分销利润（日）
    SUM(CASE WHEN chain_level_no = '3' THEN distribution_profit_amt END) AS l3_distribution_profit_amt,  -- 三级分销利润（日）
    SUM(CASE WHEN chain_level_no = '4' THEN distribution_profit_amt END) AS l4_distribution_profit_amt,  -- 四级分销利润（日）
    SUM(CASE WHEN chain_level_no = '1' THEN distribution_profit_amt END) AS l1_distribution_profit_numerator_amt,  -- 一级分销利润率分子（日）
    SUM(CASE WHEN chain_level_no = '1' THEN distribution_sale_amt END) AS l1_distribution_profit_denominator_amt,  -- 一级分销利润率分母（日）
    SUM(CASE WHEN chain_level_no = '2' THEN distribution_profit_amt END) AS l2_distribution_profit_numerator_amt,  -- 二级分销利润率分子（日）
    SUM(CASE WHEN chain_level_no = '2' THEN distribution_sale_amt END) AS l2_distribution_profit_denominator_amt,  -- 二级分销利润率分母（日）
    SUM(CASE WHEN chain_level_no = '3' THEN distribution_profit_amt END) AS l3_distribution_profit_numerator_amt,  -- 三级分销利润率分子（日）
    SUM(CASE WHEN chain_level_no = '3' THEN distribution_sale_amt END) AS l3_distribution_profit_denominator_amt,  -- 三级分销利润率分母（日）
    SUM(CASE WHEN chain_level_no = '4' THEN distribution_profit_amt END) AS l4_distribution_profit_numerator_amt,  -- 四级分销利润率分子（日）
    SUM(CASE WHEN chain_level_no = '4' THEN distribution_sale_amt END) AS l4_distribution_profit_denominator_amt,  -- 四级分销利润率分母（日）
    SUM(chain_level_qty) AS avg_chain_level_numerator_qty,                        -- 平均分销层级分子（日）
    SUM(distribution_ticket_qty) AS avg_chain_level_denominator_qty               -- 平均分销层级分母（日）
  FROM dws.dws_trf_distributor_trade_di s                                         -- 来源表「分销商×供应商×SKU×层级 分销日汇总」
  WHERE s.travel_date = '${bizdate}'                                              -- 只取当日分区
  GROUP BY supplier_tenant_id, sku_id                                             -- 按粒度键汇总
) u                                                                               -- 各来源合并后的明细
GROUP BY u.supplier_tenant_id, u.sku_id                                           -- 按粒度键汇总
) x                                                                               -- 汇总结果，外层再补维度名称
LEFT JOIN dim.dim_sup_tenant_zip d1 ON d1.tenant_id = x.supplier_tenant_id AND d1.travel_date = '${bizdate}' AND d1.end_date = '9999-12-31'  -- 关联「租户（商户/供应商/分销商）维度」，取维度名称
LEFT JOIN dim.dim_prd_sku_zip d2 ON d2.sku_id = x.sku_id AND d2.travel_date = '${bizdate}' AND d2.end_date = '9999-12-31';  -- 关联「SKU维度」，取维度名称
