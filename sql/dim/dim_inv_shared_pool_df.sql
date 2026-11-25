-- dim.dim_inv_shared_pool_df  共享库存配额维度
-- 粒度：1行=1条共享配额
-- 来源：ods_inv_shared_inventory_pool_df
-- 生成方式：Spark SQL / Hive；字段 13 个：直接翻译 13 · 规则翻译 0 · 待确认 0

INSERT OVERWRITE TABLE dim.dim_inv_shared_pool_df PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  a.id                             AS shared_pool_id,      -- 共享库存池ID（源表主键 id）
  a.relation_id                    AS relation_id,         -- 分销关系ID
  a.source_pool_no                 AS source_pool_no,      -- 源库存池编号（供应商池）
  ROUND(a.shared_pool_no / 100, 2) AS shared_pool_no,      -- 共享池编号（分销商独立池
  a.quota_type                     AS quota_type,          -- 配额类型
  a.quota_quantity                 AS quota_qty,           -- 配额数量
  a.quota_used                     AS quota_used_qty,      -- 已用配额
  a.sharing_status                 AS sharing_status,      -- 状态
  a.create_time                    AS create_time,         -- 创建时间
  a.update_time                    AS update_time,         -- 更新时间
  j1.supplier_tenant_id            AS supplier_tenant_id,  -- 供应商租户ID
  j1.distributor_tenant_id         AS distributor_tenant_id,  -- 分销商租户ID
  CURRENT_TIMESTAMP()              AS etl_time             -- ETL 加载时间
FROM ods.ods_inv_shared_inventory_pool_df a                -- 主表「共享库存池」
LEFT JOIN ods.ods_trf_distribution_relation_df j1          -- 关联「分销关系」，取 供应商租户ID、分销商租户ID
  ON j1.id = a.relation_id                                 -- 按 relation_id→id 关联
 AND j1.travel_date = '${bizdate}'                         -- 只取当日分区
WHERE a.travel_date = '${bizdate}';                        -- 只取当日分区
