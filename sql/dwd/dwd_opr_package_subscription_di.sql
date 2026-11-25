-- dwd.dwd_opr_package_subscription_di  套餐订购明细
-- 粒度：1行=1笔套餐订购
-- 来源：ods_opr_package_subscription_di + ods_opr_package_df
-- 生成方式：Spark SQL / Hive；字段 14 个：直接翻译 14 · 规则翻译 0 · 待确认 0
-- ODS 增量按主键取最新一条（ROW_NUMBER），剔除删除记录

INSERT OVERWRITE TABLE dwd.dwd_opr_package_subscription_di PARTITION (travel_date = '${bizdate}')
SELECT
  a.id                             AS subscription_id,
  a.subscription_no                AS subscription_no,
  a.tenant_id                      AS tenant_id,
  a.package_id                     AS package_id,
  a.subscription_type              AS subscription_type,
  a.start_at                       AS start_time,
  a.expire_at                      AS expire_time,
  a.subscription_status            AS subscription_status,
  a.create_time                    AS create_time,
  a.update_time                    AS update_time,
  j1.package_name                  AS package_name,
  ROUND(j2.package_price / 100, 2) AS package_amt,
  j2.duration_days                 AS duration_day_qty,
  CURRENT_TIMESTAMP()              AS etl_time
FROM (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY id ORDER BY binlog_time DESC) AS rn
  FROM ods.ods_opr_package_subscription_di
  WHERE travel_date = '${bizdate}'
) a
LEFT JOIN ods.ods_opr_package_df j1
  ON j1.id = a.package_id
 AND j1.travel_date = '${bizdate}'
LEFT JOIN ods.ods_opr_package_df j2
  ON j2.id = a.tenant_id
 AND j2.travel_date = '${bizdate}'
WHERE a.rn = 1
  AND a.binlog_op_type <> 'DELETE';
