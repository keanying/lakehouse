-- ads.ads_opr_package_revenue_mo  套餐收入与续费（月）
-- 粒度：月 × package_id
-- 来源：dws_opr_package_subscription_df
-- 生成方式：Spark SQL / Hive；字段 10 个：直接翻译 4 · 规则翻译 6 · 待确认 0
-- 周/月区间可改为关联时间表 dim_opr_period_f（LW/LM）

INSERT OVERWRITE TABLE ads.ads_opr_package_revenue_mo PARTITION (travel_date = '${bizdate}')
SELECT
  x.stat_month_code,
  x.package_id,
  d1.package_name AS package_name,
  x.package_1m_amt,
  x.package_renew_1m_qty,
  x.package_renew_1m_rate,
  x.active_subscription_1m_qty,
  x.expiring_30d_subscription_1m_qty,
  x.package_ytd_amt,
  x.etl_time
FROM (
SELECT
  u.stat_month_code,
  u.package_id,
  SUM(u.package_amt) AS package_1m_amt,
  SUM(u.package_renew_qty) AS package_renew_1m_qty,
  SUM(u.package_renew_qty) AS package_renew_1m_rate,
  SUM(u.active_subscription_qty) AS active_subscription_1m_qty,
  SUM(u.expiring_30d_subscription_qty) AS expiring_30d_subscription_1m_qty,
  SUM(u.package_amt) AS package_ytd_amt,
  CURRENT_TIMESTAMP() AS etl_time
FROM (
  -- 来源：dws_opr_package_subscription_df
  SELECT
    '${last_month_code}' AS stat_month_code,
    s.package_id AS package_id,
    SUM(s.package_amt) AS package_amt,
    SUM(s.package_renew_qty) AS package_renew_qty,
    SUM(s.active_subscription_qty) AS active_subscription_qty,
    SUM(s.expiring_30d_subscription_qty) AS expiring_30d_subscription_qty
  FROM dws.dws_opr_package_subscription_df s
  WHERE s.travel_date BETWEEN '${last_month_start}' AND '${last_month_end}'
  GROUP BY '${last_month_code}', s.package_id
) u
GROUP BY u.stat_month_code, u.package_id
) x
LEFT JOIN dim.dim_opr_package_df d1 ON d1.package_id = x.package_id AND d1.travel_date = '${bizdate}';
