-- ads.ads_cus_customer_rfm_df  会员RFM与复购
-- 粒度：travel_date × seller_tenant_id × rfm_segment_code
-- 来源：dws_cus_customer_lifetime_df
-- 生成方式：Spark SQL / Hive；字段 10 个：直接翻译 9 · 规则翻译 1 · 待确认 0
-- 来源先按粒度键预聚合；快照/累计表：增量来源取截至统计日的全部分区

WITH
src_customer_lifetime AS (                               -- 来源「游客累计至今汇总」按粒度键预聚合
  SELECT
    seller_tenant_id AS seller_tenant_id,                -- 卖家租户ID
    CAST(NULL AS STRING) AS rfm_segment_code,
    BITMAP_UNION(pay_buyer_bitmap) AS pay_buyer_bitmap,  -- 支付买家数去重位图（日）
    BITMAP_UNION(repeat_buyer_bitmap) AS repeat_buyer_bitmap,  -- 老客买家数去重位图（日）
    SUM(buyer_type) AS repurchase_numerator_qty,         -- 复购率分子（日）
    BITMAP_UNION(pay_buyer_bitmap) AS repurchase_denominator_bitmap,  -- 复购率分母（日）
    SUM(pay_buyer_qty) AS per_customer_numerator_amt,    -- 客单价分子（日）
    BITMAP_UNION(pay_buyer_bitmap) AS per_customer_denominator_bitmap  -- 客单价分母（日）
  FROM dws.dws_cus_customer_lifetime_df s                -- 来源表「游客累计至今汇总」
  WHERE s.travel_date = '${bizdate}'                     -- 只取当日分区
  GROUP BY seller_tenant_id                              -- 按粒度键汇总
),
merged AS (                                              -- 按粒度键汇总，计算派生指标
  SELECT
    u.seller_tenant_id,                                  -- 卖家租户ID
    u.rfm_segment_code,                                  -- RFM 分层
    u.pay_buyer_bitmap,                                  -- 支付买家数去重位图（日）
    u.repeat_buyer_bitmap,                               -- 老客买家数去重位图（日）
    u.repurchase_numerator_qty,                          -- 复购率分子（日）
    u.repurchase_denominator_bitmap,                     -- 复购率分母（日）
    u.per_customer_numerator_amt,                        -- 客单价分子（日）
    u.per_customer_denominator_bitmap,                   -- 客单价分母（日）
    CURRENT_TIMESTAMP() AS etl_time                      -- ETL 加载时间
  FROM src_customer_lifetime u
),
tenant_cur AS (                                          -- 「租户（商户/供应商/分销商）维度」当前有效版本，只取名称类字段
  SELECT tenant_id, tenant_name
  FROM dim.dim_sup_tenant_zip
  WHERE travel_date = '${bizdate}' AND end_date = '9999-12-31'  -- 取当日分区里的拉链当前有效版本
)
INSERT OVERWRITE TABLE ads.ads_cus_customer_rfm_df PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  merged.seller_tenant_id,                               -- 卖家租户ID
  merged.rfm_segment_code,                               -- RFM 分层
  tenant_cur.tenant_name AS seller_tenant_name,          -- 卖家租户名称
  merged.pay_buyer_bitmap,                               -- 支付买家数去重位图（日）
  merged.repeat_buyer_bitmap,                            -- 老客买家数去重位图（日）
  merged.repurchase_numerator_qty,                       -- 复购率分子（日）
  merged.repurchase_denominator_bitmap,                  -- 复购率分母（日）
  merged.per_customer_numerator_amt,                     -- 客单价分子（日）
  merged.per_customer_denominator_bitmap,                -- 客单价分母（日）
  merged.etl_time                                        -- ETL 加载时间
FROM merged
LEFT JOIN tenant_cur                                     -- 关联「租户（商户/供应商/分销商）维度」，补 seller_tenant_name
  ON tenant_cur.tenant_id = merged.seller_tenant_id;     -- 按 seller_tenant_id→tenant_id 关联
