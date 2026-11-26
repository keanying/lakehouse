-- dim.dim_inv_shared_pool_df  共享库存配额维度
-- 粒度：1行=1条共享配额
-- 来源：ods_inv_shared_inventory_pool_df
-- 生成方式：Spark SQL / Hive；字段 13 个：直接翻译 13 · 规则翻译 0 · 待确认 0
-- 每个 WITH 逻辑块只取用到的列并先过滤分区

WITH
shared_inventory_pool_src AS (                                                    -- 主表「共享库存池」，只取用到的列
  SELECT create_time, id, quota_quantity, quota_type, quota_used, relation_id, shared_pool_no,
         sharing_status, source_pool_no, update_time
  FROM ods.ods_inv_shared_inventory_pool_df
  WHERE travel_date = '${bizdate}'                                                -- 只取当日分区
),
distribution_relation_src AS (                                                    -- 「分销关系」当日数据，只取用到的列
  SELECT distributor_tenant_id, id, supplier_tenant_id
  FROM ods.ods_trf_distribution_relation_df
  WHERE travel_date = '${bizdate}'                                                -- 只取当日分区
)
INSERT OVERWRITE TABLE dim.dim_inv_shared_pool_df PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  shared_inventory_pool_src.id                             AS shared_pool_id,     -- 共享库存池ID（源表主键 id）
  shared_inventory_pool_src.relation_id                    AS relation_id,        -- 分销关系ID
  shared_inventory_pool_src.source_pool_no                 AS source_pool_no,     -- 源库存池编号（供应商池）
  ROUND(shared_inventory_pool_src.shared_pool_no / 100, 2) AS shared_pool_no,     -- 共享池编号（分销商独立池
  shared_inventory_pool_src.quota_type                     AS quota_type,         -- 配额类型
  shared_inventory_pool_src.quota_quantity                 AS quota_qty,          -- 配额数量
  shared_inventory_pool_src.quota_used                     AS quota_used_qty,     -- 已用配额
  shared_inventory_pool_src.sharing_status                 AS sharing_status,     -- 状态
  shared_inventory_pool_src.create_time                    AS create_time,        -- 创建时间
  shared_inventory_pool_src.update_time                    AS update_time,        -- 更新时间
  distribution_relation_src.supplier_tenant_id             AS supplier_tenant_id,  -- 供应商租户ID
  distribution_relation_src.distributor_tenant_id          AS distributor_tenant_id,  -- 分销商租户ID
  CURRENT_TIMESTAMP()                                      AS etl_time            -- ETL 加载时间
FROM shared_inventory_pool_src
LEFT JOIN distribution_relation_src                                               -- 关联「分销关系」，取 供应商租户ID、分销商租户ID
  ON distribution_relation_src.id = shared_inventory_pool_src.relation_id;        -- 按 relation_id→id 关联
