-- ads.ads_cus_customer_growth_di  游客增长
-- 粒度：travel_date × tenant_id × register_channel_id
-- 来源：dws_cus_tenant_growth_di
-- 生成方式：Spark SQL / Hive；字段 16 个：直接翻译 16 · 规则翻译 0 · 待确认 0

INSERT OVERWRITE TABLE ads.ads_cus_customer_growth_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  x.tenant_id,                                                            -- 租户ID
  x.register_channel_id,                                                  -- 注册渠道ID
  d1.tenant_name AS tenant_name,                                          -- 租户名称
  d2.channel_name AS register_channel_name,                               -- 注册渠道名称
  x.new_customer_qty,                                                     -- 新注册游客数（日）
  x.first_pay_customer_qty,                                               -- 首单买家数（日）
  x.face_register_qty,                                                    -- 人脸注册数（日）
  x.certified_customer_qty,                                               -- 新增实名认证游客数（日）
  x.register_pay_conversion_numerator_qty,                                -- 注册下单转化率分子（日）
  x.register_pay_conversion_denominator_qty,                              -- 注册下单转化率分母（日）
  x.new_buyer_share_numerator_qty,                                        -- 新客占比分子（日）
  x.new_buyer_share_denominator_bitmap,                                   -- 新客占比分母（日）
  x.face_register_numerator_qty,                                          -- 人脸注册率分子（日）
  x.face_register_denominator_qty,                                        -- 人脸注册率分母（日）
  x.repeat_buyer_bitmap,                                                  -- 老客买家数去重位图（日）
  x.identity_bind_qty,                                                    -- 渠道身份绑定数（日）
  x.etl_time                                                              -- ETL 加载时间
FROM (
SELECT
  u.tenant_id,                                                            -- 租户ID
  u.register_channel_id,                                                  -- 注册渠道ID
  SUM(u.new_customer_qty) AS new_customer_qty,                            -- 新注册游客数（日）
  SUM(u.first_pay_customer_qty) AS first_pay_customer_qty,                -- 首单买家数（日）
  SUM(u.face_register_qty) AS face_register_qty,                          -- 人脸注册数（日）
  SUM(u.certified_customer_qty) AS certified_customer_qty,                -- 新增实名认证游客数（日）
  SUM(u.register_pay_conversion_numerator_qty) AS register_pay_conversion_numerator_qty,  -- 注册下单转化率分子（日）
  SUM(u.register_pay_conversion_denominator_qty) AS register_pay_conversion_denominator_qty,  -- 注册下单转化率分母（日）
  SUM(u.new_buyer_share_numerator_qty) AS new_buyer_share_numerator_qty,  -- 新客占比分子（日）
  BITMAP_UNION(u.new_buyer_share_denominator_bitmap) AS new_buyer_share_denominator_bitmap,  -- 新客占比分母（日）
  SUM(u.face_register_numerator_qty) AS face_register_numerator_qty,      -- 人脸注册率分子（日）
  SUM(u.face_register_denominator_qty) AS face_register_denominator_qty,  -- 人脸注册率分母（日）
  BITMAP_UNION(u.repeat_buyer_bitmap) AS repeat_buyer_bitmap,             -- 老客买家数去重位图（日）
  SUM(u.identity_bind_qty) AS identity_bind_qty,                          -- 渠道身份绑定数（日）
  CURRENT_TIMESTAMP() AS etl_time                                         -- ETL 加载时间
FROM (
  -- 来源：dws_cus_tenant_growth_di
  SELECT
    tenant_id AS tenant_id,                                               -- 租户ID
    register_channel_id AS register_channel_id,                           -- 注册渠道ID
    SUM(new_customer_qty) AS new_customer_qty,                            -- 新注册游客数（日）
    SUM(first_pay_customer_qty) AS first_pay_customer_qty,                -- 首单买家数（日）
    SUM(face_register_qty) AS face_register_qty,                          -- 人脸注册数（日）
    SUM(certified_customer_qty) AS certified_customer_qty,                -- 新增实名认证游客数（日）
    SUM(register_pay_customer_qty) AS register_pay_conversion_numerator_qty,  -- 注册下单转化率分子（日）
    SUM(new_customer_qty) AS register_pay_conversion_denominator_qty,     -- 注册下单转化率分母（日）
    SUM(first_pay_customer_qty) AS new_buyer_share_numerator_qty,         -- 新客占比分子（日）
    BITMAP_UNION(pay_buyer_bitmap) AS new_buyer_share_denominator_bitmap,  -- 新客占比分母（日）
    SUM(face_register_qty) AS face_register_numerator_qty,                -- 人脸注册率分子（日）
    SUM(new_customer_qty) AS face_register_denominator_qty,               -- 人脸注册率分母（日）
    BITMAP_UNION(repeat_buyer_bitmap) AS repeat_buyer_bitmap,             -- 老客买家数去重位图（日）
    SUM(identity_bind_qty) AS identity_bind_qty                           -- 渠道身份绑定数（日）
  FROM dws.dws_cus_tenant_growth_di s                                     -- 来源表「商户×注册渠道 游客增长日汇总」
  WHERE s.travel_date = '${bizdate}'                                      -- 只取当日分区
  GROUP BY tenant_id, register_channel_id                                 -- 按粒度键汇总
) u                                                                       -- 各来源合并后的明细
GROUP BY u.tenant_id, u.register_channel_id                               -- 按粒度键汇总
) x                                                                       -- 汇总结果，外层再补维度名称
LEFT JOIN dim.dim_sup_tenant_zip d1 ON d1.tenant_id = x.tenant_id AND d1.travel_date = '${bizdate}' AND d1.end_date = '9999-12-31'  -- 关联「租户（商户/供应商/分销商）维度」，取维度名称
LEFT JOIN dim.dim_trf_channel_df d2 ON d2.channel_id = x.register_channel_id AND d2.travel_date = '${bizdate}';  -- 关联「渠道/接入端维度」，取维度名称
