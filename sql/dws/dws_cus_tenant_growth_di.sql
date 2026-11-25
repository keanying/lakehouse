-- dws.dws_cus_tenant_growth_di  商户×注册渠道 游客增长日汇总
-- 粒度：travel_date × tenant_id × register_channel_id
-- 来源：dwd_cus_customer_register_di, dwd_cus_credential_register_di, dim_cus_customer_zip, dws_cus_customer_lifetime_df, dwd_cus_identity_bind_di
-- 生成方式：Spark SQL / Hive；字段 14 个：直接翻译 3 · 规则翻译 6 · 待确认 5
-- 多来源：每个来源表按粒度键先汇总，UNION ALL 后再合并
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT OVERWRITE TABLE dws.dws_cus_tenant_growth_di PARTITION (travel_date = '${bizdate}')
SELECT
  u.tenant_id,
  u.register_channel_id,
  SUM(u.new_customer_qty) AS new_customer_qty,
  SUM(u.certified_customer_qty) AS certified_customer_qty,
  SUM(u.face_register_qty) AS face_register_qty,
  SUM(u.first_pay_customer_qty) AS first_pay_customer_qty,
  SUM(u.register_pay_customer_qty) AS register_pay_customer_qty,
  SUM(u.repeat_buyer_qty) AS repeat_buyer_qty,
  BITMAP_UNION(u.repeat_buyer_bitmap) AS repeat_buyer_bitmap,
  BITMAP_COUNT(BITMAP_UNION(u.pay_buyer_bitmap)) AS pay_buyer_qty,
  BITMAP_UNION(u.pay_buyer_bitmap) AS pay_buyer_bitmap,
  SUM(u.identity_bind_qty) AS identity_bind_qty,
  CURRENT_TIMESTAMP() AS etl_time
FROM (
  -- 来源：dwd_cus_customer_register_di
  SELECT
    register_tenant_id AS tenant_id,
    register_channel_id AS register_channel_id,
    COUNT(CASE WHEN 1 = 1 THEN customer_id END) AS new_customer_qty,  -- 待确认：kind='REAL'
    NULL AS certified_customer_qty,
    NULL AS face_register_qty,
    NULL AS first_pay_customer_qty,
    COUNT(CASE WHEN 1 = 1 THEN customer_id END) AS register_pay_customer_qty,  -- 待确认：register_date and first_pay_date in 周期
    NULL AS repeat_buyer_qty,
    CAST(NULL AS BINARY) AS repeat_buyer_bitmap,
    CAST(NULL AS BINARY) AS pay_buyer_bitmap,
    NULL AS identity_bind_qty
  FROM dwd.dwd_cus_customer_register_di s
  WHERE s.travel_date = '${bizdate}'
  GROUP BY register_tenant_id, register_channel_id
  UNION ALL
  -- 来源：dim_cus_customer_zip
  SELECT
    register_tenant_id AS tenant_id,
    register_channel_id AS register_channel_id,
    NULL AS new_customer_qty,
    COUNT(CASE WHEN 1 = 1 THEN customer_id END) AS certified_customer_qty,  -- 待确认：auth_status 变为 PERSON_CERTIFIED
    NULL AS face_register_qty,
    NULL AS first_pay_customer_qty,
    NULL AS register_pay_customer_qty,
    NULL AS repeat_buyer_qty,
    CAST(NULL AS BINARY) AS repeat_buyer_bitmap,
    CAST(NULL AS BINARY) AS pay_buyer_bitmap,
    NULL AS identity_bind_qty
  FROM dim.dim_cus_customer_zip s
  WHERE s.travel_date = '${bizdate}' AND s.end_date = '9999-12-31'
  GROUP BY register_tenant_id, register_channel_id
  UNION ALL
  -- 来源：dwd_cus_credential_register_di
  SELECT
    register_tenant_id AS tenant_id,
    CAST(NULL AS BIGINT) AS register_channel_id,
    NULL AS new_customer_qty,
    NULL AS certified_customer_qty,
    COUNT(CASE WHEN credential_type='FACE' THEN credential_no END) AS face_register_qty,
    NULL AS first_pay_customer_qty,
    NULL AS register_pay_customer_qty,
    NULL AS repeat_buyer_qty,
    CAST(NULL AS BINARY) AS repeat_buyer_bitmap,
    CAST(NULL AS BINARY) AS pay_buyer_bitmap,
    NULL AS identity_bind_qty
  FROM dwd.dwd_cus_credential_register_di s
  WHERE s.travel_date = '${bizdate}'
  GROUP BY register_tenant_id
  UNION ALL
  -- 来源：dws_cus_customer_lifetime_df
  SELECT
    seller_tenant_id AS tenant_id,
    CAST(NULL AS BIGINT) AS register_channel_id,
    NULL AS new_customer_qty,
    NULL AS certified_customer_qty,
    NULL AS face_register_qty,
    COUNT(CASE WHEN DATE_FORMAT(first_pay_date, 'yyyyMMdd') = '${bizdate}' THEN buyer_customer_id END) AS first_pay_customer_qty,
    NULL AS register_pay_customer_qty,
    COUNT(CASE WHEN DATE_FORMAT(first_pay_date, 'yyyyMMdd') < '${bizdate}' THEN buyer_customer_id END) AS repeat_buyer_qty,
    BITMAP_UNION(TO_BITMAP(CASE WHEN DATE_FORMAT(first_pay_date, 'yyyyMMdd') < '${bizdate}' THEN buyer_customer_id END)) AS repeat_buyer_bitmap,
    BITMAP_UNION(pay_buyer_bitmap) AS pay_buyer_bitmap,
    NULL AS identity_bind_qty
  FROM dws.dws_cus_customer_lifetime_df s
  WHERE s.travel_date = '${bizdate}'
  GROUP BY seller_tenant_id
  UNION ALL
  -- 来源：dwd_cus_identity_bind_di
  SELECT
    bind_tenant_id AS tenant_id,
    bind_channel_id AS register_channel_id,
    NULL AS new_customer_qty,
    NULL AS certified_customer_qty,
    NULL AS face_register_qty,
    NULL AS first_pay_customer_qty,
    NULL AS register_pay_customer_qty,
    NULL AS repeat_buyer_qty,
    CAST(NULL AS BINARY) AS repeat_buyer_bitmap,
    CAST(NULL AS BINARY) AS pay_buyer_bitmap,
    COUNT(1) AS identity_bind_qty
  FROM dwd.dwd_cus_identity_bind_di s
  WHERE s.travel_date = '${bizdate}'
  GROUP BY bind_tenant_id, bind_channel_id
) u
GROUP BY u.tenant_id, u.register_channel_id;
