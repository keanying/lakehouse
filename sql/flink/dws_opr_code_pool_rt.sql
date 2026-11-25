-- dws.dws_opr_code_pool_rt  码池实时余量
-- 粒度：tenant_id × code_pool_id
-- 来源：dwd_opr_code_pool_rt
-- 生成方式：Flink SQL（1 分钟滚动窗口聚合 → StarRocks 主键模型表）；字段 6 个：直接翻译 3 · 规则翻译 0 · 待确认 3
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT INTO dws.dws_opr_code_pool_rt
SELECT
  u.window_start_time,
  u.window_end_time,
  u.travel_date,
  u.tenant_id,
  u.code_pool_id,
  SUM(u.code_capacity_qty) AS code_capacity_qty,
  SUM(u.code_allocated_qty) AS code_allocated_qty,
  SUM(u.code_recycled_qty) AS code_recycled_qty,
  CURRENT_TIMESTAMP AS update_time
FROM (
  -- 来源：dwd_opr_code_pool_rt
  SELECT
    window_start AS window_start_time,
    window_end AS window_end_time,
    travel_date AS travel_date,
    tenant_id AS tenant_id,
    code_pool_id AS code_pool_id,
    NULL AS code_capacity_qty,  -- 待确认：sum(capacity)（与离线同一口径 A138）
    NULL AS code_allocated_qty,  -- 待确认：sum(allocated_count)（与离线同一口径 A139）
    NULL AS code_recycled_qty  -- 待确认：sum(recycled_count)（与离线同一口径 A140）
  FROM TABLE(TUMBLE(TABLE dwd.dwd_opr_code_pool_rt, DESCRIPTOR(event_time), INTERVAL '1' MINUTE)) s
  GROUP BY window_start, window_end, travel_date, tenant_id, code_pool_id
) u
GROUP BY u.window_start_time, u.window_end_time, u.travel_date, u.tenant_id, u.code_pool_id;
