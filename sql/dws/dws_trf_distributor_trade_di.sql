-- dws.dws_trf_distributor_trade_di  分销商×供应商×SKU×层级 分销日汇总
-- 粒度：travel_date × distributor_tenant_id × supplier_tenant_id × sku_id × chain_level_no
-- 来源：dwd_trf_distribution_settle_di + dwd_ord_refund_ticket_di
-- 生成方式：手写（结构不适合按字段自动翻译）；业务规则：
--   · 一行明细 = 采购链上一级的一笔采购付款：分销商（付款方）向供应商（收款方）采购；只取 2 级及以上（1 级为游客付款）
--   · 售出 = 本级售价 sale_amt（支付记录 amount），采购 = 本级结算价 settle_amt，利润 = profit_amt
--   · 分销层级合计：每张票取其最大层级，只记在该票的最大层级那一行，粒度汇总后求平均层级用
--   · 退款票：退款完成的票按票号回找当日及历史采购链（近 400 天），落到对应分销商 / 供应商 / 层级
--   · 动销分销商：本行有分销票即为 1（粒度含分销商），任意周期用位图去重
-- 性能：
--   · 采购链明细按票号关联退款票，只取近 400 天分区

WITH settle AS (
    SELECT distributor_tenant_id, supplier_tenant_id, sku_id, chain_level_no, ticket_no, sale_amt, settle_amt, profit_amt,
           MAX(chain_level_no) OVER (PARTITION BY ticket_no) AS max_level_no
    FROM dwd.dwd_trf_distribution_settle_di
    WHERE travel_date = '${bizdate}' AND chain_level_no >= 2                      -- 只取当日分区，并按条件过滤｜1 级为游客付款给末级分销商，不算分销采购
),
chain AS (                                                                        -- 退款票回找采购链
    SELECT ticket_no, distributor_tenant_id, supplier_tenant_id, sku_id, chain_level_no
    FROM dwd.dwd_trf_distribution_settle_di
    WHERE travel_date >= DATE_FORMAT(DATE_SUB(TO_DATE('${bizdate}', 'yyyyMMdd'), 400), 'yyyyMMdd') AND chain_level_no >= 2
    GROUP BY ticket_no, distributor_tenant_id, supplier_tenant_id, sku_id, chain_level_no  -- 按粒度键汇总
),
refund AS (
    SELECT c.distributor_tenant_id, c.supplier_tenant_id, c.sku_id, c.chain_level_no, COUNT(DISTINCT r.ticket_no) AS refund_ticket_qty
    FROM (SELECT DISTINCT ticket_no FROM dwd.dwd_ord_refund_ticket_di WHERE travel_date = '${bizdate}' AND refund_status = 'COMPLETED') r
    JOIN chain c ON c.ticket_no = r.ticket_no
    GROUP BY c.distributor_tenant_id, c.supplier_tenant_id, c.sku_id, c.chain_level_no  -- 按粒度键汇总
),
agg AS (
    SELECT distributor_tenant_id, supplier_tenant_id, sku_id, chain_level_no,
           COUNT(DISTINCT ticket_no)                                         AS distribution_ticket_qty,  -- 分销票数
           SUM(sale_amt)                                                     AS distribution_sale_amt,  -- 分销售出金额
           SUM(settle_amt)                                                   AS distribution_purchase_amt,  -- 分销采购金额
           SUM(profit_amt)                                                   AS distribution_profit_amt,  -- 分销利润
           SUM(IF(chain_level_no = max_level_no, chain_level_no, 0))         AS chain_level_qty  -- 分销层级合计
    FROM settle
    GROUP BY distributor_tenant_id, supplier_tenant_id, sku_id, chain_level_no    -- 按粒度键汇总
)
INSERT OVERWRITE TABLE dws.dws_trf_distributor_trade_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
    COALESCE(a.distributor_tenant_id, r.distributor_tenant_id)       AS distributor_tenant_id,  -- 分销商租户ID
    COALESCE(a.supplier_tenant_id, r.supplier_tenant_id)             AS supplier_tenant_id,  -- 供应商租户ID
    COALESCE(a.sku_id, r.sku_id)                                     AS sku_id,   -- SKU ID
    COALESCE(a.chain_level_no, r.chain_level_no)                     AS chain_level_no,  -- 分销链层级
    COALESCE(a.distribution_ticket_qty, 0)                           AS distribution_ticket_qty,  -- 分销票数
    COALESCE(a.distribution_sale_amt, 0)                             AS distribution_sale_amt,  -- 分销售出金额
    COALESCE(a.distribution_purchase_amt, 0)                         AS distribution_purchase_amt,  -- 分销采购金额
    COALESCE(a.distribution_profit_amt, 0)                           AS distribution_profit_amt,  -- 分销利润
    COALESCE(r.refund_ticket_qty, 0)                                 AS refund_ticket_qty,  -- 退款票数
    COALESCE(a.chain_level_qty, 0)                                   AS chain_level_qty,  -- 分销层级合计
    IF(a.distribution_ticket_qty > 0, 1, 0)                          AS active_distributor_qty,  -- 动销分销商数
    TO_BITMAP(IF(a.distribution_ticket_qty > 0, a.distributor_tenant_id, NULL)) AS active_distributor_bitmap,  -- 动销分销商数去重位图
    CURRENT_TIMESTAMP() AS etl_time                                               -- ETL 加载时间
FROM agg a
FULL OUTER JOIN refund r
  ON r.distributor_tenant_id = a.distributor_tenant_id AND r.supplier_tenant_id = a.supplier_tenant_id  -- 按 distributor_tenant_id、supplier_tenant_id 关联
 AND r.sku_id = a.sku_id AND r.chain_level_no = a.chain_level_no;
