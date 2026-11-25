-- dws.dws_sup_tenant_lifetime_df  商户累计至今汇总
-- 粒度：travel_date（快照日）× seller_tenant_id
-- 来源：dws_sup_tenant_trade_di
-- 生成方式：Spark SQL / Hive；字段 8 个：直接翻译 1 · 规则翻译 2 · 待确认 5
-- 多来源：每个来源表按粒度键先汇总，UNION ALL 后再合并；快照/累计表：增量来源取截至统计日的全部分区
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT OVERWRITE TABLE dws.dws_sup_tenant_lifetime_df PARTITION (travel_date = '${bizdate}')
SELECT
  u.seller_tenant_id,
  MIN(u.first_pay_date) AS first_pay_date,
  MAX(u.last_pay_date) AS last_pay_date,
  SUM(u.active_tenant_qty) AS active_tenant_qty,
  BITMAP_UNION(u.active_tenant_bitmap) AS active_tenant_bitmap,
  NULL AS total_pay_amt,  -- 待确认：sum(pay_amt) 全历史
  NULL AS pay_30d_amt,  -- 待确认：sum(pay_amt) 近30天
  NULL AS active_day_30d_qty,  -- 待确认：count(distinct travel_date) where pay_amt>0 近30天
  CURRENT_TIMESTAMP() AS etl_time
FROM (
  -- 来源：dws_cus_customer_trade_di
  SELECT
    seller_tenant_id AS seller_tenant_id,
    NULL AS first_pay_date,  -- 待确认：min(pay_date)
    NULL AS last_pay_date,  -- 待确认：max(pay_date)
    NULL AS active_tenant_qty,
    CAST(NULL AS BINARY) AS active_tenant_bitmap
  FROM dws.dws_cus_customer_trade_di s
  WHERE s.travel_date <= '${bizdate}'
  GROUP BY seller_tenant_id
  UNION ALL
  -- 来源：dws_sup_tenant_trade_di
  SELECT
    seller_tenant_id AS seller_tenant_id,
    NULL AS first_pay_date,
    NULL AS last_pay_date,
    COUNT(DISTINCT CASE WHEN pay_amt>0 THEN seller_tenant_id END) AS active_tenant_qty,
    BITMAP_UNION(TO_BITMAP(CASE WHEN pay_amt>0 THEN seller_tenant_id END)) AS active_tenant_bitmap
  FROM dws.dws_sup_tenant_trade_di s
  WHERE s.travel_date <= '${bizdate}'
  GROUP BY seller_tenant_id
) u
GROUP BY u.seller_tenant_id;
