-- ================================================================================================
-- dwd.dwd_fin_merchant_order_fund_rt  实时商户订单资金明细
-- 依据：《3.0 通用财务报表 · 需求说明》v1.0（2026-11-24）
-- 业务规则：
--   · 与离线 dwd_fin_merchant_order_fund_di 同口径同字段：支付拆收 / 付两侧，退款拆退 / 退回，核销解冻拆确认
--   · 维度（产品 / 票种 / 渠道 / 售票员 / 两侧支付信息）按票 lookup 当日实时支付明细与票维表
-- 性能：
--   · 三条流 UNION ALL 后一次 lookup；lookup 缓存 5 分钟
-- ================================================================================================

-- Flink SQL：dwd_fin_payment_rt + dwd_ord_refund_rt + dwd_fin_frozen_rt → StarRocks dwd.dwd_fin_merchant_order_fund_rt
CREATE TEMPORARY VIEW ev AS
SELECT 'PAYMENT' AS source_type, payment_no AS source_no, payee_tenant_id AS merchant_tenant_id, ticket_no, 'IN' AS side,
       IF(pay_method_type = 'CREDIT', 'CREDIT', 'CASH') AS pm_grp, pay_amt AS amt, pay_time AS event_time, 1 AS tk, proc_time
FROM dwd_fin_payment_rt WHERE pay_status = 'PAID'
UNION ALL
SELECT 'PAYMENT', payment_no, payer_tenant_id, ticket_no, 'OUT', IF(pay_method_type = 'CREDIT', 'CREDIT', 'CASH'), pay_amt, pay_time, 1, proc_time
FROM dwd_fin_payment_rt WHERE pay_status = 'PAID' AND pay_direction_type = 'OUTBOUND'
UNION ALL
SELECT 'VERIFY', frozen_no, CAST(NULL AS BIGINT), ticket_no, 'ALL', CAST(NULL AS STRING), CAST(NULL AS DECIMAL(18,2)), CAST(release_time AS STRING), 0, proc_time
FROM dwd_fin_frozen_rt WHERE frozen_status = 'RELEASED' AND release_event_type = 'VERIFY';
-- 聚合单支付（ticket_no 为空）的分摊在物化视图 mv_fin_ticket_side 内完成，与离线同口径；此处 ticket_no 为空的支付由视图按票展开
-- 退款：待确认——实时链路只有退款单流（dwd_ord_refund_rt），退款明细（按支付记录）无实时流；需补 ods_ord_refund_detail_rt 后按离线同口径拆退 / 退回

INSERT INTO sr_dwd_fin_merchant_order_fund_rt                                     -- 写入 StarRocks 目标表
SELECT DATE_FORMAT(CAST(e.event_time AS TIMESTAMP), 'yyyyMMdd') AS travel_date,
       CONCAT_WS(':', e.source_no, e.ticket_no, CAST(COALESCE(e.merchant_tenant_id, s.merchant_tenant_id) AS STRING), r.report_code, r.measure_code) AS fund_event_id,  -- 资金动作ID = 来源单号
       e.event_time, COALESCE(e.merchant_tenant_id, s.merchant_tenant_id) AS merchant_tenant_id, r.report_code, r.measure_code,
       COALESCE(e.amt, IF(r.direction_type = 'IN', s.sale_unit_price_amt, s.buy_unit_price_amt)) AS event_amt,  -- 发生金额（元
       COALESCE(e.amt, IF(r.direction_type = 'IN', s.sale_unit_price_amt, s.buy_unit_price_amt)) * r.sign_qty AS balance_effect_amt,  -- 对本报表余额的影响（元
       IF(r.measure_code IN ('RECEIVE', 'PAY'), e.tk, 0) AS ticket_net_qty,       -- 净票数
       e.source_type, r.pay_method_group_type, e.source_no, s.payment_no, s.order_group_no, s.order_no, e.ticket_no,
       s.spu_id, s.sku_id, s.channel_id, s.channel_type, s.seller_staff_id, CAST(NULL AS STRING) AS sale_point_code,  -- 售票站点（待确认
       s.payer_tenant_id, s.payer_type, s.payee_tenant_id, s.payee_type, s.sale_unit_price_amt, s.buy_unit_price_amt,
       s.receive_pay_method_type, s.pay_pay_method_type, s.settle_timing_type
FROM ev e
-- 票 × 商户的两侧支付信息与订单维度：StarRocks 物化视图 mv_fin_ticket_side（由 dwd_fin_payment_rt + dwd_fin_payment_di 汇总），按票 lookup
JOIN mv_fin_ticket_side_lookup FOR SYSTEM_TIME AS OF e.proc_time AS s
  ON s.ticket_no = e.ticket_no AND (e.merchant_tenant_id IS NULL OR s.merchant_tenant_id = e.merchant_tenant_id)  -- 按 ticket_no、merchant_tenant_id 关联
JOIN dim_fin_report_rule_lookup FOR SYSTEM_TIME AS OF e.proc_time AS r
  ON r.source_type = e.source_type                                                -- 按 source_type 关联
 AND (   (r.direction_type = e.side AND r.pay_method_group_type = e.pm_grp)
      OR (e.side = 'ALL' AND IF(r.direction_type = 'IN', s.in_payment_no, s.out_payment_no) IS NOT NULL
          AND r.pay_method_group_type = IF(IF(r.direction_type = 'IN', s.receive_pay_method_type, s.pay_pay_method_type) = 'CREDIT', 'CREDIT', 'CASH')
          AND (s.settle_timing_type = 'VERIFY' OR r.pay_method_group_type = 'CREDIT')));
