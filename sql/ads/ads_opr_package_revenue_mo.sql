-- ads.ads_opr_package_revenue_mo  套餐收入与续费（月）
-- 粒度：月 × package_id
-- 来源：dws_opr_package_subscription_df
-- 生成方式：Spark SQL / Hive；字段 10 个：直接翻译 4 · 规则翻译 6 · 待确认 0
-- 来源按粒度键预聚合后按公式计算；周/月区间可改为关联时间表 dim_opr_period_f（LW/LM）

WITH
src_package_subscription AS (                     -- 来源「套餐订购存量快照」按粒度键预聚合
  SELECT
    '${last_month_code}' AS stat_month_code,      -- 统计自然月
    s.package_id AS package_id,                   -- 套餐ID
    SUM(s.package_amt) AS package_amt,
    SUM(s.package_renew_qty) AS package_renew_qty,
    SUM(s.active_subscription_qty) AS active_subscription_qty,
    SUM(s.expiring_30d_subscription_qty) AS expiring_30d_subscription_qty
  FROM dws.dws_opr_package_subscription_df s      -- 来源表「套餐订购存量快照」
  WHERE s.travel_date BETWEEN '${last_month_start}' AND '${last_month_end}'
  GROUP BY s.package_id                           -- 按粒度键汇总
),
merged AS (                                       -- 按粒度键汇总，计算派生指标
  SELECT
    u.stat_month_code,                            -- 统计自然月
    u.package_id,                                 -- 套餐ID
    u.package_amt AS package_1m_amt,              -- 本月套餐金额
    u.package_renew_qty AS package_renew_1m_qty,  -- 本月续费订购数
    u.package_renew_qty AS package_renew_1m_rate,  -- 本月套餐续费率
    u.active_subscription_qty AS active_subscription_1m_qty,  -- 本月生效套餐订购数
    u.expiring_30d_subscription_qty AS expiring_30d_subscription_1m_qty,  -- 本月30天内到期订购数
    u.package_amt AS package_ytd_amt,             -- 本年累计套餐金额
    CURRENT_TIMESTAMP() AS etl_time               -- ETL 加载时间
  FROM src_package_subscription u
),
package_dim AS (                                  -- 「套餐维度」当日数据，只取名称类字段
  SELECT package_id, package_name
  FROM dim.dim_opr_package_df
  WHERE travel_date = '${bizdate}'                -- 只取当日分区
)
INSERT OVERWRITE TABLE ads.ads_opr_package_revenue_mo PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT  /*+ BROADCAST(package_dim) */
  merged.stat_month_code,                         -- 统计自然月
  merged.package_id,                              -- 套餐ID
  package_dim.package_name AS package_name,       -- 套餐名称
  merged.package_1m_amt,                          -- 本月套餐金额
  merged.package_renew_1m_qty,                    -- 本月续费订购数
  merged.package_renew_1m_rate,                   -- 本月套餐续费率
  merged.active_subscription_1m_qty,              -- 本月生效套餐订购数
  merged.expiring_30d_subscription_1m_qty,        -- 本月30天内到期订购数
  merged.package_ytd_amt,                         -- 本年累计套餐金额
  merged.etl_time                                 -- ETL 加载时间
FROM merged
LEFT JOIN package_dim                             -- 关联「套餐维度」，补 package_name
  ON package_dim.package_id = merged.package_id;  -- 按 package_id 关联
