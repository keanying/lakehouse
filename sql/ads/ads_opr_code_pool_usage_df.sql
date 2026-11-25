-- ads.ads_opr_code_pool_usage_df  码池使用
-- 粒度：travel_date × tenant_id × code_pool_id
-- 来源：dws_opr_code_pool_df
-- 生成方式：Spark SQL / Hive；字段 13 个：直接翻译 13 · 规则翻译 0 · 待确认 0
-- 快照/累计表：增量来源取截至统计日的全部分区

INSERT OVERWRITE TABLE ads.ads_opr_code_pool_usage_df PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  x.tenant_id,                                                      -- 租户ID
  x.code_pool_id,                                                   -- 码池ID
  d1.tenant_name AS tenant_name,                                    -- 租户名称
  d2.pool_no AS code_pool_no,                                       -- 码池编号
  x.code_capacity_qty,                                              -- 码池容量（日快照）
  x.code_allocated_qty,                                             -- 已分配码数（日快照）
  x.code_recycled_qty,                                              -- 回收复用码数（日快照）
  x.code_pool_usage_numerator_qty,                                  -- 码池使用率分子（日）
  x.code_pool_usage_denominator_qty,                                -- 码池使用率分母（日）
  x.code_recycle_numerator_qty,                                     -- 码回收复用率分子（日）
  x.code_recycle_denominator_qty,                                   -- 码回收复用率分母（日）
  x.issue_credential_qty,                                           -- 发码数（日）
  x.revoke_credential_qty,                                          -- 凭证撤销数（日）
  x.etl_time                                                        -- ETL 加载时间
FROM (
SELECT
  u.tenant_id,                                                      -- 租户ID
  u.code_pool_id,                                                   -- 码池ID
  SUM(u.code_capacity_qty) AS code_capacity_qty,                    -- 码池容量（日快照）
  SUM(u.code_allocated_qty) AS code_allocated_qty,                  -- 已分配码数（日快照）
  SUM(u.code_recycled_qty) AS code_recycled_qty,                    -- 回收复用码数（日快照）
  SUM(u.code_pool_usage_numerator_qty) AS code_pool_usage_numerator_qty,  -- 码池使用率分子（日）
  SUM(u.code_pool_usage_denominator_qty) AS code_pool_usage_denominator_qty,  -- 码池使用率分母（日）
  SUM(u.code_recycle_numerator_qty) AS code_recycle_numerator_qty,  -- 码回收复用率分子（日）
  SUM(u.code_recycle_denominator_qty) AS code_recycle_denominator_qty,  -- 码回收复用率分母（日）
  SUM(u.issue_credential_qty) AS issue_credential_qty,              -- 发码数（日）
  SUM(u.revoke_credential_qty) AS revoke_credential_qty,            -- 凭证撤销数（日）
  CURRENT_TIMESTAMP() AS etl_time                                   -- ETL 加载时间
FROM (
  -- 来源：dws_opr_code_pool_df
  SELECT
    tenant_id AS tenant_id,                                         -- 租户ID
    code_pool_id AS code_pool_id,                                   -- 码池ID
    SUM(code_capacity_qty) AS code_capacity_qty,                    -- 码池容量（日快照）
    SUM(code_allocated_qty) AS code_allocated_qty,                  -- 已分配码数（日快照）
    SUM(code_recycled_qty) AS code_recycled_qty,                    -- 回收复用码数（日快照）
    SUM(code_allocated_qty) AS code_pool_usage_numerator_qty,       -- 码池使用率分子（日）
    SUM(code_capacity_qty) AS code_pool_usage_denominator_qty,      -- 码池使用率分母（日）
    SUM(code_recycled_qty) AS code_recycle_numerator_qty,           -- 码回收复用率分子（日）
    SUM(code_allocated_qty) AS code_recycle_denominator_qty,        -- 码回收复用率分母（日）
    SUM(issue_credential_qty) AS issue_credential_qty,              -- 发码数（日）
    SUM(revoke_credential_qty) AS revoke_credential_qty             -- 凭证撤销数（日）
  FROM dws.dws_opr_code_pool_df s                                   -- 来源表「码池使用快照」
  WHERE s.travel_date = '${bizdate}'                                -- 只取当日分区
  GROUP BY tenant_id, code_pool_id                                  -- 按粒度键汇总
) u                                                                 -- 各来源合并后的明细
GROUP BY u.tenant_id, u.code_pool_id                                -- 按粒度键汇总
) x                                                                 -- 汇总结果，外层再补维度名称
LEFT JOIN dim.dim_sup_tenant_zip d1 ON d1.tenant_id = x.tenant_id AND d1.travel_date = '${bizdate}' AND d1.end_date = '9999-12-31'  -- 关联「租户（商户/供应商/分销商）维度」，取维度名称
LEFT JOIN dim.dim_opr_code_pool_df d2 ON d2.code_pool_id = x.code_pool_id AND d2.travel_date = '${bizdate}';  -- 关联「码池维度」，取维度名称
