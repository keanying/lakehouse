-- dws.dws_sup_tenant_trade_di  商户经营日汇总
-- 粒度：travel_date × seller_tenant_id
-- 来源：dws_ord_tenant_sku_channel_trade_di, dws_ord_tenant_sku_verify_di, dws_ord_tenant_refund_di, dwd_cus_customer_register_di, dws_cus_customer_lifetime_df
-- 生成方式：Spark SQL / Hive；字段 21 个：直接翻译 2 · 规则翻译 17 · 待确认 2
-- 多来源：每个来源表按粒度键先汇总，UNION ALL 后再合并
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT OVERWRITE TABLE dws.dws_sup_tenant_trade_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  u.seller_tenant_id,                          -- 卖家租户ID
  SUM(u.pay_order_qty) AS pay_order_qty,       -- 支付子单数
  SUM(u.pay_ticket_qty) AS pay_ticket_qty,     -- 支付票数
  SUM(u.pay_amt) AS pay_amt,                   -- 支付金额（GMV）
  SUM(u.refund_amt) AS refund_amt,             -- 退款金额
  SUM(u.pay_amt) - SUM(u.refund_amt) AS net_pay_amt,  -- 净成交金额
  SUM(u.verify_ticket_qty) AS verify_ticket_qty,  -- 核销票数
  SUM(u.verify_amt) AS verify_amt,             -- 核销金额
  BITMAP_COUNT(BITMAP_UNION(u.pay_buyer_bitmap)) AS pay_buyer_qty,  -- 支付买家数
  BITMAP_UNION(u.pay_buyer_bitmap) AS pay_buyer_bitmap,  -- 支付买家数去重位图
  SUM(u.new_customer_qty) AS new_customer_qty,  -- 新注册游客数
  SUM(u.on_sale_sku_qty) AS on_sale_sku_qty,   -- 在售SKU数
  SUM(u.cost_amt) AS cost_amt,                 -- 成本金额
  SUM(u.sold_sku_qty) AS sold_sku_qty,         -- 动销SKU数
  BITMAP_UNION(u.sold_sku_bitmap) AS sold_sku_bitmap,  -- 动销SKU数去重位图
  SUM(u.first_pay_customer_qty) AS first_pay_customer_qty,  -- 首单买家数
  SUM(u.pay_order_group_qty) AS pay_order_group_qty,  -- 支付聚合单数
  SUM(u.refund_ticket_qty) AS refund_ticket_qty,  -- 退款票数
  SUM(u.order_qty) AS order_qty,               -- 下单子单数
  SUM(u.pay_order_qty) * 100 / NULLIF(SUM(u.order_qty), 0) AS pay_conversion_rate,  -- 下单支付转化率
  CURRENT_TIMESTAMP() AS etl_time              -- ETL 加载时间
FROM (
  -- 来源：dws_ord_tenant_sku_channel_trade_di
  SELECT
    seller_tenant_id AS seller_tenant_id,      -- 卖家租户ID
    SUM(pay_order_qty) AS pay_order_qty,       -- 支付子单数
    SUM(pay_ticket_qty) AS pay_ticket_qty,     -- 支付票数
    SUM(pay_amt) AS pay_amt,                   -- 支付金额（GMV）
    NULL AS refund_amt,                        -- 退款金额
    NULL AS verify_ticket_qty,                 -- 核销票数
    NULL AS verify_amt,                        -- 核销金额
    BITMAP_UNION(pay_buyer_bitmap) AS pay_buyer_bitmap,  -- 支付买家数去重位图
    NULL AS new_customer_qty,                  -- 新注册游客数
    NULL AS on_sale_sku_qty,                   -- 在售SKU数
    SUM(cost_amt) AS cost_amt,                 -- 成本金额
    COUNT(DISTINCT CASE WHEN pay_amt>0 THEN sku_id END) AS sold_sku_qty,  -- 动销SKU数
    BITMAP_UNION(TO_BITMAP(CASE WHEN pay_amt>0 THEN sku_id END)) AS sold_sku_bitmap,  -- 动销SKU数去重位图
    NULL AS first_pay_customer_qty,            -- 首单买家数
    SUM(pay_order_group_qty) AS pay_order_group_qty,  -- 支付聚合单数
    NULL AS refund_ticket_qty,                 -- 退款票数
    SUM(order_qty) AS order_qty                -- 下单子单数
  FROM dws.dws_ord_tenant_sku_channel_trade_di s  -- 来源表「商户×SKU×渠道 交易日汇总」
  WHERE s.travel_date = '${bizdate}'           -- 只取当日分区
  GROUP BY seller_tenant_id                    -- 按粒度键汇总
  UNION ALL                                    -- 合并各来源
  -- 来源：dws_ord_tenant_refund_di
  SELECT
    seller_tenant_id AS seller_tenant_id,      -- 卖家租户ID
    NULL AS pay_order_qty,                     -- 支付子单数
    NULL AS pay_ticket_qty,                    -- 支付票数
    NULL AS pay_amt,                           -- 支付金额（GMV）
    SUM(refund_amt) AS refund_amt,             -- 退款金额
    NULL AS verify_ticket_qty,                 -- 核销票数
    NULL AS verify_amt,                        -- 核销金额
    CAST(NULL AS BINARY) AS pay_buyer_bitmap,  -- 支付买家数去重位图
    NULL AS new_customer_qty,                  -- 新注册游客数
    NULL AS on_sale_sku_qty,                   -- 在售SKU数
    NULL AS cost_amt,                          -- 成本金额
    NULL AS sold_sku_qty,                      -- 动销SKU数
    CAST(NULL AS BINARY) AS sold_sku_bitmap,   -- 动销SKU数去重位图
    NULL AS first_pay_customer_qty,            -- 首单买家数
    NULL AS pay_order_group_qty,               -- 支付聚合单数
    SUM(refund_ticket_qty) AS refund_ticket_qty,  -- 退款票数
    NULL AS order_qty                          -- 下单子单数
  FROM dws.dws_ord_tenant_refund_di s          -- 来源表「商户×SKU 退款日汇总」
  WHERE s.travel_date = '${bizdate}'           -- 只取当日分区
  GROUP BY seller_tenant_id                    -- 按粒度键汇总
  UNION ALL                                    -- 合并各来源
  -- 来源：dws_ord_tenant_sku_verify_di
  SELECT
    seller_tenant_id AS seller_tenant_id,      -- 卖家租户ID
    NULL AS pay_order_qty,                     -- 支付子单数
    NULL AS pay_ticket_qty,                    -- 支付票数
    NULL AS pay_amt,                           -- 支付金额（GMV）
    NULL AS refund_amt,                        -- 退款金额
    SUM(verify_ticket_qty) AS verify_ticket_qty,  -- 核销票数
    SUM(verify_amt) AS verify_amt,             -- 核销金额
    CAST(NULL AS BINARY) AS pay_buyer_bitmap,  -- 支付买家数去重位图
    NULL AS new_customer_qty,                  -- 新注册游客数
    NULL AS on_sale_sku_qty,                   -- 在售SKU数
    NULL AS cost_amt,                          -- 成本金额
    NULL AS sold_sku_qty,                      -- 动销SKU数
    CAST(NULL AS BINARY) AS sold_sku_bitmap,   -- 动销SKU数去重位图
    NULL AS first_pay_customer_qty,            -- 首单买家数
    NULL AS pay_order_group_qty,               -- 支付聚合单数
    NULL AS refund_ticket_qty,                 -- 退款票数
    NULL AS order_qty                          -- 下单子单数
  FROM dws.dws_ord_tenant_sku_verify_di s      -- 来源表「商户×SKU×核销点 核销日汇总」
  WHERE s.travel_date = '${bizdate}'           -- 只取当日分区
  GROUP BY seller_tenant_id                    -- 按粒度键汇总
  UNION ALL                                    -- 合并各来源
  -- 来源：dwd_cus_customer_register_di
  SELECT
    CAST(NULL AS BIGINT) AS seller_tenant_id,  -- 卖家租户ID
    NULL AS pay_order_qty,                     -- 支付子单数
    NULL AS pay_ticket_qty,                    -- 支付票数
    NULL AS pay_amt,                           -- 支付金额（GMV）
    NULL AS refund_amt,                        -- 退款金额
    NULL AS verify_ticket_qty,                 -- 核销票数
    NULL AS verify_amt,                        -- 核销金额
    CAST(NULL AS BINARY) AS pay_buyer_bitmap,  -- 支付买家数去重位图
    COUNT(CASE WHEN 1 = 1 THEN customer_id END) AS new_customer_qty,  -- 新注册游客数｜待确认：kind='REAL'
    NULL AS on_sale_sku_qty,                   -- 在售SKU数
    NULL AS cost_amt,                          -- 成本金额
    NULL AS sold_sku_qty,                      -- 动销SKU数
    CAST(NULL AS BINARY) AS sold_sku_bitmap,   -- 动销SKU数去重位图
    NULL AS first_pay_customer_qty,            -- 首单买家数
    NULL AS pay_order_group_qty,               -- 支付聚合单数
    NULL AS refund_ticket_qty,                 -- 退款票数
    NULL AS order_qty                          -- 下单子单数
  FROM dwd.dwd_cus_customer_register_di s      -- 来源表「游客注册明细」
  WHERE s.travel_date = '${bizdate}'           -- 只取当日分区
  UNION ALL                                    -- 合并各来源
  -- 来源：dim_prd_sku_zip
  SELECT
    tenant_id AS seller_tenant_id,             -- 卖家租户ID
    NULL AS pay_order_qty,                     -- 支付子单数
    NULL AS pay_ticket_qty,                    -- 支付票数
    NULL AS pay_amt,                           -- 支付金额（GMV）
    NULL AS refund_amt,                        -- 退款金额
    NULL AS verify_ticket_qty,                 -- 核销票数
    NULL AS verify_amt,                        -- 核销金额
    CAST(NULL AS BINARY) AS pay_buyer_bitmap,  -- 支付买家数去重位图
    NULL AS new_customer_qty,                  -- 新注册游客数
    COUNT(CASE WHEN sku_status='PUBLISHED' THEN sku_id END) AS on_sale_sku_qty,  -- 在售SKU数
    NULL AS cost_amt,                          -- 成本金额
    NULL AS sold_sku_qty,                      -- 动销SKU数
    CAST(NULL AS BINARY) AS sold_sku_bitmap,   -- 动销SKU数去重位图
    NULL AS first_pay_customer_qty,            -- 首单买家数
    NULL AS pay_order_group_qty,               -- 支付聚合单数
    NULL AS refund_ticket_qty,                 -- 退款票数
    NULL AS order_qty                          -- 下单子单数
  FROM dim.dim_prd_sku_zip s                   -- 来源表「SKU维度」
  WHERE s.travel_date = '${bizdate}' AND s.end_date = '9999-12-31'  -- 取当日分区里的拉链当前有效版本
  GROUP BY tenant_id                           -- 按粒度键汇总
  UNION ALL                                    -- 合并各来源
  -- 来源：dws_cus_customer_lifetime_df
  SELECT
    seller_tenant_id AS seller_tenant_id,      -- 卖家租户ID
    NULL AS pay_order_qty,                     -- 支付子单数
    NULL AS pay_ticket_qty,                    -- 支付票数
    NULL AS pay_amt,                           -- 支付金额（GMV）
    NULL AS refund_amt,                        -- 退款金额
    NULL AS verify_ticket_qty,                 -- 核销票数
    NULL AS verify_amt,                        -- 核销金额
    CAST(NULL AS BINARY) AS pay_buyer_bitmap,  -- 支付买家数去重位图
    NULL AS new_customer_qty,                  -- 新注册游客数
    NULL AS on_sale_sku_qty,                   -- 在售SKU数
    NULL AS cost_amt,                          -- 成本金额
    NULL AS sold_sku_qty,                      -- 动销SKU数
    CAST(NULL AS BINARY) AS sold_sku_bitmap,   -- 动销SKU数去重位图
    COUNT(CASE WHEN DATE_FORMAT(first_pay_date, 'yyyyMMdd') = '${bizdate}' THEN buyer_customer_id END) AS first_pay_customer_qty,  -- 首单买家数
    NULL AS pay_order_group_qty,               -- 支付聚合单数
    NULL AS refund_ticket_qty,                 -- 退款票数
    NULL AS order_qty                          -- 下单子单数
  FROM dws.dws_cus_customer_lifetime_df s      -- 来源表「游客累计至今汇总」
  WHERE s.travel_date = '${bizdate}'           -- 只取当日分区
  GROUP BY seller_tenant_id                    -- 按粒度键汇总
) u                                            -- 各来源合并后的明细
GROUP BY u.seller_tenant_id;                   -- 按粒度键汇总
