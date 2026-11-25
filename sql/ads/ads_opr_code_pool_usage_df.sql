-- ads.ads_opr_code_pool_usage_df  码池使用
-- 粒度：travel_date × tenant_id × code_pool_id
-- 来源：dws_opr_code_pool_df
-- 生成方式：Spark SQL / Hive；字段 13 个：直接翻译 13 · 规则翻译 0 · 待确认 0
-- 快照/累计表：增量来源取截至统计日的全部分区

INSERT OVERWRITE TABLE ads.ads_opr_code_pool_usage_df PARTITION (travel_date = '${bizdate}')
SELECT
  x.tenant_id,
  x.code_pool_id,
  d2.pool_no AS code_pool_no,
  d1.tenant_name AS tenant_name,
  x.code_capacity_qty,
  x.code_allocated_qty,
  x.code_recycled_qty,
  x.code_pool_usage_numerator_qty,
  x.code_pool_usage_denominator_qty,
  x.code_recycle_numerator_qty,
  x.code_recycle_denominator_qty,
  x.issue_credential_qty,
  x.revoke_credential_qty,
  x.etl_time
FROM (
SELECT
  u.tenant_id,
  u.code_pool_id,
  SUM(u.code_capacity_qty) AS code_capacity_qty,
  SUM(u.code_allocated_qty) AS code_allocated_qty,
  SUM(u.code_recycled_qty) AS code_recycled_qty,
  SUM(u.code_pool_usage_numerator_qty) AS code_pool_usage_numerator_qty,
  SUM(u.code_pool_usage_denominator_qty) AS code_pool_usage_denominator_qty,
  SUM(u.code_recycle_numerator_qty) AS code_recycle_numerator_qty,
  SUM(u.code_recycle_denominator_qty) AS code_recycle_denominator_qty,
  SUM(u.issue_credential_qty) AS issue_credential_qty,
  SUM(u.revoke_credential_qty) AS revoke_credential_qty,
  CURRENT_TIMESTAMP() AS etl_time
FROM (
  -- 来源：dws_opr_code_pool_df
  SELECT
    tenant_id AS tenant_id,
    code_pool_id AS code_pool_id,
    SUM(code_capacity_qty) AS code_capacity_qty,
    SUM(code_allocated_qty) AS code_allocated_qty,
    SUM(code_recycled_qty) AS code_recycled_qty,
    SUM(code_allocated_qty) AS code_pool_usage_numerator_qty,
    SUM(code_capacity_qty) AS code_pool_usage_denominator_qty,
    SUM(code_recycled_qty) AS code_recycle_numerator_qty,
    SUM(code_allocated_qty) AS code_recycle_denominator_qty,
    SUM(issue_credential_qty) AS issue_credential_qty,
    SUM(revoke_credential_qty) AS revoke_credential_qty
  FROM dws.dws_opr_code_pool_df s
  WHERE s.travel_date = '${bizdate}'
  GROUP BY tenant_id, code_pool_id
) u
GROUP BY u.tenant_id, u.code_pool_id
) x
LEFT JOIN dim.dim_sup_tenant_zip d1 ON d1.tenant_id = x.tenant_id AND d1.travel_date = '${bizdate}' AND d1.end_date = '9999-12-31'
LEFT JOIN dim.dim_opr_code_pool_df d2 ON d2.code_pool_id = x.code_pool_id AND d2.travel_date = '${bizdate}';
