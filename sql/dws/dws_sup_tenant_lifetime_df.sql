-- dws.dws_sup_tenant_lifetime_df  商户累计至今汇总
-- 粒度：travel_date（快照日）× seller_tenant_id
-- 来源：dws_sup_tenant_lifetime_df（T-1）+ dws_sup_tenant_trade_di
-- 生成方式：手写（结构不适合按字段自动翻译）；业务规则：
--   · 字典原写来源为游客交易汇总，商户口径应取商户经营日汇总 dws_sup_tenant_trade_di（同一份订单，粒度更合适）
--   · 累计用「昨日快照 + 今日」滚动；近 30 天读 30 个日分区；动销 = 当日支付金额 > 0
-- 性能：
--   · 只读 T-1 快照 + 30 个日分区

WITH today AS (
    SELECT seller_tenant_id, SUM(pay_amt) AS pay_amt
    FROM dws.dws_sup_tenant_trade_di WHERE travel_date = '${bizdate}' AND pay_amt > 0
    GROUP BY seller_tenant_id                                                     -- 按粒度键汇总
),
prev AS (
    SELECT seller_tenant_id, first_pay_date, last_pay_date, total_pay_amt
    FROM dws.dws_sup_tenant_lifetime_df WHERE travel_date = DATE_FORMAT(DATE_SUB(TO_DATE('${bizdate}', 'yyyyMMdd'), 1), 'yyyyMMdd')
),
d30 AS (
    SELECT seller_tenant_id, SUM(pay_amt) AS pay_30d_amt, COUNT(DISTINCT IF(pay_amt > 0, travel_date, NULL)) AS active_day_30d_qty
    FROM dws.dws_sup_tenant_trade_di
    WHERE travel_date BETWEEN DATE_FORMAT(DATE_SUB(TO_DATE('${bizdate}', 'yyyyMMdd'), 29), 'yyyyMMdd') AND '${bizdate}'
    GROUP BY seller_tenant_id                                                     -- 按粒度键汇总
)
INSERT OVERWRITE TABLE dws.dws_sup_tenant_lifetime_df PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
    COALESCE(t.seller_tenant_id, p.seller_tenant_id)                                  AS seller_tenant_id,  -- 卖家租户ID
    COALESCE(p.first_pay_date, IF(t.seller_tenant_id IS NOT NULL, '${bizdate_dash}', NULL)) AS first_pay_date,  -- 首次支付日期
    IF(t.seller_tenant_id IS NOT NULL, '${bizdate_dash}', p.last_pay_date)            AS last_pay_date,  -- 最近支付日期
    COALESCE(p.total_pay_amt, 0) + COALESCE(t.pay_amt, 0)                             AS total_pay_amt,  -- 累计支付金额
    COALESCE(d.pay_30d_amt, 0)                                                        AS pay_30d_amt,  -- 近30天支付金额
    COALESCE(d.active_day_30d_qty, 0)                                                 AS active_day_30d_qty,  -- 近30天动销天数
    IF(t.seller_tenant_id IS NOT NULL, 1, 0)                                          AS active_tenant_qty,  -- 动销商户数
    TO_BITMAP(t.seller_tenant_id)                                                     AS active_tenant_bitmap,  -- 动销商户数去重位图
    CURRENT_TIMESTAMP() AS etl_time                                               -- ETL 加载时间
FROM today t
FULL OUTER JOIN prev p ON p.seller_tenant_id = t.seller_tenant_id
LEFT JOIN d30 d ON d.seller_tenant_id = COALESCE(t.seller_tenant_id, p.seller_tenant_id);
