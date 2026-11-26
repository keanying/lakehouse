-- dim.dim_opr_code_pool_df  码池维度
-- 粒度：1行=1个码池
-- 来源：ods_opr_code_pool_df
-- 生成方式：Spark SQL / Hive；字段 13 个：直接翻译 12 · 规则翻译 1 · 待确认 0
-- 每个 WITH 逻辑块只取用到的列并先过滤分区

WITH
code_pool_src AS (                                                                -- 主表「码池」，只取用到的列
  SELECT allocated_count, capacity, create_time, credential_type, id, pool_no, pool_status, pool_type,
         recycled_count, tenant_id, update_time
  FROM ods.ods_opr_code_pool_df
  WHERE travel_date = '${bizdate}'                                                -- 只取当日分区
)
INSERT OVERWRITE TABLE dim.dim_opr_code_pool_df PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  code_pool_src.id                                             AS code_pool_id,   -- 码池ID（源表主键 id）
  code_pool_src.pool_no                                        AS pool_no,        -- 码池编号
  code_pool_src.tenant_id                                      AS tenant_id,      -- 归属商户ID
  code_pool_src.pool_type                                      AS pool_type,      -- 池类型
  code_pool_src.credential_type                                AS credential_type,  -- 凭证类型
  code_pool_src.capacity                                       AS capacity_qty,   -- 池容量（最大并发码数）
  code_pool_src.allocated_count                                AS allocated_qty,  -- 已分配码数
  code_pool_src.recycled_count                                 AS recycled_qty,   -- 已回收复用码数
  code_pool_src.pool_status                                    AS pool_status,    -- 状态
  code_pool_src.create_time                                    AS create_time,    -- 创建时间
  code_pool_src.update_time                                    AS update_time,    -- 更新时间
  (code_pool_src.capacity) - (code_pool_src.allocated_count) + (code_pool_src.recycled_count) AS remain_qty,  -- 剩余可分配码数 = 容量 - 已分配 + 已回收
  CURRENT_TIMESTAMP()                                          AS etl_time        -- ETL 加载时间
FROM code_pool_src;
