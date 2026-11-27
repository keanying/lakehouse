-- ================================================================================================
-- dwd.dwd_fin_merchant_order_fund_di  商户订单资金明细（财务报表事实）
-- 依据：《3.0 通用财务报表 · 需求说明》v1.0（2026-11-24）
-- 业务规则：
--   · 全部来自 ODS 基础表：支付记录（ods_fin_payment_record_di）、退款明细 / 退款单（ods_ord_refund_detail_di / ods_ord_refund_order_di.refund_items）、冻结记录（ods_fin_frozen_record_di，核销解冻时间取 binlog）、票 / 子单 / 聚合单（ods_ord_ticket_di / ods_ord_order_di / ods_ord_order_group_di）
--   · 一笔支付记录拆成两侧：收款方（payee_account_no → 主体）记「收」，采购付款方（payer_account_no → 主体）记「付」；只取商户自己这一侧，双式记账不重复（风险 2）
--   · 金额 = 支付记录 amount（这笔记录实际转移的钱，收款方收到、付款方付出）。settle_amount 注释写「INBOUND=售价」与架构文档「利润 = amount − settle_amount」矛盾，不用于计量
--   · 支付记录的 ticket_no 默认空串（按聚合单支付）：按票单价 unit_price_amt 占比分摊到聚合单下每张票；退款同理按退款单 refund_items 的票金额占比分摊
--   · 现款（余额 / 微信 / 支付宝 / 线下 / 0 元）：支付记 预收 + / 预付 +，退款记 预收 − / 预付 −，核销记 预收 − → 确认收入 +、预付 − → 确认成本 +
--   · 授信（pay_method=CREDIT，只占额度不动现金）：支付与核销前退款只记「授信在途」，不进预收 / 预付；核销时记 应收 + / 应付 + 与确认收入 / 成本（架构文档 3.5.2：授信核销后才记账）
--   · 支付即结算（结算时点配置，待业务库补字段）：现款收款当日同时确认
--   · 维度：产品 / 票种 / 渠道 / 售票员取订单与票；付款方、收款方、卖出 / 买入单价、收款 / 付款支付方式按本方两侧支付记录取（需求 4.4 三对收付维度分开）
-- 性能：
--   · 票维度与两侧支付信息先按 (商户, 票) 汇成一行（side），各类动作只关联一次
--   · 支付 / 票只扫近 400 天分区（票有效期上限），按聚合单 / 票号等值关联
--   · 归属规则、结算时点为小表 BROADCAST
-- ================================================================================================

WITH tk AS (                                                                      -- 票：聚合单内按单价占比（全 0 元时均分）
    SELECT ticket_no, order_no, order_group_no, spu_id, sku_id,
           COALESCE(unit_price_amt / NULLIF(SUM(unit_price_amt) OVER (PARTITION BY order_group_no), 0),
                    1.0 / COUNT(*) OVER (PARTITION BY order_group_no))  AS w
    FROM dwd.dwd_ord_ticket_di
    WHERE travel_date >= DATE_FORMAT(DATE_SUB(TO_DATE('${bizdate}', 'yyyyMMdd'), 400), 'yyyyMMdd')
),
pay AS (                                                                          -- 支付记录落到票（近 400 天，退款 / 核销要回找原支付）
    SELECT p.payment_no, p.order_group_no, COALESCE(NULLIF(p.ticket_no, ''), t.ticket_no) AS ticket_no, p.pay_direction_type, p.pay_method_type,
           CAST(p.pay_amt * IF(p.ticket_no = '', t.w, 1) AS DECIMAL(18,2)) AS amt,
           p.pay_time, p.payee_tenant_id, p.payer_tenant_id,
           IF(p.pay_method_type = 'CREDIT', 'CREDIT', 'CASH')              AS pm_grp
    FROM (SELECT * FROM dwd.dwd_fin_payment_di WHERE travel_date >= DATE_FORMAT(DATE_SUB(TO_DATE('${bizdate}', 'yyyyMMdd'), 400), 'yyyyMMdd') AND pay_status IN ('PAID', 'PARTIAL_REFUNDED', 'REFUNDED')) p
    LEFT JOIN tk t ON p.ticket_no = '' AND t.order_group_no = p.order_group_no
),
side AS (                                                                         -- (本方商户, 票) → 收侧 / 付侧支付信息
    SELECT merchant_tenant_id, ticket_no,
           MAX(IF(side = 'IN', payment_no, NULL))          AS in_payment_no,
           MAX(IF(side = 'IN', amt, NULL))                 AS sale_unit_price_amt,  -- 卖出单价（元）
           MAX(IF(side = 'IN', pay_method_type, NULL))     AS receive_pay_method_type,  -- 收款支付方式（收侧）
           MAX(IF(side = 'IN', counterparty, NULL))        AS payer_tenant_id,    -- 付款方（收侧维度）
           MAX(IF(side = 'IN', cp_type, NULL))             AS payer_type,         -- 付款方类型
           MAX(IF(side = 'OUT', payment_no, NULL))         AS out_payment_no,
           MAX(IF(side = 'OUT', amt, NULL))                AS buy_unit_price_amt,  -- 买入单价（元）
           MAX(IF(side = 'OUT', pay_method_type, NULL))    AS pay_pay_method_type,  -- 付款支付方式（付侧）
           MAX(IF(side = 'OUT', counterparty, NULL))       AS payee_tenant_id,    -- 收款方（付侧维度）
           MAX(order_group_no)                             AS order_group_no      -- 聚合单号
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
dims AS (
    SELECT /*+ BROADCAST(st) */ s.*, t.order_no,
        t.spu_id,                                                                 -- 产品(SPU)ID
        t.sku_id,                                                                 -- SKU ID
        g.channel_id,                                                             -- 入口渠道ID
        g.channel_type,                                                           -- 入口渠道类型
        IF(g.operator_type = 'TENANT_STAFF', g.operator_id, 0) AS seller_staff_id,  -- 售票员（订单操作人
        CAST(NULL AS STRING) AS sale_point_code /* 待确认：业务库无售票站点 */,
        COALESCE(st.settle_timing_type, 'VERIFY') AS settle_timing_type           -- 结算时点
    FROM side s
    LEFT JOIN tk t ON t.ticket_no = s.ticket_no
    LEFT JOIN (SELECT order_group_no, channel_id, channel_type, operator_type, operator_id FROM dwd.dwd_ord_order_group_di WHERE travel_date >= DATE_FORMAT(DATE_SUB(TO_DATE('${bizdate}', 'yyyyMMdd'), 400), 'yyyyMMdd')) g ON g.order_group_no = s.order_group_no
    LEFT JOIN (SELECT tenant_id, pay_method_type, settle_timing_type FROM dim.dim_fin_settle_timing_df WHERE travel_date = '${bizdate}') st  -- 关联「结算时点配置」按键聚合
           ON st.tenant_id = s.merchant_tenant_id AND st.pay_method_type = s.receive_pay_method_type  -- 按 merchant_tenant_id→tenant_id、receive_pay_method_type→pay_method_type 关联
),
ref AS (                                                                          -- 当日成功的退款明细（按支付记录）落到票：按退款单 refund_items 的票金额占比分摊
    SELECT r.refund_detail_no, r.finish_time, p.payment_no, p.ticket_no, p.pay_direction_type, p.payee_tenant_id, p.payer_tenant_id, p.pm_grp,
           CAST(r.refund_amt * COALESCE(rt.refund_amt / NULLIF(SUM(rt.refund_amt) OVER (PARTITION BY r.refund_detail_no), 0),
                                        1.0 / COUNT(*) OVER (PARTITION BY r.refund_detail_no)) AS DECIMAL(18,2)) AS amt
    FROM (SELECT refund_detail_no, refund_no, payment_no, refund_amt, finish_time FROM dwd.dwd_fin_refund_payment_di WHERE travel_date = '${bizdate}' AND refund_detail_status = 'SUCCESS') r
    JOIN (SELECT refund_no, ticket_no, refund_amt FROM dwd.dwd_ord_refund_ticket_di WHERE travel_date >= DATE_FORMAT(DATE_SUB(TO_DATE('${bizdate}', 'yyyyMMdd'), 400), 'yyyyMMdd')) rt ON rt.refund_no = r.refund_no
    JOIN pay p ON p.payment_no = r.payment_no AND p.ticket_no = rt.ticket_no
),
ev AS (                                                                           -- 当日资金动作（本方视角）：side IN = 收侧，OUT = 付侧
    -- ① 支付：收 / 付
    SELECT 'PAYMENT' AS source_type, payment_no AS source_no, payee_tenant_id AS merchant_tenant_id, ticket_no, 'IN' AS side, pm_grp, amt, pay_time AS event_time, 1 AS tk
    FROM pay WHERE DATE_FORMAT(pay_time, 'yyyyMMdd') = '${bizdate}'
    UNION ALL
    SELECT 'PAYMENT', payment_no, payer_tenant_id, ticket_no, 'OUT', pm_grp, amt, pay_time, 1
    FROM pay WHERE pay_direction_type = 'OUTBOUND' AND DATE_FORMAT(pay_time, 'yyyyMMdd') = '${bizdate}'
    UNION ALL
    -- ② 退款：退 / 退回（同一支付记录的收、付两侧成对冲减）
    SELECT 'REFUND', refund_detail_no, payee_tenant_id, ticket_no, 'IN', pm_grp, amt, finish_time, -1 FROM ref
    UNION ALL
    SELECT 'REFUND', refund_detail_no, payer_tenant_id, ticket_no, 'OUT', pm_grp, amt, finish_time, -1 FROM ref WHERE pay_direction_type = 'OUTBOUND'
),
verify AS (                                                                       -- ③ 核销：票的冻结记录当日因核销解冻（release_time = 状态变 RELEASED 的 binlog 时间；同票多账户取最早）
    SELECT ticket_no, MIN(release_time) AS release_time, MIN(frozen_no) AS frozen_no
    FROM dwd.dwd_fin_frozen_di
    WHERE travel_date = '${bizdate}' AND frozen_status = 'RELEASED' AND release_event_type = 'VERIFY'  -- 只取当日分区，并按条件过滤
    GROUP BY ticket_no                                                            -- 按粒度键汇总
),
rows AS (
    SELECT e.source_type, e.source_no, e.merchant_tenant_id, e.ticket_no, e.side, e.pm_grp, e.amt, e.event_time, e.tk FROM ev e
    UNION ALL
    -- 核销确认：核销即结算的现款票、全部授信票（收侧按卖出单价、付侧按买入单价）
    SELECT 'VERIFY', v.frozen_no, d.merchant_tenant_id, d.ticket_no, s.side, s.pm_grp, IF(s.side = 'IN', d.sale_unit_price_amt, d.buy_unit_price_amt), v.release_time, 0
    FROM verify v
    JOIN dims d ON d.ticket_no = v.ticket_no
    LATERAL VIEW INLINE(ARRAY(STRUCT('IN' AS side, IF(d.receive_pay_method_type = 'CREDIT', 'CREDIT', 'CASH') AS pm_grp),
                              STRUCT('OUT' AS side, IF(d.pay_pay_method_type = 'CREDIT', 'CREDIT', 'CASH') AS pm_grp))) s
    WHERE IF(s.side = 'IN', d.in_payment_no, d.out_payment_no) IS NOT NULL
      AND (d.settle_timing_type = 'VERIFY' OR s.pm_grp = 'CREDIT')
    UNION ALL
    -- 支付即结算：现款收款当日同时确认（成本随收入配比）
    SELECT 'PAY_SETTLE', p.source_no, d.merchant_tenant_id, d.ticket_no, s.side, 'CASH', IF(s.side = 'IN', d.sale_unit_price_amt, d.buy_unit_price_amt), p.event_time, 0
    FROM (SELECT source_no, merchant_tenant_id, ticket_no, event_time FROM ev WHERE source_type = 'PAYMENT' AND side = 'IN' AND pm_grp = 'CASH') p
    JOIN dims d ON d.merchant_tenant_id = p.merchant_tenant_id AND d.ticket_no = p.ticket_no AND d.settle_timing_type = 'PAY'
    LATERAL VIEW EXPLODE(ARRAY('IN', 'OUT')) s AS side
    WHERE IF(s.side = 'IN', d.in_payment_no, d.out_payment_no) IS NOT NULL
      AND COALESCE(IF(s.side = 'IN', d.receive_pay_method_type, d.pay_pay_method_type), '') <> 'CREDIT'
)
INSERT OVERWRITE TABLE dwd.dwd_fin_merchant_order_fund_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT /*+ BROADCAST(rl) */
    CONCAT_WS(':', r.source_no, r.ticket_no, CAST(r.merchant_tenant_id AS STRING), rl.report_code, rl.measure_code) AS fund_event_id,  -- 资金动作ID = 来源单号
    r.event_time,                                                                 -- 动作发生时间
    r.merchant_tenant_id,                                                         -- 本方商户租户ID（报表归属方）
    rl.report_code,                                                               -- 报表
    rl.measure_code,                                                              -- 报表列
    r.amt                                                            AS event_amt,  -- 发生金额（元
    r.amt * rl.sign_qty                                            AS balance_effect_amt,  -- 对本报表余额的影响（元
    IF(rl.measure_code IN ('RECEIVE', 'PAY', 'REFUND', 'RETURN'), r.tk, 0) AS ticket_net_qty,  -- 净票数
    r.source_type,                                                                -- 来源
    r.pm_grp                                                         AS pay_method_group_type,  -- 本侧付款性质
    r.source_no,                                                                  -- 来源单号
    IF(r.side = 'IN', d.in_payment_no, d.out_payment_no)             AS payment_no,  -- 对应支付记录号（本方这一侧的支付记录）
    d.order_group_no,                                                             -- 聚合单号
    d.order_no,                                                                   -- 子单号（支付挂聚合单、退款挂子单
    r.ticket_no,                                                                  -- 票号
    d.spu_id, d.sku_id, d.channel_id, d.channel_type, d.seller_staff_id, d.sale_point_code,
    COALESCE(d.payer_tenant_id, 0)                                   AS payer_tenant_id,  -- 付款方（收侧维度）
    d.payer_type,                                                                 -- 付款方类型
    COALESCE(d.payee_tenant_id, 0)                                   AS payee_tenant_id,  -- 收款方（付侧维度）
    IF(d.out_payment_no IS NULL, 'SELF', 'SUPPLIER')                 AS payee_type,  -- 收款方类型
    d.sale_unit_price_amt,                                                        -- 卖出单价（元）
    d.buy_unit_price_amt,                                                         -- 买入单价（元）
    d.receive_pay_method_type,                                                    -- 收款支付方式（收侧）
    d.pay_pay_method_type,                                                        -- 付款支付方式（付侧）
    d.settle_timing_type,                                                         -- 结算时点
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time           -- ETL 加载时间
FROM rows r
JOIN dims d ON d.merchant_tenant_id = r.merchant_tenant_id AND d.ticket_no = r.ticket_no
JOIN (SELECT * FROM dim.dim_fin_report_rule_f WHERE source_type IN ('PAYMENT', 'REFUND', 'VERIFY', 'PAY_SETTLE')) rl  -- 关联「财务报表归属规则」按键聚合
  ON rl.source_type = r.source_type AND rl.direction_type = r.side AND rl.pay_method_group_type = r.pm_grp;  -- 按 source_type、side→direction_type、pm_grp→pay_method_group_type 关联
