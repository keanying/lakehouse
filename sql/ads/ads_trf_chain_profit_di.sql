-- ads.ads_trf_chain_profit_di  分销链利润分配
-- 粒度：travel_date × supplier_tenant_id × sku_id
-- 来源：dws_trf_distributor_trade_di
-- 生成方式：Spark SQL / Hive；字段 22 个：直接翻译 6 · 规则翻译 16 · 待确认 0
-- 来源先按粒度键预聚合

WITH
src_distributor_trade AS (                                                        -- 来源「分销商×供应商×SKU×层级 分销日汇总」按粒度键预聚合
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
),
merged AS (                                                                       -- 按粒度键汇总，计算派生指标
  SELECT
    u.supplier_tenant_id,                                                         -- 供应商租户ID
    u.sku_id,                                                                     -- SKU ID
    u.l1_distribution_purchase_amt,                                               -- 一级分销采购金额（日）
    u.l2_distribution_purchase_amt,                                               -- 二级分销采购金额（日）
    u.l3_distribution_purchase_amt,                                               -- 三级分销采购金额（日）
    u.l4_distribution_purchase_amt,                                               -- 四级分销采购金额（日）
    u.l1_distribution_profit_amt,                                                 -- 一级分销利润（日）
    u.l2_distribution_profit_amt,                                                 -- 二级分销利润（日）
    u.l3_distribution_profit_amt,                                                 -- 三级分销利润（日）
    u.l4_distribution_profit_amt,                                                 -- 四级分销利润（日）
    u.l1_distribution_profit_numerator_amt,                                       -- 一级分销利润率分子（日）
    u.l1_distribution_profit_denominator_amt,                                     -- 一级分销利润率分母（日）
    u.l2_distribution_profit_numerator_amt,                                       -- 二级分销利润率分子（日）
    u.l2_distribution_profit_denominator_amt,                                     -- 二级分销利润率分母（日）
    u.l3_distribution_profit_numerator_amt,                                       -- 三级分销利润率分子（日）
    u.l3_distribution_profit_denominator_amt,                                     -- 三级分销利润率分母（日）
    u.l4_distribution_profit_numerator_amt,                                       -- 四级分销利润率分子（日）
    u.l4_distribution_profit_denominator_amt,                                     -- 四级分销利润率分母（日）
    u.avg_chain_level_numerator_qty,                                              -- 平均分销层级分子（日）
    u.avg_chain_level_denominator_qty,                                            -- 平均分销层级分母（日）
    CURRENT_TIMESTAMP() AS etl_time                                               -- ETL 加载时间
  FROM src_distributor_trade u
),
tenant_cur AS (                                                                   -- 「租户（商户/供应商/分销商）维度」当前有效版本，只取名称类字段
  SELECT tenant_id, tenant_name
  FROM dim.dim_sup_tenant_zip
  WHERE travel_date = '${bizdate}' AND end_date = '9999-12-31'                    -- 取当日分区里的拉链当前有效版本
),
sku_cur AS (                                                                      -- 「SKU维度」当前有效版本，只取名称类字段
  SELECT sku_id, sku_name
  FROM dim.dim_prd_sku_zip
  WHERE travel_date = '${bizdate}' AND end_date = '9999-12-31'                    -- 取当日分区里的拉链当前有效版本
)
INSERT OVERWRITE TABLE ads.ads_trf_chain_profit_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  merged.supplier_tenant_id,                                                      -- 供应商租户ID
  merged.sku_id,                                                                  -- SKU ID
  tenant_cur.tenant_name AS supplier_tenant_name,                                 -- 供应商名称
  sku_cur.sku_name AS sku_name,                                                   -- SKU 名称
  merged.l1_distribution_purchase_amt,                                            -- 一级分销采购金额（日）
  merged.l2_distribution_purchase_amt,                                            -- 二级分销采购金额（日）
  merged.l3_distribution_purchase_amt,                                            -- 三级分销采购金额（日）
  merged.l4_distribution_purchase_amt,                                            -- 四级分销采购金额（日）
  merged.l1_distribution_profit_amt,                                              -- 一级分销利润（日）
  merged.l2_distribution_profit_amt,                                              -- 二级分销利润（日）
  merged.l3_distribution_profit_amt,                                              -- 三级分销利润（日）
  merged.l4_distribution_profit_amt,                                              -- 四级分销利润（日）
  merged.l1_distribution_profit_numerator_amt,                                    -- 一级分销利润率分子（日）
  merged.l1_distribution_profit_denominator_amt,                                  -- 一级分销利润率分母（日）
  merged.l2_distribution_profit_numerator_amt,                                    -- 二级分销利润率分子（日）
  merged.l2_distribution_profit_denominator_amt,                                  -- 二级分销利润率分母（日）
  merged.l3_distribution_profit_numerator_amt,                                    -- 三级分销利润率分子（日）
  merged.l3_distribution_profit_denominator_amt,                                  -- 三级分销利润率分母（日）
  merged.l4_distribution_profit_numerator_amt,                                    -- 四级分销利润率分子（日）
  merged.l4_distribution_profit_denominator_amt,                                  -- 四级分销利润率分母（日）
  merged.avg_chain_level_numerator_qty,                                           -- 平均分销层级分子（日）
  merged.avg_chain_level_denominator_qty,                                         -- 平均分销层级分母（日）
  merged.etl_time                                                                 -- ETL 加载时间
FROM merged
LEFT JOIN tenant_cur                                                              -- 关联「租户（商户/供应商/分销商）维度」，补 supplier_tenant_name
  ON tenant_cur.tenant_id = merged.supplier_tenant_id                             -- 按 supplier_tenant_id→tenant_id 关联
LEFT JOIN sku_cur                                                                 -- 关联「SKU维度」，补 sku_name
  ON sku_cur.sku_id = merged.sku_id;                                              -- 按 sku_id 关联
