-- ads.ads_sup_tenant_lifecycle_df  商户生命周期
-- 粒度：travel_date × tenant_lifecycle_stage_code
-- 来源：dws_sup_tenant_lifetime_df
-- 生成方式：手写（结构不适合按字段自动翻译）；业务规则：
--   · 阶段（按优先级）：首单在近 30 天内 → NEW 新入驻；近 30 天有支付 → ACTIVE 活跃；近 30 天无支付、近 90 天有 → SILENT 沉默；近 90 天无支付 → CHURN 流失；从未支付 → NEW
--   · 动销率 = 动销商户数 / 该阶段商户数
--   · 流失阈值 90 天与口径说明一致；「套餐已到期」条件待套餐到期日进入商户快照后叠加（口径说明标注阈值待定）
-- 性能：
--   · 快照只读当日一个分区，按阶段分组一次聚合

WITH lt AS (
    SELECT seller_tenant_id,
           active_tenant_bitmap,                                                  -- 动销商户数去重位图（日）
           active_tenant_qty,
           pay_30d_amt,
           total_pay_amt,
           last_pay_date,
           CASE WHEN first_pay_date IS NULL OR first_pay_date >= DATE_SUB('${bizdate_dash}', 29) THEN 'NEW'
                WHEN pay_30d_amt > 0 THEN 'ACTIVE'
                WHEN last_pay_date >= DATE_SUB('${bizdate_dash}', 89) THEN 'SILENT'
                ELSE 'CHURN'
           END AS tenant_lifecycle_stage_code                                     -- 租户生命周期
    FROM dws.dws_sup_tenant_lifetime_df
    WHERE travel_date = '${bizdate}'                                              -- 只取当日分区
)
INSERT OVERWRITE TABLE ads.ads_sup_tenant_lifecycle_df PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT tenant_lifecycle_stage_code,                                               -- 租户生命周期
       BITMAP_UNION(active_tenant_bitmap) AS active_tenant_bitmap,                -- 动销商户数去重位图（日）
       BITMAP_UNION(active_tenant_bitmap) AS tenant_active_numerator_bitmap,      -- 商户动销率分子（日）
       COUNT(DISTINCT seller_tenant_id) AS tenant_active_denominator_qty,         -- 商户动销率分母（日）
       COUNT(CASE WHEN pay_30d_amt = 0 AND total_pay_amt > 0 THEN seller_tenant_id END) AS silent_tenant_qty,  -- 沉默商户数（日快照）
       COUNT(CASE WHEN last_pay_date < DATE_SUB('${bizdate_dash}', 89) THEN seller_tenant_id END) AS churn_tenant_qty,  -- 流失商户数（日快照）
       CURRENT_TIMESTAMP() AS etl_time                                            -- ETL 加载时间
FROM lt
GROUP BY tenant_lifecycle_stage_code;                                             -- 按粒度键汇总
