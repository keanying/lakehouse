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

WITH p AS (                                                                       -- 期间值：按报表展开
    SELECT merchant_tenant_id, spu_id, sku_id, channel_type, seller_staff_id, sale_point_code, payer_tenant_id, payer_type, payee_tenant_id, payee_type, sale_unit_price_amt, buy_unit_price_amt, receive_pay_method_type, pay_pay_method_type,
           STACK(4,
        'ADV_RECEIPT', receive_amt, refund_amt, to_revenue_amt, CAST(0 AS DECIMAL(18,2)), sale_ticket_qty - refund_ticket_qty, CAST(0 AS BIGINT),
        'ADV_PAYMENT', pay_amt, return_amt, to_cost_amt, CAST(0 AS DECIMAL(18,2)), buy_ticket_qty - return_ticket_qty, CAST(0 AS BIGINT),
        'REVENUE', CAST(0 AS DECIMAL(18,2)), CAST(0 AS DECIMAL(18,2)), CAST(0 AS DECIMAL(18,2)), revenue_amt, CAST(0 AS BIGINT), revenue_ticket_qty,
        'COST', CAST(0 AS DECIMAL(18,2)), CAST(0 AS DECIMAL(18,2)), CAST(0 AS DECIMAL(18,2)), cost_amt, CAST(0 AS BIGINT), cost_ticket_qty
    ) AS (report_code, in_amt, out_amt, trans_amt, confirm_amt, net_ticket_qty, confirm_ticket_qty)
    FROM dws.dws_fin_merchant_order_fund_di
    WHERE travel_date = '${bizdate}'                                              -- 只取当日分区
),
c AS (                                                                            -- 日终余额：在途快照按维度组合汇总
    SELECT merchant_tenant_id, report_code, spu_id, sku_id, channel_type, seller_staff_id, sale_point_code, payer_tenant_id, payer_type, payee_tenant_id, payee_type, sale_unit_price_amt, buy_unit_price_amt, receive_pay_method_type, pay_pay_method_type, SUM(unsettled_amt) AS close_amt
    FROM dws.dws_fin_merchant_unsettled_df
    WHERE travel_date = '${bizdate}'                                              -- 只取当日分区
    GROUP BY merchant_tenant_id, report_code, spu_id, sku_id, channel_type, seller_staff_id, sale_point_code, payer_tenant_id, payer_type, payee_tenant_id, payee_type, sale_unit_price_amt, buy_unit_price_amt, receive_pay_method_type, pay_pay_method_type  -- 按粒度键汇总
),
u AS (
    SELECT merchant_tenant_id, report_code, spu_id, sku_id, channel_type, seller_staff_id, sale_point_code, payer_tenant_id, payer_type, payee_tenant_id, payee_type, sale_unit_price_amt, buy_unit_price_amt, receive_pay_method_type, pay_pay_method_type, in_amt, out_amt, trans_amt, confirm_amt, CAST(0 AS DECIMAL(18,2)) AS close_amt, net_ticket_qty, confirm_ticket_qty FROM p
    UNION ALL
    SELECT merchant_tenant_id, report_code, spu_id, sku_id, channel_type, seller_staff_id, sale_point_code, payer_tenant_id, payer_type, payee_tenant_id, payee_type, sale_unit_price_amt, buy_unit_price_amt, receive_pay_method_type, pay_pay_method_type, 0, 0, 0, 0, close_amt, 0, 0 FROM c
)
INSERT OVERWRITE TABLE ads.ads_fin_order_report_dim_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT merchant_tenant_id, report_code, spu_id, sku_id, channel_type, seller_staff_id, sale_point_code, payer_tenant_id, payer_type, payee_tenant_id, payee_type, sale_unit_price_amt, buy_unit_price_amt, receive_pay_method_type, pay_pay_method_type,
       SUM(in_amt) AS in_amt, SUM(out_amt) AS out_amt, SUM(trans_amt) AS trans_amt, SUM(confirm_amt) AS confirm_amt, SUM(close_amt) AS close_amt,  -- 期末预收 / 期末预付（日终时点值）
       SUM(net_ticket_qty) AS net_ticket_qty, SUM(confirm_ticket_qty) AS confirm_ticket_qty,  -- 核销票数（确认收入 / 确认成本）
       DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time        -- ETL 加载时间
FROM u
GROUP BY merchant_tenant_id, report_code, spu_id, sku_id, channel_type, seller_staff_id, sale_point_code, payer_tenant_id, payer_type, payee_tenant_id, payee_type, sale_unit_price_amt, buy_unit_price_amt, receive_pay_method_type, pay_pay_method_type  -- 按粒度键汇总
HAVING SUM(ABS(in_amt)) + SUM(ABS(out_amt)) + SUM(ABS(trans_amt)) + SUM(ABS(confirm_amt)) + ABS(SUM(close_amt)) > 0;
