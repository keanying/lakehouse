-- ================================================================================================
-- dws.dws_fin_merchant_unsettled_df  预收预付在途快照
-- 依据：《3.0 通用财务报表 · 需求说明》v1.0（2026-11-24）
-- 业务规则：
--   · 在途 = T-1 快照 + 当日预收 / 预付的余额影响（收 / 付 +，退 / 退回 / 转实收 / 转实付 −）；归零的票不再保留
--   · 期初 = 区间首日前一天快照，期末 = 区间末日快照（5.7）；按票保留全部订单维度，因此按任意维度拆分都成立
-- 性能：
--   · 只读 T-1 一个分区 + 当日明细一个分区，不回扫历史流水
-- ================================================================================================

WITH today AS (
    SELECT merchant_tenant_id, report_code, ticket_no, MAX(order_no) AS order_no,  -- 子单号
           MAX(spu_id) AS spu_id,                                                 -- 产品(SPU)ID
           MAX(sku_id) AS sku_id,                                                 -- SKU ID
           MAX(channel_type) AS channel_type,                                     -- 下单渠道（维度）
           MAX(seller_staff_id) AS seller_staff_id,                               -- 售票员
           MAX(sale_point_code) AS sale_point_code,                               -- 售票站点
           MAX(payer_tenant_id) AS payer_tenant_id,                               -- 付款方
           MAX(payer_type) AS payer_type,                                         -- 付款方类型
           MAX(payee_tenant_id) AS payee_tenant_id,                               -- 收款方
           MAX(payee_type) AS payee_type,                                         -- 收款方类型
           MAX(sale_unit_price_amt) AS sale_unit_price_amt,                       -- 卖出单价
           MAX(buy_unit_price_amt) AS buy_unit_price_amt,                         -- 买入单价
           MAX(receive_pay_method_type) AS receive_pay_method_type,               -- 收款支付方式
           MAX(pay_pay_method_type) AS pay_pay_method_type,                       -- 付款支付方式
           SUM(balance_effect_amt) AS chg_amt,                                    -- 变动金额（元）
           SUM(ticket_net_qty) AS chg_qty                                         -- 变动数量
    FROM dwd.dwd_fin_merchant_order_fund_di
    WHERE travel_date = '${bizdate}' AND report_code IN ('ADV_RECEIPT', 'ADV_PAYMENT')  -- 只取当日分区，并按条件过滤
    GROUP BY merchant_tenant_id, report_code, ticket_no                           -- 按粒度键汇总
),
prev AS (
    SELECT * FROM dws.dws_fin_merchant_unsettled_df WHERE travel_date = DATE_FORMAT(DATE_SUB(TO_DATE('${bizdate}', 'yyyyMMdd'), 1), 'yyyyMMdd')
)
INSERT OVERWRITE TABLE dws.dws_fin_merchant_unsettled_df PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
    COALESCE(n.merchant_tenant_id, p.merchant_tenant_id)            AS merchant_tenant_id,  -- 本方商户租户ID
    COALESCE(n.report_code, p.report_code)                          AS report_code,  -- 报表
    COALESCE(n.ticket_no, p.ticket_no)                              AS ticket_no,  -- 票号
    COALESCE(p.order_no, n.order_no)                                AS order_no,  -- 子单号
    COALESCE(p.spu_id, n.spu_id) AS spu_id,                                       -- 产品(SPU)ID
    COALESCE(p.sku_id, n.sku_id) AS sku_id,                                       -- SKU ID
    COALESCE(p.channel_type, n.channel_type) AS channel_type,                     -- 下单渠道（维度）
    COALESCE(p.seller_staff_id, n.seller_staff_id) AS seller_staff_id,            -- 售票员
    COALESCE(p.sale_point_code, n.sale_point_code) AS sale_point_code,            -- 售票站点
    COALESCE(p.payer_tenant_id, n.payer_tenant_id) AS payer_tenant_id,            -- 付款方
    COALESCE(p.payer_type, n.payer_type) AS payer_type,                           -- 付款方类型
    COALESCE(p.payee_tenant_id, n.payee_tenant_id) AS payee_tenant_id,            -- 收款方
    COALESCE(p.payee_type, n.payee_type) AS payee_type,                           -- 收款方类型
    COALESCE(p.sale_unit_price_amt, n.sale_unit_price_amt) AS sale_unit_price_amt,  -- 卖出单价
    COALESCE(p.buy_unit_price_amt, n.buy_unit_price_amt) AS buy_unit_price_amt,   -- 买入单价
    COALESCE(p.receive_pay_method_type, n.receive_pay_method_type) AS receive_pay_method_type,  -- 收款支付方式
    COALESCE(p.pay_pay_method_type, n.pay_pay_method_type) AS pay_pay_method_type,  -- 付款支付方式
    COALESCE(p.unsettled_amt, 0) + COALESCE(n.chg_amt, 0)           AS unsettled_amt,  -- 在途金额（期末预收 / 期末预付）
    COALESCE(p.unsettled_ticket_qty, 0) + COALESCE(n.chg_qty, 0)    AS unsettled_ticket_qty,  -- 在途票数
    COALESCE(p.first_event_date, '${bizdate}')                     AS first_event_date,  -- 首次进入在途的日期（收 / 付日期）
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time           -- ETL 加载时间
FROM today n
FULL OUTER JOIN prev p
  ON p.merchant_tenant_id = n.merchant_tenant_id                                  -- 按 merchant_tenant_id 关联
    AND p.report_code = n.report_code
    AND p.ticket_no = n.ticket_no
WHERE ROUND(COALESCE(p.unsettled_amt, 0) + COALESCE(n.chg_amt, 0), 2) <> 0;
