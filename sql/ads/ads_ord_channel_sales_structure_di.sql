-- ads.ads_ord_channel_sales_structure_di  渠道销售结构
-- 粒度：travel_date × seller_tenant_id
-- 来源：dws_ord_tenant_sku_channel_trade_di
-- 生成方式：Spark SQL / Hive；字段 29 个：直接翻译 4 · 规则翻译 25 · 待确认 0

INSERT OVERWRITE TABLE ads.ads_ord_channel_sales_structure_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  x.seller_tenant_id,                                                             -- 卖家租户ID
  d1.tenant_name AS seller_tenant_name,                                           -- 卖家租户名称
  x.mp_pay_amt,                                                                   -- 小程序支付金额（GMV）（日）
  x.h5_pay_amt,                                                                   -- H5支付金额（GMV）（日）
  x.pc_pay_amt,                                                                   -- PC后台代下支付金额（GMV）（日）
  x.offline_pay_amt,                                                              -- 线下窗口支付金额（GMV）（日）
  x.api_pay_amt,                                                                  -- OTA/API支付金额（GMV）（日）
  x.mp_pay_ticket_qty,                                                            -- 小程序支付票数（日）
  x.h5_pay_ticket_qty,                                                            -- H5支付票数（日）
  x.pc_pay_ticket_qty,                                                            -- PC后台代下支付票数（日）
  x.offline_pay_ticket_qty,                                                       -- 线下窗口支付票数（日）
  x.api_pay_ticket_qty,                                                           -- OTA/API支付票数（日）
  x.mp_pay_order_qty,                                                             -- 小程序支付子单数（日）
  x.h5_pay_order_qty,                                                             -- H5支付子单数（日）
  x.pc_pay_order_qty,                                                             -- PC后台代下支付子单数（日）
  x.offline_pay_order_qty,                                                        -- 线下窗口支付子单数（日）
  x.api_pay_order_qty,                                                            -- OTA/API支付子单数（日）
  x.mp_channel_pay_share_numerator_amt,                                           -- 小程序渠道销售占比分子（日）
  x.mp_channel_pay_share_denominator_amt,                                         -- 小程序渠道销售占比分母（日）
  x.h5_channel_pay_share_numerator_amt,                                           -- H5渠道销售占比分子（日）
  x.h5_channel_pay_share_denominator_amt,                                         -- H5渠道销售占比分母（日）
  x.pc_channel_pay_share_numerator_amt,                                           -- PC后台代下渠道销售占比分子（日）
  x.pc_channel_pay_share_denominator_amt,                                         -- PC后台代下渠道销售占比分母（日）
  x.offline_channel_pay_share_numerator_amt,                                      -- 线下窗口渠道销售占比分子（日）
  x.offline_channel_pay_share_denominator_amt,                                    -- 线下窗口渠道销售占比分母（日）
  x.api_channel_pay_share_numerator_amt,                                          -- OTA/API渠道销售占比分子（日）
  x.api_channel_pay_share_denominator_amt,                                        -- OTA/API渠道销售占比分母（日）
  x.staff_order_qty,                                                              -- 员工代下单数（日）
  x.staff_pay_amt,                                                                -- 员工代下单支付金额（日）
  x.etl_time                                                                      -- ETL 加载时间
FROM (
SELECT
  u.seller_tenant_id,                                                             -- 卖家租户ID
  SUM(u.mp_pay_amt) AS mp_pay_amt,                                                -- 小程序支付金额（GMV）（日）
  SUM(u.h5_pay_amt) AS h5_pay_amt,                                                -- H5支付金额（GMV）（日）
  SUM(u.pc_pay_amt) AS pc_pay_amt,                                                -- PC后台代下支付金额（GMV）（日）
  SUM(u.offline_pay_amt) AS offline_pay_amt,                                      -- 线下窗口支付金额（GMV）（日）
  SUM(u.api_pay_amt) AS api_pay_amt,                                              -- OTA/API支付金额（GMV）（日）
  SUM(u.mp_pay_ticket_qty) AS mp_pay_ticket_qty,                                  -- 小程序支付票数（日）
  SUM(u.h5_pay_ticket_qty) AS h5_pay_ticket_qty,                                  -- H5支付票数（日）
  SUM(u.pc_pay_ticket_qty) AS pc_pay_ticket_qty,                                  -- PC后台代下支付票数（日）
  SUM(u.offline_pay_ticket_qty) AS offline_pay_ticket_qty,                        -- 线下窗口支付票数（日）
  SUM(u.api_pay_ticket_qty) AS api_pay_ticket_qty,                                -- OTA/API支付票数（日）
  SUM(u.mp_pay_order_qty) AS mp_pay_order_qty,                                    -- 小程序支付子单数（日）
  SUM(u.h5_pay_order_qty) AS h5_pay_order_qty,                                    -- H5支付子单数（日）
  SUM(u.pc_pay_order_qty) AS pc_pay_order_qty,                                    -- PC后台代下支付子单数（日）
  SUM(u.offline_pay_order_qty) AS offline_pay_order_qty,                          -- 线下窗口支付子单数（日）
  SUM(u.api_pay_order_qty) AS api_pay_order_qty,                                  -- OTA/API支付子单数（日）
  SUM(u.mp_channel_pay_share_numerator_amt) AS mp_channel_pay_share_numerator_amt,  -- 小程序渠道销售占比分子（日）
  SUM(u.mp_channel_pay_share_denominator_amt) AS mp_channel_pay_share_denominator_amt,  -- 小程序渠道销售占比分母（日）
  SUM(u.h5_channel_pay_share_numerator_amt) AS h5_channel_pay_share_numerator_amt,  -- H5渠道销售占比分子（日）
  SUM(u.h5_channel_pay_share_denominator_amt) AS h5_channel_pay_share_denominator_amt,  -- H5渠道销售占比分母（日）
  SUM(u.pc_channel_pay_share_numerator_amt) AS pc_channel_pay_share_numerator_amt,  -- PC后台代下渠道销售占比分子（日）
  SUM(u.pc_channel_pay_share_denominator_amt) AS pc_channel_pay_share_denominator_amt,  -- PC后台代下渠道销售占比分母（日）
  SUM(u.offline_channel_pay_share_numerator_amt) AS offline_channel_pay_share_numerator_amt,  -- 线下窗口渠道销售占比分子（日）
  SUM(u.offline_channel_pay_share_denominator_amt) AS offline_channel_pay_share_denominator_amt,  -- 线下窗口渠道销售占比分母（日）
  SUM(u.api_channel_pay_share_numerator_amt) AS api_channel_pay_share_numerator_amt,  -- OTA/API渠道销售占比分子（日）
  SUM(u.api_channel_pay_share_denominator_amt) AS api_channel_pay_share_denominator_amt,  -- OTA/API渠道销售占比分母（日）
  SUM(u.staff_order_qty) AS staff_order_qty,                                      -- 员工代下单数（日）
  SUM(u.staff_pay_amt) AS staff_pay_amt,                                          -- 员工代下单支付金额（日）
  CURRENT_TIMESTAMP() AS etl_time                                                 -- ETL 加载时间
FROM (
  -- 来源：dws_ord_tenant_sku_channel_trade_di
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
    SUM(pay_amt) AS staff_pay_amt                                                 -- 员工代下单支付金额（日）
  FROM dws.dws_ord_tenant_sku_channel_trade_di s                                  -- 来源表「商户×SKU×渠道 交易日汇总」
  LEFT JOIN dim.dim_trf_channel_df ch ON ch.channel_id = s.channel_id AND ch.travel_date = '${bizdate}'  -- 关联「渠道/接入端维度」，取渠道类型（修饰词条件用）
  WHERE s.travel_date = '${bizdate}'                                              -- 只取当日分区
  GROUP BY seller_tenant_id                                                       -- 按粒度键汇总
) u                                                                               -- 各来源合并后的明细
GROUP BY u.seller_tenant_id                                                       -- 按粒度键汇总
) x                                                                               -- 汇总结果，外层再补维度名称
LEFT JOIN dim.dim_sup_tenant_zip d1 ON d1.tenant_id = x.seller_tenant_id AND d1.travel_date = '${bizdate}' AND d1.end_date = '9999-12-31';  -- 关联「租户（商户/供应商/分销商）维度」，取维度名称
