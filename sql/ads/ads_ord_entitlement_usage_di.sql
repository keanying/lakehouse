-- ads.ads_ord_entitlement_usage_di  权益使用分析（年卡/次卡/计时/额度）
-- 粒度：travel_date × seller_tenant_id × sku_id
-- 来源：dws_ord_tenant_entitlement_di, dws_ord_tenant_ticket_stock_df
-- 生成方式：Spark SQL / Hive；字段 34 个：直接翻译 16 · 规则翻译 18 · 待确认 0
-- 多来源：每个来源先按粒度键预聚合，UNION ALL 后再汇总
-- 补 0 / 补空列：多来源 UNION ALL 时，某来源不产出的指标补 0 或空，外层按粒度 SUM 后即为各来源之和，不影响结果

WITH
src_tenant_entitlement AS (                                                       -- 来源「商户×权益类型 权益使用日汇总」按粒度键预聚合
  SELECT
    seller_tenant_id AS seller_tenant_id,                                         -- 卖家租户ID
    sku_id AS sku_id,                                                             -- SKU ID
    SUM(CASE WHEN entitlement_type = 'FIXED' THEN entitlement_used_qty END) AS fixed_entitlement_used_qty,  -- 固定型权益已用次数（日）
    SUM(CASE WHEN entitlement_type = 'SELECTABLE' THEN entitlement_used_qty END) AS selectable_entitlement_used_qty,  -- 选择型权益已用次数（日）
    SUM(CASE WHEN entitlement_type = 'COUNTED' THEN entitlement_used_qty END) AS counted_entitlement_used_qty,  -- 计次型权益已用次数（日）
    SUM(CASE WHEN entitlement_type = 'TIMED' THEN entitlement_used_qty END) AS timed_entitlement_used_qty,  -- 计时型权益已用次数（日）
    SUM(CASE WHEN entitlement_type = 'UNLIMITED' THEN entitlement_used_qty END) AS unlimited_entitlement_used_qty,  -- 不限次型权益已用次数（日）
    SUM(CASE WHEN entitlement_type = 'QUOTA' THEN entitlement_used_qty END) AS quota_entitlement_used_qty,  -- 额度型权益已用次数（日）
    SUM(CASE WHEN entitlement_type = 'FIXED' THEN entitlement_used_qty END) AS fixed_entitlement_usage_numerator_qty,  -- 固定型权益使用率分子（日）
    SUM(CASE WHEN entitlement_type = 'FIXED' THEN entitlement_total_qty END) AS fixed_entitlement_usage_denominator_qty,  -- 固定型权益使用率分母（日）
    SUM(CASE WHEN entitlement_type = 'SELECTABLE' THEN entitlement_used_qty END) AS selectable_entitlement_usage_numerator_qty,  -- 选择型权益使用率分子（日）
    SUM(CASE WHEN entitlement_type = 'SELECTABLE' THEN entitlement_total_qty END) AS selectable_entitlement_usage_denominator_qty,  -- 选择型权益使用率分母（日）
    SUM(CASE WHEN entitlement_type = 'COUNTED' THEN entitlement_used_qty END) AS counted_entitlement_usage_numerator_qty,  -- 计次型权益使用率分子（日）
    SUM(CASE WHEN entitlement_type = 'COUNTED' THEN entitlement_total_qty END) AS counted_entitlement_usage_denominator_qty,  -- 计次型权益使用率分母（日）
    SUM(CASE WHEN entitlement_type = 'TIMED' THEN entitlement_used_qty END) AS timed_entitlement_usage_numerator_qty,  -- 计时型权益使用率分子（日）
    SUM(CASE WHEN entitlement_type = 'TIMED' THEN entitlement_total_qty END) AS timed_entitlement_usage_denominator_qty,  -- 计时型权益使用率分母（日）
    SUM(CASE WHEN entitlement_type = 'UNLIMITED' THEN entitlement_used_qty END) AS unlimited_entitlement_usage_numerator_qty,  -- 不限次型权益使用率分子（日）
    SUM(CASE WHEN entitlement_type = 'UNLIMITED' THEN entitlement_total_qty END) AS unlimited_entitlement_usage_denominator_qty,  -- 不限次型权益使用率分母（日）
    SUM(CASE WHEN entitlement_type = 'QUOTA' THEN entitlement_used_qty END) AS quota_entitlement_usage_numerator_qty,  -- 额度型权益使用率分子（日）
    SUM(CASE WHEN entitlement_type = 'QUOTA' THEN entitlement_total_qty END) AS quota_entitlement_usage_denominator_qty,  -- 额度型权益使用率分母（日）
    SUM(activate_ticket_qty) AS activate_ticket_qty,                              -- 激活票数（日）
    SUM(activate_ticket_qty) AS activate_numerator_qty,                           -- 激活率分子（日）
    SUM(pending_activate_ticket_qty) AS activate_denominator_qty,                 -- 激活率分母（日）
    SUM(activate_delay_day_qty) AS avg_activate_delay_day_numerator_qty,          -- 平均激活延迟天数分子（日）
    SUM(activate_ticket_qty) AS avg_activate_delay_day_denominator_qty,           -- 平均激活延迟天数分母（日）
    NULL AS expire_ticket_qty,                                                    -- 过期票数（日）：此来源不产出，补空
    NULL AS expire_numerator_qty,                                                 -- 过期率分子（日）：此来源不产出，补空
    NULL AS expire_denominator_qty,                                               -- 过期率分母（日）：此来源不产出，补空
    NULL AS unverified_ticket_qty,                                                -- 未核销在途票数（日快照）：此来源不产出，补空
    NULL AS unverified_amt,                                                       -- 未核销在途金额（预收）（日快照）：此来源不产出，补空
    SUM(pending_activate_ticket_qty) AS pending_activate_ticket_qty,              -- 待激活票数（日快照）
    SUM(quota_total_amt) AS quota_total_amt                                       -- 额度型权益总额度（日快照）
  FROM dws.dws_ord_tenant_entitlement_di s                                        -- 来源表「商户×权益类型 权益使用日汇总」
  WHERE s.travel_date = '${bizdate}'                                              -- 只取当日分区
  GROUP BY seller_tenant_id, sku_id                                               -- 按粒度键汇总
),
src_tenant_ticket_stock AS (                                                      -- 来源「商户×SKU 票状态存量快照」按粒度键预聚合
  SELECT
    seller_tenant_id AS seller_tenant_id,                                         -- 卖家租户ID
    sku_id AS sku_id,                                                             -- SKU ID
    NULL AS fixed_entitlement_used_qty,                                           -- 固定型权益已用次数（日）：此来源不产出，补空
    NULL AS selectable_entitlement_used_qty,                                      -- 选择型权益已用次数（日）：此来源不产出，补空
    NULL AS counted_entitlement_used_qty,                                         -- 计次型权益已用次数（日）：此来源不产出，补空
    NULL AS timed_entitlement_used_qty,                                           -- 计时型权益已用次数（日）：此来源不产出，补空
    NULL AS unlimited_entitlement_used_qty,                                       -- 不限次型权益已用次数（日）：此来源不产出，补空
    NULL AS quota_entitlement_used_qty,                                           -- 额度型权益已用次数（日）：此来源不产出，补空
    NULL AS fixed_entitlement_usage_numerator_qty,                                -- 固定型权益使用率分子（日）：此来源不产出，补空
    NULL AS fixed_entitlement_usage_denominator_qty,                              -- 固定型权益使用率分母（日）：此来源不产出，补空
    NULL AS selectable_entitlement_usage_numerator_qty,                           -- 选择型权益使用率分子（日）：此来源不产出，补空
    NULL AS selectable_entitlement_usage_denominator_qty,                         -- 选择型权益使用率分母（日）：此来源不产出，补空
    NULL AS counted_entitlement_usage_numerator_qty,                              -- 计次型权益使用率分子（日）：此来源不产出，补空
    NULL AS counted_entitlement_usage_denominator_qty,                            -- 计次型权益使用率分母（日）：此来源不产出，补空
    NULL AS timed_entitlement_usage_numerator_qty,                                -- 计时型权益使用率分子（日）：此来源不产出，补空
    NULL AS timed_entitlement_usage_denominator_qty,                              -- 计时型权益使用率分母（日）：此来源不产出，补空
    NULL AS unlimited_entitlement_usage_numerator_qty,                            -- 不限次型权益使用率分子（日）：此来源不产出，补空
    NULL AS unlimited_entitlement_usage_denominator_qty,                          -- 不限次型权益使用率分母（日）：此来源不产出，补空
    NULL AS quota_entitlement_usage_numerator_qty,                                -- 额度型权益使用率分子（日）：此来源不产出，补空
    NULL AS quota_entitlement_usage_denominator_qty,                              -- 额度型权益使用率分母（日）：此来源不产出，补空
    NULL AS activate_ticket_qty,                                                  -- 激活票数（日）：此来源不产出，补空
    NULL AS activate_numerator_qty,                                               -- 激活率分子（日）：此来源不产出，补空
    NULL AS activate_denominator_qty,                                             -- 激活率分母（日）：此来源不产出，补空
    NULL AS avg_activate_delay_day_numerator_qty,                                 -- 平均激活延迟天数分子（日）：此来源不产出，补空
    NULL AS avg_activate_delay_day_denominator_qty,                               -- 平均激活延迟天数分母（日）：此来源不产出，补空
    SUM(expire_ticket_qty) AS expire_ticket_qty,                                  -- 过期票数（日）
    SUM(expire_ticket_qty) AS expire_numerator_qty,                               -- 过期率分子（日）
    SUM(issue_ticket_qty) AS expire_denominator_qty,                              -- 过期率分母（日）
    SUM(unverified_ticket_qty) AS unverified_ticket_qty,                          -- 未核销在途票数（日快照）
    SUM(unverified_amt) AS unverified_amt,                                        -- 未核销在途金额（预收）（日快照）
    NULL AS pending_activate_ticket_qty,                                          -- 待激活票数（日快照）：此来源不产出，补空
    NULL AS quota_total_amt                                                       -- 额度型权益总额度（日快照）：此来源不产出，补空
  FROM dws.dws_ord_tenant_ticket_stock_df s                                       -- 来源表「商户×SKU 票状态存量快照」
  WHERE s.travel_date = '${bizdate}'                                              -- 只取当日分区
  GROUP BY seller_tenant_id, sku_id                                               -- 按粒度键汇总
),
all_src AS (                                                                      -- 各来源字段已对齐，UNION ALL 合并（比多表 FULL JOIN 少 shuffle）
  SELECT * FROM src_tenant_entitlement
  UNION ALL
  SELECT * FROM src_tenant_ticket_stock
),
merged AS (                                                                       -- 按粒度键汇总，计算派生指标
  SELECT
    u.seller_tenant_id,                                                           -- 卖家租户ID
    u.sku_id,                                                                     -- SKU ID
    SUM(u.fixed_entitlement_used_qty) AS fixed_entitlement_used_qty,              -- 固定型权益已用次数（日）
    SUM(u.selectable_entitlement_used_qty) AS selectable_entitlement_used_qty,    -- 选择型权益已用次数（日）
    SUM(u.counted_entitlement_used_qty) AS counted_entitlement_used_qty,          -- 计次型权益已用次数（日）
    SUM(u.timed_entitlement_used_qty) AS timed_entitlement_used_qty,              -- 计时型权益已用次数（日）
    SUM(u.unlimited_entitlement_used_qty) AS unlimited_entitlement_used_qty,      -- 不限次型权益已用次数（日）
    SUM(u.quota_entitlement_used_qty) AS quota_entitlement_used_qty,              -- 额度型权益已用次数（日）
    SUM(u.fixed_entitlement_usage_numerator_qty) AS fixed_entitlement_usage_numerator_qty,  -- 固定型权益使用率分子（日）
    SUM(u.fixed_entitlement_usage_denominator_qty) AS fixed_entitlement_usage_denominator_qty,  -- 固定型权益使用率分母（日）
    SUM(u.selectable_entitlement_usage_numerator_qty) AS selectable_entitlement_usage_numerator_qty,  -- 选择型权益使用率分子（日）
    SUM(u.selectable_entitlement_usage_denominator_qty) AS selectable_entitlement_usage_denominator_qty,  -- 选择型权益使用率分母（日）
    SUM(u.counted_entitlement_usage_numerator_qty) AS counted_entitlement_usage_numerator_qty,  -- 计次型权益使用率分子（日）
    SUM(u.counted_entitlement_usage_denominator_qty) AS counted_entitlement_usage_denominator_qty,  -- 计次型权益使用率分母（日）
    SUM(u.timed_entitlement_usage_numerator_qty) AS timed_entitlement_usage_numerator_qty,  -- 计时型权益使用率分子（日）
    SUM(u.timed_entitlement_usage_denominator_qty) AS timed_entitlement_usage_denominator_qty,  -- 计时型权益使用率分母（日）
    SUM(u.unlimited_entitlement_usage_numerator_qty) AS unlimited_entitlement_usage_numerator_qty,  -- 不限次型权益使用率分子（日）
    SUM(u.unlimited_entitlement_usage_denominator_qty) AS unlimited_entitlement_usage_denominator_qty,  -- 不限次型权益使用率分母（日）
    SUM(u.quota_entitlement_usage_numerator_qty) AS quota_entitlement_usage_numerator_qty,  -- 额度型权益使用率分子（日）
    SUM(u.quota_entitlement_usage_denominator_qty) AS quota_entitlement_usage_denominator_qty,  -- 额度型权益使用率分母（日）
    SUM(u.activate_ticket_qty) AS activate_ticket_qty,                            -- 激活票数（日）
    SUM(u.activate_numerator_qty) AS activate_numerator_qty,                      -- 激活率分子（日）
    SUM(u.activate_denominator_qty) AS activate_denominator_qty,                  -- 激活率分母（日）
    SUM(u.avg_activate_delay_day_numerator_qty) AS avg_activate_delay_day_numerator_qty,  -- 平均激活延迟天数分子（日）
    SUM(u.avg_activate_delay_day_denominator_qty) AS avg_activate_delay_day_denominator_qty,  -- 平均激活延迟天数分母（日）
    SUM(u.expire_ticket_qty) AS expire_ticket_qty,                                -- 过期票数（日）
    SUM(u.expire_numerator_qty) AS expire_numerator_qty,                          -- 过期率分子（日）
    SUM(u.expire_denominator_qty) AS expire_denominator_qty,                      -- 过期率分母（日）
    SUM(u.unverified_ticket_qty) AS unverified_ticket_qty,                        -- 未核销在途票数（日快照）
    SUM(u.unverified_amt) AS unverified_amt,                                      -- 未核销在途金额（预收）（日快照）
    SUM(u.pending_activate_ticket_qty) AS pending_activate_ticket_qty,            -- 待激活票数（日快照）
    SUM(u.quota_total_amt) AS quota_total_amt,                                    -- 额度型权益总额度（日快照）
    CURRENT_TIMESTAMP() AS etl_time                                               -- ETL 加载时间
  FROM all_src u
  GROUP BY u.seller_tenant_id, u.sku_id                                           -- 按粒度键汇总
),
tenant_cur AS (                                                                   -- 「租户（商户/供应商/分销商）维度」当前有效版本，只取名称类字段
  SELECT tenant_id, tenant_name
  FROM dim.dim_sup_tenant_zip
  WHERE travel_date = '${bizdate}' AND end_date = '9999-12-31'                    -- 取当日分区里的拉链当前有效版本
),
sku_cur AS (                                                                      -- 「SKU维度」当前有效版本，只取名称类字段
  SELECT sku_id, sku_name
  FROM dim.dim_prd_sku_zip
  WHERE travel_date = '${bizdate}' AND end_date = '9999-12-31'                    -- 取当日分区里的拉链当前有效版本
)
INSERT OVERWRITE TABLE ads.ads_ord_entitlement_usage_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  merged.seller_tenant_id,                                                        -- 卖家租户ID
  merged.sku_id,                                                                  -- SKU ID
  tenant_cur.tenant_name AS seller_tenant_name,                                   -- 卖家租户名称
  sku_cur.sku_name AS sku_name,                                                   -- SKU 名称
  merged.fixed_entitlement_used_qty,                                              -- 固定型权益已用次数（日）
  merged.selectable_entitlement_used_qty,                                         -- 选择型权益已用次数（日）
  merged.counted_entitlement_used_qty,                                            -- 计次型权益已用次数（日）
  merged.timed_entitlement_used_qty,                                              -- 计时型权益已用次数（日）
  merged.unlimited_entitlement_used_qty,                                          -- 不限次型权益已用次数（日）
  merged.quota_entitlement_used_qty,                                              -- 额度型权益已用次数（日）
  merged.fixed_entitlement_usage_numerator_qty,                                   -- 固定型权益使用率分子（日）
  merged.fixed_entitlement_usage_denominator_qty,                                 -- 固定型权益使用率分母（日）
  merged.selectable_entitlement_usage_numerator_qty,                              -- 选择型权益使用率分子（日）
  merged.selectable_entitlement_usage_denominator_qty,                            -- 选择型权益使用率分母（日）
  merged.counted_entitlement_usage_numerator_qty,                                 -- 计次型权益使用率分子（日）
  merged.counted_entitlement_usage_denominator_qty,                               -- 计次型权益使用率分母（日）
  merged.timed_entitlement_usage_numerator_qty,                                   -- 计时型权益使用率分子（日）
  merged.timed_entitlement_usage_denominator_qty,                                 -- 计时型权益使用率分母（日）
  merged.unlimited_entitlement_usage_numerator_qty,                               -- 不限次型权益使用率分子（日）
  merged.unlimited_entitlement_usage_denominator_qty,                             -- 不限次型权益使用率分母（日）
  merged.quota_entitlement_usage_numerator_qty,                                   -- 额度型权益使用率分子（日）
  merged.quota_entitlement_usage_denominator_qty,                                 -- 额度型权益使用率分母（日）
  merged.activate_ticket_qty,                                                     -- 激活票数（日）
  merged.activate_numerator_qty,                                                  -- 激活率分子（日）
  merged.activate_denominator_qty,                                                -- 激活率分母（日）
  merged.avg_activate_delay_day_numerator_qty,                                    -- 平均激活延迟天数分子（日）
  merged.avg_activate_delay_day_denominator_qty,                                  -- 平均激活延迟天数分母（日）
  merged.expire_ticket_qty,                                                       -- 过期票数（日）
  merged.expire_numerator_qty,                                                    -- 过期率分子（日）
  merged.expire_denominator_qty,                                                  -- 过期率分母（日）
  merged.unverified_ticket_qty,                                                   -- 未核销在途票数（日快照）
  merged.unverified_amt,                                                          -- 未核销在途金额（预收）（日快照）
  merged.pending_activate_ticket_qty,                                             -- 待激活票数（日快照）
  merged.quota_total_amt,                                                         -- 额度型权益总额度（日快照）
  merged.etl_time                                                                 -- ETL 加载时间
FROM merged
LEFT JOIN tenant_cur                                                              -- 关联「租户（商户/供应商/分销商）维度」，补 seller_tenant_name
  ON tenant_cur.tenant_id = merged.seller_tenant_id                               -- 按 seller_tenant_id→tenant_id 关联
LEFT JOIN sku_cur                                                                 -- 关联「SKU维度」，补 sku_name
  ON sku_cur.sku_id = merged.sku_id;                                              -- 按 sku_id 关联
