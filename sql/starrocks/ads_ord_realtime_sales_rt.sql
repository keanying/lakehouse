-- ads.ads_ord_realtime_sales_rt  实时销售看板（对应 DP08）
-- 粒度：seller_tenant_id × 窗口
-- 来源：dws_ord_tenant_sku_trade_rt
-- 生成方式：StarRocks 异步物化视图（每分钟刷新）；字段 24 个：直接翻译 6 · 规则翻译 18 · 待确认 0
-- 来源按粒度键预聚合后按公式计算

CREATE MATERIALIZED VIEW IF NOT EXISTS ads.ads_ord_realtime_sales_rt  -- 异步物化视图，StarRocks 定时刷新
REFRESH ASYNC EVERY (INTERVAL 1 MINUTE)
AS
WITH
src_tenant_sku_trade AS (                      -- 来源「商户×SKU 分钟级交易」按粒度键预聚合
  SELECT
    s.travel_date AS travel_date,              -- 数据日期
    s.window_start_time AS window_start_time,  -- 窗口开始时间
    s.window_end_time AS window_end_time,      -- 窗口结束时间
    s.seller_tenant_id AS seller_tenant_id,    -- 卖家租户ID
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
  FROM dws.dws_ord_tenant_sku_trade_rt s       -- 来源表「商户×SKU 分钟级交易」
  WHERE s.travel_date = DATE_FORMAT(CURDATE(), '%Y%m%d')  -- 只取今日数据
  GROUP BY s.travel_date, s.window_start_time, s.window_end_time, s.seller_tenant_id  -- 按粒度键汇总
),
merged AS (                                    -- 按粒度键汇总，计算派生指标
  SELECT
    u.travel_date,                             -- 数据日期
    u.window_start_time,                       -- 窗口开始时间
    u.window_end_time,                         -- 窗口结束时间
    u.seller_tenant_id,                        -- 卖家租户ID
    u.pay_amt AS pay_today_amt,                -- 今日实时支付金额（GMV）
    u.pay_amt_1 AS pay_1h_amt,                 -- 近1小时支付金额（GMV）
    u.pay_amt_2 AS pay_5m_amt,                 -- 近5分钟支付金额（GMV）
    u.pay_order_qty AS pay_order_today_qty,    -- 今日实时支付子单数
    u.pay_order_qty_1 AS pay_order_1h_qty,     -- 近1小时支付子单数
    u.pay_order_qty_2 AS pay_order_5m_qty,     -- 近5分钟支付子单数
    u.pay_ticket_qty AS pay_ticket_today_qty,  -- 今日实时支付票数
    u.pay_ticket_qty_1 AS pay_ticket_1h_qty,   -- 近1小时支付票数
    u.pay_ticket_qty_2 AS pay_ticket_5m_qty,   -- 近5分钟支付票数
    u.pay_buyer_qty AS pay_buyer_today_qty,    -- 今日实时支付买家数
    u.pay_buyer_qty_1 AS pay_buyer_1h_qty,     -- 近1小时支付买家数
    u.pay_buyer_qty_2 AS pay_buyer_5m_qty,     -- 近5分钟支付买家数
    u.refund_amt AS refund_today_amt,          -- 今日实时退款金额
    u.refund_amt_1 AS refund_1h_amt,           -- 近1小时退款金额
    u.refund_amt_2 AS refund_5m_amt,           -- 近5分钟退款金额
    u.pay_amt / NULLIF(u.pay_ticket_qty, 0) AS avg_ticket_price_today_amt,  -- 今日实时平均票价
    u.pay_amt_1 / NULLIF(u.pay_ticket_qty_1, 0) AS avg_ticket_price_1h_amt,  -- 近1小时平均票价
    u.pay_amt_2 / NULLIF(u.pay_ticket_qty_2, 0) AS avg_ticket_price_5m_amt,  -- 近5分钟平均票价
    NOW() AS update_time                       -- 最近一次写入时间
  FROM src_tenant_sku_trade u
),
tenant_cur AS (                                -- 「租户（商户/供应商/分销商）维度」当前有效版本，只取名称类字段
  SELECT tenant_id, tenant_name
  FROM dim.dim_sup_tenant_zip
  WHERE end_date = '9999-12-31'                -- 只取拉链当前有效版本
)
SELECT
  merged.travel_date,                          -- 数据日期
  merged.window_start_time,                    -- 窗口开始时间
  merged.window_end_time,                      -- 窗口结束时间
  merged.seller_tenant_id,                     -- 卖家租户ID
  tenant_cur.tenant_name AS seller_tenant_name,  -- 卖家租户名称
  merged.pay_today_amt,                        -- 今日实时支付金额（GMV）
  merged.pay_1h_amt,                           -- 近1小时支付金额（GMV）
  merged.pay_5m_amt,                           -- 近5分钟支付金额（GMV）
  merged.pay_order_today_qty,                  -- 今日实时支付子单数
  merged.pay_order_1h_qty,                     -- 近1小时支付子单数
  merged.pay_order_5m_qty,                     -- 近5分钟支付子单数
  merged.pay_ticket_today_qty,                 -- 今日实时支付票数
  merged.pay_ticket_1h_qty,                    -- 近1小时支付票数
  merged.pay_ticket_5m_qty,                    -- 近5分钟支付票数
  merged.pay_buyer_today_qty,                  -- 今日实时支付买家数
  merged.pay_buyer_1h_qty,                     -- 近1小时支付买家数
  merged.pay_buyer_5m_qty,                     -- 近5分钟支付买家数
  merged.refund_today_amt,                     -- 今日实时退款金额
  merged.refund_1h_amt,                        -- 近1小时退款金额
  merged.refund_5m_amt,                        -- 近5分钟退款金额
  merged.avg_ticket_price_today_amt,           -- 今日实时平均票价
  merged.avg_ticket_price_1h_amt,              -- 近1小时平均票价
  merged.avg_ticket_price_5m_amt,              -- 近5分钟平均票价
  merged.update_time                           -- 最近一次写入时间
FROM merged
LEFT JOIN tenant_cur                           -- 关联「租户（商户/供应商/分销商）维度」，补 seller_tenant_name
  ON tenant_cur.tenant_id = merged.seller_tenant_id;  -- 按 seller_tenant_id→tenant_id 关联
