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
           MAX(spu_id) AS spu_id, MAX(sku_id) AS sku_id, MAX(channel_id) AS channel_id, MAX(channel_type) AS channel_type, MAX(seller_staff_id) AS seller_staff_id, MAX(payer_tenant_id) AS payer_tenant_id, MAX(payer_type) AS payer_type, MAX(payee_tenant_id) AS payee_tenant_id, MAX(payee_type) AS payee_type, MAX(sale_unit_price_amt) AS sale_unit_price_amt, MAX(buy_unit_price_amt) AS buy_unit_price_amt, MAX(receive_pay_method_type) AS receive_pay_method_type, MAX(pay_pay_method_type) AS pay_pay_method_type,
           SUM(balance_effect_amt) AS chg_amt, SUM(ticket_net_qty) AS chg_qty
    FROM dwd.dwd_fin_merchant_order_fund_di
    WHERE travel_date = '${bizdate}' AND report_code IN ('ADV_RECEIPT', 'ADV_PAYMENT', 'CREDIT_IN', 'CREDIT_OUT')
    GROUP BY merchant_tenant_id, report_code, ticket_no
),
prev AS (
    SELECT * FROM dws.dws_fin_merchant_unsettled_df
    WHERE travel_date = DATE_FORMAT(DATE_SUB(TO_DATE('${bizdate}', 'yyyyMMdd'), 1), 'yyyyMMdd')
)
INSERT OVERWRITE TABLE dws.dws_fin_merchant_unsettled_df PARTITION (travel_date = '${bizdate}')
SELECT
    COALESCE(n.merchant_tenant_id, p.merchant_tenant_id)            AS merchant_tenant_id,
    COALESCE(n.report_code, p.report_code)                          AS report_code,
    COALESCE(n.ticket_no, p.ticket_no)                              AS ticket_no,
    COALESCE(p.order_no, n.order_no)                                AS order_no,
    COALESCE(p.spu_id, n.spu_id)                                  AS spu_id,
    COALESCE(p.sku_id, n.sku_id)                                  AS sku_id,
    COALESCE(p.channel_id, n.channel_id)                          AS channel_id,
    COALESCE(p.channel_type, n.channel_type)                      AS channel_type,
    COALESCE(p.seller_staff_id, n.seller_staff_id)                AS seller_staff_id,
    COALESCE(p.payer_tenant_id, n.payer_tenant_id)                AS payer_tenant_id,
    COALESCE(p.payer_type, n.payer_type)                          AS payer_type,
    COALESCE(p.payee_tenant_id, n.payee_tenant_id)                AS payee_tenant_id,
    COALESCE(p.payee_type, n.payee_type)                          AS payee_type,
    COALESCE(p.sale_unit_price_amt, n.sale_unit_price_amt)        AS sale_unit_price_amt,
    COALESCE(p.buy_unit_price_amt, n.buy_unit_price_amt)          AS buy_unit_price_amt,
    COALESCE(p.receive_pay_method_type, n.receive_pay_method_type) AS receive_pay_method_type,
    COALESCE(p.pay_pay_method_type, n.pay_pay_method_type)        AS pay_pay_method_type,
    COALESCE(p.unsettled_amt, 0) + COALESCE(n.chg_amt, 0)           AS unsettled_amt,
    COALESCE(p.unsettled_ticket_qty, 0) + COALESCE(n.chg_qty, 0)    AS unsettled_ticket_qty,
    COALESCE(p.first_event_date, '${bizdate}')                     AS first_event_date,
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time
FROM today n
FULL OUTER JOIN prev p ON p.merchant_tenant_id = n.merchant_tenant_id AND p.report_code = n.report_code AND p.ticket_no = n.ticket_no
WHERE ROUND(COALESCE(p.unsettled_amt, 0) + COALESCE(n.chg_amt, 0), 2) <> 0;
