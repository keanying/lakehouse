-- dws.dws_cus_customer_lifetime_df  游客累计至今汇总
-- 粒度：travel_date（快照日）× buyer_customer_id × seller_tenant_id
-- 来源：dws_cus_customer_trade_di
-- 生成方式：Spark SQL / Hive；字段 13 个：直接翻译 2 · 规则翻译 0 · 待确认 11
-- 多来源：每个来源表按粒度键先汇总，UNION ALL 后再合并；快照/累计表：增量来源取截至统计日的全部分区
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT OVERWRITE TABLE dws.dws_cus_customer_lifetime_df PARTITION (travel_date = '${bizdate}')
SELECT
  u.buyer_customer_id,
  u.seller_tenant_id,
  MIN(u.first_pay_date) AS first_pay_date,
  MAX(u.last_pay_date) AS last_pay_date,
  SUM(u.pay_buyer_qty) AS pay_buyer_qty,
  BITMAP_UNION(u.pay_buyer_bitmap) AS pay_buyer_bitmap,
  SUM(u.repeat_buyer_qty) AS repeat_buyer_qty,
  BITMAP_UNION(u.repeat_buyer_bitmap) AS repeat_buyer_bitmap,
  NULL AS total_pay_order_qty,  -- 待确认：sum(pay_order_qty) 全历史
  NULL AS total_pay_amt,  -- 待确认：sum(pay_amt) 全历史
  NULL AS pay_order_30d_qty,  -- 待确认：sum(pay_order_qty) 近30天
  NULL AS pay_30d_amt,  -- 待确认：sum(pay_amt) 近30天
  NULL AS buyer_type,  -- 待确认：case when pay_order_30d_qty>=2 then 1 else 0 end
  CURRENT_TIMESTAMP() AS etl_time
FROM (
  -- 来源：dws_cus_customer_trade_di
  SELECT
    buyer_customer_id AS buyer_customer_id,
    seller_tenant_id AS seller_tenant_id,
    NULL AS first_pay_date,  -- 待确认：min(pay_date)
    NULL AS last_pay_date,  -- 待确认：max(pay_date)
    NULL AS pay_buyer_qty,
    CAST(NULL AS BINARY) AS pay_buyer_bitmap,
    NULL AS repeat_buyer_qty,
    CAST(NULL AS BINARY) AS repeat_buyer_bitmap
  FROM dws.dws_cus_customer_trade_di s
  WHERE s.travel_date <= '${bizdate}'
  GROUP BY buyer_customer_id, seller_tenant_id
  UNION ALL
  -- 来源：dwd_ord_order_di
  SELECT
    buyer_customer_id AS buyer_customer_id,
    seller_tenant_id AS seller_tenant_id,
    NULL AS first_pay_date,
    NULL AS last_pay_date,
    COUNT(DISTINCT CASE WHEN 1 = 1 THEN buyer_customer_id END) AS pay_buyer_qty,  -- 待确认：buyer_customer_id>0 and kind='REAL'
    BITMAP_UNION(TO_BITMAP(CASE WHEN 1 = 1 THEN buyer_customer_id END)) AS pay_buyer_bitmap,  -- 待确认：buyer_customer_id>0 and kind='REAL'
    NULL AS repeat_buyer_qty,
    CAST(NULL AS BINARY) AS repeat_buyer_bitmap
  FROM dwd.dwd_ord_order_di s
  WHERE s.travel_date <= '${bizdate}'
  GROUP BY buyer_customer_id, seller_tenant_id
  UNION ALL
  -- 来源：dws_cus_customer_lifetime_df
  SELECT
    buyer_customer_id AS buyer_customer_id,
    seller_tenant_id AS seller_tenant_id,
    NULL AS first_pay_date,
    NULL AS last_pay_date,
    NULL AS pay_buyer_qty,
    CAST(NULL AS BINARY) AS pay_buyer_bitmap,
    NULL AS repeat_buyer_qty,  -- 待确认：引用本表（count(buyer) where first_pay_date < 周期起始），需拆成两步计算
    NULL AS repeat_buyer_bitmap  -- 待确认：引用本表（count(buyer) where first_pay_date < 周期起始），需拆成两步计算
  FROM dws.dws_cus_customer_lifetime_df s
  WHERE s.travel_date = '${bizdate}'
  GROUP BY buyer_customer_id, seller_tenant_id
) u
GROUP BY u.buyer_customer_id, u.seller_tenant_id;
