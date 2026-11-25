-- ads.ads_cus_customer_rfm_df  会员RFM与复购
-- 粒度：travel_date × seller_tenant_id × rfm_segment_code
-- 来源：dws_cus_customer_lifetime_df
-- 生成方式：Spark SQL / Hive；字段 10 个：直接翻译 9 · 规则翻译 0 · 待确认 1
-- 快照/累计表：增量来源取截至统计日的全部分区
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT OVERWRITE TABLE ads.ads_cus_customer_rfm_df PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  x.seller_tenant_id,                                                 -- 卖家租户ID
  x.rfm_segment_code,                                                 -- RFM 分层
  d1.tenant_name AS seller_tenant_name,                               -- 卖家租户名称
  x.pay_buyer_bitmap,                                                 -- 支付买家数去重位图（日）
  x.repeat_buyer_bitmap,                                              -- 老客买家数去重位图（日）
  x.repurchase_numerator_qty,                                         -- 复购率分子（日）
  x.repurchase_denominator_bitmap,                                    -- 复购率分母（日）
  x.per_customer_numerator_amt,                                       -- 客单价分子（日）
  x.per_customer_denominator_bitmap,                                  -- 客单价分母（日）
  x.etl_time                                                          -- ETL 加载时间
FROM (
SELECT
  u.seller_tenant_id,                                                 -- 卖家租户ID
  u.rfm_segment_code,                                                 -- RFM 分层
  BITMAP_UNION(u.pay_buyer_bitmap) AS pay_buyer_bitmap,               -- 支付买家数去重位图（日）
  BITMAP_UNION(u.repeat_buyer_bitmap) AS repeat_buyer_bitmap,         -- 老客买家数去重位图（日）
  SUM(u.repurchase_numerator_qty) AS repurchase_numerator_qty,        -- 复购率分子（日）
  BITMAP_UNION(u.repurchase_denominator_bitmap) AS repurchase_denominator_bitmap,  -- 复购率分母（日）
  SUM(u.per_customer_numerator_amt) AS per_customer_numerator_amt,    -- 客单价分子（日）
  BITMAP_UNION(u.per_customer_denominator_bitmap) AS per_customer_denominator_bitmap,  -- 客单价分母（日）
  CURRENT_TIMESTAMP() AS etl_time                                     -- ETL 加载时间
FROM (
  -- 来源：dws_cus_customer_lifetime_df
  SELECT
    seller_tenant_id AS seller_tenant_id,                             -- 卖家租户ID
    CAST(NULL AS STRING) AS rfm_segment_code,                         -- RFM 分层
    BITMAP_UNION(pay_buyer_bitmap) AS pay_buyer_bitmap,               -- 支付买家数去重位图（日）
    BITMAP_UNION(repeat_buyer_bitmap) AS repeat_buyer_bitmap,         -- 老客买家数去重位图（日）
    SUM(buyer_type) AS repurchase_numerator_qty,                      -- 复购率分子（日）
    BITMAP_UNION(pay_buyer_bitmap) AS repurchase_denominator_bitmap,  -- 复购率分母（日）
    SUM(pay_buyer_qty) AS per_customer_numerator_amt,                 -- 客单价分子（日）
    BITMAP_UNION(pay_buyer_bitmap) AS per_customer_denominator_bitmap  -- 客单价分母（日）
  FROM dws.dws_cus_customer_lifetime_df s                             -- 来源表「游客累计至今汇总」
  WHERE s.travel_date = '${bizdate}'                                  -- 只取当日分区
  GROUP BY seller_tenant_id                                           -- 按粒度键汇总
) u                                                                   -- 各来源合并后的明细
GROUP BY u.seller_tenant_id, u.rfm_segment_code                       -- 按粒度键汇总
) x                                                                   -- 汇总结果，外层再补维度名称
LEFT JOIN dim.dim_sup_tenant_zip d1 ON d1.tenant_id = x.seller_tenant_id AND d1.travel_date = '${bizdate}' AND d1.end_date = '9999-12-31';  -- 关联「租户（商户/供应商/分销商）维度」，取维度名称
