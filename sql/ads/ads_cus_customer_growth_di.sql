-- ads.ads_cus_customer_growth_di  游客增长
-- 粒度：travel_date × tenant_id × register_channel_id
-- 来源：dws_cus_tenant_growth_di
-- 生成方式：Spark SQL / Hive；字段 16 个：直接翻译 16 · 规则翻译 0 · 待确认 0
-- 来源先按粒度键预聚合

WITH
src_tenant_growth AS (                                      -- 来源「商户×注册渠道 游客增长日汇总」按粒度键预聚合
  SELECT
    tenant_id AS tenant_id,                                 -- 租户ID
    register_channel_id AS register_channel_id,             -- 注册渠道ID
    SUM(new_customer_qty) AS new_customer_qty,              -- 新注册游客数（日）
    SUM(first_pay_customer_qty) AS first_pay_customer_qty,  -- 首单买家数（日）
    SUM(face_register_qty) AS face_register_qty,            -- 人脸注册数（日）
    SUM(certified_customer_qty) AS certified_customer_qty,  -- 新增实名认证游客数（日）
    SUM(register_pay_customer_qty) AS register_pay_conversion_numerator_qty,  -- 注册下单转化率分子（日）
    SUM(new_customer_qty) AS register_pay_conversion_denominator_qty,  -- 注册下单转化率分母（日）
    SUM(first_pay_customer_qty) AS new_buyer_share_numerator_qty,  -- 新客占比分子（日）
    BITMAP_UNION(pay_buyer_bitmap) AS new_buyer_share_denominator_bitmap,  -- 新客占比分母（日）
    SUM(face_register_qty) AS face_register_numerator_qty,  -- 人脸注册率分子（日）
    SUM(new_customer_qty) AS face_register_denominator_qty,  -- 人脸注册率分母（日）
    BITMAP_UNION(repeat_buyer_bitmap) AS repeat_buyer_bitmap,  -- 老客买家数去重位图（日）
    SUM(identity_bind_qty) AS identity_bind_qty             -- 渠道身份绑定数（日）
  FROM dws.dws_cus_tenant_growth_di s                       -- 来源表「商户×注册渠道 游客增长日汇总」
  WHERE s.travel_date = '${bizdate}'                        -- 只取当日分区
  GROUP BY tenant_id, register_channel_id                   -- 按粒度键汇总
),
merged AS (                                                 -- 按粒度键汇总，计算派生指标
  SELECT
    u.tenant_id,                                            -- 租户ID
    u.register_channel_id,                                  -- 注册渠道ID
    u.new_customer_qty,                                     -- 新注册游客数（日）
    u.first_pay_customer_qty,                               -- 首单买家数（日）
    u.face_register_qty,                                    -- 人脸注册数（日）
    u.certified_customer_qty,                               -- 新增实名认证游客数（日）
    u.register_pay_conversion_numerator_qty,                -- 注册下单转化率分子（日）
    u.register_pay_conversion_denominator_qty,              -- 注册下单转化率分母（日）
    u.new_buyer_share_numerator_qty,                        -- 新客占比分子（日）
    u.new_buyer_share_denominator_bitmap,                   -- 新客占比分母（日）
    u.face_register_numerator_qty,                          -- 人脸注册率分子（日）
    u.face_register_denominator_qty,                        -- 人脸注册率分母（日）
    u.repeat_buyer_bitmap,                                  -- 老客买家数去重位图（日）
    u.identity_bind_qty,                                    -- 渠道身份绑定数（日）
    CURRENT_TIMESTAMP() AS etl_time                         -- ETL 加载时间
  FROM src_tenant_growth u
),
tenant_cur AS (                                             -- 「租户（商户/供应商/分销商）维度」当前有效版本，只取名称类字段
  SELECT tenant_id, tenant_name
  FROM dim.dim_sup_tenant_zip
  WHERE travel_date = '${bizdate}' AND end_date = '9999-12-31'  -- 取当日分区里的拉链当前有效版本
),
channel_dim AS (                                            -- 「渠道/接入端维度」当日数据，只取名称类字段
  SELECT channel_id, channel_name
  FROM dim.dim_trf_channel_df
  WHERE travel_date = '${bizdate}'                          -- 只取当日分区
)
INSERT OVERWRITE TABLE ads.ads_cus_customer_growth_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT  /*+ BROADCAST(channel_dim) */
  merged.tenant_id,                                         -- 租户ID
  merged.register_channel_id,                               -- 注册渠道ID
  tenant_cur.tenant_name AS tenant_name,                    -- 租户名称
  channel_dim.channel_name AS register_channel_name,        -- 注册渠道名称
  merged.new_customer_qty,                                  -- 新注册游客数（日）
  merged.first_pay_customer_qty,                            -- 首单买家数（日）
  merged.face_register_qty,                                 -- 人脸注册数（日）
  merged.certified_customer_qty,                            -- 新增实名认证游客数（日）
  merged.register_pay_conversion_numerator_qty,             -- 注册下单转化率分子（日）
  merged.register_pay_conversion_denominator_qty,           -- 注册下单转化率分母（日）
  merged.new_buyer_share_numerator_qty,                     -- 新客占比分子（日）
  merged.new_buyer_share_denominator_bitmap,                -- 新客占比分母（日）
  merged.face_register_numerator_qty,                       -- 人脸注册率分子（日）
  merged.face_register_denominator_qty,                     -- 人脸注册率分母（日）
  merged.repeat_buyer_bitmap,                               -- 老客买家数去重位图（日）
  merged.identity_bind_qty,                                 -- 渠道身份绑定数（日）
  merged.etl_time                                           -- ETL 加载时间
FROM merged
LEFT JOIN tenant_cur                                        -- 关联「租户（商户/供应商/分销商）维度」，补 tenant_name
  ON tenant_cur.tenant_id = merged.tenant_id                -- 按 tenant_id 关联
LEFT JOIN channel_dim                                       -- 关联「渠道/接入端维度」，补 register_channel_name
  ON channel_dim.channel_id = merged.register_channel_id;   -- 按 register_channel_id→channel_id 关联
