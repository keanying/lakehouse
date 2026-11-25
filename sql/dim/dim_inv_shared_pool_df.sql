-- dim.dim_inv_shared_pool_df  共享库存配额维度
-- 粒度：1行=1条共享配额
-- 来源：ods_inv_shared_inventory_pool_df
-- 生成方式：Spark SQL / Hive；字段 13 个：直接翻译 13 · 规则翻译 0 · 待确认 0

INSERT OVERWRITE TABLE dim.dim_inv_shared_pool_df PARTITION (travel_date = '${bizdate}')
SELECT
  a.id                             AS shared_pool_id,
  a.relation_id                    AS relation_id,
  a.source_pool_no                 AS source_pool_no,
  ROUND(a.shared_pool_no / 100, 2) AS shared_pool_no,
  a.quota_type                     AS quota_type,
  a.quota_quantity                 AS quota_qty,
  a.quota_used                     AS quota_used_qty,
  a.sharing_status                 AS sharing_status,
  a.create_time                    AS create_time,
  a.update_time                    AS update_time,
  j1.supplier_tenant_id            AS supplier_tenant_id,
  j1.distributor_tenant_id         AS distributor_tenant_id,
  CURRENT_TIMESTAMP()              AS etl_time
FROM ods.ods_inv_shared_inventory_pool_df a
LEFT JOIN ods.ods_trf_distribution_relation_df j1
  ON j1.id = a.relation_id
 AND j1.travel_date = '${bizdate}'
WHERE a.travel_date = '${bizdate}';
