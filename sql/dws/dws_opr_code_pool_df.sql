-- dws.dws_opr_code_pool_df  码池使用快照
-- 粒度：travel_date × tenant_id × code_pool_id × pool_type
-- 来源：dim_opr_code_pool_df, dwd_ord_ticket_credential_di
-- 生成方式：Spark SQL / Hive；字段 9 个：直接翻译 3 · 规则翻译 1 · 待确认 5
-- 多来源：每个来源表按粒度键先汇总，UNION ALL 后再合并；快照/累计表：增量来源取截至统计日的全部分区
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT OVERWRITE TABLE dws.dws_opr_code_pool_df PARTITION (travel_date = '${bizdate}')
SELECT
  u.tenant_id,
  u.code_pool_id,
  u.pool_type,
  SUM(u.code_capacity_qty) AS code_capacity_qty,
  SUM(u.code_allocated_qty) AS code_allocated_qty,
  SUM(u.code_recycled_qty) AS code_recycled_qty,
  SUM(u.issue_credential_qty) AS issue_credential_qty,
  SUM(u.revoke_credential_qty) AS revoke_credential_qty,
  CURRENT_TIMESTAMP() AS etl_time
FROM (
  -- 来源：dim_opr_code_pool_df
  SELECT
    tenant_id AS tenant_id,
    code_pool_id AS code_pool_id,
    pool_type AS pool_type,
    NULL AS code_capacity_qty,  -- 待确认：sum(capacity)
    NULL AS code_allocated_qty,  -- 待确认：sum(allocated_count)
    NULL AS code_recycled_qty,  -- 待确认：sum(recycled_count)
    NULL AS issue_credential_qty,
    NULL AS revoke_credential_qty
  FROM dim.dim_opr_code_pool_df s
  WHERE s.travel_date = '${bizdate}'
  GROUP BY tenant_id, code_pool_id, pool_type
  UNION ALL
  -- 来源：dwd_ord_ticket_credential_di
  SELECT
    tenant_id AS tenant_id,
    code_pool_id AS code_pool_id,
    CAST(NULL AS STRING) AS pool_type,
    NULL AS code_capacity_qty,
    NULL AS code_allocated_qty,
    NULL AS code_recycled_qty,
    COUNT(credential_no) AS issue_credential_qty,
    COUNT(CASE WHEN 1 = 1 THEN credential_no END) AS revoke_credential_qty  -- 待确认：status='REVOKED'
  FROM dwd.dwd_ord_ticket_credential_di s
  WHERE s.travel_date <= '${bizdate}'
  GROUP BY tenant_id, code_pool_id
) u
GROUP BY u.tenant_id, u.code_pool_id, u.pool_type;
