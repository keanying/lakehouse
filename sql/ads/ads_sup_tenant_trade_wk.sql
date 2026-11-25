-- ads.ads_sup_tenant_trade_wk  商户经营周报
-- 粒度：自然周 × seller_tenant_id
-- 来源：dws_sup_tenant_trade_di
-- 生成方式：Spark SQL / Hive；字段 13 个：直接翻译 5 · 规则翻译 7 · 待确认 1
-- 周/月区间可改为关联时间表 dim_opr_period_f（LW/LM）
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT OVERWRITE TABLE ads.ads_sup_tenant_trade_wk PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  x.stat_week_code,                                               -- 统计自然周
  x.week_start_date,                                              -- 自然周开始日期（周一）
  x.seller_tenant_id,                                             -- 卖家租户ID
  d1.tenant_name AS seller_tenant_name,                           -- 卖家租户名称
  x.pay_1w_amt,                                                   -- 本周支付金额（GMV）
  x.net_pay_1w_amt,                                               -- 本周净成交金额
  x.verify_ticket_1w_qty,                                         -- 本周核销票数
  x.refund_1w_amt,                                                -- 本周退款金额
  x.refund_1w_rate,                                               -- 本周退票率
  x.gross_profit_1w_amt,                                          -- 本周毛利额
  x.per_customer_1w_amt,                                          -- 本周客单价
  x.pay_amt_wow_rate,                                             -- 支付金额周同比
  x.etl_time                                                      -- ETL 加载时间
FROM (
SELECT
  u.stat_week_code,                                               -- 统计自然周
  u.week_start_date,                                              -- 自然周开始日期（周一）
  u.seller_tenant_id,                                             -- 卖家租户ID
  SUM(u.pay_amt) AS pay_1w_amt,                                   -- 本周支付金额（GMV）
  SUM(u.net_pay_amt) AS net_pay_1w_amt,                           -- 本周净成交金额
  SUM(u.verify_ticket_qty) AS verify_ticket_1w_qty,               -- 本周核销票数
  SUM(u.refund_amt) AS refund_1w_amt,                             -- 本周退款金额
  SUM(u.refund_ticket_qty) * 100 / NULLIF(SUM(u.pay_ticket_qty), 0) AS refund_1w_rate,  -- 本周退票率
  SUM(u.pay_amt) - SUM(u.cost_amt) AS gross_profit_1w_amt,        -- 本周毛利额
  SUM(u.pay_amt) / NULLIF(SUM(u.pay_buyer_qty), 0) AS per_customer_1w_amt,  -- 本周客单价
  NULL AS pay_amt_wow_rate,                                       -- 待确认：支付金额周同比 = (本期支付金额-上期支付金额)*100/上期支付金额；日表：本期=统计日，上期=上周同一天；周报：本期=本周，上期=上周；保留 6 位小数；分母为 0 时结果为空（需上一周期的值：关联时间表 prev_* 区间计算）
  CURRENT_TIMESTAMP() AS etl_time                                 -- ETL 加载时间
FROM (
  -- 来源：dws_sup_tenant_trade_di
  SELECT
    '${last_week_code}' AS stat_week_code,                        -- 统计自然周
    '${last_week_start_dash}' AS week_start_date,                 -- 自然周开始日期（周一）
    s.seller_tenant_id AS seller_tenant_id,                       -- 卖家租户ID
    SUM(s.pay_amt) AS pay_amt,
    SUM(s.net_pay_amt) AS net_pay_amt,
    SUM(s.verify_ticket_qty) AS verify_ticket_qty,
    SUM(s.refund_amt) AS refund_amt,
    SUM(s.refund_ticket_qty) AS refund_ticket_qty,
    SUM(s.pay_ticket_qty) AS pay_ticket_qty,
    SUM(s.cost_amt) AS cost_amt,
    SUM(s.pay_buyer_qty) AS pay_buyer_qty
  FROM dws.dws_sup_tenant_trade_di s                              -- 来源表「商户经营日汇总」
  WHERE s.travel_date BETWEEN '${last_week_start}' AND '${last_week_end}'
  GROUP BY '${last_week_code}', '${last_week_start_dash}', s.seller_tenant_id  -- 按粒度键汇总
) u                                                               -- 各来源合并后的明细
GROUP BY u.stat_week_code, u.week_start_date, u.seller_tenant_id  -- 按粒度键汇总
) x                                                               -- 汇总结果，外层再补维度名称
LEFT JOIN dim.dim_sup_tenant_zip d1 ON d1.tenant_id = x.seller_tenant_id AND d1.travel_date = '${bizdate}' AND d1.end_date = '9999-12-31';  -- 关联「租户（商户/供应商/分销商）维度」，取维度名称
