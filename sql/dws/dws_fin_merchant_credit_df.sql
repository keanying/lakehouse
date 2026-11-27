-- ================================================================================================
-- dws.dws_fin_merchant_credit_df  商户应收应付快照
-- 依据：《3.0 通用财务报表 · 需求说明》v1.0（2026-11-24）
-- 业务规则：
--   · 授信只占额度不动现金（架构文档 3.5.2）：核销前不算应收 / 应付（未收未提供），核销后记应收 / 应付
--   · 业务库没有授信还款明细，余额由快照倒推：期末 = 分销关系已用授信 credit_used − 授信在途（已卖未核销未退）；还款 = 期初 + 本期增加 − 期末
--   · 同一分销关系：供应商一侧记应收（对方 = 分销商），分销商一侧记应付（对方 = 供应商），两侧应相等
-- 性能：
--   · 分销关系、在途快照均按 (商户, 对方) 预聚合后 FULL JOIN
-- ================================================================================================

WITH rel AS (   -- 分销关系日终已用授信（只取授信模式）
    SELECT r.supplier_tenant_id, r.distributor_tenant_id, SUM(c.credit_used_amt) AS credit_used_amt
    FROM (SELECT relation_no, credit_used_amt FROM dws.dws_trf_distributor_credit_df WHERE travel_date = '${bizdate}') c
    JOIN (SELECT relation_no, supplier_tenant_id, distributor_tenant_id FROM dim.dim_trf_distribution_relation_zip
          WHERE payment_mode_type = 'CREDIT' AND start_date <= '${bizdate}' AND end_date > '${bizdate}') r ON r.relation_no = c.relation_no
    GROUP BY r.supplier_tenant_id, r.distributor_tenant_id
),
used AS (
    SELECT supplier_tenant_id AS merchant_tenant_id, distributor_tenant_id AS counterparty_tenant_id, 'AR' AS report_code, credit_used_amt FROM rel
    UNION ALL
    SELECT distributor_tenant_id, supplier_tenant_id, 'AP', credit_used_amt FROM rel
),
uns AS (   -- 授信在途：收侧对方 = 付款方（下级），付侧对方 = 收款方（上级）
    SELECT merchant_tenant_id, IF(report_code = 'CREDIT_IN', payer_tenant_id, payee_tenant_id) AS counterparty_tenant_id,
           IF(report_code = 'CREDIT_IN', 'AR', 'AP') AS report_code, SUM(unsettled_amt) AS credit_unsettled_amt
    FROM dws.dws_fin_merchant_unsettled_df
    WHERE travel_date = '${bizdate}' AND report_code IN ('CREDIT_IN', 'CREDIT_OUT')
    GROUP BY 1, 2, 3
),
adds AS (   -- 本期核销记应收 / 应付
    SELECT merchant_tenant_id, IF(report_code = 'AR', payer_tenant_id, payee_tenant_id) AS counterparty_tenant_id, report_code, SUM(event_amt) AS add_amt
    FROM dwd.dwd_fin_merchant_order_fund_di
    WHERE travel_date = '${bizdate}' AND report_code IN ('AR', 'AP')
    GROUP BY 1, 2, 3
),
prev AS (
    SELECT merchant_tenant_id, counterparty_tenant_id, report_code, close_amt AS open_amt
    FROM dws.dws_fin_merchant_credit_df WHERE travel_date = DATE_FORMAT(DATE_SUB(TO_DATE('${bizdate}', 'yyyyMMdd'), 1), 'yyyyMMdd')
),
k AS (
    SELECT merchant_tenant_id, counterparty_tenant_id, report_code FROM used
    UNION SELECT merchant_tenant_id, counterparty_tenant_id, report_code FROM uns
    UNION SELECT merchant_tenant_id, counterparty_tenant_id, report_code FROM adds
    UNION SELECT merchant_tenant_id, counterparty_tenant_id, report_code FROM prev
),
v AS (
    SELECT k.*, COALESCE(u.credit_used_amt, 0) AS credit_used_amt, COALESCE(n.credit_unsettled_amt, 0) AS credit_unsettled_amt,
           COALESCE(p.open_amt, 0) AS open_amt, COALESCE(a.add_amt, 0) AS add_amt,
           COALESCE(u.credit_used_amt, 0) - COALESCE(n.credit_unsettled_amt, 0) AS close_amt
    FROM k
    LEFT JOIN used u ON u.merchant_tenant_id = k.merchant_tenant_id AND u.counterparty_tenant_id = k.counterparty_tenant_id AND u.report_code = k.report_code
    LEFT JOIN uns  n ON n.merchant_tenant_id = k.merchant_tenant_id AND n.counterparty_tenant_id = k.counterparty_tenant_id AND n.report_code = k.report_code
    LEFT JOIN adds a ON a.merchant_tenant_id = k.merchant_tenant_id AND a.counterparty_tenant_id = k.counterparty_tenant_id AND a.report_code = k.report_code
    LEFT JOIN prev p ON p.merchant_tenant_id = k.merchant_tenant_id AND p.counterparty_tenant_id = k.counterparty_tenant_id AND p.report_code = k.report_code
)
INSERT OVERWRITE TABLE dws.dws_fin_merchant_credit_df PARTITION (travel_date = '${bizdate}')
SELECT merchant_tenant_id, counterparty_tenant_id, report_code, credit_used_amt, credit_unsettled_amt, open_amt, add_amt,
       open_amt + add_amt - close_amt                                  AS settle_amt,
       close_amt,
       DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time
FROM v
WHERE ABS(open_amt) + ABS(add_amt) + ABS(close_amt) + ABS(credit_used_amt) > 0;
