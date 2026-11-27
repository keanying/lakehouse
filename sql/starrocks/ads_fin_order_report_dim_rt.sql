-- ================================================================================================
-- ads.ads_fin_order_report_dim_rt  订单报表多维汇总（今日实时）
-- 依据：《3.0 通用财务报表 · 需求说明》v1.0（2026-11-24）
-- 业务规则：
--   · 今日期间值取实时明细；今日日终余额 = 昨日 close_amt（离线定版，同步到 StarRocks）+ 今日余额影响
--   · 与离线同一套通用列，报表服务按日期分段拼接（6.1）
-- 性能：
--   · StarRocks 异步物化视图，1 分钟刷新
-- ================================================================================================

CREATE MATERIALIZED VIEW IF NOT EXISTS ads.ads_fin_order_report_dim_rt  -- 异步物化视图，StarRocks 定时刷新
REFRESH ASYNC EVERY (INTERVAL 1 MINUTE)
AS
WITH d AS (
    SELECT merchant_tenant_id,       -- 本方商户租户ID
           report_code,              -- 报表
           spu_id,                   -- 产品(SPU)ID
           sku_id,                   -- SKU ID
           channel_type,             -- 下单渠道（维度）
           seller_staff_id,          -- 售票员
           sale_point_code,          -- 售票站点
           payer_tenant_id,          -- 付款方
           payer_type,               -- 付款方类型
           payee_tenant_id,          -- 收款方
           payee_type,               -- 收款方类型
           sale_unit_price_amt,      -- 卖出单价
           buy_unit_price_amt,       -- 买入单价
           receive_pay_method_type,  -- 收款支付方式
           pay_pay_method_type,      -- 付款支付方式
           SUM(IF(measure_code IN ('RECEIVE', 'PAY'), event_amt, 0))          AS in_amt,  -- 本期收 / 本期付
           SUM(IF(measure_code IN ('REFUND', 'RETURN'), event_amt, 0))        AS out_amt,  -- 本期退 / 本期退回
           SUM(IF(measure_code IN ('TO_REVENUE', 'TO_COST'), event_amt, 0))   AS trans_amt,  -- 转实收 / 转实付
           SUM(IF(measure_code = 'CONFIRM', event_amt, 0))                    AS confirm_amt,  -- 履约收入 / 成本结算
           SUM(IF(report_code IN ('ADV_RECEIPT', 'ADV_PAYMENT'), balance_effect_amt, 0)) AS chg_amt,  -- 变动金额（元）
           SUM(ticket_net_qty)                                                AS net_ticket_qty,  -- 净票数（预收 / 预付）
           SUM(confirm_ticket_qty)                                            AS confirm_ticket_qty  -- 核销票数（确认收入 / 确认成本）
    FROM dwd.dwd_fin_merchant_order_fund_rt
    WHERE travel_date = DATE_FORMAT(CURDATE(), '%Y%m%d')  -- 只取今日数据
    GROUP BY merchant_tenant_id,     -- 按粒度键汇总
             report_code,            -- 报表
             spu_id,                 -- 产品(SPU)ID
             sku_id,                 -- SKU ID
             channel_type,           -- 下单渠道（维度）
             seller_staff_id,        -- 售票员
             sale_point_code,        -- 售票站点
             payer_tenant_id,        -- 付款方
             payer_type,             -- 付款方类型
             payee_tenant_id,        -- 收款方
             payee_type,             -- 收款方类型
             sale_unit_price_amt,    -- 卖出单价
             buy_unit_price_amt,     -- 买入单价
             receive_pay_method_type,  -- 收款支付方式
             pay_pay_method_type     -- 付款支付方式
),
y AS (
    SELECT merchant_tenant_id,       -- 本方商户租户ID
           report_code,              -- 报表
           spu_id,                   -- 产品(SPU)ID
           sku_id,                   -- SKU ID
           channel_type,             -- 下单渠道（维度）
           seller_staff_id,          -- 售票员
           sale_point_code,          -- 售票站点
           payer_tenant_id,          -- 付款方
           payer_type,               -- 付款方类型
           payee_tenant_id,          -- 收款方
           payee_type,               -- 收款方类型
           sale_unit_price_amt,      -- 卖出单价
           buy_unit_price_amt,       -- 买入单价
           receive_pay_method_type,  -- 收款支付方式
           pay_pay_method_type,      -- 付款支付方式
           close_amt                 -- 期末预收 / 期末预付（日终时点值）
    FROM ads.ads_fin_order_report_dim_di
    WHERE travel_date = DATE_FORMAT(DATE_SUB(CURDATE(), INTERVAL 1 DAY), '%Y%m%d') AND close_amt <> 0  -- 只取今日数据
),
u AS (
    SELECT merchant_tenant_id,       -- 本方商户租户ID
           report_code,              -- 报表
           spu_id,                   -- 产品(SPU)ID
           sku_id,                   -- SKU ID
           channel_type,             -- 下单渠道（维度）
           seller_staff_id,          -- 售票员
           sale_point_code,          -- 售票站点
           payer_tenant_id,          -- 付款方
           payer_type,               -- 付款方类型
           payee_tenant_id,          -- 收款方
           payee_type,               -- 收款方类型
           sale_unit_price_amt,      -- 卖出单价
           buy_unit_price_amt,       -- 买入单价
           receive_pay_method_type,  -- 收款支付方式
           pay_pay_method_type,      -- 付款支付方式
           in_amt,                   -- 本期收 / 本期付
           out_amt,                  -- 本期退 / 本期退回
           trans_amt,                -- 转实收 / 转实付
           confirm_amt,              -- 履约收入 / 成本结算
           chg_amt AS close_amt,     -- 期末预收 / 期末预付（日终时点值）
           net_ticket_qty,           -- 净票数（预收 / 预付）
           confirm_ticket_qty FROM d
    UNION ALL
    SELECT merchant_tenant_id,       -- 本方商户租户ID
           report_code,              -- 报表
           spu_id,                   -- 产品(SPU)ID
           sku_id,                   -- SKU ID
           channel_type,             -- 下单渠道（维度）
           seller_staff_id,          -- 售票员
           sale_point_code,          -- 售票站点
           payer_tenant_id,          -- 付款方
           payer_type,               -- 付款方类型
           payee_tenant_id,          -- 收款方
           payee_type,               -- 收款方类型
           sale_unit_price_amt,      -- 卖出单价
           buy_unit_price_amt,       -- 买入单价
           receive_pay_method_type,  -- 收款支付方式
           pay_pay_method_type,      -- 付款支付方式
           0,
           0,
           0,
           0,
           close_amt,                -- 期末预收 / 期末预付（日终时点值）
           0,
           0 FROM y
)
SELECT DATE_FORMAT(CURDATE(), '%Y%m%d') AS travel_date,  -- 数据日期
       merchant_tenant_id,           -- 本方商户租户ID
       report_code,                  -- 报表
       spu_id,                       -- 产品(SPU)ID
       sku_id,                       -- SKU ID
       channel_type,                 -- 下单渠道（维度）
       seller_staff_id,              -- 售票员
       sale_point_code,              -- 售票站点
       payer_tenant_id,              -- 付款方
       payer_type,                   -- 付款方类型
       payee_tenant_id,              -- 收款方
       payee_type,                   -- 收款方类型
       sale_unit_price_amt,          -- 卖出单价
       buy_unit_price_amt,           -- 买入单价
       receive_pay_method_type,      -- 收款支付方式
       pay_pay_method_type,          -- 付款支付方式
       SUM(in_amt) AS in_amt,        -- 本期收 / 本期付
       SUM(out_amt) AS out_amt,      -- 本期退 / 本期退回
       SUM(trans_amt) AS trans_amt,  -- 转实收 / 转实付
       SUM(confirm_amt) AS confirm_amt,  -- 履约收入 / 成本结算
       SUM(close_amt) AS close_amt,  -- 期末预收 / 期末预付（日终时点值）
       SUM(net_ticket_qty) AS net_ticket_qty,  -- 净票数（预收 / 预付）
       SUM(confirm_ticket_qty) AS confirm_ticket_qty,  -- 核销票数（确认收入 / 确认成本）
       NOW() AS update_time          -- 最近一次刷新时间
FROM u
GROUP BY merchant_tenant_id,         -- 按粒度键汇总
         report_code,                -- 报表
         spu_id,                     -- 产品(SPU)ID
         sku_id,                     -- SKU ID
         channel_type,               -- 下单渠道（维度）
         seller_staff_id,            -- 售票员
         sale_point_code,            -- 售票站点
         payer_tenant_id,            -- 付款方
         payer_type,                 -- 付款方类型
         payee_tenant_id,            -- 收款方
         payee_type,                 -- 收款方类型
         sale_unit_price_amt,        -- 卖出单价
         buy_unit_price_amt,         -- 买入单价
         receive_pay_method_type,    -- 收款支付方式
         pay_pay_method_type;
