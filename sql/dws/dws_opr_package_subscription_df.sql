-- dws.dws_opr_package_subscription_df  套餐订购存量快照
-- 粒度：travel_date × package_id × subscription_type
-- 来源：dwd_opr_package_subscription_di
-- 生成方式：Spark SQL / Hive；字段 6 个：直接翻译 2 · 规则翻译 4 · 待确认 0
-- 来源先按粒度键预聚合；快照/累计表：增量来源取截至统计日的全部分区

WITH
src_package_subscription AS (                                      -- 来源「套餐订购明细」按粒度键预聚合
  SELECT
    package_id AS package_id,                                      -- 套餐ID
    subscription_type AS subscription_type,                        -- 订购类型
    COUNT(DISTINCT CASE WHEN TO_DATE(start_time) <= '${bizdate_dash}' AND TO_DATE(expire_time) >= '${bizdate_dash}' AND subscription_status <> 'CANCELLED' THEN subscription_no END) AS active_subscription_qty,  -- 生效套餐订购数｜口径：快照日处于生效期、未取消的订购
    SUM(CASE WHEN TO_DATE(start_time) <= '${bizdate_dash}' AND TO_DATE(expire_time) >= '${bizdate_dash}' AND subscription_status <> 'CANCELLED' THEN package_amt END) AS package_amt,  -- 套餐金额｜口径：生效订购的套餐价格合计（DWD 已转元，不再除 100）
    COUNT(DISTINCT CASE WHEN TO_DATE(expire_time) BETWEEN '${bizdate_dash}' AND DATE_ADD('${bizdate_dash}', 30) AND subscription_status <> 'CANCELLED' THEN subscription_no END) AS expiring_30d_subscription_qty,  -- 30天内到期订购数｜口径：到期日在快照日起 30 天内
    COUNT(DISTINCT CASE WHEN subscription_type = 'RENEW' AND TO_DATE(start_time) <= '${bizdate_dash}' AND TO_DATE(expire_time) >= '${bizdate_dash}' THEN subscription_no END) AS package_renew_qty  -- 续费订购数｜口径：生效订购中类型为续费的
  FROM dwd.dwd_opr_package_subscription_di s                       -- 来源表「套餐订购明细」
  WHERE s.travel_date <= '${bizdate}'                              -- 累计口径：取截至统计日的全部分区
  GROUP BY package_id, subscription_type                           -- 按粒度键汇总
)
INSERT OVERWRITE TABLE dws.dws_opr_package_subscription_df PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  u.package_id,                                                    -- 套餐ID
  u.subscription_type,                                             -- 订购类型
  u.active_subscription_qty,                                       -- 生效套餐订购数
  u.package_amt,                                                   -- 套餐金额
  u.expiring_30d_subscription_qty,                                 -- 30天内到期订购数
  u.package_renew_qty,                                             -- 续费订购数
  CURRENT_TIMESTAMP() AS etl_time                                  -- ETL 加载时间
FROM src_package_subscription u;
