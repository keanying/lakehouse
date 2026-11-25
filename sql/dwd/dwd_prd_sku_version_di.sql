-- dwd.dwd_prd_sku_version_di  SKU版本变更明细
-- 粒度：1行=1次SKU版本变更
-- 来源：ods_prd_sku_version_snapshot_di
-- 生成方式：Spark SQL / Hive；字段 15 个：直接翻译 11 · 规则翻译 2 · 待确认 2
-- 流水/状态变更类：保留每条变更记录
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT OVERWRITE TABLE dwd.dwd_prd_sku_version_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  a.id                                                 AS snapshot_id,        -- SKU版本快照ID（源表主键 id）
  a.snapshot_no                                        AS snapshot_no,        -- 快照编号
  a.sku_id                                             AS sku_id,             -- SKU ID
  a.version                                            AS version_no,         -- 版本号（变更前的版本号）
  a.changed_by                                         AS change_operator_name,  -- 变更操作人
  a.change_reason                                      AS change_reason_desc,  -- 变更原因
  a.tenant_id                                          AS tenant_id,          -- 租户ID（分库维度）
  a.create_time                                        AS create_time,        -- 创建时间
  a.update_time                                        AS update_time,        -- 更新时间
  j1.version_no                                        AS new_version_no,     -- 变更后版本号｜待确认：dim_prd_sku_zip.version_no 当前值
  GET_JSON_OBJECT(a.snapshot_data, '$.priceChangeLog') AS old_price_amt,      -- 变更前价格（元）
  GET_JSON_OBJECT(a.snapshot_data, '$.priceChangeLog') AS new_price_amt,      -- 变更后价格（元）
  NULL                                                 AS price_change_type,  -- 本次是否改价｜待确认：old_price_amt 与 new_price_amt 比较
  a.create_time                                        AS change_time,        -- 变更时间
  CURRENT_TIMESTAMP()                                  AS etl_time            -- ETL 加载时间
FROM ods.ods_prd_sku_version_snapshot_di a                                    -- 主表「SKU版本快照」
LEFT JOIN dim.dim_prd_sku_zip j1                                              -- 关联「SKU维度」，取 变更后版本号
  ON j1.sku_id = a.sku_id                                                     -- 按 sku_id 关联
 AND j1.travel_date = '${bizdate}' AND j1.end_date = '9999-12-31'             -- 取当日分区里的拉链当前有效版本
WHERE a.travel_date = '${bizdate}';                                           -- 只取当日分区
