-- ads.ads_ord_channel_sales_structure_di  渠道销售结构
-- 粒度：travel_date × seller_tenant_id
-- 来源：dws_ord_tenant_sku_channel_trade_di
-- 生成方式：Spark SQL / Hive；字段 29 个：直接翻译 3 · 规则翻译 26 · 待确认 0
-- 来源先按粒度键预聚合

WITH
channel_dim AS (                                                                  -- 「渠道/接入端维度」渠道类型（修饰词条件用）
  SELECT channel_id, channel_type
  FROM dim.dim_trf_channel_df
  WHERE travel_date = '${bizdate}'                                                -- 只取当日分区
),
src_tenant_sku_channel_trade AS (                                                 -- 来源「商户×SKU×渠道 交易日汇总」按粒度键预聚合
  SELECT
    seller_tenant_id AS seller_tenant_id,                                         -- 卖家租户ID
    SUM(CASE WHEN ch.channel_type = 'MP' THEN pay_amt END) AS mp_pay_amt,         -- 小程序支付金额（GMV）（日）
    SUM(CASE WHEN ch.channel_type = 'H5' THEN pay_amt END) AS h5_pay_amt,         -- H5支付金额（GMV）（日）
    SUM(CASE WHEN ch.channel_type = 'PC' THEN pay_amt END) AS pc_pay_amt,         -- PC后台代下支付金额（GMV）（日）
    SUM(CASE WHEN ch.channel_type = 'OFFLINE' THEN pay_amt END) AS offline_pay_amt,  -- 线下窗口支付金额（GMV）（日）
    SUM(CASE WHEN ch.channel_type = 'API' THEN pay_amt END) AS api_pay_amt,       -- OTA/API支付金额（GMV）（日）
    SUM(CASE WHEN ch.channel_type = 'MP' THEN pay_ticket_qty END) AS mp_pay_ticket_qty,  -- 小程序支付票数（日）
    SUM(CASE WHEN ch.channel_type = 'H5' THEN pay_ticket_qty END) AS h5_pay_ticket_qty,  -- H5支付票数（日）
    SUM(CASE WHEN ch.channel_type = 'PC' THEN pay_ticket_qty END) AS pc_pay_ticket_qty,  -- PC后台代下支付票数（日）
    SUM(CASE WHEN ch.channel_type = 'OFFLINE' THEN pay_ticket_qty END) AS offline_pay_ticket_qty,  -- 线下窗口支付票数（日）
    SUM(CASE WHEN ch.channel_type = 'API' THEN pay_ticket_qty END) AS api_pay_ticket_qty,  -- OTA/API支付票数（日）
    SUM(CASE WHEN ch.channel_type = 'MP' THEN pay_order_qty END) AS mp_pay_order_qty,  -- 小程序支付子单数（日）
    SUM(CASE WHEN ch.channel_type = 'H5' THEN pay_order_qty END) AS h5_pay_order_qty,  -- H5支付子单数（日）
    SUM(CASE WHEN ch.channel_type = 'PC' THEN pay_order_qty END) AS pc_pay_order_qty,  -- PC后台代下支付子单数（日）
    SUM(CASE WHEN ch.channel_type = 'OFFLINE' THEN pay_order_qty END) AS offline_pay_order_qty,  -- 线下窗口支付子单数（日）
    SUM(CASE WHEN ch.channel_type = 'API' THEN pay_order_qty END) AS api_pay_order_qty,  -- OTA/API支付子单数（日）
    SUM(CASE WHEN ch.channel_type = 'MP' THEN pay_amt END) AS mp_channel_pay_share_numerator_amt,  -- 小程序渠道销售占比分子（日）
    SUM(CASE WHEN ch.channel_type = 'MP' THEN pay_amt END) AS mp_channel_pay_share_denominator_amt,  -- 小程序渠道销售占比分母（日）
    SUM(CASE WHEN ch.channel_type = 'H5' THEN pay_amt END) AS h5_channel_pay_share_numerator_amt,  -- H5渠道销售占比分子（日）
    SUM(CASE WHEN ch.channel_type = 'H5' THEN pay_amt END) AS h5_channel_pay_share_denominator_amt,  -- H5渠道销售占比分母（日）
    SUM(CASE WHEN ch.channel_type = 'PC' THEN pay_amt END) AS pc_channel_pay_share_numerator_amt,  -- PC后台代下渠道销售占比分子（日）
    SUM(CASE WHEN ch.channel_type = 'PC' THEN pay_amt END) AS pc_channel_pay_share_denominator_amt,  -- PC后台代下渠道销售占比分母（日）
    SUM(CASE WHEN ch.channel_type = 'OFFLINE' THEN pay_amt END) AS offline_channel_pay_share_numerator_amt,  -- 线下窗口渠道销售占比分子（日）
    SUM(CASE WHEN ch.channel_type = 'OFFLINE' THEN pay_amt END) AS offline_channel_pay_share_denominator_amt,  -- 线下窗口渠道销售占比分母（日）
    SUM(CASE WHEN ch.channel_type = 'API' THEN pay_amt END) AS api_channel_pay_share_numerator_amt,  -- OTA/API渠道销售占比分子（日）
    SUM(CASE WHEN ch.channel_type = 'API' THEN pay_amt END) AS api_channel_pay_share_denominator_amt,  -- OTA/API渠道销售占比分母（日）
    SUM(staff_order_qty) AS staff_order_qty,                                      -- 员工代下单数（日）
    SUM(CASE WHEN operator_type = 'TENANT_STAFF' THEN pay_amt END) AS staff_pay_amt  -- 员工代下单支付金额（日）
  FROM dws.dws_ord_tenant_sku_channel_trade_di s                                  -- 来源表「商户×SKU×渠道 交易日汇总」
  LEFT JOIN channel_dim ch ON ch.channel_id = s.channel_id
  WHERE s.travel_date = '${bizdate}'                                              -- 只取当日分区
  GROUP BY seller_tenant_id                                                       -- 按粒度键汇总
),
merged AS (                                                                       -- 按粒度键汇总，计算派生指标
  SELECT
    u.seller_tenant_id,                                                           -- 卖家租户ID
    u.mp_pay_amt,                                                                 -- 小程序支付金额（GMV）（日）
    u.h5_pay_amt,                                                                 -- H5支付金额（GMV）（日）
    u.pc_pay_amt,                                                                 -- PC后台代下支付金额（GMV）（日）
    u.offline_pay_amt,                                                            -- 线下窗口支付金额（GMV）（日）
    u.api_pay_amt,                                                                -- OTA/API支付金额（GMV）（日）
    u.mp_pay_ticket_qty,                                                          -- 小程序支付票数（日）
    u.h5_pay_ticket_qty,                                                          -- H5支付票数（日）
    u.pc_pay_ticket_qty,                                                          -- PC后台代下支付票数（日）
    u.offline_pay_ticket_qty,                                                     -- 线下窗口支付票数（日）
    u.api_pay_ticket_qty,                                                         -- OTA/API支付票数（日）
    u.mp_pay_order_qty,                                                           -- 小程序支付子单数（日）
    u.h5_pay_order_qty,                                                           -- H5支付子单数（日）
    u.pc_pay_order_qty,                                                           -- PC后台代下支付子单数（日）
    u.offline_pay_order_qty,                                                      -- 线下窗口支付子单数（日）
    u.api_pay_order_qty,                                                          -- OTA/API支付子单数（日）
    u.mp_channel_pay_share_numerator_amt,                                         -- 小程序渠道销售占比分子（日）
    u.mp_channel_pay_share_denominator_amt,                                       -- 小程序渠道销售占比分母（日）
    u.h5_channel_pay_share_numerator_amt,                                         -- H5渠道销售占比分子（日）
    u.h5_channel_pay_share_denominator_amt,                                       -- H5渠道销售占比分母（日）
    u.pc_channel_pay_share_numerator_amt,                                         -- PC后台代下渠道销售占比分子（日）
    u.pc_channel_pay_share_denominator_amt,                                       -- PC后台代下渠道销售占比分母（日）
    u.offline_channel_pay_share_numerator_amt,                                    -- 线下窗口渠道销售占比分子（日）
    u.offline_channel_pay_share_denominator_amt,                                  -- 线下窗口渠道销售占比分母（日）
    u.api_channel_pay_share_numerator_amt,                                        -- OTA/API渠道销售占比分子（日）
    u.api_channel_pay_share_denominator_amt,                                      -- OTA/API渠道销售占比分母（日）
    u.staff_order_qty,                                                            -- 员工代下单数（日）
    u.staff_pay_amt,                                                              -- 员工代下单支付金额（日）
    CURRENT_TIMESTAMP() AS etl_time                                               -- ETL 加载时间
  FROM src_tenant_sku_channel_trade u
),
tenant_cur AS (                                                                   -- 「租户（商户/供应商/分销商）维度」当前有效版本，只取名称类字段
  SELECT tenant_id, tenant_name
  FROM dim.dim_sup_tenant_zip
  WHERE travel_date = '${bizdate}' AND end_date = '9999-12-31'                    -- 取当日分区里的拉链当前有效版本
)
INSERT OVERWRITE TABLE ads.ads_ord_channel_sales_structure_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  merged.seller_tenant_id,                                                        -- 卖家租户ID
  tenant_cur.tenant_name AS seller_tenant_name,                                   -- 卖家租户名称
  merged.mp_pay_amt,                                                              -- 小程序支付金额（GMV）（日）
  merged.h5_pay_amt,                                                              -- H5支付金额（GMV）（日）
  merged.pc_pay_amt,                                                              -- PC后台代下支付金额（GMV）（日）
  merged.offline_pay_amt,                                                         -- 线下窗口支付金额（GMV）（日）
  merged.api_pay_amt,                                                             -- OTA/API支付金额（GMV）（日）
  merged.mp_pay_ticket_qty,                                                       -- 小程序支付票数（日）
  merged.h5_pay_ticket_qty,                                                       -- H5支付票数（日）
  merged.pc_pay_ticket_qty,                                                       -- PC后台代下支付票数（日）
  merged.offline_pay_ticket_qty,                                                  -- 线下窗口支付票数（日）
  merged.api_pay_ticket_qty,                                                      -- OTA/API支付票数（日）
  merged.mp_pay_order_qty,                                                        -- 小程序支付子单数（日）
  merged.h5_pay_order_qty,                                                        -- H5支付子单数（日）
  merged.pc_pay_order_qty,                                                        -- PC后台代下支付子单数（日）
  merged.offline_pay_order_qty,                                                   -- 线下窗口支付子单数（日）
  merged.api_pay_order_qty,                                                       -- OTA/API支付子单数（日）
  merged.mp_channel_pay_share_numerator_amt,                                      -- 小程序渠道销售占比分子（日）
  merged.mp_channel_pay_share_denominator_amt,                                    -- 小程序渠道销售占比分母（日）
  merged.h5_channel_pay_share_numerator_amt,                                      -- H5渠道销售占比分子（日）
  merged.h5_channel_pay_share_denominator_amt,                                    -- H5渠道销售占比分母（日）
  merged.pc_channel_pay_share_numerator_amt,                                      -- PC后台代下渠道销售占比分子（日）
  merged.pc_channel_pay_share_denominator_amt,                                    -- PC后台代下渠道销售占比分母（日）
  merged.offline_channel_pay_share_numerator_amt,                                 -- 线下窗口渠道销售占比分子（日）
  merged.offline_channel_pay_share_denominator_amt,                               -- 线下窗口渠道销售占比分母（日）
  merged.api_channel_pay_share_numerator_amt,                                     -- OTA/API渠道销售占比分子（日）
  merged.api_channel_pay_share_denominator_amt,                                   -- OTA/API渠道销售占比分母（日）
  merged.staff_order_qty,                                                         -- 员工代下单数（日）
  merged.staff_pay_amt,                                                           -- 员工代下单支付金额（日）
  merged.etl_time                                                                 -- ETL 加载时间
FROM merged
LEFT JOIN tenant_cur                                                              -- 关联「租户（商户/供应商/分销商）维度」，补 seller_tenant_name
  ON tenant_cur.tenant_id = merged.seller_tenant_id;                              -- 按 seller_tenant_id→tenant_id 关联
