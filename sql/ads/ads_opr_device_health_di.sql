-- ads.ads_opr_device_health_di  设备健康
-- 粒度：travel_date × tenant_id × device_type
-- 来源：dws_opr_device_di, dws_ord_tenant_sku_verify_di
-- 生成方式：Spark SQL / Hive；字段 12 个：直接翻译 10 · 规则翻译 0 · 待确认 2
-- 多来源：每个来源表按粒度键先汇总，UNION ALL 后再合并
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT OVERWRITE TABLE ads.ads_opr_device_health_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  x.tenant_id,                                                -- 租户ID
  x.device_type,                                              -- 设备类型
  d1.tenant_name AS tenant_name,                              -- 租户名称
  x.device_online_numerator_qty,                              -- 设备在线率分子（日）
  x.device_online_denominator_qty,                            -- 设备在线率分母（日）
  x.offline_times_qty,                                        -- 设备离线次数（日）
  x.offline_verify_numerator_qty,                             -- 离线核销占比分子（日）
  x.offline_verify_denominator_qty,                           -- 离线核销占比分母（日）
  x.offline_conflict_qty,                                     -- 离线核销冲突次数（日）
  x.device_total_qty,                                         -- 设备数（日快照）
  x.etl_time                                                  -- ETL 加载时间
FROM (
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
FROM (
  -- 来源：dws_opr_device_di
  SELECT
    tenant_id AS tenant_id,                                   -- 租户ID
    CAST(NULL AS STRING) AS device_type,                      -- 设备类型
    SUM(online_minute_qty) AS device_online_numerator_qty,    -- 设备在线率分子（日）
    SUM(online_minute_qty) AS device_online_denominator_qty,  -- 设备在线率分母（日）
    SUM(offline_times_qty) AS offline_times_qty,              -- 设备离线次数（日）
    SUM(offline_verify_qty) AS offline_verify_numerator_qty,  -- 离线核销占比分子（日）
    SUM(verify_entitlement_qty) AS offline_verify_denominator_qty,  -- 离线核销占比分母（日）
    NULL AS offline_conflict_qty,                             -- 离线核销冲突次数（日）
    SUM(device_total_qty) AS device_total_qty                 -- 设备数（日快照）
  FROM dws.dws_opr_device_di s                                -- 来源表「设备日汇总」
  WHERE s.travel_date = '${bizdate}'                          -- 只取当日分区
  GROUP BY tenant_id                                          -- 按粒度键汇总
  UNION ALL                                                   -- 合并各来源
  -- 来源：dws_ord_tenant_sku_verify_di
  SELECT
    seller_tenant_id AS tenant_id,                            -- 租户ID
    CAST(NULL AS STRING) AS device_type,                      -- 设备类型
    NULL AS device_online_numerator_qty,                      -- 设备在线率分子（日）
    NULL AS device_online_denominator_qty,                    -- 设备在线率分母（日）
    NULL AS offline_times_qty,                                -- 设备离线次数（日）
    NULL AS offline_verify_numerator_qty,                     -- 离线核销占比分子（日）
    NULL AS offline_verify_denominator_qty,                   -- 离线核销占比分母（日）
    SUM(offline_conflict_qty) AS offline_conflict_qty,        -- 离线核销冲突次数（日）
    NULL AS device_total_qty                                  -- 设备数（日快照）
  FROM dws.dws_ord_tenant_sku_verify_di s                     -- 来源表「商户×SKU×核销点 核销日汇总」
  WHERE s.travel_date = '${bizdate}'                          -- 只取当日分区
  GROUP BY seller_tenant_id                                   -- 按粒度键汇总
) u                                                           -- 各来源合并后的明细
GROUP BY u.tenant_id, u.device_type                           -- 按粒度键汇总
) x                                                           -- 汇总结果，外层再补维度名称
LEFT JOIN dim.dim_sup_tenant_zip d1 ON d1.tenant_id = x.tenant_id AND d1.travel_date = '${bizdate}' AND d1.end_date = '9999-12-31';  -- 关联「租户（商户/供应商/分销商）维度」，取维度名称
