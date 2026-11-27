-- ================================================================================================
-- dws.dws_fin_merchant_unsettled_df  预收预付在途快照
-- 依据：《3.0 通用财务报表 · 需求说明》v1.0（2026-11-24）
-- 业务规则：
--   · 在途 = T-1 快照 + 当日预收 / 预付的余额影响（收 / 付 +，退 / 退回 / 转确认 −）；归零的票不再保留
--   · 期初 = T-1 快照，期末 = T 快照（需求 5.7：时点值由累计得出，不独立维护）
-- 性能：
--   · 只读 T-1 一个分区 + 当日明细一个分区，不回扫历史流水
--   · 先按 (商户, 报表, 票) 聚合当日变动再与快照合并
-- ================================================================================================

WITH today AS (
    SELECT merchant_tenant_id, report_code, ticket_no, MAX(order_no) AS order_no,
           MAX(spu_id) AS spu_id, MAX(sku_id) AS sku_id, MAX(channel_id) AS channel_id, MAX(channel_type) AS channel_type, MAX(seller_staff_id) AS seller_staff_id, MAX(payer_tenant_id) AS payer_tenant_id, MAX(payer_type) AS payer_type, MAX(payee_tenant_id) AS payee_tenant_id, MAX(payee_type) AS payee_type, MAX(sale_unit_price_amt) AS sale_unit_price_amt, MAX(buy_unit_price_amt) AS buy_unit_price_amt, MAX(receive_pay_method_type) AS receive_pay_method_type, MAX(pay_pay_method_type) AS pay_pay_method_type,  -- 付款支付方式（付侧）
           SUM(balance_effect_amt) AS chg_amt, SUM(ticket_net_qty) AS chg_qty
    FROM dwd.dwd_fin_merchant_order_fund_di
    WHERE travel_date = '${bizdate}' AND report_code IN ('ADV_RECEIPT', 'ADV_PAYMENT', 'CREDIT_IN', 'CREDIT_OUT')  -- 只取当日分区，并按条件过滤
    GROUP BY merchant_tenant_id, report_code, ticket_no                           -- 按粒度键汇总
),
prev AS (
    SELECT * FROM dws.dws_fin_merchant_unsettled_df
    WHERE travel_date = DATE_FORMAT(DATE_SUB(TO_DATE('${bizdate}', 'yyyyMMdd'), 1), 'yyyyMMdd')
)
INSERT OVERWRITE TABLE dws.dws_fin_merchant_unsettled_df PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
    COALESCE(n.merchant_tenant_id, p.merchant_tenant_id)            AS merchant_tenant_id,  -- 本方商户租户ID
    COALESCE(n.report_code, p.report_code)                          AS report_code,  -- 报表
    COALESCE(n.ticket_no, p.ticket_no)                              AS ticket_no,  -- 票号
    COALESCE(p.order_no, n.order_no)                                AS order_no,  -- 子单号
    COALESCE(p.spu_id, n.spu_id)                                  AS spu_id,      -- 产品(SPU)ID
    COALESCE(p.sku_id, n.sku_id)                                  AS sku_id,      -- SKU ID
    COALESCE(p.channel_id, n.channel_id)                          AS channel_id,  -- 入口渠道ID
    COALESCE(p.channel_type, n.channel_type)                      AS channel_type,  -- 入口渠道类型
    COALESCE(p.seller_staff_id, n.seller_staff_id)                AS seller_staff_id,  -- 售票员（订单操作人
    COALESCE(p.payer_tenant_id, n.payer_tenant_id)                AS payer_tenant_id,  -- 付款方（收侧维度）
    COALESCE(p.payer_type, n.payer_type)                          AS payer_type,  -- 付款方类型
    COALESCE(p.payee_tenant_id, n.payee_tenant_id)                AS payee_tenant_id,  -- 收款方（付侧维度）
    COALESCE(p.payee_type, n.payee_type)                          AS payee_type,  -- 收款方类型
    COALESCE(p.sale_unit_price_amt, n.sale_unit_price_amt)        AS sale_unit_price_amt,  -- 卖出单价（元）
    COALESCE(p.buy_unit_price_amt, n.buy_unit_price_amt)          AS buy_unit_price_amt,  -- 买入单价（元）
    COALESCE(p.receive_pay_method_type, n.receive_pay_method_type) AS receive_pay_method_type,  -- 收款支付方式（收侧）
    COALESCE(p.pay_pay_method_type, n.pay_pay_method_type)        AS pay_pay_method_type,  -- 付款支付方式（付侧）
    COALESCE(p.unsettled_amt, 0) + COALESCE(n.chg_amt, 0)           AS unsettled_amt,  -- 在途金额
    COALESCE(p.unsettled_ticket_qty, 0) + COALESCE(n.chg_qty, 0)    AS unsettled_ticket_qty,  -- 在途票数
    COALESCE(p.first_event_date, '${bizdate}')                     AS first_event_date,  -- 首次进入在途的日期（收 / 付日期）
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time           -- ETL 加载时间
FROM today n
FULL OUTER JOIN prev p ON p.merchant_tenant_id = n.merchant_tenant_id AND p.report_code = n.report_code AND p.ticket_no = n.ticket_no
WHERE ROUND(COALESCE(p.unsettled_amt, 0) + COALESCE(n.chg_amt, 0), 2) <> 0;
