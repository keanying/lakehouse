-- ads.ads_ord_channel_sales_rt  渠道实时销售结构
-- 粒度：seller_tenant_id × 今日
-- 来源：dws_ord_tenant_sku_trade_rt
-- 生成方式：StarRocks 异步物化视图（每分钟刷新）；字段 26 个：直接翻译 4 · 规则翻译 22 · 待确认 0

CREATE MATERIALIZED VIEW IF NOT EXISTS ads.ads_ord_channel_sales_rt  -- 异步物化视图，StarRocks 定时刷新
REFRESH ASYNC EVERY (INTERVAL 1 MINUTE)
AS
SELECT
  x.travel_date,                                      -- 数据日期
  x.seller_tenant_id,                                 -- 卖家租户ID
  d1.tenant_name AS seller_tenant_name,               -- 卖家租户名称
  x.mp_pay_today_amt,                                 -- 今日实时小程序支付金额（GMV）
  x.h5_pay_today_amt,                                 -- 今日实时H5支付金额（GMV）
  x.pc_pay_today_amt,                                 -- 今日实时PC后台代下支付金额（GMV）
  x.offline_pay_today_amt,                            -- 今日实时线下窗口支付金额（GMV）
  x.api_pay_today_amt,                                -- 今日实时OTA/API支付金额（GMV）
  x.mp_pay_order_today_qty,                           -- 今日实时小程序支付子单数
  x.h5_pay_order_today_qty,                           -- 今日实时H5支付子单数
  x.pc_pay_order_today_qty,                           -- 今日实时PC后台代下支付子单数
  x.offline_pay_order_today_qty,                      -- 今日实时线下窗口支付子单数
  x.api_pay_order_today_qty,                          -- 今日实时OTA/API支付子单数
  x.mp_pay_ticket_today_qty,                          -- 今日实时小程序支付票数
  x.h5_pay_ticket_today_qty,                          -- 今日实时H5支付票数
  x.pc_pay_ticket_today_qty,                          -- 今日实时PC后台代下支付票数
  x.offline_pay_ticket_today_qty,                     -- 今日实时线下窗口支付票数
  x.api_pay_ticket_today_qty,                         -- 今日实时OTA/API支付票数
  x.mp_channel_pay_share_today_rate,                  -- 今日实时小程序渠道销售占比
  x.h5_channel_pay_share_today_rate,                  -- 今日实时H5渠道销售占比
  x.pc_channel_pay_share_today_rate,                  -- 今日实时PC后台代下渠道销售占比
  x.offline_channel_pay_share_today_rate,             -- 今日实时线下窗口渠道销售占比
  x.api_channel_pay_share_today_rate,                 -- 今日实时OTA/API渠道销售占比
  x.staff_order_today_qty,                            -- 今日实时员工代下单数
  x.staff_pay_today_amt,                              -- 今日实时员工代下单支付金额
  x.update_time                                       -- 最近一次写入时间
FROM (
SELECT
  u.travel_date,                                      -- 数据日期
  u.seller_tenant_id,                                 -- 卖家租户ID
  SUM(u.pay_amt) AS mp_pay_today_amt,                 -- 今日实时小程序支付金额（GMV）
  SUM(u.pay_amt) AS h5_pay_today_amt,                 -- 今日实时H5支付金额（GMV）
  SUM(u.pay_amt) AS pc_pay_today_amt,                 -- 今日实时PC后台代下支付金额（GMV）
  SUM(u.pay_amt) AS offline_pay_today_amt,            -- 今日实时线下窗口支付金额（GMV）
  SUM(u.pay_amt) AS api_pay_today_amt,                -- 今日实时OTA/API支付金额（GMV）
  SUM(u.pay_order_qty) AS mp_pay_order_today_qty,     -- 今日实时小程序支付子单数
  SUM(u.pay_order_qty) AS h5_pay_order_today_qty,     -- 今日实时H5支付子单数
  SUM(u.pay_order_qty) AS pc_pay_order_today_qty,     -- 今日实时PC后台代下支付子单数
  SUM(u.pay_order_qty) AS offline_pay_order_today_qty,  -- 今日实时线下窗口支付子单数
  SUM(u.pay_order_qty) AS api_pay_order_today_qty,    -- 今日实时OTA/API支付子单数
  SUM(u.pay_ticket_qty) AS mp_pay_ticket_today_qty,   -- 今日实时小程序支付票数
  SUM(u.pay_ticket_qty) AS h5_pay_ticket_today_qty,   -- 今日实时H5支付票数
  SUM(u.pay_ticket_qty) AS pc_pay_ticket_today_qty,   -- 今日实时PC后台代下支付票数
  SUM(u.pay_ticket_qty) AS offline_pay_ticket_today_qty,  -- 今日实时线下窗口支付票数
  SUM(u.pay_ticket_qty) AS api_pay_ticket_today_qty,  -- 今日实时OTA/API支付票数
  SUM(u.pay_amt) AS mp_channel_pay_share_today_rate,  -- 今日实时小程序渠道销售占比
  SUM(u.pay_amt) AS h5_channel_pay_share_today_rate,  -- 今日实时H5渠道销售占比
  SUM(u.pay_amt) AS pc_channel_pay_share_today_rate,  -- 今日实时PC后台代下渠道销售占比
  SUM(u.pay_amt) AS offline_channel_pay_share_today_rate,  -- 今日实时线下窗口渠道销售占比
  SUM(u.pay_amt) AS api_channel_pay_share_today_rate,  -- 今日实时OTA/API渠道销售占比
  SUM(u.staff_order_qty) AS staff_order_today_qty,    -- 今日实时员工代下单数
  SUM(u.staff_pay_amt) AS staff_pay_today_amt,        -- 今日实时员工代下单支付金额
  NOW() AS update_time                                -- 最近一次写入时间
FROM (
  -- 来源：dws_ord_tenant_sku_trade_rt
  SELECT
    s.travel_date AS travel_date,                     -- 数据日期
    s.seller_tenant_id AS seller_tenant_id,           -- 卖家租户ID
    SUM(s.pay_amt) AS pay_amt,
    SUM(s.pay_order_qty) AS pay_order_qty,
    SUM(s.pay_ticket_qty) AS pay_ticket_qty,
    SUM(s.staff_order_qty) AS staff_order_qty,
    SUM(s.staff_pay_amt) AS staff_pay_amt
  FROM dws.dws_ord_tenant_sku_trade_rt s              -- 来源表「商户×SKU 分钟级交易」
  WHERE s.travel_date = DATE_FORMAT(CURDATE(), '%Y%m%d')  -- 只取今日数据
  GROUP BY s.travel_date, s.seller_tenant_id          -- 按粒度键汇总
) u                                                   -- 各来源合并后的明细
GROUP BY u.travel_date, u.seller_tenant_id            -- 按粒度键汇总
) x                                                   -- 汇总结果，外层再补维度名称
LEFT JOIN dim.dim_sup_tenant_zip d1 ON d1.tenant_id = x.seller_tenant_id AND d1.end_date = '9999-12-31';  -- 关联「租户（商户/供应商/分销商）维度」，取维度名称
