-- ================================================================================================
-- ads.ads_fin_order_report_dim_di  订单报表多维汇总（日）
-- 依据：《3.0 通用财务报表 · 需求说明》v1.0（2026-11-24）
-- 业务规则：
--   · 期间值：日汇总按报表展开成通用列（in / out / trans / confirm），一行一个报表 × 维度组合
--   · 日终余额 close_amt：在途快照按维度组合汇总，没有当日发生的组合也保留（期初 / 期末要用）
--   · 只保留有发生额或有余额的组合
-- 性能：
--   · 日汇总、快照各扫一个分区，UNION ALL 后按维度汇总
-- ================================================================================================

WITH p AS (                        -- 期间值：按报表展开
    SELECT merchant_tenant_id,     -- 本方商户租户ID
           spu_id,                 -- 产品(SPU)ID
           sku_id,                 -- SKU ID
           channel_type,           -- 下单渠道（维度）
           seller_staff_id,        -- 售票员
           sale_point_code,        -- 售票站点
           payer_tenant_id,        -- 付款方
           payer_type,             -- 付款方类型
           payee_tenant_id,        -- 收款方
           payee_type,             -- 收款方类型
           sale_unit_price_amt,    -- 卖出单价
           buy_unit_price_amt,     -- 买入单价
           receive_pay_method_type,  -- 收款支付方式
           pay_pay_method_type,    -- 付款支付方式
           STACK(4,
               -- 每行一个报表：报表编码, 发生额收(in), 发生额付(out), 转实收 / 实付(trans), 确认(confirm), 净票数, 确认票数
               'ADV_RECEIPT', receive_amt, refund_amt, to_revenue_amt, z_amt, sale_ticket_qty - refund_ticket_qty, z_qty,
               'ADV_PAYMENT', pay_amt,     return_amt, to_cost_amt,    z_amt, buy_ticket_qty - return_ticket_qty,  z_qty,
               'REVENUE',     z_amt,       z_amt,      z_amt,          revenue_amt, z_qty,                         revenue_ticket_qty,
               'COST',        z_amt,       z_amt,      z_amt,          cost_amt,    z_qty,                         cost_ticket_qty
           ) AS (report_code, in_amt, out_amt, trans_amt, confirm_amt, net_ticket_qty, confirm_ticket_qty)
    FROM (                         -- 该报表不适用的列补 0（STACK 各行类型须一致）
        SELECT *,
               CAST(0 AS DECIMAL(18,2)) AS z_amt,  -- 金额补 0（类型对齐）
               CAST(0 AS BIGINT) AS z_qty  -- 数量补 0（类型对齐）
        FROM dws.dws_fin_merchant_order_fund_di
        WHERE travel_date = '${bizdate}'  -- 只取当日分区
    ) s
),
c AS (                             -- 日终余额：在途快照按维度组合汇总
    SELECT merchant_tenant_id,     -- 本方商户租户ID
           report_code,            -- 报表
           spu_id,                 -- 产品(SPU)ID
           sku_id,                 -- SKU ID
           channel_type,           -- 下单渠道（维度）
           seller_staff_id,        -- 售票员
           sale_point_code,        -- 售票站点
           payer_tenant_id,        -- 付款方
           payer_type,             -- 付款方类型
           payee_tenant_id,        -- 收款方
           payee_type,             -- 收款方类型
           sale_unit_price_amt,    -- 卖出单价
           buy_unit_price_amt,     -- 买入单价
           receive_pay_method_type,  -- 收款支付方式
           pay_pay_method_type,    -- 付款支付方式
           SUM(unsettled_amt) AS close_amt  -- 期末预收 / 期末预付（日终时点值）
    FROM dws.dws_fin_merchant_unsettled_df
    WHERE travel_date = '${bizdate}'  -- 只取当日分区
    GROUP BY merchant_tenant_id,   -- 按粒度键汇总
             report_code,          -- 报表
             spu_id,               -- 产品(SPU)ID
             sku_id,               -- SKU ID
             channel_type,         -- 下单渠道（维度）
             seller_staff_id,      -- 售票员
             sale_point_code,      -- 售票站点
             payer_tenant_id,      -- 付款方
             payer_type,           -- 付款方类型
             payee_tenant_id,      -- 收款方
             payee_type,           -- 收款方类型
             sale_unit_price_amt,  -- 卖出单价
             buy_unit_price_amt,   -- 买入单价
             receive_pay_method_type,  -- 收款支付方式
             pay_pay_method_type   -- 付款支付方式
),
u AS (
    SELECT merchant_tenant_id,     -- 本方商户租户ID
           report_code,            -- 报表
           spu_id,                 -- 产品(SPU)ID
           sku_id,                 -- SKU ID
           channel_type,           -- 下单渠道（维度）
           seller_staff_id,        -- 售票员
           sale_point_code,        -- 售票站点
           payer_tenant_id,        -- 付款方
           payer_type,             -- 付款方类型
           payee_tenant_id,        -- 收款方
           payee_type,             -- 收款方类型
           sale_unit_price_amt,    -- 卖出单价
           buy_unit_price_amt,     -- 买入单价
           receive_pay_method_type,  -- 收款支付方式
           pay_pay_method_type,    -- 付款支付方式
           in_amt,                 -- 本期收 / 本期付
           out_amt,                -- 本期退 / 本期退回
           trans_amt,              -- 转实收 / 转实付
           confirm_amt,            -- 履约收入 / 成本结算
           CAST(0 AS DECIMAL(18,2)) AS close_amt,  -- 期末预收 / 期末预付（日终时点值）：本来源无，补空对齐 UNION ALL
           net_ticket_qty,         -- 净票数（预收 / 预付）
           confirm_ticket_qty FROM p
    UNION ALL
    SELECT merchant_tenant_id,     -- 本方商户租户ID
           report_code,            -- 报表
           spu_id,                 -- 产品(SPU)ID
           sku_id,                 -- SKU ID
           channel_type,           -- 下单渠道（维度）
           seller_staff_id,        -- 售票员
           sale_point_code,        -- 售票站点
           payer_tenant_id,        -- 付款方
           payer_type,             -- 付款方类型
           payee_tenant_id,        -- 收款方
           payee_type,             -- 收款方类型
           sale_unit_price_amt,    -- 卖出单价
           buy_unit_price_amt,     -- 买入单价
           receive_pay_method_type,  -- 收款支付方式
           pay_pay_method_type,    -- 付款支付方式
           0,
           0,
           0,
           0,
           close_amt,              -- 期末预收 / 期末预付（日终时点值）
           0,
           0 FROM c
)
INSERT OVERWRITE TABLE ads.ads_fin_order_report_dim_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT merchant_tenant_id,         -- 本方商户租户ID
       report_code,                -- 报表
       spu_id,                     -- 产品(SPU)ID
       sku_id,                     -- SKU ID
       channel_type,               -- 下单渠道（维度）
       seller_staff_id,            -- 售票员
       sale_point_code,            -- 售票站点
       payer_tenant_id,            -- 付款方
       payer_type,                 -- 付款方类型
       payee_tenant_id,            -- 收款方
       payee_type,                 -- 收款方类型
       sale_unit_price_amt,        -- 卖出单价
       buy_unit_price_amt,         -- 买入单价
       receive_pay_method_type,    -- 收款支付方式
       pay_pay_method_type,        -- 付款支付方式
       SUM(in_amt) AS in_amt,      -- 本期收 / 本期付
       SUM(out_amt) AS out_amt,    -- 本期退 / 本期退回
       SUM(trans_amt) AS trans_amt,  -- 转实收 / 转实付
       SUM(confirm_amt) AS confirm_amt,  -- 履约收入 / 成本结算
       SUM(close_amt) AS close_amt,  -- 期末预收 / 期末预付（日终时点值）
       SUM(net_ticket_qty) AS net_ticket_qty,  -- 净票数（预收 / 预付）
       SUM(confirm_ticket_qty) AS confirm_ticket_qty,  -- 核销票数（确认收入 / 确认成本）
       DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time  -- ETL 加载时间
FROM u
GROUP BY merchant_tenant_id,       -- 按粒度键汇总
         report_code,              -- 报表
         spu_id,                   -- 产品(SPU)ID
         sku_id,                   -- SKU ID
         channel_type,             -- 下单渠道（维度）
         seller_staff_id,          -- 售票员
         sale_point_code,          -- 售票站点
         payer_tenant_id,          -- 付款方
         payer_type,               -- 付款方类型
         payee_tenant_id,          -- 收款方
         payee_type,               -- 收款方类型
         sale_unit_price_amt,      -- 卖出单价
         buy_unit_price_amt,       -- 买入单价
         receive_pay_method_type,  -- 收款支付方式
         pay_pay_method_type       -- 付款支付方式
HAVING SUM(ABS(in_amt)) + SUM(ABS(out_amt)) + SUM(ABS(trans_amt)) + SUM(ABS(confirm_amt)) + ABS(SUM(close_amt)) > 0;
