-- dws.dws_opr_package_subscription_df  套餐订购存量快照
-- 粒度：travel_date × package_id × subscription_type
-- 来源：dwd_opr_package_subscription_di
-- 生成方式：Spark SQL / Hive；字段 6 个：直接翻译 2 · 规则翻译 0 · 待确认 4
-- 快照/累计表：增量来源取截至统计日的全部分区
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT OVERWRITE TABLE dws.dws_opr_package_subscription_df PARTITION (travel_date = '${bizdate}')
SELECT
  u.package_id,
  u.subscription_type,
  SUM(u.active_subscription_qty) AS active_subscription_qty,
  SUM(u.package_amt) AS package_amt,
  SUM(u.expiring_30d_subscription_qty) AS expiring_30d_subscription_qty,
  SUM(u.package_renew_qty) AS package_renew_qty,
  CURRENT_TIMESTAMP() AS etl_time
FROM (
  -- 来源：dwd_opr_package_subscription_di
  SELECT
    package_id AS package_id,
    subscription_type AS subscription_type,
    COUNT(CASE WHEN 1 = 1 THEN 1 END) AS active_subscription_qty,  -- 待确认：start_at<=snapshot<=expire_at
    NULL AS package_amt,  -- 待确认：sum(package_price)/100
    COUNT(CASE WHEN 1 = 1 THEN 1 END) AS expiring_30d_subscription_qty,  -- 待确认：expire_at<=snapshot+30
    COUNT(CASE WHEN 1 = 1 THEN 1 END) AS package_renew_qty  -- 待确认：type='RENEW'
  FROM dwd.dwd_opr_package_subscription_di s
  WHERE s.travel_date <= '${bizdate}'
  GROUP BY package_id, subscription_type
) u
GROUP BY u.package_id, u.subscription_type;
