-- ads.ads_opr_code_pool_usage_df  码池使用
-- 粒度：travel_date × tenant_id × code_pool_id
-- 来源：dws_opr_code_pool_df
-- 生成方式：Spark SQL / Hive；字段 13 个：直接翻译 13 · 规则翻译 0 · 待确认 0
-- 来源先按粒度键预聚合；快照/累计表：增量来源取截至统计日的全部分区

WITH
src_code_pool AS (                                      -- 来源「码池使用快照」按粒度键预聚合
  SELECT
    tenant_id AS tenant_id,                             -- 租户ID
    code_pool_id AS code_pool_id,                       -- 码池ID
    SUM(code_capacity_qty) AS code_capacity_qty,        -- 码池容量（日快照）
    SUM(code_allocated_qty) AS code_allocated_qty,      -- 已分配码数（日快照）
    SUM(code_recycled_qty) AS code_recycled_qty,        -- 回收复用码数（日快照）
    SUM(code_allocated_qty) AS code_pool_usage_numerator_qty,  -- 码池使用率分子（日）
    SUM(code_capacity_qty) AS code_pool_usage_denominator_qty,  -- 码池使用率分母（日）
    SUM(code_recycled_qty) AS code_recycle_numerator_qty,  -- 码回收复用率分子（日）
    SUM(code_allocated_qty) AS code_recycle_denominator_qty,  -- 码回收复用率分母（日）
    SUM(issue_credential_qty) AS issue_credential_qty,  -- 发码数（日）
    SUM(revoke_credential_qty) AS revoke_credential_qty  -- 凭证撤销数（日）
  FROM dws.dws_opr_code_pool_df s                       -- 来源表「码池使用快照」
  WHERE s.travel_date = '${bizdate}'                    -- 只取当日分区
  GROUP BY tenant_id, code_pool_id                      -- 按粒度键汇总
),
merged AS (                                             -- 按粒度键汇总，计算派生指标
  SELECT
    u.tenant_id,                                        -- 租户ID
    u.code_pool_id,                                     -- 码池ID
    u.code_capacity_qty,                                -- 码池容量（日快照）
    u.code_allocated_qty,                               -- 已分配码数（日快照）
    u.code_recycled_qty,                                -- 回收复用码数（日快照）
    u.code_pool_usage_numerator_qty,                    -- 码池使用率分子（日）
    u.code_pool_usage_denominator_qty,                  -- 码池使用率分母（日）
    u.code_recycle_numerator_qty,                       -- 码回收复用率分子（日）
    u.code_recycle_denominator_qty,                     -- 码回收复用率分母（日）
    u.issue_credential_qty,                             -- 发码数（日）
    u.revoke_credential_qty,                            -- 凭证撤销数（日）
    CURRENT_TIMESTAMP() AS etl_time                     -- ETL 加载时间
  FROM src_code_pool u
),
tenant_cur AS (                                         -- 「租户（商户/供应商/分销商）维度」当前有效版本，只取名称类字段
  SELECT tenant_id, tenant_name
  FROM dim.dim_sup_tenant_zip
  WHERE travel_date = '${bizdate}' AND end_date = '9999-12-31'  -- 取当日分区里的拉链当前有效版本
),
code_pool_dim AS (                                      -- 「码池维度」当日数据，只取名称类字段
  SELECT code_pool_id, pool_no
  FROM dim.dim_opr_code_pool_df
  WHERE travel_date = '${bizdate}'                      -- 只取当日分区
)
INSERT OVERWRITE TABLE ads.ads_opr_code_pool_usage_df PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT  /*+ BROADCAST(code_pool_dim) */
  merged.tenant_id,                                     -- 租户ID
  merged.code_pool_id,                                  -- 码池ID
  tenant_cur.tenant_name AS tenant_name,                -- 租户名称
  code_pool_dim.pool_no AS code_pool_no,                -- 码池编号
  merged.code_capacity_qty,                             -- 码池容量（日快照）
  merged.code_allocated_qty,                            -- 已分配码数（日快照）
  merged.code_recycled_qty,                             -- 回收复用码数（日快照）
  merged.code_pool_usage_numerator_qty,                 -- 码池使用率分子（日）
  merged.code_pool_usage_denominator_qty,               -- 码池使用率分母（日）
  merged.code_recycle_numerator_qty,                    -- 码回收复用率分子（日）
  merged.code_recycle_denominator_qty,                  -- 码回收复用率分母（日）
  merged.issue_credential_qty,                          -- 发码数（日）
  merged.revoke_credential_qty,                         -- 凭证撤销数（日）
  merged.etl_time                                       -- ETL 加载时间
FROM merged
LEFT JOIN tenant_cur                                    -- 关联「租户（商户/供应商/分销商）维度」，补 tenant_name
  ON tenant_cur.tenant_id = merged.tenant_id            -- 按 tenant_id 关联
LEFT JOIN code_pool_dim                                 -- 关联「码池维度」，补 code_pool_no
  ON code_pool_dim.code_pool_id = merged.code_pool_id;  -- 按 code_pool_id 关联
