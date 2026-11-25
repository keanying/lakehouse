-- dwd.dwd_opr_code_pool_rt  实时码池状态
-- 粒度：1行=1个码池
-- 来源：ods_opr_code_pool_rt
-- 生成方式：Flink SQL（CDC 源表 → StarRocks 主键模型表；维表 Lookup Join）；字段 14 个：直接翻译 12 · 规则翻译 2 · 待确认 0
-- 源表 ods.*_rt 为 Flink CDC 表（含 proc_time AS PROCTIME()），目标表在 StarRocks catalog 中

INSERT INTO dwd.dwd_opr_code_pool_rt
SELECT
  DATE_FORMAT(a.binlog_time, 'yyyyMMdd')                  AS travel_date,
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
  CURRENT_TIMESTAMP                                       AS event_time
FROM ods.ods_opr_code_pool_rt a;
