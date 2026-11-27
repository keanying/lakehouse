-- dws.dws_opr_code_pool_df  码池使用快照
-- 粒度：travel_date × tenant_id × code_pool_id × pool_type
-- 来源：dim_opr_code_pool_df, dwd_ord_ticket_credential_di
-- 生成方式：Spark SQL / Hive；字段 9 个：直接翻译 3 · 规则翻译 6 · 待确认 0
-- 多来源：每个来源先按粒度键预聚合，UNION ALL 后再汇总；快照/累计表：增量来源取截至统计日的全部分区
-- 补 0 / 补空列：多来源 UNION ALL 时，某来源不产出的指标补 0 或空，外层按粒度 SUM 后即为各来源之和，不影响结果

WITH
src_code_pool AS (                                  -- 来源「码池维度」按粒度键预聚合
  SELECT
    tenant_id AS tenant_id,                         -- 租户ID
    code_pool_id AS code_pool_id,                   -- 码池ID
    pool_type AS pool_type,                         -- 码池类型
    SUM(capacity_qty) AS code_capacity_qty,         -- 码池容量
    SUM(allocated_qty) AS code_allocated_qty,       -- 已分配码数
    SUM(recycled_qty) AS code_recycled_qty,         -- 回收复用码数
    NULL AS issue_credential_qty,                   -- 发码数：此来源不产出，补空
    NULL AS revoke_credential_qty                   -- 凭证撤销数：此来源不产出，补空
  FROM dim.dim_opr_code_pool_df s                   -- 来源表「码池维度」
  WHERE s.travel_date = '${bizdate}'                -- 只取当日分区
  GROUP BY tenant_id, code_pool_id, pool_type       -- 按粒度键汇总
),
src_ticket_credential AS (                          -- 来源「凭证发码/撤销明细」按粒度键预聚合
  SELECT
    tenant_id AS tenant_id,                         -- 租户ID
    code_pool_id AS code_pool_id,                   -- 码池ID
    CAST(NULL AS STRING) AS pool_type,              -- 码池类型：此来源不产出，补空
    NULL AS code_capacity_qty,                      -- 码池容量：此来源不产出，补空
    NULL AS code_allocated_qty,                     -- 已分配码数：此来源不产出，补空
    NULL AS code_recycled_qty,                      -- 回收复用码数：此来源不产出，补空
    COUNT(credential_no) AS issue_credential_qty,   -- 发码数
    COUNT(CASE WHEN credential_status='REVOKED' THEN credential_no END) AS revoke_credential_qty  -- 凭证撤销数
  FROM dwd.dwd_ord_ticket_credential_di s           -- 来源表「凭证发码/撤销明细」
  WHERE s.travel_date <= '${bizdate}'               -- 累计口径：取截至统计日的全部分区
  GROUP BY tenant_id, code_pool_id                  -- 按粒度键汇总
),
all_src AS (                                        -- 各来源字段已对齐，UNION ALL 合并（比多表 FULL JOIN 少 shuffle）
  SELECT * FROM src_code_pool
  UNION ALL
  SELECT * FROM src_ticket_credential
)
INSERT OVERWRITE TABLE dws.dws_opr_code_pool_df PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  u.tenant_id,                                      -- 租户ID
  u.code_pool_id,                                   -- 码池ID
  u.pool_type,                                      -- 码池类型
  SUM(u.code_capacity_qty) AS code_capacity_qty,    -- 码池容量
  SUM(u.code_allocated_qty) AS code_allocated_qty,  -- 已分配码数
  SUM(u.code_recycled_qty) AS code_recycled_qty,    -- 回收复用码数
  SUM(u.issue_credential_qty) AS issue_credential_qty,  -- 发码数
  SUM(u.revoke_credential_qty) AS revoke_credential_qty,  -- 凭证撤销数
  CURRENT_TIMESTAMP() AS etl_time                   -- ETL 加载时间
FROM all_src u
GROUP BY u.tenant_id, u.code_pool_id, u.pool_type;  -- 按粒度键汇总
