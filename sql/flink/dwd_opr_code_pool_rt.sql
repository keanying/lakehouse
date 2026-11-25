-- dwd.dwd_opr_code_pool_rt  实时码池状态
-- 粒度：1行=1个码池
-- 来源：ods_opr_code_pool_rt
-- 生成方式：Flink SQL（CDC 源表 → StarRocks 主键模型表；维表 Lookup Join）；字段 14 个：直接翻译 12 · 规则翻译 2 · 待确认 0
-- 源表 ods.*_rt 为 Flink CDC 表（含 proc_time AS PROCTIME()），目标表在 StarRocks catalog 中

INSERT INTO dwd.dwd_opr_code_pool_rt                                        -- 写入 StarRocks 目标表
SELECT
  DATE_FORMAT(a.binlog_time, 'yyyyMMdd')                  AS travel_date,   -- 数据日期
  a.id                                                    AS code_pool_id,  -- 码池ID（源表主键 id）
  a.pool_no                                               AS pool_no,       -- 码池编号
  a.tenant_id                                             AS tenant_id,     -- 归属商户ID
  a.pool_type                                             AS pool_type,     -- 池类型
  a.credential_type                                       AS credential_type,  -- 凭证类型
  a.capacity                                              AS capacity_qty,  -- 池容量（最大并发码数）
  a.allocated_count                                       AS allocated_qty,  -- 已分配码数
  a.recycled_count                                        AS recycled_qty,  -- 已回收复用码数
  a.pool_status                                           AS pool_status,   -- 状态
  a.create_time                                           AS create_time,   -- 创建时间
  a.update_time                                           AS update_time,   -- 更新时间
  (a.capacity) - (a.allocated_count) + (a.recycled_count) AS remain_qty,    -- 剩余可分配码数 = 容量 - 已分配 + 已回收
  CURRENT_TIMESTAMP                                       AS event_time     -- 事件时间（binlog 时间）
FROM ods.ods_opr_code_pool_rt a;
