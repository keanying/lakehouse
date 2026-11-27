-- dwd.dwd_prd_sku_version_di  SKU版本变更明细
-- 粒度：1行=1次SKU版本变更
-- 来源：ods_prd_sku_version_snapshot_di
-- 生成方式：Spark SQL / Hive；字段 15 个：直接翻译 11 · 规则翻译 4 · 待确认 0
-- 流水/状态变更类：保留每条变更记录；每个 WITH 逻辑块只取用到的列并先过滤分区

WITH
sku_version_snapshot_chg AS (                                                     -- 主表「SKU版本快照」：保留每条变更记录，只取用到的列
  SELECT change_reason, changed_by, create_time, id, sku_id, snapshot_data, snapshot_no, tenant_id,
         update_time, version
  FROM ods.ods_prd_sku_version_snapshot_di
  WHERE travel_date = '${bizdate}'                                                -- 只取当日分区
),
sku_cur AS (                                                                      -- 「SKU维度」当前有效版本，只取用到的列
  SELECT sku_id, version_no
  FROM dim.dim_prd_sku_zip
  WHERE travel_date = '${bizdate}' AND end_date = '9999-12-31'                    -- 取当日分区里的拉链当前有效版本
)
INSERT OVERWRITE TABLE dwd.dwd_prd_sku_version_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  sku_version_snapshot_chg.id                                  AS snapshot_id,    -- SKU版本快照ID（源表主键 id）
  sku_version_snapshot_chg.snapshot_no                         AS snapshot_no,    -- 快照编号
  sku_version_snapshot_chg.sku_id                              AS sku_id,         -- SKU ID
  sku_version_snapshot_chg.version                             AS version_no,     -- 版本号（变更前的版本号）
  sku_version_snapshot_chg.changed_by                          AS change_operator_name,  -- 变更操作人
  sku_version_snapshot_chg.change_reason                       AS change_reason_desc,  -- 变更原因
  sku_version_snapshot_chg.tenant_id                           AS tenant_id,      -- 租户ID（分库维度）
  sku_version_snapshot_chg.create_time                         AS create_time,    -- 创建时间
  sku_version_snapshot_chg.update_time                         AS update_time,    -- 更新时间
  sku_version_snapshot_chg.version + 1 AS new_version_no,                         -- 变更后版本号｜口径：快照记录的是变更前版本号，变更后 = 变更前 + 1
  ROUND(CAST(GET_JSON_OBJECT(sku_version_snapshot_chg.snapshot_data, '$.priceChangeLog.oldPrice') AS DECIMAL(18,2)) / 100, 2) AS old_price_amt,  -- 变更前价格（元）
  ROUND(CAST(GET_JSON_OBJECT(sku_version_snapshot_chg.snapshot_data, '$.priceChangeLog.newPrice') AS DECIMAL(18,2)) / 100, 2) AS new_price_amt,  -- 变更后价格（元）
  CASE                                                                            -- 本次是否改价｜口径：变更前后价格不同即改价
      WHEN COALESCE(GET_JSON_OBJECT(sku_version_snapshot_chg.snapshot_data, '$.priceChangeLog.oldPrice'), '') <> COALESCE(GET_JSON_OBJECT(sku_version_snapshot_chg.snapshot_data, '$.priceChangeLog.newPrice'), '') THEN 1
      ELSE 0
  END AS price_change_type,                                                       -- 本次是否改价
  sku_version_snapshot_chg.create_time                         AS change_time,    -- 变更时间
  CURRENT_TIMESTAMP()                                          AS etl_time        -- ETL 加载时间
FROM sku_version_snapshot_chg
LEFT JOIN sku_cur                                                                 -- 关联「SKU维度」，取 变更后版本号
  ON sku_cur.sku_id = sku_version_snapshot_chg.sku_id;                            -- 按 sku_id 关联
