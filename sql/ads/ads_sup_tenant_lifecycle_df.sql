-- ads.ads_sup_tenant_lifecycle_df  商户生命周期（活跃/沉默/流失）
-- 粒度：travel_date × tenant_lifecycle_stage_code
-- 来源：dws_sup_tenant_lifetime_df
-- 生成方式：Spark SQL / Hive；字段 7 个：直接翻译 6 · 规则翻译 0 · 待确认 1
-- 来源先按粒度键预聚合；快照/累计表：增量来源取截至统计日的全部分区
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

WITH
src_tenant_lifetime AS (                                         -- 来源「商户累计至今汇总」按粒度键预聚合
  SELECT
    CAST(NULL AS STRING) AS tenant_lifecycle_stage_code,
    BITMAP_UNION(active_tenant_bitmap) AS active_tenant_bitmap,  -- 动销商户数去重位图（日）
    BITMAP_UNION(active_tenant_bitmap) AS tenant_active_numerator_bitmap,  -- 商户动销率分子（日）
    SUM(active_tenant_qty) AS tenant_active_denominator_qty,     -- 商户动销率分母（日）
    SUM(pay_30d_amt) AS silent_tenant_qty,                       -- 沉默商户数（日快照）
    SUM(last_pay_date) AS churn_tenant_qty                       -- 流失商户数（日快照）
  FROM dws.dws_sup_tenant_lifetime_df s                          -- 来源表「商户累计至今汇总」
  WHERE s.travel_date = '${bizdate}'                             -- 只取当日分区
)
INSERT OVERWRITE TABLE ads.ads_sup_tenant_lifecycle_df PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  u.tenant_lifecycle_stage_code,                                 -- 租户生命周期
  u.active_tenant_bitmap,                                        -- 动销商户数去重位图（日）
  u.tenant_active_numerator_bitmap,                              -- 商户动销率分子（日）
  u.tenant_active_denominator_qty,                               -- 商户动销率分母（日）
  u.silent_tenant_qty,                                           -- 沉默商户数（日快照）
  u.churn_tenant_qty,                                            -- 流失商户数（日快照）
  CURRENT_TIMESTAMP() AS etl_time                                -- ETL 加载时间
FROM src_tenant_lifetime u;
