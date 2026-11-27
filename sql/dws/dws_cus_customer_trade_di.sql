-- dws.dws_cus_customer_trade_di  游客×商户 交易日汇总
-- 粒度：travel_date × buyer_customer_id × seller_tenant_id
-- 来源：dwd_ord_order_di, dwd_ord_refund_ticket_di, dwd_ord_verify_di
-- 生成方式：Spark SQL / Hive；字段 10 个：直接翻译 2 · 规则翻译 8 · 待确认 0
-- 多来源：每个来源先按粒度键预聚合，UNION ALL 后再汇总

WITH
src_order_status_log AS (                                                         -- 来源「子单状态流转明细」按粒度键预聚合
  SELECT
    CAST(NULL AS BIGINT) AS buyer_customer_id,
    seller_tenant_id AS seller_tenant_id,                                         -- 卖家租户ID
    COUNT(DISTINCT CASE WHEN after_status='PAID' THEN order_no END) AS pay_order_qty,  -- 支付子单数
    NULL AS pay_ticket_qty,
    NULL AS pay_amt,
    NULL AS refund_amt,
    NULL AS verify_ticket_qty
  FROM dwd.dwd_ord_order_status_log_di s                                          -- 来源表「子单状态流转明细」
  WHERE s.travel_date = '${bizdate}'                                              -- 只取当日分区
  GROUP BY seller_tenant_id                                                       -- 按粒度键汇总
),
src_order AS (                                                                    -- 来源「子单明细」按粒度键预聚合
  SELECT
    buyer_customer_id AS buyer_customer_id,                                       -- 买家游客ID
    seller_tenant_id AS seller_tenant_id,                                         -- 卖家租户ID
    NULL AS pay_order_qty,
    SUM(CASE WHEN pay_time IS NOT NULL THEN buy_ticket_qty END) AS pay_ticket_qty,  -- 支付票数
    SUM(CASE WHEN pay_time IS NOT NULL THEN unit_price_amt*buy_ticket_qty END) AS pay_amt,  -- 支付金额（GMV）
    NULL AS refund_amt,
    NULL AS verify_ticket_qty
  FROM dwd.dwd_ord_order_di s                                                     -- 来源表「子单明细」
  WHERE s.travel_date = '${bizdate}'                                              -- 只取当日分区
  GROUP BY buyer_customer_id, seller_tenant_id                                    -- 按粒度键汇总
),
src_refund_ticket AS (                                                            -- 来源「退款票明细」按粒度键预聚合
  SELECT
    CAST(NULL AS BIGINT) AS buyer_customer_id,
    seller_tenant_id AS seller_tenant_id,                                         -- 卖家租户ID
    NULL AS pay_order_qty,
    NULL AS pay_ticket_qty,
    NULL AS pay_amt,
    SUM(CASE WHEN refund_status = 'COMPLETED' THEN refund_amt END) AS refund_amt,  -- 退款金额
    NULL AS verify_ticket_qty
  FROM dwd.dwd_ord_refund_ticket_di s                                             -- 来源表「退款票明细」
  WHERE s.travel_date = '${bizdate}'                                              -- 只取当日分区
  GROUP BY seller_tenant_id                                                       -- 按粒度键汇总
),
src_verify AS (                                                                   -- 来源「核销明细（权益级）」按粒度键预聚合
  SELECT
    CAST(NULL AS BIGINT) AS buyer_customer_id,
    seller_tenant_id AS seller_tenant_id,                                         -- 卖家租户ID
    NULL AS pay_order_qty,
    NULL AS pay_ticket_qty,
    NULL AS pay_amt,
    NULL AS refund_amt,
    COUNT(DISTINCT CASE WHEN verify_result_type='SUCCESS' THEN ticket_no END) AS verify_ticket_qty  -- 核销票数
  FROM dwd.dwd_ord_verify_di s                                                    -- 来源表「核销明细（权益级）」
  WHERE s.travel_date = '${bizdate}'                                              -- 只取当日分区
  GROUP BY seller_tenant_id                                                       -- 按粒度键汇总
),
all_src AS (                                                                      -- 各来源字段已对齐，UNION ALL 合并（比多表 FULL JOIN 少 shuffle）
  SELECT * FROM src_order_status_log
  UNION ALL
  SELECT * FROM src_order
  UNION ALL
  SELECT * FROM src_refund_ticket
  UNION ALL
  SELECT * FROM src_verify
)
INSERT OVERWRITE TABLE dws.dws_cus_customer_trade_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  u.buyer_customer_id,                                                            -- 买家游客ID
  u.seller_tenant_id,                                                             -- 卖家租户ID
  SUM(u.pay_order_qty) AS pay_order_qty,                                          -- 支付子单数
  SUM(u.pay_ticket_qty) AS pay_ticket_qty,                                        -- 支付票数
  SUM(u.pay_amt) AS pay_amt,                                                      -- 支付金额（GMV）
  SUM(u.refund_amt) AS refund_amt,                                                -- 退款金额
  SUM(u.verify_ticket_qty) AS verify_ticket_qty,                                  -- 核销票数
  CURRENT_TIMESTAMP() AS etl_time                                                 -- ETL 加载时间
FROM all_src u
GROUP BY u.buyer_customer_id, u.seller_tenant_id;                                 -- 按粒度键汇总
