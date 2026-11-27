-- dws.dws_cus_customer_lifetime_df  游客累计至今汇总
-- 粒度：travel_date（快照日）× buyer_customer_id × seller_tenant_id
-- 来源：dws_cus_customer_lifetime_df（T-1）+ dws_cus_customer_trade_di + dim_cus_customer_zip
-- 生成方式：手写（结构不适合按字段自动翻译）；业务规则：
--   · 累计口径用「昨日快照 + 今日增量」滚动，不回扫全部历史；首次上线需按日期顺序回刷一次
--   · 首次 / 最近支付日、累计单数 / 金额：昨日快照与今日支付合并；近 30 天：读 30 个日分区
--   · 复购（buyer_type = 1）：近 30 天支付子单数 ≥ 2
--   · 支付买家：真人买家（customer_type = REAL），剔除匿名与商户代下单占位买家；本行（游客 × 商户）有支付记 1
--   · 老客买家：今日支付、且首次支付早于今日
-- 性能：
--   · 只读 T-1 一个快照分区 + 30 个日汇总分区；游客维表只取当前版本的 REAL 账号

WITH today AS (                                                                   -- 今日支付
    SELECT buyer_customer_id, seller_tenant_id, SUM(pay_order_qty) AS pay_order_qty, SUM(pay_amt) AS pay_amt
    FROM dws.dws_cus_customer_trade_di
    WHERE travel_date = '${bizdate}' AND pay_order_qty > 0                        -- 只取当日分区，并按条件过滤
    GROUP BY buyer_customer_id, seller_tenant_id                                  -- 按粒度键汇总
),
prev AS (                                                                         -- 昨日快照
    SELECT buyer_customer_id, seller_tenant_id, first_pay_date, last_pay_date, total_pay_order_qty, total_pay_amt
    FROM dws.dws_cus_customer_lifetime_df
    WHERE travel_date = DATE_FORMAT(DATE_SUB(TO_DATE('${bizdate}', 'yyyyMMdd'), 1), 'yyyyMMdd')
),
d30 AS (                                                                          -- 近 30 天（含今日）
    SELECT buyer_customer_id, seller_tenant_id, SUM(pay_order_qty) AS pay_order_30d_qty, SUM(pay_amt) AS pay_30d_amt
    FROM dws.dws_cus_customer_trade_di
    WHERE travel_date BETWEEN DATE_FORMAT(DATE_SUB(TO_DATE('${bizdate}', 'yyyyMMdd'), 29), 'yyyyMMdd') AND '${bizdate}'
    GROUP BY buyer_customer_id, seller_tenant_id                                  -- 按粒度键汇总
),
real_buyer AS (                                                                   -- 真人账号
    SELECT customer_id FROM dim.dim_cus_customer_zip
    WHERE travel_date = '${bizdate}' AND end_date = '9999-12-31' AND customer_type = 'REAL'  -- 取当日分区里的拉链当前有效版本
),
m AS (
    SELECT COALESCE(t.buyer_customer_id, p.buyer_customer_id) AS buyer_customer_id,
           COALESCE(t.seller_tenant_id, p.seller_tenant_id) AS seller_tenant_id,  -- 卖家租户ID
           COALESCE(p.first_pay_date, IF(t.buyer_customer_id IS NOT NULL, '${bizdate_dash}', NULL)) AS first_pay_date,  -- 首次支付日期
           IF(t.buyer_customer_id IS NOT NULL, '${bizdate_dash}', p.last_pay_date) AS last_pay_date,  -- 最近支付日期
           COALESCE(p.total_pay_order_qty, 0) + COALESCE(t.pay_order_qty, 0) AS total_pay_order_qty,  -- 累计支付单数
           COALESCE(p.total_pay_amt, 0) + COALESCE(t.pay_amt, 0) AS total_pay_amt,  -- 累计支付金额
           t.buyer_customer_id IS NOT NULL AS paid_today
    FROM today t
    FULL OUTER JOIN prev p ON p.buyer_customer_id = t.buyer_customer_id AND p.seller_tenant_id = t.seller_tenant_id
)
INSERT OVERWRITE TABLE dws.dws_cus_customer_lifetime_df PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT /*+ BROADCAST(r) */
    m.buyer_customer_id,                                                          -- 买家游客ID
    m.seller_tenant_id,                                                           -- 卖家租户ID
    m.first_pay_date,                                                             -- 首次支付日期
    m.last_pay_date,                                                              -- 最近支付日期
    m.total_pay_order_qty,                                                        -- 累计支付单数
    m.total_pay_amt,                                                              -- 累计支付金额
    COALESCE(d.pay_order_30d_qty, 0)                                              AS pay_order_30d_qty,  -- 近30天支付单数
    COALESCE(d.pay_30d_amt, 0)                                                    AS pay_30d_amt,  -- 近30天支付金额
    CAST(IF(COALESCE(d.pay_order_30d_qty, 0) >= 2, 1, 0) AS TINYINT)              AS buyer_type,  -- 买家类型
    IF(m.paid_today AND r.customer_id IS NOT NULL, 1, 0)                          AS pay_buyer_qty,  -- 支付买家数
    TO_BITMAP(IF(m.paid_today AND r.customer_id IS NOT NULL, m.buyer_customer_id, NULL)) AS pay_buyer_bitmap,  -- 支付买家数去重位图
    IF(m.paid_today AND r.customer_id IS NOT NULL AND m.first_pay_date < '${bizdate_dash}', 1, 0) AS repeat_buyer_qty,  -- 老客买家数
    TO_BITMAP(IF(m.paid_today AND r.customer_id IS NOT NULL AND m.first_pay_date < '${bizdate_dash}', m.buyer_customer_id, NULL)) AS repeat_buyer_bitmap,  -- 老客买家数去重位图
    CURRENT_TIMESTAMP() AS etl_time                                               -- ETL 加载时间
FROM m
LEFT JOIN d30 d ON d.buyer_customer_id = m.buyer_customer_id AND d.seller_tenant_id = m.seller_tenant_id
LEFT JOIN real_buyer r ON r.customer_id = m.buyer_customer_id;
