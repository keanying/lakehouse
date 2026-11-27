-- ads.ads_ord_channel_sales_rt  渠道实时销售结构
-- 粒度：seller_tenant_id × 今日
-- 来源：dws_ord_tenant_sku_trade_rt
-- 生成方式：StarRocks 异步物化视图（每分钟刷新）；字段 26 个：直接翻译 4 · 规则翻译 22 · 待确认 0
-- 来源按粒度键预聚合后按公式计算

CREATE MATERIALIZED VIEW IF NOT EXISTS ads.ads_ord_channel_sales_rt  -- 异步物化视图，StarRocks 定时刷新
REFRESH ASYNC EVERY (INTERVAL 1 MINUTE)
AS
WITH
src_tenant_sku_trade AS (                          -- 来源「商户×SKU 分钟级交易」按粒度键预聚合
  SELECT
    s.travel_date AS travel_date,                  -- 数据日期
    s.seller_tenant_id AS seller_tenant_id,        -- 卖家租户ID
    SUM(s.pay_amt) AS pay_amt,                     -- 支付金额（GMV）
    SUM(s.pay_order_qty) AS pay_order_qty,         -- 支付子单数
    SUM(s.pay_ticket_qty) AS pay_ticket_qty,       -- 支付票数
    SUM(s.staff_order_qty) AS staff_order_qty,     -- 员工代下单数
    SUM(s.staff_pay_amt) AS staff_pay_amt          -- 员工代下单支付金额
  FROM dws.dws_ord_tenant_sku_trade_rt s           -- 来源表「商户×SKU 分钟级交易」
  WHERE s.travel_date = DATE_FORMAT(CURDATE(), '%Y%m%d')  -- 只取今日数据
  GROUP BY s.travel_date, s.seller_tenant_id       -- 按粒度键汇总
),
merged AS (                                        -- 按粒度键汇总，计算派生指标
  SELECT
    u.travel_date,                                 -- 数据日期
    u.seller_tenant_id,                            -- 卖家租户ID
    u.pay_amt AS mp_pay_today_amt,                 -- 今日实时小程序支付金额（GMV）
    u.pay_amt AS h5_pay_today_amt,                 -- 今日实时H5支付金额（GMV）
    u.pay_amt AS pc_pay_today_amt,                 -- 今日实时PC后台代下支付金额（GMV）
    u.pay_amt AS offline_pay_today_amt,            -- 今日实时线下窗口支付金额（GMV）
    u.pay_amt AS api_pay_today_amt,                -- 今日实时OTA/API支付金额（GMV）
    u.pay_order_qty AS mp_pay_order_today_qty,     -- 今日实时小程序支付子单数
    u.pay_order_qty AS h5_pay_order_today_qty,     -- 今日实时H5支付子单数
    u.pay_order_qty AS pc_pay_order_today_qty,     -- 今日实时PC后台代下支付子单数
    u.pay_order_qty AS offline_pay_order_today_qty,  -- 今日实时线下窗口支付子单数
    u.pay_order_qty AS api_pay_order_today_qty,    -- 今日实时OTA/API支付子单数
    u.pay_ticket_qty AS mp_pay_ticket_today_qty,   -- 今日实时小程序支付票数
    u.pay_ticket_qty AS h5_pay_ticket_today_qty,   -- 今日实时H5支付票数
    u.pay_ticket_qty AS pc_pay_ticket_today_qty,   -- 今日实时PC后台代下支付票数
    u.pay_ticket_qty AS offline_pay_ticket_today_qty,  -- 今日实时线下窗口支付票数
    u.pay_ticket_qty AS api_pay_ticket_today_qty,  -- 今日实时OTA/API支付票数
    u.pay_amt AS mp_channel_pay_share_today_rate,  -- 今日实时小程序渠道销售占比
    u.pay_amt AS h5_channel_pay_share_today_rate,  -- 今日实时H5渠道销售占比
    u.pay_amt AS pc_channel_pay_share_today_rate,  -- 今日实时PC后台代下渠道销售占比
    u.pay_amt AS offline_channel_pay_share_today_rate,  -- 今日实时线下窗口渠道销售占比
    u.pay_amt AS api_channel_pay_share_today_rate,  -- 今日实时OTA/API渠道销售占比
    u.staff_order_qty AS staff_order_today_qty,    -- 今日实时员工代下单数
    u.staff_pay_amt AS staff_pay_today_amt,        -- 今日实时员工代下单支付金额
    NOW() AS update_time                           -- 最近一次写入时间
  FROM src_tenant_sku_trade u
),
tenant_cur AS (                                    -- 「租户（商户/供应商/分销商）维度」当前有效版本，只取名称类字段
  SELECT tenant_id, tenant_name
  FROM dim.dim_sup_tenant_zip
  WHERE end_date = '9999-12-31'                    -- 只取拉链当前有效版本
)
SELECT
  merged.travel_date,                              -- 数据日期
  merged.seller_tenant_id,                         -- 卖家租户ID
  tenant_cur.tenant_name AS seller_tenant_name,    -- 卖家租户名称
  merged.mp_pay_today_amt,                         -- 今日实时小程序支付金额（GMV）
  merged.h5_pay_today_amt,                         -- 今日实时H5支付金额（GMV）
  merged.pc_pay_today_amt,                         -- 今日实时PC后台代下支付金额（GMV）
  merged.offline_pay_today_amt,                    -- 今日实时线下窗口支付金额（GMV）
  merged.api_pay_today_amt,                        -- 今日实时OTA/API支付金额（GMV）
  merged.mp_pay_order_today_qty,                   -- 今日实时小程序支付子单数
  merged.h5_pay_order_today_qty,                   -- 今日实时H5支付子单数
  merged.pc_pay_order_today_qty,                   -- 今日实时PC后台代下支付子单数
  merged.offline_pay_order_today_qty,              -- 今日实时线下窗口支付子单数
  merged.api_pay_order_today_qty,                  -- 今日实时OTA/API支付子单数
  merged.mp_pay_ticket_today_qty,                  -- 今日实时小程序支付票数
  merged.h5_pay_ticket_today_qty,                  -- 今日实时H5支付票数
  merged.pc_pay_ticket_today_qty,                  -- 今日实时PC后台代下支付票数
  merged.offline_pay_ticket_today_qty,             -- 今日实时线下窗口支付票数
  merged.api_pay_ticket_today_qty,                 -- 今日实时OTA/API支付票数
  merged.mp_channel_pay_share_today_rate,          -- 今日实时小程序渠道销售占比
  merged.h5_channel_pay_share_today_rate,          -- 今日实时H5渠道销售占比
  merged.pc_channel_pay_share_today_rate,          -- 今日实时PC后台代下渠道销售占比
  merged.offline_channel_pay_share_today_rate,     -- 今日实时线下窗口渠道销售占比
  merged.api_channel_pay_share_today_rate,         -- 今日实时OTA/API渠道销售占比
  merged.staff_order_today_qty,                    -- 今日实时员工代下单数
  merged.staff_pay_today_amt,                      -- 今日实时员工代下单支付金额
  merged.update_time                               -- 最近一次写入时间
FROM merged
LEFT JOIN tenant_cur                               -- 关联「租户（商户/供应商/分销商）维度」，补 seller_tenant_name
  ON tenant_cur.tenant_id = merged.seller_tenant_id;  -- 按 seller_tenant_id→tenant_id 关联
