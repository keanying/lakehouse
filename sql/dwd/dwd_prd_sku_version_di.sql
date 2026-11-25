-- dwd.dwd_prd_sku_version_di  SKU版本变更明细
-- 粒度：1行=1次SKU版本变更
-- 来源：ods_prd_sku_version_snapshot_di
-- 生成方式：Spark SQL / Hive；字段 15 个：直接翻译 11 · 规则翻译 2 · 待确认 2
-- 流水/状态变更类：保留每条变更记录
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT OVERWRITE TABLE dwd.dwd_prd_sku_version_di PARTITION (travel_date = '${bizdate}')
SELECT
  a.id                                                 AS snapshot_id,
  a.snapshot_no                                        AS snapshot_no,
  a.sku_id                                             AS sku_id,
  a.version                                            AS version_no,
  a.changed_by                                         AS change_operator_name,
  a.change_reason                                      AS change_reason_desc,
  a.tenant_id                                          AS tenant_id,
  a.create_time                                        AS create_time,
  a.update_time                                        AS update_time,
  j1.version_no                                        AS new_version_no,  -- 待确认：dim_prd_sku_zip.version_no 当前值
  GET_JSON_OBJECT(a.snapshot_data, '$.priceChangeLog') AS old_price_amt,
  GET_JSON_OBJECT(a.snapshot_data, '$.priceChangeLog') AS new_price_amt,
  NULL                                                 AS price_change_type,  -- 待确认：old_price_amt 与 new_price_amt 比较
  a.create_time                                        AS change_time,
  CURRENT_TIMESTAMP()                                  AS etl_time
FROM ods.ods_prd_sku_version_snapshot_di a
LEFT JOIN dim.dim_prd_sku_zip j1
  ON j1.sku_id = a.sku_id
 AND j1.travel_date = '${bizdate}' AND j1.end_date = '9999-12-31'
WHERE a.travel_date = '${bizdate}';
