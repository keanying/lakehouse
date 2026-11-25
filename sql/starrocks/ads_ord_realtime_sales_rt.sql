-- ads.ads_ord_realtime_sales_rt  实时销售看板（对应 DP08）
-- 粒度：seller_tenant_id × 窗口
-- 来源：dws_ord_tenant_sku_trade_rt
-- 生成方式：StarRocks 异步物化视图（每分钟刷新）；字段 24 个：直接翻译 6 · 规则翻译 18 · 待确认 0

CREATE MATERIALIZED VIEW IF NOT EXISTS ads.ads_ord_realtime_sales_rt  -- 异步物化视图，StarRocks 定时刷新
REFRESH ASYNC EVERY (INTERVAL 1 MINUTE)
AS
SELECT
  x.travel_date,                                  -- 数据日期
  x.window_start_time,                            -- 窗口开始时间
  x.window_end_time,                              -- 窗口结束时间
  x.seller_tenant_id,                             -- 卖家租户ID
  d1.tenant_name AS seller_tenant_name,           -- 卖家租户名称
  x.pay_today_amt,                                -- 今日实时支付金额（GMV）
  x.pay_1h_amt,                                   -- 近1小时支付金额（GMV）
  x.pay_5m_amt,                                   -- 近5分钟支付金额（GMV）
  x.pay_order_today_qty,                          -- 今日实时支付子单数
  x.pay_order_1h_qty,                             -- 近1小时支付子单数
  x.pay_order_5m_qty,                             -- 近5分钟支付子单数
  x.pay_ticket_today_qty,                         -- 今日实时支付票数
  x.pay_ticket_1h_qty,                            -- 近1小时支付票数
  x.pay_ticket_5m_qty,                            -- 近5分钟支付票数
  x.pay_buyer_today_qty,                          -- 今日实时支付买家数
  x.pay_buyer_1h_qty,                             -- 近1小时支付买家数
  x.pay_buyer_5m_qty,                             -- 近5分钟支付买家数
  x.refund_today_amt,                             -- 今日实时退款金额
  x.refund_1h_amt,                                -- 近1小时退款金额
  x.refund_5m_amt,                                -- 近5分钟退款金额
  x.avg_ticket_price_today_amt,                   -- 今日实时平均票价
  x.avg_ticket_price_1h_amt,                      -- 近1小时平均票价
  x.avg_ticket_price_5m_amt,                      -- 近5分钟平均票价
  x.update_time                                   -- 最近一次写入时间
FROM (
SELECT
  u.travel_date,                                  -- 数据日期
  u.window_start_time,                            -- 窗口开始时间
  u.window_end_time,                              -- 窗口结束时间
  u.seller_tenant_id,                             -- 卖家租户ID
  SUM(u.pay_amt) AS pay_today_amt,                -- 今日实时支付金额（GMV）
  SUM(u.pay_amt_1) AS pay_1h_amt,                 -- 近1小时支付金额（GMV）
  SUM(u.pay_amt_2) AS pay_5m_amt,                 -- 近5分钟支付金额（GMV）
  SUM(u.pay_order_qty) AS pay_order_today_qty,    -- 今日实时支付子单数
  SUM(u.pay_order_qty_1) AS pay_order_1h_qty,     -- 近1小时支付子单数
  SUM(u.pay_order_qty_2) AS pay_order_5m_qty,     -- 近5分钟支付子单数
  SUM(u.pay_ticket_qty) AS pay_ticket_today_qty,  -- 今日实时支付票数
  SUM(u.pay_ticket_qty_1) AS pay_ticket_1h_qty,   -- 近1小时支付票数
  SUM(u.pay_ticket_qty_2) AS pay_ticket_5m_qty,   -- 近5分钟支付票数
  SUM(u.pay_buyer_qty) AS pay_buyer_today_qty,    -- 今日实时支付买家数
  SUM(u.pay_buyer_qty_1) AS pay_buyer_1h_qty,     -- 近1小时支付买家数
  SUM(u.pay_buyer_qty_2) AS pay_buyer_5m_qty,     -- 近5分钟支付买家数
  SUM(u.refund_amt) AS refund_today_amt,          -- 今日实时退款金额
  SUM(u.refund_amt_1) AS refund_1h_amt,           -- 近1小时退款金额
  SUM(u.refund_amt_2) AS refund_5m_amt,           -- 近5分钟退款金额
  SUM(u.pay_amt) / NULLIF(SUM(u.pay_ticket_qty), 0) AS avg_ticket_price_today_amt,  -- 今日实时平均票价
  SUM(u.pay_amt_1) / NULLIF(SUM(u.pay_ticket_qty_1), 0) AS avg_ticket_price_1h_amt,  -- 近1小时平均票价
  SUM(u.pay_amt_2) / NULLIF(SUM(u.pay_ticket_qty_2), 0) AS avg_ticket_price_5m_amt,  -- 近5分钟平均票价
  NOW() AS update_time                            -- 最近一次写入时间
FROM (
  -- 来源：dws_ord_tenant_sku_trade_rt
  SELECT
    s.travel_date AS travel_date,                 -- 数据日期
    s.window_start_time AS window_start_time,     -- 窗口开始时间
    s.window_end_time AS window_end_time,         -- 窗口结束时间
    s.seller_tenant_id AS seller_tenant_id,       -- 卖家租户ID
    SUM(s.pay_amt) AS pay_amt,
    SUM(CASE WHEN s.window_start_time >= NOW() - INTERVAL 1 HOUR THEN s.pay_amt END) AS pay_amt_1,
    SUM(CASE WHEN s.window_start_time >= NOW() - INTERVAL 5 MINUTE THEN s.pay_amt END) AS pay_amt_2,
    SUM(s.pay_order_qty) AS pay_order_qty,
    SUM(CASE WHEN s.window_start_time >= NOW() - INTERVAL 1 HOUR THEN s.pay_order_qty END) AS pay_order_qty_1,
    SUM(CASE WHEN s.window_start_time >= NOW() - INTERVAL 5 MINUTE THEN s.pay_order_qty END) AS pay_order_qty_2,
    SUM(s.pay_ticket_qty) AS pay_ticket_qty,
    SUM(CASE WHEN s.window_start_time >= NOW() - INTERVAL 1 HOUR THEN s.pay_ticket_qty END) AS pay_ticket_qty_1,
    SUM(CASE WHEN s.window_start_time >= NOW() - INTERVAL 5 MINUTE THEN s.pay_ticket_qty END) AS pay_ticket_qty_2,
    SUM(s.pay_buyer_qty) AS pay_buyer_qty,
    SUM(CASE WHEN s.window_start_time >= NOW() - INTERVAL 1 HOUR THEN s.pay_buyer_qty END) AS pay_buyer_qty_1,
    SUM(CASE WHEN s.window_start_time >= NOW() - INTERVAL 5 MINUTE THEN s.pay_buyer_qty END) AS pay_buyer_qty_2,
    SUM(s.refund_amt) AS refund_amt,
    SUM(CASE WHEN s.window_start_time >= NOW() - INTERVAL 1 HOUR THEN s.refund_amt END) AS refund_amt_1,
    SUM(CASE WHEN s.window_start_time >= NOW() - INTERVAL 5 MINUTE THEN s.refund_amt END) AS refund_amt_2
  FROM dws.dws_ord_tenant_sku_trade_rt s          -- 来源表「商户×SKU 分钟级交易」
  WHERE s.travel_date = DATE_FORMAT(CURDATE(), '%Y%m%d')  -- 只取今日数据
  GROUP BY s.travel_date, s.window_start_time, s.window_end_time, s.seller_tenant_id  -- 按粒度键汇总
) u                                               -- 各来源合并后的明细
GROUP BY u.travel_date, u.window_start_time, u.window_end_time, u.seller_tenant_id  -- 按粒度键汇总
) x                                               -- 汇总结果，外层再补维度名称
LEFT JOIN dim.dim_sup_tenant_zip d1 ON d1.tenant_id = x.seller_tenant_id AND d1.end_date = '9999-12-31';  -- 关联「租户（商户/供应商/分销商）维度」，取维度名称
