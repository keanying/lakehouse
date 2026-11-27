-- dws.dws_cus_tenant_growth_di  商户×注册渠道 游客增长日汇总
-- 粒度：travel_date × tenant_id × register_channel_id
-- 来源：dwd_cus_customer_register_di, dwd_cus_credential_register_di, dim_cus_customer_zip, dws_cus_customer_lifetime_df, dwd_cus_identity_bind_di
-- 生成方式：Spark SQL / Hive；字段 14 个：直接翻译 3 · 规则翻译 11 · 待确认 0
-- 多来源：每个来源先按粒度键预聚合，UNION ALL 后再汇总
-- 补 0 / 补空列：多来源 UNION ALL 时，某来源不产出的指标补 0 或空，外层按粒度 SUM 后即为各来源之和，不影响结果

WITH
src_customer_register AS (                                  -- 来源「游客注册明细」按粒度键预聚合
  SELECT
    register_tenant_id AS tenant_id,                        -- 租户ID
    register_channel_id AS register_channel_id,             -- 注册渠道ID
    COUNT(CASE WHEN customer_type = 'REAL' THEN customer_id END) AS new_customer_qty,  -- 新注册游客数｜口径：只计真人注册账号，剔除商户代下单占位买家（customer_type = TENANT_DEFAULT）
    NULL AS certified_customer_qty,                         -- 新增实名认证游客数：此来源不产出，补空
    NULL AS face_register_qty,                              -- 人脸注册数：此来源不产出，补空
    NULL AS first_pay_customer_qty,                         -- 首单买家数：此来源不产出，补空
    COUNT(CASE WHEN customer_type = 'REAL' AND fp.fp_first_pay_date = '${bizdate_dash}' THEN customer_id END) AS register_pay_customer_qty,  -- 注册当期下单新客数｜口径：当日注册且当日首次支付的真人游客（首次支付日取 dws_cus_customer_lifetime_df）
    NULL AS repeat_buyer_qty,                               -- 老客买家数：此来源不产出，补空
    CAST(NULL AS BINARY) AS repeat_buyer_bitmap,            -- 老客买家数去重位图：此来源不产出，补空
    CAST(NULL AS BINARY) AS pay_buyer_bitmap,               -- 支付买家数去重位图：此来源不产出，补空
    NULL AS identity_bind_qty                               -- 渠道身份绑定数：此来源不产出，补空
  FROM dwd.dwd_cus_customer_register_di s                   -- 来源表「游客注册明细」
  LEFT JOIN (SELECT buyer_customer_id AS fp_customer_id, MIN(first_pay_date) AS fp_first_pay_date FROM dws.dws_cus_customer_lifetime_df
             WHERE travel_date = '${bizdate}' GROUP BY buyer_customer_id) fp ON fp.fp_customer_id = s.customer_id  -- 只取当日分区
  WHERE s.travel_date = '${bizdate}'                        -- 只取当日分区
  GROUP BY register_tenant_id, register_channel_id          -- 按粒度键汇总
),
src_customer AS (                                           -- 来源「游客维度」按粒度键预聚合
  SELECT
    register_tenant_id AS tenant_id,                        -- 租户ID
    register_channel_id AS register_channel_id,             -- 注册渠道ID
    NULL AS new_customer_qty,                               -- 新注册游客数：此来源不产出，补空
    COUNT(CASE WHEN auth_status = 'PERSON_CERTIFIED'        -- 新增实名认证游客数｜口径：今日新开拉链版本为已实名、上一版本不是已实名
        AND start_date = '${bizdate_dash}'
          AND COALESCE(pv.pv_auth_status, '') <> 'PERSON_CERTIFIED' THEN customer_id END) AS certified_customer_qty,  -- 新增实名认证游客数
    NULL AS face_register_qty,                              -- 人脸注册数：此来源不产出，补空
    NULL AS first_pay_customer_qty,                         -- 首单买家数：此来源不产出，补空
    NULL AS register_pay_customer_qty,                      -- 注册当期下单新客数：此来源不产出，补空
    NULL AS repeat_buyer_qty,                               -- 老客买家数：此来源不产出，补空
    CAST(NULL AS BINARY) AS repeat_buyer_bitmap,            -- 老客买家数去重位图：此来源不产出，补空
    CAST(NULL AS BINARY) AS pay_buyer_bitmap,               -- 支付买家数去重位图：此来源不产出，补空
    NULL AS identity_bind_qty                               -- 渠道身份绑定数：此来源不产出，补空
  FROM dim.dim_cus_customer_zip s                           -- 来源表「游客维度」
  LEFT JOIN (SELECT customer_id AS pv_key, auth_status AS pv_auth_status FROM dim.dim_cus_customer_zip
             WHERE travel_date = '${bizdate}'               -- 只取当日分区
               AND end_date = '${bizdate_prev_dash}') pv ON pv.pv_key = s.customer_id
  WHERE s.travel_date = '${bizdate}' AND s.end_date = '9999-12-31'  -- 取当日分区里的拉链当前有效版本
  GROUP BY register_tenant_id, register_channel_id          -- 按粒度键汇总
),
src_credential_register AS (                                -- 来源「个人凭证注册明细」按粒度键预聚合
  SELECT
    register_tenant_id AS tenant_id,                        -- 租户ID
    CAST(NULL AS BIGINT) AS register_channel_id,            -- 注册渠道ID：此来源不产出，补空
    NULL AS new_customer_qty,                               -- 新注册游客数：此来源不产出，补空
    NULL AS certified_customer_qty,                         -- 新增实名认证游客数：此来源不产出，补空
    COUNT(CASE WHEN credential_type='FACE' THEN credential_no END) AS face_register_qty,  -- 人脸注册数
    NULL AS first_pay_customer_qty,                         -- 首单买家数：此来源不产出，补空
    NULL AS register_pay_customer_qty,                      -- 注册当期下单新客数：此来源不产出，补空
    NULL AS repeat_buyer_qty,                               -- 老客买家数：此来源不产出，补空
    CAST(NULL AS BINARY) AS repeat_buyer_bitmap,            -- 老客买家数去重位图：此来源不产出，补空
    CAST(NULL AS BINARY) AS pay_buyer_bitmap,               -- 支付买家数去重位图：此来源不产出，补空
    NULL AS identity_bind_qty                               -- 渠道身份绑定数：此来源不产出，补空
  FROM dwd.dwd_cus_credential_register_di s                 -- 来源表「个人凭证注册明细」
  WHERE s.travel_date = '${bizdate}'                        -- 只取当日分区
  GROUP BY register_tenant_id                               -- 按粒度键汇总
),
src_customer_lifetime AS (                                  -- 来源「游客累计至今汇总」按粒度键预聚合
  SELECT
    seller_tenant_id AS tenant_id,                          -- 租户ID
    CAST(NULL AS BIGINT) AS register_channel_id,            -- 注册渠道ID：此来源不产出，补空
    NULL AS new_customer_qty,                               -- 新注册游客数：此来源不产出，补空
    NULL AS certified_customer_qty,                         -- 新增实名认证游客数：此来源不产出，补空
    NULL AS face_register_qty,                              -- 人脸注册数：此来源不产出，补空
    COUNT(CASE WHEN DATE_FORMAT(first_pay_date, 'yyyyMMdd') = '${bizdate}' THEN buyer_customer_id END) AS first_pay_customer_qty,  -- 首单买家数
    NULL AS register_pay_customer_qty,                      -- 注册当期下单新客数：此来源不产出，补空
    COUNT(CASE WHEN DATE_FORMAT(first_pay_date, 'yyyyMMdd') < '${bizdate}' THEN buyer_customer_id END) AS repeat_buyer_qty,  -- 老客买家数
    BITMAP_UNION(TO_BITMAP(CASE WHEN DATE_FORMAT(first_pay_date, 'yyyyMMdd') < '${bizdate}' THEN buyer_customer_id END)) AS repeat_buyer_bitmap,  -- 老客买家数去重位图
    BITMAP_UNION(pay_buyer_bitmap) AS pay_buyer_bitmap,     -- 支付买家数去重位图
    NULL AS identity_bind_qty                               -- 渠道身份绑定数：此来源不产出，补空
  FROM dws.dws_cus_customer_lifetime_df s                   -- 来源表「游客累计至今汇总」
  WHERE s.travel_date = '${bizdate}'                        -- 只取当日分区
  GROUP BY seller_tenant_id                                 -- 按粒度键汇总
),
src_identity_bind AS (                                      -- 来源「渠道身份绑定明细」按粒度键预聚合
  SELECT
    bind_tenant_id AS tenant_id,                            -- 租户ID
    bind_channel_id AS register_channel_id,                 -- 注册渠道ID
    NULL AS new_customer_qty,                               -- 新注册游客数：此来源不产出，补空
    NULL AS certified_customer_qty,                         -- 新增实名认证游客数：此来源不产出，补空
    NULL AS face_register_qty,                              -- 人脸注册数：此来源不产出，补空
    NULL AS first_pay_customer_qty,                         -- 首单买家数：此来源不产出，补空
    NULL AS register_pay_customer_qty,                      -- 注册当期下单新客数：此来源不产出，补空
    NULL AS repeat_buyer_qty,                               -- 老客买家数：此来源不产出，补空
    CAST(NULL AS BINARY) AS repeat_buyer_bitmap,            -- 老客买家数去重位图：此来源不产出，补空
    CAST(NULL AS BINARY) AS pay_buyer_bitmap,               -- 支付买家数去重位图：此来源不产出，补空
    COUNT(1) AS identity_bind_qty                           -- 渠道身份绑定数
  FROM dwd.dwd_cus_identity_bind_di s                       -- 来源表「渠道身份绑定明细」
  WHERE s.travel_date = '${bizdate}'                        -- 只取当日分区
  GROUP BY bind_tenant_id, bind_channel_id                  -- 按粒度键汇总
),
all_src AS (                                                -- 各来源字段已对齐，UNION ALL 合并（比多表 FULL JOIN 少 shuffle）
  SELECT * FROM src_customer_register
  UNION ALL
  SELECT * FROM src_customer
  UNION ALL
  SELECT * FROM src_credential_register
  UNION ALL
  SELECT * FROM src_customer_lifetime
  UNION ALL
  SELECT * FROM src_identity_bind
)
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
FROM all_src u
GROUP BY u.tenant_id, u.register_channel_id;                -- 按粒度键汇总
