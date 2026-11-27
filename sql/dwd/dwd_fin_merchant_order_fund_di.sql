-- ================================================================================================
-- dwd.dwd_fin_merchant_order_fund_di  商户订单资金明细（订单报表事实）
-- 依据：《3.0 通用财务报表 · 需求说明》v1.0（2026-11-24）
-- 业务规则：
--   · 取数来源：支付记录（收 / 付）、退款明细（退 / 退回）、冻结记录核销解冻（结算）——授信订单不产生资金流水，按需求 3.1「下单即计入预收」须以支付记录为准；维度来自订单（原则 3）
--   · 一笔支付记录拆成两侧：收款方记「收」，采购付款方记「付」；只取本方商户侧（第十章 2）
--   · 金额 = 支付记录 amount（这笔记录实际转移的钱）；支付挂聚合单时按票单价占比分摊到票（第十章 3：按产品拆分须从订单侧取）
--   · 退款：只取订单退款（售后补偿本期不纳入），上下游成对冲减；核销：转实收 / 转实付 并确认收入 / 成本；支付即结算：收款当日同时结转
--   · 费用类型：付款 / 退款 / 结算（界面不出现「解冻」）；票数：售票记正、退款记负、核销不改变票数，核销票数单列
-- 性能：
--   · 票维度与两侧支付信息先按 (商户, 票) 汇成一行，各类动作只关联一次
--   · 支付 / 票只扫近 400 天分区（票有效期上限）
--   · 归属规则为小表 BROADCAST
-- ================================================================================================
WITH tk AS (                                                                      -- 票：聚合单内按单价占比（全 0 元时均分），用于把按聚合单的支付分摊到票
    SELECT ticket_no, order_no, order_group_no, spu_id, sku_id,
           COALESCE(unit_price_amt / NULLIF(SUM(unit_price_amt) OVER (PARTITION BY order_group_no), 0),
                    1.0 / COUNT(*) OVER (PARTITION BY order_group_no))  AS w      -- 分摊权重（同一订单组按票数均分）
    FROM dwd.dwd_ord_ticket_di WHERE travel_date >= DATE_FORMAT(DATE_SUB(TO_DATE('${bizdate}', 'yyyyMMdd'), 400), 'yyyyMMdd')
),
pay AS (                                                                          -- 支付记录落到票（近 400 天：退款 / 核销要回找原支付）
    SELECT p.payment_no,                                                          -- 本方这一侧的支付记录号
           p.order_group_no,                                                      -- 业务订单号
           COALESCE(NULLIF(p.ticket_no, ''), t.ticket_no) AS ticket_no,           -- 票号
           p.pay_direction_type,
           p.pay_method_type,
           CAST(p.pay_amt * IF(p.ticket_no = '', t.w, 1) AS DECIMAL(18,2)) AS amt,  -- 分摊后金额（元）
           p.pay_time, p.payee_tenant_id, p.payer_tenant_id
    FROM (SELECT * FROM dwd.dwd_fin_payment_di WHERE travel_date >= DATE_FORMAT(DATE_SUB(TO_DATE('${bizdate}', 'yyyyMMdd'), 400), 'yyyyMMdd')) p
    LEFT JOIN tk t ON p.ticket_no = '' AND t.order_group_no = p.order_group_no
    WHERE p.pay_status IN ('PAID', 'PARTIAL_REFUNDED', 'REFUNDED')
),
side AS (                                                                         -- (本方商户, 票) → 收侧 / 付侧支付信息（需求 4.4：三对收付维度分开取）
    SELECT merchant_tenant_id, ticket_no,
           MAX(IF(side = 'IN', payment_no, NULL))          AS in_payment_no,      -- 收款支付单号
           MAX(IF(side = 'IN', amt, NULL))                 AS sale_unit_price_amt,  -- 卖出单价
           MAX(IF(side = 'IN', pay_method_type, NULL))     AS receive_pay_method_type,  -- 收款支付方式
           MAX(IF(side = 'IN', counterparty, NULL))        AS payer_tenant_id,    -- 付款方
           MAX(IF(side = 'IN', cp_type, NULL))             AS payer_type,         -- 付款方类型
           MAX(IF(side = 'OUT', payment_no, NULL))         AS out_payment_no,     -- 付款支付单号
           MAX(IF(side = 'OUT', amt, NULL))                AS buy_unit_price_amt,  -- 买入单价
           MAX(IF(side = 'OUT', pay_method_type, NULL))    AS pay_pay_method_type,  -- 付款支付方式
           MAX(IF(side = 'OUT', counterparty, NULL))       AS payee_tenant_id,    -- 收款方
           MAX(order_group_no)                             AS order_group_no      -- 业务订单号
    FROM (
        SELECT payee_tenant_id AS merchant_tenant_id,                             -- 本方商户租户ID（报表归属方）
               ticket_no,                                                         -- 票号
               'IN' AS side,                                                      -- 收付方向：IN-收 / OUT-付
               payment_no,                                                        -- 本方这一侧的支付记录号
               amt,
               pay_method_type,
               order_group_no,                                                    -- 业务订单号
               IF(pay_direction_type = 'OUTBOUND', payer_tenant_id, 0) AS counterparty,  -- 交易对手ID
               IF(pay_direction_type = 'OUTBOUND', 'DISTRIBUTOR', 'CUSTOMER') AS cp_type  -- 交易对手类型
        FROM pay
        UNION ALL
        SELECT payer_tenant_id,                                                   -- 付款方
               ticket_no,                                                         -- 票号
               'OUT',
               payment_no,                                                        -- 本方这一侧的支付记录号
               amt,
               pay_method_type,
               order_group_no,                                                    -- 业务订单号
               payee_tenant_id,                                                   -- 收款方
               'SUPPLIER'
        FROM pay WHERE pay_direction_type = 'OUTBOUND'
    ) x                                                                           -- 汇总结果，外层再补维度名称
    GROUP BY merchant_tenant_id, ticket_no                                        -- 按粒度键汇总
),
dims AS (                                                                         -- 订单维度：产品 / 票种取票，下单渠道 / 售票员取聚合单
    SELECT s.*, t.order_no, t.spu_id, t.sku_id, g.channel_type,
           IF(g.operator_type = 'TENANT_STAFF', g.operator_id, NULL)   AS seller_staff_id,  -- 售票员
           CAST(NULL AS STRING)                                         AS sale_point_code,  -- 售票站点
           /* 源端缺口：业务库订单无售票站点 */
           IF(s.out_payment_no IS NULL, 'SELF', 'SUPPLIER')             AS payee_type,  -- 收款方类型
           COALESCE(st.settle_timing_type, 'VERIFY')                    AS settle_timing_type  -- 结算时点
    FROM side s
    LEFT JOIN tk t ON t.ticket_no = s.ticket_no
    LEFT JOIN (SELECT order_group_no, MAX(channel_type) AS channel_type, MAX(operator_type) AS operator_type, MAX(operator_id) AS operator_id
               FROM dwd.dwd_ord_order_group_di WHERE travel_date >= DATE_FORMAT(DATE_SUB(TO_DATE('${bizdate}', 'yyyyMMdd'), 400), 'yyyyMMdd')
                   GROUP BY order_group_no) g ON g.order_group_no = s.order_group_no  -- 按粒度键汇总
    LEFT JOIN (                                                                   -- 关联「结算时点配置」按键聚合
        SELECT tenant_id,
        pay_method_type,
        settle_timing_type FROM dim.dim_fin_settle_timing_df WHERE travel_date = '${bizdate}'
    ) st
           ON st.tenant_id = s.merchant_tenant_id AND st.pay_method_type = s.receive_pay_method_type  -- 按 merchant_tenant_id→tenant_id、receive_pay_method_type→pay_method_type 关联
),
ref AS (                                                                          -- 当日成功的退款明细落到票：按退款单票金额占比分摊；售后补偿不纳入（需求第十章 4）
    SELECT r.refund_detail_no,
           r.finish_time,
           p.ticket_no,                                                           -- 票号
           p.pay_direction_type,
           p.payee_tenant_id,                                                     -- 收款方
           p.payer_tenant_id,                                                     -- 付款方
           CAST(r.refund_amt * COALESCE(rt.refund_amt / NULLIF(SUM(rt.refund_amt) OVER (PARTITION BY r.refund_detail_no), 0),
                                        1.0 / COUNT(*) OVER (PARTITION BY r.refund_detail_no)) AS DECIMAL(18,
                                        2)) AS amt                                -- 分摊后金额（元）
    FROM (
        SELECT refund_detail_no,
        refund_no,
        payment_no,                                                               -- 本方这一侧的支付记录号
        refund_amt,
        finish_time FROM dwd.dwd_fin_refund_payment_di WHERE travel_date = '${bizdate}' AND refund_detail_status = 'SUCCESS'
    ) r
    JOIN (                                                                        -- 关联「退款票明细」按键聚合
        SELECT refund_no,
        ticket_no,                                                                -- 票号
        MAX(refund_amt) AS refund_amt FROM dwd.dwd_ord_refund_ticket_di
            WHERE travel_date >= DATE_FORMAT(DATE_SUB(TO_DATE('${bizdate}', 'yyyyMMdd'), 400), 'yyyyMMdd')
              AND refund_type = 'ORDER_REFUND' GROUP BY refund_no,
        ticket_no                                                                 -- 票号
    ) rt
      ON rt.refund_no = r.refund_no                                               -- 按 refund_no 关联
    JOIN pay p ON p.payment_no = r.payment_no AND p.ticket_no = rt.ticket_no
),
ev AS (                                                                           -- 当日资金动作（本方视角）：side IN = 收侧，OUT = 付侧
    SELECT 'PAYMENT' AS source_type,                                              -- 来源
           payment_no AS source_no,                                               -- 业务流水号
           payee_tenant_id AS merchant_tenant_id,                                 -- 本方商户租户ID（报表归属方）
           ticket_no,                                                             -- 票号
           'IN' AS side,                                                          -- 收付方向：IN-收 / OUT-付
           amt,
           pay_time AS event_time                                                 -- 交易时间（明细「交易时间」列）
    FROM pay WHERE DATE_FORMAT(pay_time, 'yyyyMMdd') = '${bizdate}'
    UNION ALL
    SELECT 'PAYMENT', payment_no, payer_tenant_id, ticket_no, 'OUT', amt, pay_time
    FROM pay WHERE pay_direction_type = 'OUTBOUND' AND DATE_FORMAT(pay_time, 'yyyyMMdd') = '${bizdate}'
    UNION ALL                                                                     -- 退款上下游成对冲减（5.2 退款联动）
    SELECT 'REFUND', refund_detail_no, payee_tenant_id, ticket_no, 'IN', amt, finish_time FROM ref
    UNION ALL
    SELECT 'REFUND',
           refund_detail_no,
           payer_tenant_id,                                                       -- 付款方
           ticket_no,                                                             -- 票号
           'OUT',
           amt,
           finish_time FROM ref WHERE pay_direction_type = 'OUTBOUND'
),
verify AS (                                                                       -- 核销：票的冻结记录当日因核销解冻（同票多账户取最早）
    SELECT ticket_no,                                                             -- 票号
           MIN(release_time) AS release_time,                                     -- 解冻时间
           MIN(frozen_no) AS frozen_no                                            -- 冻结记录编号
    FROM dwd.dwd_fin_frozen_di WHERE travel_date = '${bizdate}' AND frozen_status = 'RELEASED' AND release_event_type = 'VERIFY'
    GROUP BY ticket_no                                                            -- 按粒度键汇总
),
rows_ AS (
    SELECT source_type, source_no, merchant_tenant_id, ticket_no, side, amt, event_time FROM ev
    UNION ALL                                                                     -- 核销即结算：核销时转实收 / 转实付并确认（收侧按卖出单价、付侧按买入单价）
    SELECT 'VERIFY',
           v.frozen_no,
           d.merchant_tenant_id,                                                  -- 本方商户租户ID（报表归属方）
           d.ticket_no,                                                           -- 票号
           s.side,
           IF(s.side = 'IN', d.sale_unit_price_amt, d.buy_unit_price_amt),
           v.release_time
    FROM verify v
    JOIN dims d ON d.ticket_no = v.ticket_no AND d.settle_timing_type = 'VERIFY'
    CROSS JOIN (SELECT 'IN' AS side UNION ALL SELECT 'OUT') s
    WHERE IF(s.side = 'IN', d.in_payment_no, d.out_payment_no) IS NOT NULL
    UNION ALL                                                                     -- 支付即结算：收款当日同时转实收并确认（同一行收 +、转 −，5.8）
    SELECT 'PAY_SETTLE',
           p.source_no,                                                           -- 业务流水号
           d.merchant_tenant_id,                                                  -- 本方商户租户ID（报表归属方）
           d.ticket_no,                                                           -- 票号
           s.side,
           IF(s.side = 'IN', d.sale_unit_price_amt, d.buy_unit_price_amt),
           p.event_time                                                           -- 交易时间（明细「交易时间」列）
    FROM (
        SELECT source_no,                                                         -- 业务流水号
        merchant_tenant_id,                                                       -- 本方商户租户ID（报表归属方）
        ticket_no,                                                                -- 票号
        event_time FROM ev WHERE source_type = 'PAYMENT' AND side = 'IN'
    ) p
    JOIN dims d
      ON d.merchant_tenant_id = p.merchant_tenant_id                              -- 按 merchant_tenant_id 关联
        AND d.ticket_no = p.ticket_no
        AND d.settle_timing_type = 'PAY'
    CROSS JOIN (SELECT 'IN' AS side UNION ALL SELECT 'OUT') s
    WHERE IF(s.side = 'IN', d.in_payment_no, d.out_payment_no) IS NOT NULL
)
INSERT OVERWRITE TABLE dwd.dwd_fin_merchant_order_fund_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT /*+ BROADCAST(rl) */
    CONCAT_WS(                                                                    -- 资金动作ID = 来源单号
        ':',
        r.source_no,                                                              -- 业务流水号
        r.ticket_no,                                                              -- 票号
        CAST(r.merchant_tenant_id AS STRING),
        rl.report_code,                                                           -- 报表
        rl.measure_code                                                           -- 报表列
    ) AS fund_event_id,                                                           -- 资金动作ID = 来源单号
    r.event_time,                                                                 -- 交易时间（明细「交易时间」列）
    r.merchant_tenant_id,                                                         -- 本方商户租户ID（报表归属方）
    rl.report_code,                                                               -- 报表
    rl.measure_code,                                                              -- 报表列
    rl.fee_type_name,                                                             -- 费用类型
    r.amt                                                            AS event_amt,  -- 金额
    r.amt * rl.sign_qty                                              AS balance_effect_amt,  -- 对本报表余额的影响
    IF(rl.measure_code IN ('RECEIVE', 'PAY'), 1, IF(                              -- 票数（预收 / 预付口径）
        rl.measure_code IN ('REFUND', 'RETURN'),
        -1,
        0
    )) AS ticket_net_qty,                                                         -- 票数（预收 / 预付口径）
    IF(rl.measure_code = 'CONFIRM', 1, 0)                            AS confirm_ticket_qty,  -- 票数（确认收入 / 确认成本口径）
    r.source_type,                                                                -- 来源
    r.source_no,                                                                  -- 业务流水号
    IF(r.side = 'IN', d.in_payment_no, d.out_payment_no)             AS payment_no,  -- 本方这一侧的支付记录号
    d.order_group_no,                                                             -- 业务订单号
    d.order_no,                                                                   -- 关联订单号
    r.ticket_no,                                                                  -- 票号
    d.spu_id, d.sku_id, d.channel_type, d.seller_staff_id, d.sale_point_code,
    COALESCE(d.payer_tenant_id, 0)                                   AS payer_tenant_id,  -- 付款方
    d.payer_type,                                                                 -- 付款方类型
    COALESCE(d.payee_tenant_id, 0)                                   AS payee_tenant_id,  -- 收款方
    d.payee_type,                                                                 -- 收款方类型
    d.sale_unit_price_amt,                                                        -- 卖出单价
    d.buy_unit_price_amt,                                                         -- 买入单价
    d.receive_pay_method_type,                                                    -- 收款支付方式
    d.pay_pay_method_type,                                                        -- 付款支付方式
    d.settle_timing_type,                                                         -- 结算时点
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time           -- ETL 加载时间
FROM rows_ r
JOIN dims d ON d.merchant_tenant_id = r.merchant_tenant_id AND d.ticket_no = r.ticket_no
JOIN (SELECT * FROM dim.dim_fin_report_rule_f WHERE source_type IN (              -- 关联「财务报表归属规则」按键聚合
    'PAYMENT',
    'REFUND',
    'VERIFY',
    'PAY_SETTLE'
)) rl
  ON rl.source_type = r.source_type AND rl.direction_type = r.side;               -- 按 source_type、side→direction_type 关联
