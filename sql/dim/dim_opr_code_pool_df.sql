-- dim.dim_opr_code_pool_df  码池维度
-- 粒度：1行=1个码池
-- 来源：ods_opr_code_pool_df
-- 生成方式：Spark SQL / Hive；字段 13 个：直接翻译 12 · 规则翻译 1 · 待确认 0

INSERT OVERWRITE TABLE dim.dim_opr_code_pool_df PARTITION (travel_date = '${bizdate}')
SELECT
  a.id                                                    AS code_pool_id,
  a.pool_no                                               AS pool_no,
  a.tenant_id                                             AS tenant_id,
  a.pool_type                                             AS pool_type,
  a.credential_type                                       AS credential_type,
  a.capacity                                              AS capacity_qty,
  a.allocated_count                                       AS allocated_qty,
  a.recycled_count                                        AS recycled_qty,
  a.pool_status                                           AS pool_status,
  a.create_time                                           AS create_time,
  a.update_time                                           AS update_time,
  (a.capacity) - (a.allocated_count) + (a.recycled_count) AS remain_qty,
  CURRENT_TIMESTAMP()                                     AS etl_time
FROM ods.ods_opr_code_pool_df a
WHERE a.travel_date = '${bizdate}';
