-- ads.ads_sup_platform_overview_di  平台经营大盘
-- 粒度：travel_date
-- 来源：dws_sup_tenant_trade_di, dws_sup_tenant_onboard_di, dws_cus_tenant_growth_di
-- 生成方式：Spark SQL / Hive；字段 14 个：直接翻译 12 · 规则翻译 2 · 待确认 0
-- 多来源：每个来源先按粒度键预聚合，UNION ALL 后再汇总
-- 补 0 / 补空列：多来源 UNION ALL 时，某来源不产出的指标补 0 或空，外层按粒度 SUM 后即为各来源之和，不影响结果

WITH
src_tenant_trade AS (                                            -- 来源「商户经营日汇总」按粒度键预聚合
  SELECT
    SUM(pay_amt) AS pay_amt,                                     -- 支付金额（GMV）（日）
    SUM(net_pay_amt) AS net_pay_amt,                             -- 净成交金额（日）
    SUM(verify_ticket_qty) AS verify_ticket_qty,                 -- 核销票数（日）
    SUM(pay_amt) - SUM(cost_amt) AS gross_profit_amt,            -- 毛利额（日）
    BITMAP_UNION(TO_BITMAP(CASE WHEN pay_amt > 0 THEN seller_tenant_id END)) AS active_tenant_bitmap,  -- 动销商户数去重位图（日）
    NULL AS new_tenant_qty,                                      -- 新入驻商户数（日）：此来源不产出，补空
    SUM(new_customer_qty) AS new_customer_qty,                   -- 新注册游客数（日）
    BITMAP_UNION(pay_buyer_bitmap) AS pay_buyer_bitmap,          -- 支付买家数去重位图（日）
    NULL AS tenant_cert_apply_qty,                               -- 提交认证商户数（日）：此来源不产出，补空
    NULL AS tenant_cert_pass_qty,                                -- 认证通过商户数（日）：此来源不产出，补空
    NULL AS tenant_cert_pass_numerator_qty,                      -- 商户认证通过率分子（日）：此来源不产出，补空
    NULL AS tenant_cert_pass_denominator_qty,                    -- 商户认证通过率分母（日）：此来源不产出，补空
    BITMAP_UNION(sold_sku_bitmap) AS sku_sell_numerator_bitmap,  -- SKU动销率分子（日）
    SUM(on_sale_sku_qty) AS sku_sell_denominator_qty             -- SKU动销率分母（日）
  FROM dws.dws_sup_tenant_trade_di s                             -- 来源表「商户经营日汇总」
  WHERE s.travel_date = '${bizdate}'                             -- 只取当日分区
),
src_tenant_onboard AS (                                          -- 来源「平台×地区×业态 商户入驻日汇总」按粒度键预聚合
  SELECT
    NULL AS pay_amt,                                             -- 支付金额（GMV）（日）：此来源不产出，补空
    NULL AS net_pay_amt,                                         -- 净成交金额（日）：此来源不产出，补空
    NULL AS verify_ticket_qty,                                   -- 核销票数（日）：此来源不产出，补空
    NULL AS gross_profit_amt,                                    -- 毛利额（日）：此来源不产出，补空
    CAST(NULL AS BINARY) AS active_tenant_bitmap,                -- 动销商户数去重位图（日）：此来源不产出，补空
    SUM(new_tenant_qty) AS new_tenant_qty,                       -- 新入驻商户数（日）
    NULL AS new_customer_qty,                                    -- 新注册游客数（日）：此来源不产出，补空
    CAST(NULL AS BINARY) AS pay_buyer_bitmap,                    -- 支付买家数去重位图（日）：此来源不产出，补空
    SUM(tenant_cert_apply_qty) AS tenant_cert_apply_qty,         -- 提交认证商户数（日）
    SUM(tenant_cert_pass_qty) AS tenant_cert_pass_qty,           -- 认证通过商户数（日）
    SUM(tenant_cert_pass_qty) AS tenant_cert_pass_numerator_qty,  -- 商户认证通过率分子（日）
    SUM(tenant_cert_apply_qty) AS tenant_cert_pass_denominator_qty,  -- 商户认证通过率分母（日）
    CAST(NULL AS BINARY) AS sku_sell_numerator_bitmap,           -- SKU动销率分子（日）：此来源不产出，补空
    NULL AS sku_sell_denominator_qty                             -- SKU动销率分母（日）：此来源不产出，补空
  FROM dws.dws_sup_tenant_onboard_di s                           -- 来源表「平台×地区×业态 商户入驻日汇总」
  WHERE s.travel_date = '${bizdate}'                             -- 只取当日分区
),
all_src AS (                                                     -- 各来源字段已对齐，UNION ALL 合并（比多表 FULL JOIN 少 shuffle）
  SELECT * FROM src_tenant_trade
  UNION ALL
  SELECT * FROM src_tenant_onboard
)
INSERT OVERWRITE TABLE ads.ads_sup_platform_overview_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  SUM(u.pay_amt) AS pay_amt,                                     -- 支付金额（GMV）（日）
  SUM(u.net_pay_amt) AS net_pay_amt,                             -- 净成交金额（日）
  SUM(u.verify_ticket_qty) AS verify_ticket_qty,                 -- 核销票数（日）
  SUM(u.gross_profit_amt) AS gross_profit_amt,                   -- 毛利额（日）
  BITMAP_UNION(u.active_tenant_bitmap) AS active_tenant_bitmap,  -- 动销商户数去重位图（日）
  SUM(u.new_tenant_qty) AS new_tenant_qty,                       -- 新入驻商户数（日）
  SUM(u.new_customer_qty) AS new_customer_qty,                   -- 新注册游客数（日）
  BITMAP_UNION(u.pay_buyer_bitmap) AS pay_buyer_bitmap,          -- 支付买家数去重位图（日）
  SUM(u.tenant_cert_apply_qty) AS tenant_cert_apply_qty,         -- 提交认证商户数（日）
  SUM(u.tenant_cert_pass_qty) AS tenant_cert_pass_qty,           -- 认证通过商户数（日）
  SUM(u.tenant_cert_pass_numerator_qty) AS tenant_cert_pass_numerator_qty,  -- 商户认证通过率分子（日）
  SUM(u.tenant_cert_pass_denominator_qty) AS tenant_cert_pass_denominator_qty,  -- 商户认证通过率分母（日）
  BITMAP_UNION(u.sku_sell_numerator_bitmap) AS sku_sell_numerator_bitmap,  -- SKU动销率分子（日）
  SUM(u.sku_sell_denominator_qty) AS sku_sell_denominator_qty,   -- SKU动销率分母（日）
  CURRENT_TIMESTAMP() AS etl_time                                -- ETL 加载时间
FROM all_src u;
