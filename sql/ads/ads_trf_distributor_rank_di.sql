-- ads.ads_trf_distributor_rank_di  分销商业绩排行
-- 粒度：travel_date × supplier_tenant_id × distributor_tenant_id
-- 来源：dws_trf_distributor_trade_di, dws_trf_distributor_credit_df
-- 生成方式：Spark SQL / Hive；字段 13 个：直接翻译 11 · 规则翻译 2 · 待确认 0
-- 多来源：每个来源先按粒度键预聚合，UNION ALL 后再汇总

WITH
src_distributor_trade AS (                                              -- 来源「分销商×供应商×SKU×层级 分销日汇总」按粒度键预聚合
  SELECT
    supplier_tenant_id AS supplier_tenant_id,                           -- 供应商租户ID
    distributor_tenant_id AS distributor_tenant_id,                     -- 分销商租户ID
    SUM(distribution_ticket_qty) AS distribution_ticket_qty,            -- 分销票数（日）
    SUM(distribution_sale_amt) AS distribution_sale_amt,                -- 分销售出金额（日）
    SUM(distribution_profit_amt) AS distribution_profit_amt,            -- 分销利润（日）
    SUM(distribution_profit_amt) AS distribution_profit_numerator_amt,  -- 分销利润率分子（日）
    SUM(distribution_sale_amt) AS distribution_profit_denominator_amt,  -- 分销利润率分母（日）
    BITMAP_UNION(active_distributor_bitmap) AS active_distributor_bitmap,  -- 动销分销商数去重位图（日）
    NULL AS new_distribution_relation_qty                               -- 新建分销关系数（日）：本来源无，补空对齐 UNION ALL
  FROM dws.dws_trf_distributor_trade_di s                               -- 来源表「分销商×供应商×SKU×层级 分销日汇总」
  WHERE s.travel_date = '${bizdate}'                                    -- 只取当日分区
  GROUP BY supplier_tenant_id, distributor_tenant_id                    -- 按粒度键汇总
),
src_distributor_credit AS (                                             -- 来源「分销关系授信快照」按粒度键预聚合
  SELECT
    CAST(NULL AS BIGINT) AS supplier_tenant_id,                         -- 供应商租户ID：本来源无，补空对齐 UNION ALL
    CAST(NULL AS BIGINT) AS distributor_tenant_id,                      -- 分销商租户ID：本来源无，补空对齐 UNION ALL
    NULL AS distribution_ticket_qty,                                    -- 分销票数（日）：本来源无，补空对齐 UNION ALL
    NULL AS distribution_sale_amt,                                      -- 分销售出金额（日）：本来源无，补空对齐 UNION ALL
    NULL AS distribution_profit_amt,                                    -- 分销利润（日）：本来源无，补空对齐 UNION ALL
    NULL AS distribution_profit_numerator_amt,                          -- 分销利润率分子（日）：本来源无，补空对齐 UNION ALL
    NULL AS distribution_profit_denominator_amt,                        -- 分销利润率分母（日）：本来源无，补空对齐 UNION ALL
    CAST(NULL AS BINARY) AS active_distributor_bitmap,                  -- 动销分销商数去重位图（日）：本来源无，补空对齐 UNION ALL
    SUM(new_distribution_relation_qty) AS new_distribution_relation_qty  -- 新建分销关系数（日）
  FROM dws.dws_trf_distributor_credit_df s                              -- 来源表「分销关系授信快照」
  WHERE s.travel_date = '${bizdate}'                                    -- 只取当日分区
),
all_src AS (                                                            -- 各来源字段已对齐，UNION ALL 合并（比多表 FULL JOIN 少 shuffle）
  SELECT * FROM src_distributor_trade
  UNION ALL
  SELECT * FROM src_distributor_credit
),
merged AS (                                                             -- 按粒度键汇总，计算派生指标
  SELECT
    u.supplier_tenant_id,                                               -- 供应商租户ID
    u.distributor_tenant_id,                                            -- 分销商租户ID
    SUM(u.distribution_ticket_qty) AS distribution_ticket_qty,          -- 分销票数（日）
    SUM(u.distribution_sale_amt) AS distribution_sale_amt,              -- 分销售出金额（日）
    SUM(u.distribution_profit_amt) AS distribution_profit_amt,          -- 分销利润（日）
    SUM(u.distribution_profit_numerator_amt) AS distribution_profit_numerator_amt,  -- 分销利润率分子（日）
    SUM(u.distribution_profit_denominator_amt) AS distribution_profit_denominator_amt,  -- 分销利润率分母（日）
    BITMAP_UNION(u.active_distributor_bitmap) AS active_distributor_bitmap,  -- 动销分销商数去重位图（日）
    SUM(u.new_distribution_relation_qty) AS new_distribution_relation_qty,  -- 新建分销关系数（日）
    CURRENT_TIMESTAMP() AS etl_time                                     -- ETL 加载时间
  FROM all_src u
  GROUP BY u.supplier_tenant_id, u.distributor_tenant_id                -- 按粒度键汇总
),
tenant_cur AS (                                                         -- 「租户（商户/供应商/分销商）维度」当前有效版本，只取名称类字段
  SELECT tenant_id, tenant_name
  FROM dim.dim_sup_tenant_zip
  WHERE travel_date = '${bizdate}' AND end_date = '9999-12-31'          -- 取当日分区里的拉链当前有效版本
),
tenant_cur_2 AS (                                                       -- 「租户（商户/供应商/分销商）维度」当前有效版本，只取名称类字段
  SELECT tenant_id, tenant_name
  FROM dim.dim_sup_tenant_zip
  WHERE travel_date = '${bizdate}' AND end_date = '9999-12-31'          -- 取当日分区里的拉链当前有效版本
)
INSERT OVERWRITE TABLE ads.ads_trf_distributor_rank_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  merged.supplier_tenant_id,                                            -- 供应商租户ID
  merged.distributor_tenant_id,                                         -- 分销商租户ID
  tenant_cur.tenant_name AS supplier_tenant_name,                       -- 供应商名称
  tenant_cur_2.tenant_name AS distributor_tenant_name,                  -- 分销商名称
  merged.distribution_ticket_qty,                                       -- 分销票数（日）
  merged.distribution_sale_amt,                                         -- 分销售出金额（日）
  merged.distribution_profit_amt,                                       -- 分销利润（日）
  merged.distribution_profit_numerator_amt,                             -- 分销利润率分子（日）
  merged.distribution_profit_denominator_amt,                           -- 分销利润率分母（日）
  merged.active_distributor_bitmap,                                     -- 动销分销商数去重位图（日）
  merged.new_distribution_relation_qty,                                 -- 新建分销关系数（日）
  merged.etl_time                                                       -- ETL 加载时间
FROM merged
LEFT JOIN tenant_cur                                                    -- 关联「租户（商户/供应商/分销商）维度」，补 supplier_tenant_name
  ON tenant_cur.tenant_id = merged.supplier_tenant_id                   -- 按 supplier_tenant_id→tenant_id 关联
LEFT JOIN tenant_cur_2                                                  -- 关联「租户（商户/供应商/分销商）维度」，补 distributor_tenant_name
  ON tenant_cur_2.tenant_id = merged.distributor_tenant_id;             -- 按 distributor_tenant_id→tenant_id 关联
