-- ================================================================================================
-- ads.ads_fin_order_report_dim_rt  订单报表多维汇总（今日实时）
-- 依据：《3.0 通用财务报表 · 需求说明》v1.0（2026-11-24）
-- 业务规则：
--   · 今日期间值取实时明细；今日日终余额 = 昨日 close_amt（离线定版，同步到 StarRocks）+ 今日余额影响
--   · 与离线同一套通用列，报表服务按日期分段拼接（6.1）
-- 性能：
--   · StarRocks 异步物化视图，1 分钟刷新
-- ================================================================================================

CREATE MATERIALIZED VIEW IF NOT EXISTS ads.ads_fin_order_report_dim_rt            -- 异步物化视图，StarRocks 定时刷新
REFRESH ASYNC EVERY (INTERVAL 1 MINUTE)
AS
WITH d AS (
    SELECT merchant_tenant_id, report_code, spu_id, sku_id, channel_type, seller_staff_id, sale_point_code, payer_tenant_id, payer_type, payee_tenant_id, payee_type, sale_unit_price_amt, buy_unit_price_amt, receive_pay_method_type, pay_pay_method_type,
           SUM(IF(measure_code IN ('RECEIVE', 'PAY'), event_amt, 0))          AS in_amt,  -- 本期收 / 本期付
           SUM(IF(measure_code IN ('REFUND', 'RETURN'), event_amt, 0))        AS out_amt,  -- 本期退 / 本期退回
           SUM(IF(measure_code IN ('TO_REVENUE', 'TO_COST'), event_amt, 0))   AS trans_amt,  -- 转实收 / 转实付
           SUM(IF(measure_code = 'CONFIRM', event_amt, 0))                    AS confirm_amt,  -- 履约收入 / 成本结算
           SUM(IF(report_code IN ('ADV_RECEIPT', 'ADV_PAYMENT'), balance_effect_amt, 0)) AS chg_amt,
           SUM(ticket_net_qty)                                                AS net_ticket_qty,  -- 净票数（预收 / 预付）
           SUM(confirm_ticket_qty)                                            AS confirm_ticket_qty  -- 核销票数（确认收入 / 确认成本）
    FROM dwd.dwd_fin_merchant_order_fund_rt
    WHERE travel_date = DATE_FORMAT(CURDATE(), '%Y%m%d')                          -- 只取今日数据
    GROUP BY merchant_tenant_id, report_code, spu_id, sku_id, channel_type, seller_staff_id, sale_point_code, payer_tenant_id, payer_type, payee_tenant_id, payee_type, sale_unit_price_amt, buy_unit_price_amt, receive_pay_method_type, pay_pay_method_type  -- 按粒度键汇总
),
y AS (
    SELECT merchant_tenant_id, report_code, spu_id, sku_id, channel_type, seller_staff_id, sale_point_code, payer_tenant_id, payer_type, payee_tenant_id, payee_type, sale_unit_price_amt, buy_unit_price_amt, receive_pay_method_type, pay_pay_method_type, close_amt
    FROM ads.ads_fin_order_report_dim_di
    WHERE travel_date = DATE_FORMAT(DATE_SUB(CURDATE(), INTERVAL 1 DAY), '%Y%m%d') AND close_amt <> 0  -- 只取今日数据
),
u AS (
    SELECT merchant_tenant_id, report_code, spu_id, sku_id, channel_type, seller_staff_id, sale_point_code, payer_tenant_id, payer_type, payee_tenant_id, payee_type, sale_unit_price_amt, buy_unit_price_amt, receive_pay_method_type, pay_pay_method_type, in_amt, out_amt, trans_amt, confirm_amt, chg_amt AS close_amt, net_ticket_qty, confirm_ticket_qty FROM d
    UNION ALL
    SELECT merchant_tenant_id, report_code, spu_id, sku_id, channel_type, seller_staff_id, sale_point_code, payer_tenant_id, payer_type, payee_tenant_id, payee_type, sale_unit_price_amt, buy_unit_price_amt, receive_pay_method_type, pay_pay_method_type, 0, 0, 0, 0, close_amt, 0, 0 FROM y
)
SELECT DATE_FORMAT(CURDATE(), '%Y%m%d') AS travel_date,
       merchant_tenant_id, report_code, spu_id, sku_id, channel_type, seller_staff_id, sale_point_code, payer_tenant_id, payer_type, payee_tenant_id, payee_type, sale_unit_price_amt, buy_unit_price_amt, receive_pay_method_type, pay_pay_method_type,
       SUM(in_amt) AS in_amt, SUM(out_amt) AS out_amt, SUM(trans_amt) AS trans_amt, SUM(confirm_amt) AS confirm_amt, SUM(close_amt) AS close_amt,  -- 期末预收 / 期末预付（日终时点值）
       SUM(net_ticket_qty) AS net_ticket_qty, SUM(confirm_ticket_qty) AS confirm_ticket_qty,  -- 核销票数（确认收入 / 确认成本）
       NOW() AS update_time                                                       -- 最近一次刷新时间
FROM u
GROUP BY merchant_tenant_id, report_code, spu_id, sku_id, channel_type, seller_staff_id, sale_point_code, payer_tenant_id, payer_type, payee_tenant_id, payee_type, sale_unit_price_amt, buy_unit_price_amt, receive_pay_method_type, pay_pay_method_type;  -- 按粒度键汇总
