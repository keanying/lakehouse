-- dws.dws_opr_code_pool_df  码池使用快照
-- 粒度：travel_date × tenant_id × code_pool_id × pool_type
-- 来源：dim_opr_code_pool_df, dwd_ord_ticket_credential_di
-- 生成方式：Spark SQL / Hive；字段 9 个：直接翻译 3 · 规则翻译 1 · 待确认 5
-- 多来源：每个来源表按粒度键先汇总，UNION ALL 后再合并；快照/累计表：增量来源取截至统计日的全部分区
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

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
FROM (
  -- 来源：dim_opr_code_pool_df
  SELECT
    tenant_id AS tenant_id,                         -- 租户ID
    code_pool_id AS code_pool_id,                   -- 码池ID
    pool_type AS pool_type,                         -- 码池类型
    NULL AS code_capacity_qty,                      -- 码池容量｜待确认：sum(capacity)
    NULL AS code_allocated_qty,                     -- 已分配码数｜待确认：sum(allocated_count)
    NULL AS code_recycled_qty,                      -- 回收复用码数｜待确认：sum(recycled_count)
    NULL AS issue_credential_qty,                   -- 发码数
    NULL AS revoke_credential_qty                   -- 凭证撤销数
  FROM dim.dim_opr_code_pool_df s                   -- 来源表「码池维度」
  WHERE s.travel_date = '${bizdate}'                -- 只取当日分区
  GROUP BY tenant_id, code_pool_id, pool_type       -- 按粒度键汇总
  UNION ALL                                         -- 合并各来源
  -- 来源：dwd_ord_ticket_credential_di
  SELECT
    tenant_id AS tenant_id,                         -- 租户ID
    code_pool_id AS code_pool_id,                   -- 码池ID
    CAST(NULL AS STRING) AS pool_type,              -- 码池类型
    NULL AS code_capacity_qty,                      -- 码池容量
    NULL AS code_allocated_qty,                     -- 已分配码数
    NULL AS code_recycled_qty,                      -- 回收复用码数
    COUNT(credential_no) AS issue_credential_qty,   -- 发码数
    COUNT(CASE WHEN 1 = 1 THEN credential_no END) AS revoke_credential_qty  -- 凭证撤销数｜待确认：status='REVOKED'
  FROM dwd.dwd_ord_ticket_credential_di s           -- 来源表「凭证发码/撤销明细」
  WHERE s.travel_date <= '${bizdate}'               -- 累计口径：取截至统计日的全部分区
  GROUP BY tenant_id, code_pool_id                  -- 按粒度键汇总
) u                                                 -- 各来源合并后的明细
GROUP BY u.tenant_id, u.code_pool_id, u.pool_type;  -- 按粒度键汇总
