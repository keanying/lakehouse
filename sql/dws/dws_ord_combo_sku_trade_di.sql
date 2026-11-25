-- dws.dws_ord_combo_sku_trade_di  套票×子项 交易日汇总
-- 粒度：travel_date × combo_sku_id × sub_sku_id × sub_seller_tenant_id
-- 来源：dwd_ord_order_di, dwd_ord_refund_ticket_di, dwd_ord_verify_di
-- 生成方式：Spark SQL / Hive；字段 10 个：直接翻译 3 · 规则翻译 4 · 待确认 3
-- 多来源：每个来源表按粒度键先汇总，UNION ALL 后再合并
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT OVERWRITE TABLE dws.dws_ord_combo_sku_trade_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  u.combo_sku_id,                                 -- 套票主 SKU ID
  u.sub_sku_id,                                   -- 套票子项 SKU ID
  u.sub_seller_tenant_id,                         -- 套票子项卖家租户ID
  SUM(u.combo_order_qty) AS combo_order_qty,      -- 套票主单数
  SUM(u.pay_order_qty) AS pay_order_qty,          -- 支付子单数
  SUM(u.pay_amt) AS pay_amt,                      -- 支付金额（GMV）
  SUM(u.refund_ticket_qty) AS refund_ticket_qty,  -- 退款票数
  SUM(u.refund_amt) AS refund_amt,                -- 退款金额
  SUM(u.verify_ticket_qty) AS verify_ticket_qty,  -- 核销票数
  SUM(u.pay_ticket_qty) AS pay_ticket_qty,        -- 支付票数
  CURRENT_TIMESTAMP() AS etl_time                 -- ETL 加载时间
FROM (
  -- 来源：dwd_ord_order_di
  SELECT
    sku_id AS combo_sku_id,                       -- 套票主 SKU ID
    sku_id AS sub_sku_id,                         -- 套票子项 SKU ID
    seller_tenant_id AS sub_seller_tenant_id,     -- 套票子项卖家租户ID
    COUNT(CASE WHEN 1 = 1 THEN order_no END) AS combo_order_qty,  -- 套票主单数｜待确认：combo_flag=1
    NULL AS pay_order_qty,                        -- 支付子单数
    SUM(CASE WHEN pay_time IS NOT NULL THEN unit_price_amt*buy_ticket_qty END) AS pay_amt,  -- 支付金额（GMV）
    NULL AS refund_ticket_qty,                    -- 退款票数
    NULL AS refund_amt,                           -- 退款金额
    NULL AS verify_ticket_qty,                    -- 核销票数
    SUM(CASE WHEN pay_time IS NOT NULL THEN buy_ticket_qty END) AS pay_ticket_qty  -- 支付票数
  FROM dwd.dwd_ord_order_di s                     -- 来源表「子单明细」
  WHERE s.travel_date = '${bizdate}'              -- 只取当日分区
  GROUP BY sku_id, sku_id, seller_tenant_id       -- 按粒度键汇总
  UNION ALL                                       -- 合并各来源
  -- 来源：dwd_ord_order_status_log_di
  SELECT
    sku_id AS combo_sku_id,                       -- 套票主 SKU ID
    sku_id AS sub_sku_id,                         -- 套票子项 SKU ID
    seller_tenant_id AS sub_seller_tenant_id,     -- 套票子项卖家租户ID
    NULL AS combo_order_qty,                      -- 套票主单数
    COUNT(DISTINCT CASE WHEN after_status='PAID' THEN order_no END) AS pay_order_qty,  -- 支付子单数
    NULL AS pay_amt,                              -- 支付金额（GMV）
    NULL AS refund_ticket_qty,                    -- 退款票数
    NULL AS refund_amt,                           -- 退款金额
    NULL AS verify_ticket_qty,                    -- 核销票数
    NULL AS pay_ticket_qty                        -- 支付票数
  FROM dwd.dwd_ord_order_status_log_di s          -- 来源表「子单状态流转明细」
  WHERE s.travel_date = '${bizdate}'              -- 只取当日分区
  GROUP BY sku_id, sku_id, seller_tenant_id       -- 按粒度键汇总
  UNION ALL                                       -- 合并各来源
  -- 来源：dwd_ord_refund_ticket_di
  SELECT
    sku_id AS combo_sku_id,                       -- 套票主 SKU ID
    sku_id AS sub_sku_id,                         -- 套票子项 SKU ID
    seller_tenant_id AS sub_seller_tenant_id,     -- 套票子项卖家租户ID
    NULL AS combo_order_qty,                      -- 套票主单数
    NULL AS pay_order_qty,                        -- 支付子单数
    NULL AS pay_amt,                              -- 支付金额（GMV）
    COUNT(DISTINCT CASE WHEN 1 = 1 THEN ticket_no END) AS refund_ticket_qty,  -- 退款票数｜待确认：of completed refunds
    SUM(CASE WHEN refund_status = 'COMPLETED' THEN refund_amt END) AS refund_amt,  -- 退款金额
    NULL AS verify_ticket_qty,                    -- 核销票数
    NULL AS pay_ticket_qty                        -- 支付票数
  FROM dwd.dwd_ord_refund_ticket_di s             -- 来源表「退款票明细」
  WHERE s.travel_date = '${bizdate}'              -- 只取当日分区
  GROUP BY sku_id, sku_id, seller_tenant_id       -- 按粒度键汇总
  UNION ALL                                       -- 合并各来源
  -- 来源：dwd_ord_verify_di
  SELECT
    sku_id AS combo_sku_id,                       -- 套票主 SKU ID
    sku_id AS sub_sku_id,                         -- 套票子项 SKU ID
    seller_tenant_id AS sub_seller_tenant_id,     -- 套票子项卖家租户ID
    NULL AS combo_order_qty,                      -- 套票主单数
    NULL AS pay_order_qty,                        -- 支付子单数
    NULL AS pay_amt,                              -- 支付金额（GMV）
    NULL AS refund_ticket_qty,                    -- 退款票数
    NULL AS refund_amt,                           -- 退款金额
    COUNT(DISTINCT CASE WHEN 1 = 1 THEN ticket_no END) AS verify_ticket_qty,  -- 核销票数｜待确认：verify_result='SUCCESS'
    NULL AS pay_ticket_qty                        -- 支付票数
  FROM dwd.dwd_ord_verify_di s                    -- 来源表「核销明细（权益级）」
  WHERE s.travel_date = '${bizdate}'              -- 只取当日分区
  GROUP BY sku_id, sku_id, seller_tenant_id       -- 按粒度键汇总
) u                                               -- 各来源合并后的明细
GROUP BY u.combo_sku_id, u.sub_sku_id, u.sub_seller_tenant_id;  -- 按粒度键汇总
