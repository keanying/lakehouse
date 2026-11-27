-- ================================================================================================
-- dwd.dwd_fin_merchant_order_fund_rt  实时商户订单资金明细
-- 依据：《3.0 通用财务报表 · 需求说明》v1.0（2026-11-24）
-- 业务规则：
--   · 与离线 dwd_fin_merchant_order_fund_di 同一套逻辑（7.3：明细与汇总同规则），只处理今天的支付 / 退款 / 核销
--   · 历史支付、票、聚合单、归属规则、结算时点通过 Hive 外表（hive_catalog）读取
-- 性能：
--   · StarRocks 异步物化视图，1 分钟刷新；按 travel_date 分区，只刷新今天分区
-- ================================================================================================
CREATE MATERIALIZED VIEW IF NOT EXISTS dwd.dwd_fin_merchant_order_fund_rt         -- 异步物化视图，StarRocks 定时刷新
REFRESH ASYNC EVERY (INTERVAL 1 MINUTE)
AS
WITH tk AS (                                                                      -- 票：聚合单内按单价占比（全 0 元时均分），用于把按聚合单的支付分摊到票
    SELECT ticket_no, order_no, order_group_no, spu_id, sku_id,
           COALESCE(unit_price_amt / NULLIF(SUM(unit_price_amt) OVER (PARTITION BY order_group_no), 0),
                    1.0 / COUNT(*) OVER (PARTITION BY order_group_no))  AS w
    FROM hive_catalog.dwd.dwd_ord_ticket_di WHERE travel_date >= DATE_FORMAT(DATE_SUB(CURDATE(), INTERVAL 400 DAY), '%Y%m%d')
),
pay AS (                                                                          -- 支付记录落到票（近 400 天：退款 / 核销要回找原支付）
    SELECT p.payment_no, p.order_group_no, COALESCE(NULLIF(p.ticket_no, ''), t.ticket_no) AS ticket_no, p.pay_direction_type, p.pay_method_type,
           CAST(p.pay_amt * IF(p.ticket_no = '', t.w, 1) AS DECIMAL(18,2)) AS amt,
           p.pay_time, p.payee_tenant_id, p.payer_tenant_id
    FROM (SELECT * FROM hive_catalog.dwd.dwd_fin_payment_di WHERE travel_date >= DATE_FORMAT(DATE_SUB(CURDATE(), INTERVAL 400 DAY), '%Y%m%d')
           UNION ALL SELECT * FROM dwd.dwd_fin_payment_rt WHERE travel_date = DATE_FORMAT(CURDATE(), '%Y%m%d')) p
    LEFT JOIN tk t ON p.ticket_no = '' AND t.order_group_no = p.order_group_no
    WHERE p.pay_status IN ('PAID', 'PARTIAL_REFUNDED', 'REFUNDED')
),
side AS (                                                                         -- (本方商户, 票) → 收侧 / 付侧支付信息（需求 4.4：三对收付维度分开取）
    SELECT merchant_tenant_id, ticket_no,
           MAX(IF(side = 'IN', payment_no, NULL))          AS in_payment_no,
           MAX(IF(side = 'IN', amt, NULL))                 AS sale_unit_price_amt,  -- 卖出单价（收侧维度
           MAX(IF(side = 'IN', pay_method_type, NULL))     AS receive_pay_method_type,  -- 收款支付方式（收侧维度
           MAX(IF(side = 'IN', counterparty, NULL))        AS payer_tenant_id,    -- 付款方（收侧维度
           MAX(IF(side = 'IN', cp_type, NULL))             AS payer_type,         -- 付款方类型
           MAX(IF(side = 'OUT', payment_no, NULL))         AS out_payment_no,
           MAX(IF(side = 'OUT', amt, NULL))                AS buy_unit_price_amt,  -- 买入单价（付侧维度
           MAX(IF(side = 'OUT', pay_method_type, NULL))    AS pay_pay_method_type,  -- 付款支付方式（付侧维度
           MAX(IF(side = 'OUT', counterparty, NULL))       AS payee_tenant_id,    -- 收款方（付侧维度
           MAX(order_group_no)                             AS order_group_no      -- 业务订单号（明细列
    FROM (
        SELECT payee_tenant_id AS merchant_tenant_id, ticket_no, 'IN' AS side, payment_no, amt, pay_method_type, order_group_no,
               IF(pay_direction_type = 'OUTBOUND', payer_tenant_id, 0) AS counterparty,
               IF(pay_direction_type = 'OUTBOUND', 'DISTRIBUTOR', 'CUSTOMER') AS cp_type
        FROM pay
        UNION ALL
        SELECT payer_tenant_id, ticket_no, 'OUT', payment_no, amt, pay_method_type, order_group_no, payee_tenant_id, 'SUPPLIER'
        FROM pay WHERE pay_direction_type = 'OUTBOUND'
    ) x                                                                           -- 汇总结果，外层再补维度名称
    GROUP BY merchant_tenant_id, ticket_no                                        -- 按粒度键汇总
),
dims AS (                                                                         -- 订单维度：产品 / 票种取票，下单渠道 / 售票员取聚合单
    SELECT s.*, t.order_no, t.spu_id, t.sku_id, g.channel_type,
           IF(g.operator_type = 'TENANT_STAFF', g.operator_id, NULL)   AS seller_staff_id,  -- 售票员（维度
           CAST(NULL AS STRING)                                         AS sale_point_code,   /* 源端缺口：业务库订单无售票站点 */
           IF(s.out_payment_no IS NULL, 'SELF', 'SUPPLIER')             AS payee_type,  -- 收款方类型
           COALESCE(st.settle_timing_type, 'VERIFY')                    AS settle_timing_type  -- 结算时点
    FROM side s
    LEFT JOIN tk t ON t.ticket_no = s.ticket_no
    LEFT JOIN (SELECT order_group_no, MAX(channel_type) AS channel_type, MAX(operator_type) AS operator_type, MAX(operator_id) AS operator_id
               FROM hive_catalog.dwd.dwd_ord_order_group_di WHERE travel_date >= DATE_FORMAT(DATE_SUB(CURDATE(), INTERVAL 400 DAY), '%Y%m%d') GROUP BY order_group_no) g ON g.order_group_no = s.order_group_no
    LEFT JOIN (SELECT tenant_id, pay_method_type, settle_timing_type FROM hive_catalog.dim.dim_fin_settle_timing_df WHERE travel_date = DATE_FORMAT(DATE_SUB(CURDATE(), INTERVAL 1 DAY), '%Y%m%d')) st  -- 关联「」按键聚合
           ON st.tenant_id = s.merchant_tenant_id AND st.pay_method_type = s.receive_pay_method_type  -- 按 merchant_tenant_id→tenant_id、receive_pay_method_type→pay_method_type 关联
),
ref AS (                                                                          -- 当日成功的退款明细落到票：按退款单票金额占比分摊；售后补偿不纳入（需求第十章 4）
    SELECT r.refund_detail_no, r.finish_time, p.ticket_no, p.pay_direction_type, p.payee_tenant_id, p.payer_tenant_id,
           CAST(r.refund_amt * COALESCE(rt.refund_amt / NULLIF(SUM(rt.refund_amt) OVER (PARTITION BY r.refund_detail_no), 0),
                                        1.0 / COUNT(*) OVER (PARTITION BY r.refund_detail_no)) AS DECIMAL(18,2)) AS amt
    FROM (SELECT refund_detail_no, refund_no, payment_no, refund_amt, finish_time FROM dwd.dwd_fin_refund_payment_rt WHERE travel_date = DATE_FORMAT(CURDATE(), '%Y%m%d') AND refund_detail_status = 'SUCCESS') r
    JOIN (SELECT refund_no, ticket_no, MAX(refund_amt) AS refund_amt FROM hive_catalog.dwd.dwd_ord_refund_ticket_di WHERE travel_date >= DATE_FORMAT(DATE_SUB(CURDATE(), INTERVAL 400 DAY), '%Y%m%d') AND refund_type = 'ORDER_REFUND' GROUP BY refund_no, ticket_no) rt  -- 关联「」按键聚合
      ON rt.refund_no = r.refund_no                                               -- 按 refund_no 关联
    JOIN pay p ON p.payment_no = r.payment_no AND p.ticket_no = rt.ticket_no
),
ev AS (                                                                           -- 当日资金动作（本方视角）：side IN = 收侧，OUT = 付侧
    SELECT 'PAYMENT' AS source_type, payment_no AS source_no, payee_tenant_id AS merchant_tenant_id, ticket_no, 'IN' AS side, amt, pay_time AS event_time
    FROM pay WHERE DATE_FORMAT(pay_time, '%Y%m%d') = DATE_FORMAT(CURDATE(), '%Y%m%d')
    UNION ALL
    SELECT 'PAYMENT', payment_no, payer_tenant_id, ticket_no, 'OUT', amt, pay_time
    FROM pay WHERE pay_direction_type = 'OUTBOUND' AND DATE_FORMAT(pay_time, '%Y%m%d') = DATE_FORMAT(CURDATE(), '%Y%m%d')
    UNION ALL                                                                     -- 退款上下游成对冲减（5.2 退款联动）
    SELECT 'REFUND', refund_detail_no, payee_tenant_id, ticket_no, 'IN', amt, finish_time FROM ref
    UNION ALL
    SELECT 'REFUND', refund_detail_no, payer_tenant_id, ticket_no, 'OUT', amt, finish_time FROM ref WHERE pay_direction_type = 'OUTBOUND'
),
verify AS (                                                                       -- 核销：票的冻结记录当日因核销解冻（同票多账户取最早）
    SELECT ticket_no, MIN(release_time) AS release_time, MIN(frozen_no) AS frozen_no
    FROM dwd.dwd_fin_frozen_rt WHERE travel_date = DATE_FORMAT(CURDATE(), '%Y%m%d') AND frozen_status = 'RELEASED' AND release_event_type = 'VERIFY'
    GROUP BY ticket_no                                                            -- 按粒度键汇总
),
rows_ AS (
    SELECT source_type, source_no, merchant_tenant_id, ticket_no, side, amt, event_time FROM ev
    UNION ALL                                                                     -- 核销即结算：核销时转实收 / 转实付并确认（收侧按卖出单价、付侧按买入单价）
    SELECT 'VERIFY', v.frozen_no, d.merchant_tenant_id, d.ticket_no, s.side, IF(s.side = 'IN', d.sale_unit_price_amt, d.buy_unit_price_amt), v.release_time
    FROM verify v
    JOIN dims d ON d.ticket_no = v.ticket_no AND d.settle_timing_type = 'VERIFY'
    CROSS JOIN (SELECT 'IN' AS side UNION ALL SELECT 'OUT') s
    WHERE IF(s.side = 'IN', d.in_payment_no, d.out_payment_no) IS NOT NULL
    UNION ALL                                                                     -- 支付即结算：收款当日同时转实收并确认（同一行收 +、转 −，5.8）
    SELECT 'PAY_SETTLE', p.source_no, d.merchant_tenant_id, d.ticket_no, s.side, IF(s.side = 'IN', d.sale_unit_price_amt, d.buy_unit_price_amt), p.event_time
    FROM (SELECT source_no, merchant_tenant_id, ticket_no, event_time FROM ev WHERE source_type = 'PAYMENT' AND side = 'IN') p
    JOIN dims d ON d.merchant_tenant_id = p.merchant_tenant_id AND d.ticket_no = p.ticket_no AND d.settle_timing_type = 'PAY'
    CROSS JOIN (SELECT 'IN' AS side UNION ALL SELECT 'OUT') s
    WHERE IF(s.side = 'IN', d.in_payment_no, d.out_payment_no) IS NOT NULL
)
SELECT
    DATE_FORMAT(CURDATE(), '%Y%m%d') AS travel_date,                              -- 数据日期
    CONCAT_WS(':', r.source_no, r.ticket_no, CAST(r.merchant_tenant_id AS STRING), rl.report_code, rl.measure_code) AS fund_event_id,  -- 资金动作ID = 来源单号
    r.event_time,                                                                 -- 交易时间（明细「交易时间」列）
    r.merchant_tenant_id,                                                         -- 本方商户租户ID（报表归属方）
    rl.report_code,                                                               -- 报表
    rl.measure_code,                                                              -- 报表列
    rl.fee_type_name,                                                             -- 费用类型（界面显示
    r.amt                                                            AS event_amt,  -- 金额（元
    r.amt * rl.sign_qty                                              AS balance_effect_amt,  -- 对本报表余额的影响（元
    IF(rl.measure_code IN ('RECEIVE', 'PAY'), 1, IF(rl.measure_code IN ('REFUND', 'RETURN'), -1, 0)) AS ticket_net_qty,  -- 票数（预收 / 预付口径）
    IF(rl.measure_code = 'CONFIRM', 1, 0)                            AS confirm_ticket_qty,  -- 票数（确认收入 / 确认成本口径）
    r.source_type,                                                                -- 来源
    r.source_no,                                                                  -- 业务流水号（明细列
    IF(r.side = 'IN', d.in_payment_no, d.out_payment_no)             AS payment_no,  -- 本方这一侧的支付记录号
    d.order_group_no,                                                             -- 业务订单号（明细列
    d.order_no,                                                                   -- 关联订单号（明细列
    r.ticket_no,                                                                  -- 票号
    d.spu_id, d.sku_id, d.channel_type, d.seller_staff_id, d.sale_point_code,
    COALESCE(d.payer_tenant_id, 0)                                   AS payer_tenant_id,  -- 付款方（收侧维度
    d.payer_type,                                                                 -- 付款方类型
    COALESCE(d.payee_tenant_id, 0)                                   AS payee_tenant_id,  -- 收款方（付侧维度
    d.payee_type,                                                                 -- 收款方类型
    d.sale_unit_price_amt,                                                        -- 卖出单价（收侧维度
    d.buy_unit_price_amt,                                                         -- 买入单价（付侧维度
    d.receive_pay_method_type,                                                    -- 收款支付方式（收侧维度
    d.pay_pay_method_type,                                                        -- 付款支付方式（付侧维度
    d.settle_timing_type                                                          -- 结算时点
    
FROM rows_ r
JOIN dims d ON d.merchant_tenant_id = r.merchant_tenant_id AND d.ticket_no = r.ticket_no
JOIN (SELECT * FROM hive_catalog.dim.dim_fin_report_rule_f WHERE source_type IN ('PAYMENT', 'REFUND', 'VERIFY', 'PAY_SETTLE')) rl  -- 关联「」按键聚合
  ON rl.source_type = r.source_type AND rl.direction_type = r.side;               -- 按 source_type、side→direction_type 关联
