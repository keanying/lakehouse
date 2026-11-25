-- dim.dim_opr_code_pool_df  码池维度
-- 粒度：1行=1个码池
-- 来源：ods_opr_code_pool_df
-- 生成方式：Spark SQL / Hive；字段 13 个：直接翻译 12 · 规则翻译 1 · 待确认 0

INSERT OVERWRITE TABLE dim.dim_opr_code_pool_df PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  a.id                                                    AS code_pool_id,   -- 码池ID（源表主键 id）
  a.pool_no                                               AS pool_no,        -- 码池编号
  a.tenant_id                                             AS tenant_id,      -- 归属商户ID
  a.pool_type                                             AS pool_type,      -- 池类型
  a.credential_type                                       AS credential_type,  -- 凭证类型
  a.capacity                                              AS capacity_qty,   -- 池容量（最大并发码数）
  a.allocated_count                                       AS allocated_qty,  -- 已分配码数
  a.recycled_count                                        AS recycled_qty,   -- 已回收复用码数
  a.pool_status                                           AS pool_status,    -- 状态
  a.create_time                                           AS create_time,    -- 创建时间
  a.update_time                                           AS update_time,    -- 更新时间
  (a.capacity) - (a.allocated_count) + (a.recycled_count) AS remain_qty,     -- 剩余可分配码数 = 容量 - 已分配 + 已回收
  CURRENT_TIMESTAMP()                                     AS etl_time        -- ETL 加载时间
FROM ods.ods_opr_code_pool_df a                                              -- 主表「码池」
WHERE a.travel_date = '${bizdate}';                                          -- 只取当日分区
