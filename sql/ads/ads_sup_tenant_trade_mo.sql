-- ads.ads_sup_tenant_trade_mo  商户经营月报
-- 粒度：自然月 × seller_tenant_id
-- 来源：dws_sup_tenant_trade_di
-- 生成方式：Spark SQL / Hive；字段 12 个：直接翻译 4 · 规则翻译 7 · 待确认 1
-- 周/月区间可改为关联时间表 dim_opr_period_f（LW/LM）
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT OVERWRITE TABLE ads.ads_sup_tenant_trade_mo PARTITION (travel_date = '${bizdate}')
SELECT
  x.stat_month_code,
  x.seller_tenant_id,
  d1.tenant_name AS seller_tenant_name,
  x.pay_1m_amt,
  x.net_pay_1m_amt,
  x.verify_ticket_1m_qty,
  x.refund_1m_amt,
  x.refund_1m_rate,
  x.gross_profit_1m_amt,
  x.per_customer_1m_amt,
  x.pay_amt_mom_rate,
  x.etl_time
FROM (
SELECT
  u.stat_month_code,
  u.seller_tenant_id,
  SUM(u.pay_amt) AS pay_1m_amt,
  SUM(u.net_pay_amt) AS net_pay_1m_amt,
  SUM(u.verify_ticket_qty) AS verify_ticket_1m_qty,
  SUM(u.refund_amt) AS refund_1m_amt,
  SUM(u.refund_ticket_qty) * 100 / NULLIF(SUM(u.pay_ticket_qty), 0) AS refund_1m_rate,
  SUM(u.pay_amt) - SUM(u.cost_amt) AS gross_profit_1m_amt,
  SUM(u.pay_amt) / NULLIF(SUM(u.pay_buyer_qty), 0) AS per_customer_1m_amt,
  NULL AS pay_amt_mom_rate,  -- 待确认：支付金额月环比 = (本期支付金额-上期支付金额)*100/上期支付金额；本期=本月，上期=上月；保留 6 位小数；分母为 0 时结果为空（需上一周期的值：关联时间表 prev_* 区间计算）
  CURRENT_TIMESTAMP() AS etl_time
FROM (
  -- 来源：dws_sup_tenant_trade_di
  SELECT
    '${last_month_code}' AS stat_month_code,
    s.seller_tenant_id AS seller_tenant_id,
    SUM(s.pay_amt) AS pay_amt,
    SUM(s.net_pay_amt) AS net_pay_amt,
    SUM(s.verify_ticket_qty) AS verify_ticket_qty,
    SUM(s.refund_amt) AS refund_amt,
    SUM(s.refund_ticket_qty) AS refund_ticket_qty,
    SUM(s.pay_ticket_qty) AS pay_ticket_qty,
    SUM(s.cost_amt) AS cost_amt,
    SUM(s.pay_buyer_qty) AS pay_buyer_qty
  FROM dws.dws_sup_tenant_trade_di s
  WHERE s.travel_date BETWEEN '${last_month_start}' AND '${last_month_end}'
  GROUP BY '${last_month_code}', s.seller_tenant_id
) u
GROUP BY u.stat_month_code, u.seller_tenant_id
) x
LEFT JOIN dim.dim_sup_tenant_zip d1 ON d1.tenant_id = x.seller_tenant_id AND d1.travel_date = '${bizdate}' AND d1.end_date = '9999-12-31';
