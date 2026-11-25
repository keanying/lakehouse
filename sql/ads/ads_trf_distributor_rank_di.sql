-- ads.ads_trf_distributor_rank_di  分销商业绩排行
-- 粒度：travel_date × supplier_tenant_id × distributor_tenant_id
-- 来源：dws_trf_distributor_trade_di, dws_trf_distributor_credit_df
-- 生成方式：Spark SQL / Hive；字段 13 个：直接翻译 11 · 规则翻译 0 · 待确认 2
-- 多来源：每个来源表按粒度键先汇总，UNION ALL 后再合并
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT OVERWRITE TABLE ads.ads_trf_distributor_rank_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  x.supplier_tenant_id,                                                   -- 供应商租户ID
  x.distributor_tenant_id,                                                -- 分销商租户ID
  d1.tenant_name AS supplier_tenant_name,                                 -- 供应商名称
  d2.tenant_name AS distributor_tenant_name,                              -- 分销商名称
  x.distribution_ticket_qty,                                              -- 分销票数（日）
  x.distribution_sale_amt,                                                -- 分销售出金额（日）
  x.distribution_profit_amt,                                              -- 分销利润（日）
  x.distribution_profit_numerator_amt,                                    -- 分销利润率分子（日）
  x.distribution_profit_denominator_amt,                                  -- 分销利润率分母（日）
  x.active_distributor_bitmap,                                            -- 动销分销商数去重位图（日）
  x.new_distribution_relation_qty,                                        -- 新建分销关系数（日）
  x.etl_time                                                              -- ETL 加载时间
FROM (
SELECT
  u.supplier_tenant_id,                                                   -- 供应商租户ID
  u.distributor_tenant_id,                                                -- 分销商租户ID
  SUM(u.distribution_ticket_qty) AS distribution_ticket_qty,              -- 分销票数（日）
  SUM(u.distribution_sale_amt) AS distribution_sale_amt,                  -- 分销售出金额（日）
  SUM(u.distribution_profit_amt) AS distribution_profit_amt,              -- 分销利润（日）
  SUM(u.distribution_profit_numerator_amt) AS distribution_profit_numerator_amt,  -- 分销利润率分子（日）
  SUM(u.distribution_profit_denominator_amt) AS distribution_profit_denominator_amt,  -- 分销利润率分母（日）
  BITMAP_UNION(u.active_distributor_bitmap) AS active_distributor_bitmap,  -- 动销分销商数去重位图（日）
  SUM(u.new_distribution_relation_qty) AS new_distribution_relation_qty,  -- 新建分销关系数（日）
  CURRENT_TIMESTAMP() AS etl_time                                         -- ETL 加载时间
FROM (
  -- 来源：dws_trf_distributor_trade_di
  SELECT
    supplier_tenant_id AS supplier_tenant_id,                             -- 供应商租户ID
    distributor_tenant_id AS distributor_tenant_id,                       -- 分销商租户ID
    SUM(distribution_ticket_qty) AS distribution_ticket_qty,              -- 分销票数（日）
    SUM(distribution_sale_amt) AS distribution_sale_amt,                  -- 分销售出金额（日）
    SUM(distribution_profit_amt) AS distribution_profit_amt,              -- 分销利润（日）
    SUM(distribution_profit_amt) AS distribution_profit_numerator_amt,    -- 分销利润率分子（日）
    SUM(distribution_sale_amt) AS distribution_profit_denominator_amt,    -- 分销利润率分母（日）
    BITMAP_UNION(active_distributor_bitmap) AS active_distributor_bitmap,  -- 动销分销商数去重位图（日）
    NULL AS new_distribution_relation_qty                                 -- 新建分销关系数（日）
  FROM dws.dws_trf_distributor_trade_di s                                 -- 来源表「分销商×供应商×SKU×层级 分销日汇总」
  WHERE s.travel_date = '${bizdate}'                                      -- 只取当日分区
  GROUP BY supplier_tenant_id, distributor_tenant_id                      -- 按粒度键汇总
  UNION ALL                                                               -- 合并各来源
  -- 来源：dws_trf_distributor_credit_df
  SELECT
    CAST(NULL AS BIGINT) AS supplier_tenant_id,                           -- 供应商租户ID
    CAST(NULL AS BIGINT) AS distributor_tenant_id,                        -- 分销商租户ID
    NULL AS distribution_ticket_qty,                                      -- 分销票数（日）
    NULL AS distribution_sale_amt,                                        -- 分销售出金额（日）
    NULL AS distribution_profit_amt,                                      -- 分销利润（日）
    NULL AS distribution_profit_numerator_amt,                            -- 分销利润率分子（日）
    NULL AS distribution_profit_denominator_amt,                          -- 分销利润率分母（日）
    CAST(NULL AS BINARY) AS active_distributor_bitmap,                    -- 动销分销商数去重位图（日）
    SUM(new_distribution_relation_qty) AS new_distribution_relation_qty   -- 新建分销关系数（日）
  FROM dws.dws_trf_distributor_credit_df s                                -- 来源表「分销关系授信快照」
  WHERE s.travel_date = '${bizdate}'                                      -- 只取当日分区
) u                                                                       -- 各来源合并后的明细
GROUP BY u.supplier_tenant_id, u.distributor_tenant_id                    -- 按粒度键汇总
) x                                                                       -- 汇总结果，外层再补维度名称
LEFT JOIN dim.dim_sup_tenant_zip d1 ON d1.tenant_id = x.supplier_tenant_id AND d1.travel_date = '${bizdate}' AND d1.end_date = '9999-12-31'  -- 关联「租户（商户/供应商/分销商）维度」，取维度名称
LEFT JOIN dim.dim_sup_tenant_zip d2 ON d2.tenant_id = x.distributor_tenant_id AND d2.travel_date = '${bizdate}' AND d2.end_date = '9999-12-31';  -- 关联「租户（商户/供应商/分销商）维度」，取维度名称
