-- dws.dws_trf_distributor_trade_di  分销商×供应商×SKU×层级 分销日汇总
-- 粒度：travel_date × distributor_tenant_id × supplier_tenant_id × sku_id × chain_level_no
-- 来源：dwd_trf_distribution_settle_di, dwd_ord_refund_ticket_di
-- 生成方式：Spark SQL / Hive；字段 13 个：直接翻译 4 · 规则翻译 1 · 待确认 8
-- 多来源：每个来源表按粒度键先汇总，UNION ALL 后再合并
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT OVERWRITE TABLE dws.dws_trf_distributor_trade_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  u.distributor_tenant_id,                                  -- 分销商租户ID
  u.supplier_tenant_id,                                     -- 供应商租户ID
  u.sku_id,                                                 -- SKU ID
  u.chain_level_no,                                         -- 分销链层级
  SUM(u.distribution_ticket_qty) AS distribution_ticket_qty,  -- 分销票数
  SUM(u.distribution_sale_amt) AS distribution_sale_amt,    -- 分销售出金额
  SUM(u.distribution_purchase_amt) AS distribution_purchase_amt,  -- 分销采购金额
  SUM(u.distribution_profit_amt) AS distribution_profit_amt,  -- 分销利润
  SUM(u.refund_ticket_qty) AS refund_ticket_qty,            -- 退款票数
  SUM(u.chain_level_qty) AS chain_level_qty,                -- 分销层级合计
  SUM(u.active_distributor_qty) AS active_distributor_qty,  -- 动销分销商数
  BITMAP_UNION(u.active_distributor_bitmap) AS active_distributor_bitmap,  -- 动销分销商数去重位图
  CURRENT_TIMESTAMP() AS etl_time                           -- ETL 加载时间
FROM (
  -- 来源：dwd_trf_distribution_settle_di
  SELECT
    distributor_tenant_id AS distributor_tenant_id,         -- 分销商租户ID
    supplier_tenant_id AS supplier_tenant_id,               -- 供应商租户ID
    sku_id AS sku_id,                                       -- SKU ID
    chain_level_no AS chain_level_no,                       -- 分销链层级
    COUNT(DISTINCT ticket_no) AS distribution_ticket_qty,   -- 分销票数
    NULL AS distribution_sale_amt,                          -- 分销售出金额｜待确认：sum(amount) by chain_level
    NULL AS distribution_purchase_amt,                      -- 分销采购金额｜待确认：sum(settle_amount) by chain_level
    NULL AS distribution_profit_amt,                        -- 分销利润｜待确认：sum(amount - settle_amount)
    NULL AS refund_ticket_qty,                              -- 退款票数
    NULL AS chain_level_qty,                                -- 分销层级合计｜待确认：sum(max(chain_level)) by ticket
    NULL AS active_distributor_qty,                         -- 动销分销商数
    CAST(NULL AS BINARY) AS active_distributor_bitmap       -- 动销分销商数去重位图
  FROM dwd.dwd_trf_distribution_settle_di s                 -- 来源表「分销采购链明细」
  WHERE s.travel_date = '${bizdate}'                        -- 只取当日分区
  GROUP BY distributor_tenant_id, supplier_tenant_id, sku_id, chain_level_no  -- 按粒度键汇总
  UNION ALL                                                 -- 合并各来源
  -- 来源：dwd_ord_refund_ticket_di
  SELECT
    tenant_id AS distributor_tenant_id,                     -- 分销商租户ID
    tenant_id AS supplier_tenant_id,                        -- 供应商租户ID
    sku_id AS sku_id,                                       -- SKU ID
    CAST(NULL AS INT) AS chain_level_no,                    -- 分销链层级
    NULL AS distribution_ticket_qty,                        -- 分销票数
    NULL AS distribution_sale_amt,                          -- 分销售出金额
    NULL AS distribution_purchase_amt,                      -- 分销采购金额
    NULL AS distribution_profit_amt,                        -- 分销利润
    COUNT(DISTINCT CASE WHEN 1 = 1 THEN ticket_no END) AS refund_ticket_qty,  -- 退款票数｜待确认：of completed refunds
    NULL AS chain_level_qty,                                -- 分销层级合计
    NULL AS active_distributor_qty,                         -- 动销分销商数
    CAST(NULL AS BINARY) AS active_distributor_bitmap       -- 动销分销商数去重位图
  FROM dwd.dwd_ord_refund_ticket_di s                       -- 来源表「退款票明细」
  WHERE s.travel_date = '${bizdate}'                        -- 只取当日分区
  GROUP BY tenant_id, tenant_id, sku_id                     -- 按粒度键汇总
  UNION ALL                                                 -- 合并各来源
  -- 来源：dws_trf_distributor_trade_di
  SELECT
    distributor_tenant_id AS distributor_tenant_id,         -- 分销商租户ID
    supplier_tenant_id AS supplier_tenant_id,               -- 供应商租户ID
    sku_id AS sku_id,                                       -- SKU ID
    chain_level_no AS chain_level_no,                       -- 分销链层级
    NULL AS distribution_ticket_qty,                        -- 分销票数
    NULL AS distribution_sale_amt,                          -- 分销售出金额
    NULL AS distribution_purchase_amt,                      -- 分销采购金额
    NULL AS distribution_profit_amt,                        -- 分销利润
    NULL AS refund_ticket_qty,                              -- 退款票数
    NULL AS chain_level_qty,                                -- 分销层级合计
    NULL AS active_distributor_qty,                         -- 动销分销商数｜待确认：引用本表（count(distinct distributor_tenant_id)），需拆成两步计算
    NULL AS active_distributor_bitmap                       -- 动销分销商数去重位图｜待确认：引用本表（BITMAP_UNION(TO_BITMAP(distributor_tenant_id))），需拆成两步计算
  FROM dws.dws_trf_distributor_trade_di s                   -- 来源表「分销商×供应商×SKU×层级 分销日汇总」
  WHERE s.travel_date = '${bizdate}'                        -- 只取当日分区
  GROUP BY distributor_tenant_id, supplier_tenant_id, sku_id, chain_level_no  -- 按粒度键汇总
) u                                                         -- 各来源合并后的明细
GROUP BY u.distributor_tenant_id, u.supplier_tenant_id, u.sku_id, u.chain_level_no;  -- 按粒度键汇总
