-- dws.dws_opr_code_pool_rt  码池实时余量
-- 粒度：tenant_id × code_pool_id
-- 来源：dwd_opr_code_pool_rt
-- 生成方式：Flink SQL（持续聚合（快照类，按主键更新） → StarRocks 主键模型表）；字段 6 个：直接翻译 3 · 规则翻译 0 · 待确认 3
-- 来源先按粒度键预聚合
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT INTO dws.dws_opr_code_pool_rt  -- 写入 StarRocks 目标表
WITH
src_code_pool AS (                  -- 来源「实时码池状态」按粒度键预聚合
  SELECT
    travel_date AS travel_date,     -- 数据日期
    tenant_id AS tenant_id,         -- 租户ID
    code_pool_id AS code_pool_id,   -- 码池ID
    NULL AS code_capacity_qty,      -- 待确认：sum(capacity)（与离线同一口径 A138）
    NULL AS code_allocated_qty,     -- 待确认：sum(allocated_count)（与离线同一口径 A139）
    NULL AS code_recycled_qty       -- 待确认：sum(recycled_count)（与离线同一口径 A140）
  FROM dwd.dwd_opr_code_pool_rt s   -- 来源表「实时码池状态」
  GROUP BY travel_date, tenant_id, code_pool_id  -- 按粒度键汇总
)
SELECT
  u.travel_date,                    -- 数据日期
  u.tenant_id,                      -- 租户ID
  u.code_pool_id,                   -- 码池ID
  u.code_capacity_qty,              -- 码池容量
  u.code_allocated_qty,             -- 已分配码数
  u.code_recycled_qty,              -- 回收复用码数
  CURRENT_TIMESTAMP AS update_time  -- 最近一次写入时间
FROM src_code_pool u;
