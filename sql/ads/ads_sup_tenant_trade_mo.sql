-- ads.ads_sup_tenant_trade_mo  商户经营月报
-- 粒度：自然月 × seller_tenant_id
-- 来源：dws_sup_tenant_trade_di
-- 生成方式：Spark SQL / Hive；字段 12 个：直接翻译 4 · 规则翻译 8 · 待确认 0
-- 来源按粒度键预聚合后按公式计算；周/月区间可改为关联时间表 dim_opr_period_f（LW/LM）

WITH
src_tenant_trade AS (                               -- 来源「商户经营日汇总」按粒度键预聚合
  SELECT
    '${last_month_code}' AS stat_month_code,        -- 统计自然月
    s.seller_tenant_id AS seller_tenant_id,         -- 卖家租户ID
    SUM(s.pay_amt) AS pay_amt,
    SUM(s.net_pay_amt) AS net_pay_amt,
    SUM(s.verify_ticket_qty) AS verify_ticket_qty,
    SUM(s.refund_amt) AS refund_amt,
    SUM(s.refund_ticket_qty) AS refund_ticket_qty,
    SUM(s.pay_ticket_qty) AS pay_ticket_qty,
    SUM(s.cost_amt) AS cost_amt,
    SUM(s.pay_buyer_qty) AS pay_buyer_qty
  FROM dws.dws_sup_tenant_trade_di s                -- 来源表「商户经营日汇总」
  WHERE s.travel_date BETWEEN '${last_month_start}' AND '${last_month_end}'
  GROUP BY s.seller_tenant_id                       -- 按粒度键汇总
),
merged AS (                                         -- 按粒度键汇总，计算派生指标
  SELECT
    u.stat_month_code,                              -- 统计自然月
    u.seller_tenant_id,                             -- 卖家租户ID
    u.pay_amt AS pay_1m_amt,                        -- 本月支付金额（GMV）
    u.net_pay_amt AS net_pay_1m_amt,                -- 本月净成交金额
    u.verify_ticket_qty AS verify_ticket_1m_qty,    -- 本月核销票数
    u.refund_amt AS refund_1m_amt,                  -- 本月退款金额
    u.refund_ticket_qty * 100 / NULLIF(u.pay_ticket_qty, 0) AS refund_1m_rate,  -- 本月退票率
    u.pay_amt - u.cost_amt AS gross_profit_1m_amt,  -- 本月毛利额
    u.pay_amt / NULLIF(u.pay_buyer_qty, 0) AS per_customer_1m_amt,  -- 本月客单价
    ROUND((u.pay_amt - p.p_pay_amt) * 100 / NULLIF(p.p_pay_amt, 0), 6) AS pay_amt_mom_rate,  -- 支付金额月环比｜口径：（本月 − 上月）÷ 上月 × 100；上月为 0 时为空
    CURRENT_TIMESTAMP() AS etl_time                 -- ETL 加载时间
  FROM src_tenant_trade u
    LEFT JOIN (SELECT seller_tenant_id AS p_tenant_id, SUM(pay_amt) AS p_pay_amt FROM dws.dws_sup_tenant_trade_di
               WHERE travel_date BETWEEN DATE_FORMAT(ADD_MONTHS(TO_DATE('${last_month_start}', 'yyyyMMdd'), -1), 'yyyyMMdd')
                                     AND DATE_FORMAT(DATE_SUB(TO_DATE('${last_month_start}', 'yyyyMMdd'), 1), 'yyyyMMdd')
               GROUP BY seller_tenant_id) p ON p.p_tenant_id = u.seller_tenant_id   -- 上上月（上月的环比基期）支付金额
),
tenant_cur AS (                                     -- 「租户（商户/供应商/分销商）维度」当前有效版本，只取名称类字段
  SELECT tenant_id, tenant_name
  FROM dim.dim_sup_tenant_zip
  WHERE travel_date = '${bizdate}' AND end_date = '9999-12-31'  -- 取当日分区里的拉链当前有效版本
)
INSERT OVERWRITE TABLE ads.ads_sup_tenant_trade_mo PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  merged.stat_month_code,                           -- 统计自然月
  merged.seller_tenant_id,                          -- 卖家租户ID
  tenant_cur.tenant_name AS seller_tenant_name,     -- 卖家租户名称
  merged.pay_1m_amt,                                -- 本月支付金额（GMV）
  merged.net_pay_1m_amt,                            -- 本月净成交金额
  merged.verify_ticket_1m_qty,                      -- 本月核销票数
  merged.refund_1m_amt,                             -- 本月退款金额
  merged.refund_1m_rate,                            -- 本月退票率
  merged.gross_profit_1m_amt,                       -- 本月毛利额
  merged.per_customer_1m_amt,                       -- 本月客单价
  merged.pay_amt_mom_rate,                          -- 支付金额月环比
  merged.etl_time                                   -- ETL 加载时间
FROM merged
LEFT JOIN tenant_cur                                -- 关联「租户（商户/供应商/分销商）维度」，补 seller_tenant_name
  ON tenant_cur.tenant_id = merged.seller_tenant_id;  -- 按 seller_tenant_id→tenant_id 关联
