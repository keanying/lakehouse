-- ads.ads_opr_device_health_di  设备健康
-- 粒度：travel_date × tenant_id × device_type
-- 来源：dws_opr_device_di, dws_ord_tenant_sku_verify_di
-- 生成方式：Spark SQL / Hive；字段 12 个：直接翻译 10 · 规则翻译 2 · 待确认 0
-- 多来源：每个来源先按粒度键预聚合，UNION ALL 后再汇总

WITH
src_device AS (                                                 -- 来源「设备日汇总」按粒度键预聚合
  SELECT
    tenant_id AS tenant_id,                                     -- 租户ID
    CAST(NULL AS STRING) AS device_type,
    SUM(online_minute_qty) AS device_online_numerator_qty,      -- 设备在线率分子（日）
    SUM(online_minute_qty) AS device_online_denominator_qty,    -- 设备在线率分母（日）
    SUM(offline_times_qty) AS offline_times_qty,                -- 设备离线次数（日）
    SUM(offline_verify_qty) AS offline_verify_numerator_qty,    -- 离线核销占比分子（日）
    SUM(verify_entitlement_qty) AS offline_verify_denominator_qty,  -- 离线核销占比分母（日）
    NULL AS offline_conflict_qty,
    SUM(device_total_qty) AS device_total_qty                   -- 设备数（日快照）
  FROM dws.dws_opr_device_di s                                  -- 来源表「设备日汇总」
  WHERE s.travel_date = '${bizdate}'                            -- 只取当日分区
  GROUP BY tenant_id                                            -- 按粒度键汇总
),
src_tenant_sku_verify AS (                                      -- 来源「商户×SKU×核销点 核销日汇总」按粒度键预聚合
  SELECT
    seller_tenant_id AS tenant_id,                              -- 租户ID
    CAST(NULL AS STRING) AS device_type,
    NULL AS device_online_numerator_qty,
    NULL AS device_online_denominator_qty,
    NULL AS offline_times_qty,
    NULL AS offline_verify_numerator_qty,
    NULL AS offline_verify_denominator_qty,
    SUM(offline_conflict_qty) AS offline_conflict_qty,          -- 离线核销冲突次数（日）
    NULL AS device_total_qty
  FROM dws.dws_ord_tenant_sku_verify_di s                       -- 来源表「商户×SKU×核销点 核销日汇总」
  WHERE s.travel_date = '${bizdate}'                            -- 只取当日分区
  GROUP BY seller_tenant_id                                     -- 按粒度键汇总
),
all_src AS (                                                    -- 各来源字段已对齐，UNION ALL 合并（比多表 FULL JOIN 少 shuffle）
  SELECT * FROM src_device
  UNION ALL
  SELECT * FROM src_tenant_sku_verify
),
merged AS (                                                     -- 按粒度键汇总，计算派生指标
  SELECT
    u.tenant_id,                                                -- 租户ID
    u.device_type,                                              -- 设备类型
    SUM(u.device_online_numerator_qty) AS device_online_numerator_qty,  -- 设备在线率分子（日）
    SUM(u.device_online_denominator_qty) AS device_online_denominator_qty,  -- 设备在线率分母（日）
    SUM(u.offline_times_qty) AS offline_times_qty,              -- 设备离线次数（日）
    SUM(u.offline_verify_numerator_qty) AS offline_verify_numerator_qty,  -- 离线核销占比分子（日）
    SUM(u.offline_verify_denominator_qty) AS offline_verify_denominator_qty,  -- 离线核销占比分母（日）
    SUM(u.offline_conflict_qty) AS offline_conflict_qty,        -- 离线核销冲突次数（日）
    SUM(u.device_total_qty) AS device_total_qty,                -- 设备数（日快照）
    CURRENT_TIMESTAMP() AS etl_time                             -- ETL 加载时间
  FROM all_src u
  GROUP BY u.tenant_id, u.device_type                           -- 按粒度键汇总
),
tenant_cur AS (                                                 -- 「租户（商户/供应商/分销商）维度」当前有效版本，只取名称类字段
  SELECT tenant_id, tenant_name
  FROM dim.dim_sup_tenant_zip
  WHERE travel_date = '${bizdate}' AND end_date = '9999-12-31'  -- 取当日分区里的拉链当前有效版本
)
INSERT OVERWRITE TABLE ads.ads_opr_device_health_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  merged.tenant_id,                                             -- 租户ID
  merged.device_type,                                           -- 设备类型
  tenant_cur.tenant_name AS tenant_name,                        -- 租户名称
  merged.device_online_numerator_qty,                           -- 设备在线率分子（日）
  merged.device_online_denominator_qty,                         -- 设备在线率分母（日）
  merged.offline_times_qty,                                     -- 设备离线次数（日）
  merged.offline_verify_numerator_qty,                          -- 离线核销占比分子（日）
  merged.offline_verify_denominator_qty,                        -- 离线核销占比分母（日）
  merged.offline_conflict_qty,                                  -- 离线核销冲突次数（日）
  merged.device_total_qty,                                      -- 设备数（日快照）
  merged.etl_time                                               -- ETL 加载时间
FROM merged
LEFT JOIN tenant_cur                                            -- 关联「租户（商户/供应商/分销商）维度」，补 tenant_name
  ON tenant_cur.tenant_id = merged.tenant_id;                   -- 按 tenant_id 关联
