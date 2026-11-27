-- dws.dws_cus_tenant_growth_rt  游客实时增长
-- 粒度：tenant_id × register_channel_id × 窗口
-- 来源：dwd_cus_customer_register_rt
-- 生成方式：Flink SQL（1 分钟滚动窗口聚合 → StarRocks 主键模型表）；字段 4 个：直接翻译 3 · 规则翻译 1 · 待确认 0
-- 来源先按粒度键预聚合

INSERT INTO dws.dws_cus_tenant_growth_rt                                          -- 写入 StarRocks 目标表
WITH
src_customer_register AS (                                                        -- 来源「实时游客注册」按粒度键预聚合（1 分钟滚动窗口）
  SELECT
    window_start AS window_start_time,                                            -- 窗口开始时间
    window_end AS window_end_time,                                                -- 窗口结束时间
    travel_date AS travel_date,                                                   -- 数据日期
    register_tenant_id AS tenant_id,                                              -- 租户ID
    register_channel_id AS register_channel_id,                                   -- 注册渠道ID
    COUNT(CASE WHEN customer_type = 'REAL' THEN customer_id END) AS new_customer_qty  -- 新注册游客数｜口径：只计真人注册账号，剔除占位买家
  FROM TABLE(TUMBLE(TABLE dwd.dwd_cus_customer_register_rt, DESCRIPTOR(event_time), INTERVAL '1' MINUTE)) s  -- 按事件时间切 1 分钟滚动窗口
  GROUP BY window_start, window_end, travel_date, register_tenant_id, register_channel_id  -- 按粒度键汇总
)
SELECT
  u.travel_date,                                                                  -- 数据日期
  u.window_start_time,                                                            -- 窗口开始时间
  u.window_end_time,                                                              -- 窗口结束时间
  u.tenant_id,                                                                    -- 租户ID
  u.register_channel_id,                                                          -- 注册渠道ID
  u.new_customer_qty,                                                             -- 新注册游客数
  CURRENT_TIMESTAMP AS update_time                                                -- 最近一次写入时间
FROM src_customer_register u;
