-- dws.dws_opr_device_rt  设备实时状态
-- 粒度：tenant_id × device_id
-- 来源：dwd_opr_device_status_log_rt
-- 生成方式：Flink SQL（持续聚合（快照类，按主键更新） → StarRocks 主键模型表）；字段 5 个：直接翻译 3 · 规则翻译 2 · 待确认 0

INSERT INTO dws.dws_opr_device_rt                 -- 写入 StarRocks 目标表
SELECT
  u.travel_date,                                  -- 数据日期
  u.tenant_id,                                    -- 租户ID
  u.device_id,                                    -- 设备ID
  SUM(u.offline_times_qty) AS offline_times_qty,  -- 设备离线次数
  SUM(u.device_total_qty) AS device_total_qty,    -- 设备数
  CURRENT_TIMESTAMP AS update_time                -- 最近一次写入时间
FROM (
  -- 来源：dwd_opr_device_status_log_rt
  SELECT
    travel_date AS travel_date,                   -- 数据日期
    tenant_id AS tenant_id,                       -- 租户ID
    device_id AS device_id,                       -- 设备ID
    COUNT(CASE WHEN after_status='OFFLINE' THEN 1 END) AS offline_times_qty,  -- 设备离线次数
    COUNT(device_id) AS device_total_qty          -- 设备数
  FROM dwd.dwd_opr_device_status_log_rt s         -- 来源表「实时设备状态变更」
  GROUP BY travel_date, tenant_id, device_id      -- 按粒度键汇总
) u                                               -- 各来源合并后的明细
GROUP BY u.travel_date, u.tenant_id, u.device_id;  -- 按粒度键汇总
