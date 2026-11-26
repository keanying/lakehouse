-- dwd.dwd_opr_package_subscription_di  套餐订购明细
-- 粒度：1行=1笔套餐订购
-- 来源：ods_opr_package_subscription_di + ods_opr_package_df
-- 生成方式：Spark SQL / Hive；字段 14 个：直接翻译 14 · 规则翻译 0 · 待确认 0
-- 主表增量先去重再关联；每个 WITH 逻辑块只取用到的列并先过滤分区

WITH
package_subscription_rn AS (                                             -- 「套餐订购」当日增量，同一主键按 binlog 时间倒序编号
  SELECT create_time, expire_at, id, package_id, start_at, subscription_no, subscription_status,
         subscription_type, tenant_id, update_time, binlog_op_type,
         ROW_NUMBER() OVER (PARTITION BY id ORDER BY binlog_time DESC) AS rn  -- 同一主键多次变更，按 binlog 时间倒序编号
  FROM ods.ods_opr_package_subscription_di
  WHERE travel_date = '${bizdate}'                                       -- 只取当日分区
),
package_subscription_latest AS (                                         -- 「套餐订购」每个主键只保留最新一条，剔除已删除记录
  SELECT create_time, expire_at, id, package_id, start_at, subscription_no, subscription_status,
         subscription_type, tenant_id, update_time
  FROM package_subscription_rn
  WHERE rn = 1
    AND binlog_op_type <> 'DELETE'                                       -- 剔除源库已删除的记录
),
package_src AS (                                                         -- 「套餐包」当日数据，只取用到的列
  SELECT duration_days, id, package_name, package_price
  FROM ods.ods_opr_package_df
  WHERE travel_date = '${bizdate}'                                       -- 只取当日分区
)
INSERT OVERWRITE TABLE dwd.dwd_opr_package_subscription_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  package_subscription_latest.id                  AS subscription_id,    -- 套餐订购ID（源表主键 id）
  package_subscription_latest.subscription_no     AS subscription_no,    -- 订购编号
  package_subscription_latest.tenant_id           AS tenant_id,          -- 租户ID
  package_subscription_latest.package_id          AS package_id,         -- 套餐ID
  package_subscription_latest.subscription_type   AS subscription_type,  -- 类型
  package_subscription_latest.start_at            AS start_time,         -- 生效时间
  package_subscription_latest.expire_at           AS expire_time,        -- 到期时间
  package_subscription_latest.subscription_status AS subscription_status,  -- 状态
  package_subscription_latest.create_time         AS create_time,        -- 创建时间
  package_subscription_latest.update_time         AS update_time,        -- 更新时间
  package_src.package_name                        AS package_name,       -- 套餐名称
  ROUND(package_src.package_price / 100, 2)       AS package_amt,        -- 套餐价格（元）
  package_src.duration_days                       AS duration_day_qty,   -- 订购时长（天）
  CURRENT_TIMESTAMP()                             AS etl_time            -- ETL 加载时间
FROM package_subscription_latest
LEFT JOIN package_src                                                    -- 关联「套餐包」，取 套餐名称、套餐价格（元）、订购时长（天）
  ON package_src.id = package_subscription_latest.package_id;            -- 按 package_id→id 关联
