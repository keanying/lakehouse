-- dws.dws_cus_customer_lifetime_df  游客累计至今汇总
-- 粒度：travel_date（快照日）× buyer_customer_id × seller_tenant_id
-- 来源：dws_cus_customer_trade_di
-- 生成方式：Spark SQL / Hive；字段 13 个：直接翻译 2 · 规则翻译 0 · 待确认 11
-- 多来源：每个来源表按粒度键先汇总，UNION ALL 后再合并；快照/累计表：增量来源取截至统计日的全部分区
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT OVERWRITE TABLE dws.dws_cus_customer_lifetime_df PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  u.buyer_customer_id,                           -- 买家游客ID
  u.seller_tenant_id,                            -- 卖家租户ID
  MIN(u.first_pay_date) AS first_pay_date,       -- 首次支付日期
  MAX(u.last_pay_date) AS last_pay_date,         -- 最近支付日期
  NULL AS total_pay_order_qty,                   -- 累计支付单数｜待确认：sum(pay_order_qty) 全历史
  NULL AS total_pay_amt,                         -- 累计支付金额｜待确认：sum(pay_amt) 全历史
  NULL AS pay_order_30d_qty,                     -- 近30天支付单数｜待确认：sum(pay_order_qty) 近30天
  NULL AS pay_30d_amt,                           -- 近30天支付金额｜待确认：sum(pay_amt) 近30天
  NULL AS buyer_type,                            -- 买家类型｜待确认：case when pay_order_30d_qty>=2 then 1 else 0 end
  SUM(u.pay_buyer_qty) AS pay_buyer_qty,         -- 支付买家数
  BITMAP_UNION(u.pay_buyer_bitmap) AS pay_buyer_bitmap,  -- 支付买家数去重位图
  SUM(u.repeat_buyer_qty) AS repeat_buyer_qty,   -- 老客买家数
  BITMAP_UNION(u.repeat_buyer_bitmap) AS repeat_buyer_bitmap,  -- 老客买家数去重位图
  CURRENT_TIMESTAMP() AS etl_time                -- ETL 加载时间
FROM (
  -- 来源：dws_cus_customer_trade_di
  SELECT
    buyer_customer_id AS buyer_customer_id,      -- 买家游客ID
    seller_tenant_id AS seller_tenant_id,        -- 卖家租户ID
    NULL AS first_pay_date,                      -- 首次支付日期｜待确认：min(pay_date)
    NULL AS last_pay_date,                       -- 最近支付日期｜待确认：max(pay_date)
    NULL AS pay_buyer_qty,                       -- 支付买家数
    CAST(NULL AS BINARY) AS pay_buyer_bitmap,    -- 支付买家数去重位图
    NULL AS repeat_buyer_qty,                    -- 老客买家数
    CAST(NULL AS BINARY) AS repeat_buyer_bitmap  -- 老客买家数去重位图
  FROM dws.dws_cus_customer_trade_di s           -- 来源表「游客×商户 交易日汇总」
  WHERE s.travel_date <= '${bizdate}'            -- 累计口径：取截至统计日的全部分区
  GROUP BY buyer_customer_id, seller_tenant_id   -- 按粒度键汇总
  UNION ALL                                      -- 合并各来源
  -- 来源：dwd_ord_order_di
  SELECT
    buyer_customer_id AS buyer_customer_id,      -- 买家游客ID
    seller_tenant_id AS seller_tenant_id,        -- 卖家租户ID
    NULL AS first_pay_date,                      -- 首次支付日期
    NULL AS last_pay_date,                       -- 最近支付日期
    COUNT(DISTINCT CASE WHEN 1 = 1 THEN buyer_customer_id END) AS pay_buyer_qty,  -- 支付买家数｜待确认：buyer_customer_id>0 and kind='REAL'
    BITMAP_UNION(TO_BITMAP(CASE WHEN 1 = 1 THEN buyer_customer_id END)) AS pay_buyer_bitmap,  -- 支付买家数去重位图｜待确认：buyer_customer_id>0 and kind='REAL'
    NULL AS repeat_buyer_qty,                    -- 老客买家数
    CAST(NULL AS BINARY) AS repeat_buyer_bitmap  -- 老客买家数去重位图
  FROM dwd.dwd_ord_order_di s                    -- 来源表「子单明细」
  WHERE s.travel_date <= '${bizdate}'            -- 累计口径：取截至统计日的全部分区
  GROUP BY buyer_customer_id, seller_tenant_id   -- 按粒度键汇总
  UNION ALL                                      -- 合并各来源
  -- 来源：dws_cus_customer_lifetime_df
  SELECT
    buyer_customer_id AS buyer_customer_id,      -- 买家游客ID
    seller_tenant_id AS seller_tenant_id,        -- 卖家租户ID
    NULL AS first_pay_date,                      -- 首次支付日期
    NULL AS last_pay_date,                       -- 最近支付日期
    NULL AS pay_buyer_qty,                       -- 支付买家数
    CAST(NULL AS BINARY) AS pay_buyer_bitmap,    -- 支付买家数去重位图
    NULL AS repeat_buyer_qty,                    -- 老客买家数｜待确认：引用本表（count(buyer) where first_pay_date < 周期起始），需拆成两步计算
    NULL AS repeat_buyer_bitmap                  -- 老客买家数去重位图｜待确认：引用本表（count(buyer) where first_pay_date < 周期起始），需拆成两步计算
  FROM dws.dws_cus_customer_lifetime_df s        -- 来源表「游客累计至今汇总」
  WHERE s.travel_date = '${bizdate}'             -- 只取当日分区
  GROUP BY buyer_customer_id, seller_tenant_id   -- 按粒度键汇总
) u                                              -- 各来源合并后的明细
GROUP BY u.buyer_customer_id, u.seller_tenant_id;  -- 按粒度键汇总
