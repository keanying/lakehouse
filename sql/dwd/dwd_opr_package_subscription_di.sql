-- dwd.dwd_opr_package_subscription_di  套餐订购明细
-- 粒度：1行=1笔套餐订购
-- 来源：ods_opr_package_subscription_di + ods_opr_package_df
-- 生成方式：Spark SQL / Hive；字段 14 个：直接翻译 14 · 规则翻译 0 · 待确认 0
-- ODS 增量按主键取最新一条（ROW_NUMBER），剔除删除记录

INSERT OVERWRITE TABLE dwd.dwd_opr_package_subscription_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  a.id                             AS subscription_id,    -- 套餐订购ID（源表主键 id）
  a.subscription_no                AS subscription_no,    -- 订购编号
  a.tenant_id                      AS tenant_id,          -- 租户ID
  a.package_id                     AS package_id,         -- 套餐ID
  a.subscription_type              AS subscription_type,  -- 类型
  a.start_at                       AS start_time,         -- 生效时间
  a.expire_at                      AS expire_time,        -- 到期时间
  a.subscription_status            AS subscription_status,  -- 状态
  a.create_time                    AS create_time,        -- 创建时间
  a.update_time                    AS update_time,        -- 更新时间
  j1.package_name                  AS package_name,       -- 套餐名称
  ROUND(j2.package_price / 100, 2) AS package_amt,        -- 套餐价格（元）
  j2.duration_days                 AS duration_day_qty,   -- 订购时长（天）
  CURRENT_TIMESTAMP()              AS etl_time            -- ETL 加载时间
FROM (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY id ORDER BY binlog_time DESC) AS rn  -- 同一主键多次变更，按 binlog 时间倒序编号
  FROM ods.ods_opr_package_subscription_di
  WHERE travel_date = '${bizdate}'                        -- 只取当日分区
) a                                                       -- 主表当日增量，按主键取最新一条
LEFT JOIN ods.ods_opr_package_df j1                       -- 关联「套餐包」，取 套餐名称
  ON j1.id = a.package_id                                 -- 按 package_id→id 关联
 AND j1.travel_date = '${bizdate}'                        -- 只取当日分区
LEFT JOIN ods.ods_opr_package_df j2                       -- 关联「套餐包」，取 套餐价格（元）、订购时长（天）
  ON j2.id = a.tenant_id                                  -- 按 tenant_id→id 关联
 AND j2.travel_date = '${bizdate}'                        -- 只取当日分区
WHERE a.rn = 1                                            -- 只保留每个主键的最新一条
  AND a.binlog_op_type <> 'DELETE';                       -- 剔除源库已删除的记录
