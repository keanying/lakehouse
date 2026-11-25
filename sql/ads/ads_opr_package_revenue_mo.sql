-- ads.ads_opr_package_revenue_mo  套餐收入与续费（月）
-- 粒度：月 × package_id
-- 来源：dws_opr_package_subscription_df
-- 生成方式：Spark SQL / Hive；字段 10 个：直接翻译 4 · 规则翻译 6 · 待确认 0
-- 周/月区间可改为关联时间表 dim_opr_period_f（LW/LM）

INSERT OVERWRITE TABLE ads.ads_opr_package_revenue_mo PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  x.stat_month_code,                                  -- 统计自然月
  x.package_id,                                       -- 套餐ID
  d1.package_name AS package_name,                    -- 套餐名称
  x.package_1m_amt,                                   -- 本月套餐金额
  x.package_renew_1m_qty,                             -- 本月续费订购数
  x.package_renew_1m_rate,                            -- 本月套餐续费率
  x.active_subscription_1m_qty,                       -- 本月生效套餐订购数
  x.expiring_30d_subscription_1m_qty,                 -- 本月30天内到期订购数
  x.package_ytd_amt,                                  -- 本年累计套餐金额
  x.etl_time                                          -- ETL 加载时间
FROM (
SELECT
  u.stat_month_code,                                  -- 统计自然月
  u.package_id,                                       -- 套餐ID
  SUM(u.package_amt) AS package_1m_amt,               -- 本月套餐金额
  SUM(u.package_renew_qty) AS package_renew_1m_qty,   -- 本月续费订购数
  SUM(u.package_renew_qty) AS package_renew_1m_rate,  -- 本月套餐续费率
  SUM(u.active_subscription_qty) AS active_subscription_1m_qty,  -- 本月生效套餐订购数
  SUM(u.expiring_30d_subscription_qty) AS expiring_30d_subscription_1m_qty,  -- 本月30天内到期订购数
  SUM(u.package_amt) AS package_ytd_amt,              -- 本年累计套餐金额
  CURRENT_TIMESTAMP() AS etl_time                     -- ETL 加载时间
FROM (
  -- 来源：dws_opr_package_subscription_df
  SELECT
    '${last_month_code}' AS stat_month_code,          -- 统计自然月
    s.package_id AS package_id,                       -- 套餐ID
    SUM(s.package_amt) AS package_amt,
    SUM(s.package_renew_qty) AS package_renew_qty,
    SUM(s.active_subscription_qty) AS active_subscription_qty,
    SUM(s.expiring_30d_subscription_qty) AS expiring_30d_subscription_qty
  FROM dws.dws_opr_package_subscription_df s          -- 来源表「套餐订购存量快照」
  WHERE s.travel_date BETWEEN '${last_month_start}' AND '${last_month_end}'
  GROUP BY '${last_month_code}', s.package_id         -- 按粒度键汇总
) u                                                   -- 各来源合并后的明细
GROUP BY u.stat_month_code, u.package_id              -- 按粒度键汇总
) x                                                   -- 汇总结果，外层再补维度名称
LEFT JOIN dim.dim_opr_package_df d1 ON d1.package_id = x.package_id AND d1.travel_date = '${bizdate}';  -- 关联「套餐维度」，取维度名称
