-- ads.ads_cus_customer_rfm_df  会员RFM与复购
-- 粒度：travel_date × seller_tenant_id × rfm_segment_code
-- 来源：dws_cus_customer_lifetime_df + dws_cus_customer_trade_di + dim_sup_tenant_zip
-- 生成方式：手写（结构不适合按字段自动翻译）；业务规则：
--   · R = 最近支付距统计日天数，F = 累计支付子单数，M = 累计支付金额；按「本商户全部真实买家的均值」划高低（R 越小越好）
--   · M 低于均值 → GENERAL 一般；M 高：R 近且 F 高 → HIGH_VALUE 重要价值，R 远且 F 高 → HIGH_KEEP 重要保持，R 近且 F 低 → HIGH_DEVELOP 重要发展，R 远且 F 低 → HIGH_RETAIN 重要挽留
--   · 复购率 = 复购买家数 / 支付买家数；复购买家 = 近 30 天支付子单数 ≥ 2（buyer_type = 1）
--   · 客单价 = 当日支付金额 / 当日支付买家数；分子取 dws_cus_customer_trade_di 当日支付金额（原生成误取买家数）
-- 性能：
--   · 快照只读当日一个分区；均值按商户先算一次再关联，不做全表排序

WITH lt AS (                                                        -- 游客 × 商户累计快照（真实买家）
    SELECT seller_tenant_id,                                        -- 卖家租户ID
           buyer_customer_id,
           DATEDIFF('${bizdate_dash}', last_pay_date) AS r_day,     -- R：最近支付距今天数
           total_pay_order_qty AS f_qty,                            -- F：累计支付子单数
           total_pay_amt AS m_amt,                                  -- M：累计支付金额（元）
           buyer_type,
           pay_buyer_bitmap,                                        -- 支付买家数去重位图（日）
           repeat_buyer_bitmap                                      -- 老客买家数去重位图（日）
    FROM dws.dws_cus_customer_lifetime_df
    WHERE travel_date = '${bizdate}' AND buyer_customer_id > 0      -- 只取当日分区，并按条件过滤
),
avg_ AS (                                                           -- 每个商户的 R / F / M 均值，作为高低分界
    SELECT seller_tenant_id,                                        -- 卖家租户ID
           AVG(r_day) AS r_avg,
           AVG(f_qty) AS f_avg,
           AVG(m_amt) AS m_avg
    FROM lt
    GROUP BY seller_tenant_id                                       -- 按粒度键汇总
),
seg AS (                                                            -- 每个买家落到一个 RFM 分层
    SELECT lt.*,
           CASE WHEN lt.m_amt < a.m_avg THEN 'GENERAL'
                WHEN lt.r_day <= a.r_avg AND lt.f_qty >= a.f_avg THEN 'HIGH_VALUE'
                WHEN lt.r_day > a.r_avg AND lt.f_qty >= a.f_avg THEN 'HIGH_KEEP'
                WHEN lt.r_day <= a.r_avg THEN 'HIGH_DEVELOP'
                ELSE 'HIGH_RETAIN'
           END AS rfm_segment_code                                  -- RFM 分层
    FROM lt
    JOIN avg_ a ON a.seller_tenant_id = lt.seller_tenant_id
),
td AS (                                                             -- 当日支付金额（客单价分子）
    SELECT seller_tenant_id, buyer_customer_id, SUM(pay_amt) AS pay_amt  -- 支付金额（GMV）
    FROM dws.dws_cus_customer_trade_di
    WHERE travel_date = '${bizdate}'                                -- 只取当日分区
    GROUP BY seller_tenant_id, buyer_customer_id                    -- 按粒度键汇总
),
tenant_cur AS (
    SELECT tenant_id, tenant_name
    FROM dim.dim_sup_tenant_zip
    WHERE travel_date = '${bizdate}' AND end_date = '9999-12-31'    -- 取当日分区里的拉链当前有效版本
)
INSERT OVERWRITE TABLE ads.ads_cus_customer_rfm_df PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT s.seller_tenant_id,                                          -- 卖家租户ID
       s.rfm_segment_code,                                          -- RFM 分层
       MAX(tc.tenant_name) AS seller_tenant_name,                   -- 卖家租户名称
       BITMAP_UNION(s.pay_buyer_bitmap) AS pay_buyer_bitmap,        -- 支付买家数去重位图（日）
       BITMAP_UNION(s.repeat_buyer_bitmap) AS repeat_buyer_bitmap,  -- 老客买家数去重位图（日）
       SUM(s.buyer_type) AS repurchase_numerator_qty,               -- 复购率分子（日）
       BITMAP_UNION(s.pay_buyer_bitmap) AS repurchase_denominator_bitmap,  -- 复购率分母（日）
       SUM(COALESCE(td.pay_amt, 0)) AS per_customer_numerator_amt,  -- 客单价分子（日）
       BITMAP_UNION(s.pay_buyer_bitmap) AS per_customer_denominator_bitmap,  -- 客单价分母（日）
       CURRENT_TIMESTAMP() AS etl_time                              -- ETL 加载时间
FROM seg s
LEFT JOIN td ON td.seller_tenant_id = s.seller_tenant_id AND td.buyer_customer_id = s.buyer_customer_id
LEFT JOIN tenant_cur tc ON tc.tenant_id = s.seller_tenant_id
GROUP BY s.seller_tenant_id, s.rfm_segment_code;                    -- 按粒度键汇总
