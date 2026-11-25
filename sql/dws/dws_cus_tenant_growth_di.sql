-- dws.dws_cus_tenant_growth_di  商户×注册渠道 游客增长日汇总
-- 粒度：travel_date × tenant_id × register_channel_id
-- 来源：dwd_cus_customer_register_di, dwd_cus_credential_register_di, dim_cus_customer_zip, dws_cus_customer_lifetime_df, dwd_cus_identity_bind_di
-- 生成方式：Spark SQL / Hive；字段 14 个：直接翻译 3 · 规则翻译 6 · 待确认 5
-- 多来源：每个来源表按粒度键先汇总，UNION ALL 后再合并
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT OVERWRITE TABLE dws.dws_cus_tenant_growth_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  u.tenant_id,                                              -- 租户ID
  u.register_channel_id,                                    -- 注册渠道ID
  SUM(u.new_customer_qty) AS new_customer_qty,              -- 新注册游客数
  SUM(u.certified_customer_qty) AS certified_customer_qty,  -- 新增实名认证游客数
  SUM(u.face_register_qty) AS face_register_qty,            -- 人脸注册数
  SUM(u.first_pay_customer_qty) AS first_pay_customer_qty,  -- 首单买家数
  SUM(u.register_pay_customer_qty) AS register_pay_customer_qty,  -- 注册当期下单新客数
  SUM(u.repeat_buyer_qty) AS repeat_buyer_qty,              -- 老客买家数
  BITMAP_UNION(u.repeat_buyer_bitmap) AS repeat_buyer_bitmap,  -- 老客买家数去重位图
  BITMAP_COUNT(BITMAP_UNION(u.pay_buyer_bitmap)) AS pay_buyer_qty,  -- 支付买家数
  BITMAP_UNION(u.pay_buyer_bitmap) AS pay_buyer_bitmap,     -- 支付买家数去重位图
  SUM(u.identity_bind_qty) AS identity_bind_qty,            -- 渠道身份绑定数
  CURRENT_TIMESTAMP() AS etl_time                           -- ETL 加载时间
FROM (
  -- 来源：dwd_cus_customer_register_di
  SELECT
    register_tenant_id AS tenant_id,                        -- 租户ID
    register_channel_id AS register_channel_id,             -- 注册渠道ID
    COUNT(CASE WHEN 1 = 1 THEN customer_id END) AS new_customer_qty,  -- 新注册游客数｜待确认：kind='REAL'
    NULL AS certified_customer_qty,                         -- 新增实名认证游客数
    NULL AS face_register_qty,                              -- 人脸注册数
    NULL AS first_pay_customer_qty,                         -- 首单买家数
    COUNT(CASE WHEN 1 = 1 THEN customer_id END) AS register_pay_customer_qty,  -- 注册当期下单新客数｜待确认：register_date and first_pay_date in 周期
    NULL AS repeat_buyer_qty,                               -- 老客买家数
    CAST(NULL AS BINARY) AS repeat_buyer_bitmap,            -- 老客买家数去重位图
    CAST(NULL AS BINARY) AS pay_buyer_bitmap,               -- 支付买家数去重位图
    NULL AS identity_bind_qty                               -- 渠道身份绑定数
  FROM dwd.dwd_cus_customer_register_di s                   -- 来源表「游客注册明细」
  WHERE s.travel_date = '${bizdate}'                        -- 只取当日分区
  GROUP BY register_tenant_id, register_channel_id          -- 按粒度键汇总
  UNION ALL                                                 -- 合并各来源
  -- 来源：dim_cus_customer_zip
  SELECT
    register_tenant_id AS tenant_id,                        -- 租户ID
    register_channel_id AS register_channel_id,             -- 注册渠道ID
    NULL AS new_customer_qty,                               -- 新注册游客数
    COUNT(CASE WHEN 1 = 1 THEN customer_id END) AS certified_customer_qty,  -- 新增实名认证游客数｜待确认：auth_status 变为 PERSON_CERTIFIED
    NULL AS face_register_qty,                              -- 人脸注册数
    NULL AS first_pay_customer_qty,                         -- 首单买家数
    NULL AS register_pay_customer_qty,                      -- 注册当期下单新客数
    NULL AS repeat_buyer_qty,                               -- 老客买家数
    CAST(NULL AS BINARY) AS repeat_buyer_bitmap,            -- 老客买家数去重位图
    CAST(NULL AS BINARY) AS pay_buyer_bitmap,               -- 支付买家数去重位图
    NULL AS identity_bind_qty                               -- 渠道身份绑定数
  FROM dim.dim_cus_customer_zip s                           -- 来源表「游客维度」
  WHERE s.travel_date = '${bizdate}' AND s.end_date = '9999-12-31'  -- 取当日分区里的拉链当前有效版本
  GROUP BY register_tenant_id, register_channel_id          -- 按粒度键汇总
  UNION ALL                                                 -- 合并各来源
  -- 来源：dwd_cus_credential_register_di
  SELECT
    register_tenant_id AS tenant_id,                        -- 租户ID
    CAST(NULL AS BIGINT) AS register_channel_id,            -- 注册渠道ID
    NULL AS new_customer_qty,                               -- 新注册游客数
    NULL AS certified_customer_qty,                         -- 新增实名认证游客数
    COUNT(CASE WHEN credential_type='FACE' THEN credential_no END) AS face_register_qty,  -- 人脸注册数
    NULL AS first_pay_customer_qty,                         -- 首单买家数
    NULL AS register_pay_customer_qty,                      -- 注册当期下单新客数
    NULL AS repeat_buyer_qty,                               -- 老客买家数
    CAST(NULL AS BINARY) AS repeat_buyer_bitmap,            -- 老客买家数去重位图
    CAST(NULL AS BINARY) AS pay_buyer_bitmap,               -- 支付买家数去重位图
    NULL AS identity_bind_qty                               -- 渠道身份绑定数
  FROM dwd.dwd_cus_credential_register_di s                 -- 来源表「个人凭证注册明细」
  WHERE s.travel_date = '${bizdate}'                        -- 只取当日分区
  GROUP BY register_tenant_id                               -- 按粒度键汇总
  UNION ALL                                                 -- 合并各来源
  -- 来源：dws_cus_customer_lifetime_df
  SELECT
    seller_tenant_id AS tenant_id,                          -- 租户ID
    CAST(NULL AS BIGINT) AS register_channel_id,            -- 注册渠道ID
    NULL AS new_customer_qty,                               -- 新注册游客数
    NULL AS certified_customer_qty,                         -- 新增实名认证游客数
    NULL AS face_register_qty,                              -- 人脸注册数
    COUNT(CASE WHEN DATE_FORMAT(first_pay_date, 'yyyyMMdd') = '${bizdate}' THEN buyer_customer_id END) AS first_pay_customer_qty,  -- 首单买家数
    NULL AS register_pay_customer_qty,                      -- 注册当期下单新客数
    COUNT(CASE WHEN DATE_FORMAT(first_pay_date, 'yyyyMMdd') < '${bizdate}' THEN buyer_customer_id END) AS repeat_buyer_qty,  -- 老客买家数
    BITMAP_UNION(TO_BITMAP(CASE WHEN DATE_FORMAT(first_pay_date, 'yyyyMMdd') < '${bizdate}' THEN buyer_customer_id END)) AS repeat_buyer_bitmap,  -- 老客买家数去重位图
    BITMAP_UNION(pay_buyer_bitmap) AS pay_buyer_bitmap,     -- 支付买家数去重位图
    NULL AS identity_bind_qty                               -- 渠道身份绑定数
  FROM dws.dws_cus_customer_lifetime_df s                   -- 来源表「游客累计至今汇总」
  WHERE s.travel_date = '${bizdate}'                        -- 只取当日分区
  GROUP BY seller_tenant_id                                 -- 按粒度键汇总
  UNION ALL                                                 -- 合并各来源
  -- 来源：dwd_cus_identity_bind_di
  SELECT
    bind_tenant_id AS tenant_id,                            -- 租户ID
    bind_channel_id AS register_channel_id,                 -- 注册渠道ID
    NULL AS new_customer_qty,                               -- 新注册游客数
    NULL AS certified_customer_qty,                         -- 新增实名认证游客数
    NULL AS face_register_qty,                              -- 人脸注册数
    NULL AS first_pay_customer_qty,                         -- 首单买家数
    NULL AS register_pay_customer_qty,                      -- 注册当期下单新客数
    NULL AS repeat_buyer_qty,                               -- 老客买家数
    CAST(NULL AS BINARY) AS repeat_buyer_bitmap,            -- 老客买家数去重位图
    CAST(NULL AS BINARY) AS pay_buyer_bitmap,               -- 支付买家数去重位图
    COUNT(1) AS identity_bind_qty                           -- 渠道身份绑定数
  FROM dwd.dwd_cus_identity_bind_di s                       -- 来源表「渠道身份绑定明细」
  WHERE s.travel_date = '${bizdate}'                        -- 只取当日分区
  GROUP BY bind_tenant_id, bind_channel_id                  -- 按粒度键汇总
) u                                                         -- 各来源合并后的明细
GROUP BY u.tenant_id, u.register_channel_id;                -- 按粒度键汇总
