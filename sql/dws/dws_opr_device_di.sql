-- dws.dws_opr_device_di  设备日汇总
-- 粒度：travel_date × tenant_id × device_id
-- 来源：dwd_opr_device_status_log_di, dwd_ord_verify_di
-- 生成方式：Spark SQL / Hive；字段 7 个：直接翻译 2 · 规则翻译 3 · 待确认 2
-- 多来源：每个来源先按粒度键预聚合，UNION ALL 后再汇总
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

WITH
src_device_status_log AS (                          -- 来源「设备状态变更明细」按粒度键预聚合
  SELECT
    tenant_id AS tenant_id,                         -- 租户ID
    device_id AS device_id,                         -- 设备ID
    NULL AS online_minute_qty,                      -- 待确认：sum(状态区间分钟) where ACTIVE
    COUNT(CASE WHEN after_status='OFFLINE' THEN 1 END) AS offline_times_qty,  -- 设备离线次数
    NULL AS verify_entitlement_qty,
    NULL AS device_total_qty,
    NULL AS offline_verify_qty
  FROM dwd.dwd_opr_device_status_log_di s           -- 来源表「设备状态变更明细」
  WHERE s.travel_date = '${bizdate}'                -- 只取当日分区
  GROUP BY tenant_id, device_id                     -- 按粒度键汇总
),
src_verify AS (                                     -- 来源「核销明细（权益级）」按粒度键预聚合
  SELECT
    tenant_id AS tenant_id,                         -- 租户ID
    device_id AS device_id,                         -- 设备ID
    NULL AS online_minute_qty,
    NULL AS offline_times_qty,
    COUNT(CASE WHEN 1 = 1 THEN verify_no END) AS verify_entitlement_qty,  -- 核销权益次数｜待确认：verify_result='SUCCESS'
    NULL AS device_total_qty,
    COUNT(CASE WHEN verify_type='OFFLINE' and verify_result_type = 'SUCCESS' THEN verify_no END) AS offline_verify_qty  -- 离线核销次数
  FROM dwd.dwd_ord_verify_di s                      -- 来源表「核销明细（权益级）」
  WHERE s.travel_date = '${bizdate}'                -- 只取当日分区
  GROUP BY tenant_id, device_id                     -- 按粒度键汇总
),
src_device AS (                                     -- 来源「设备维度」按粒度键预聚合
  SELECT
    tenant_id AS tenant_id,                         -- 租户ID
    device_id AS device_id,                         -- 设备ID
    NULL AS online_minute_qty,
    NULL AS offline_times_qty,
    NULL AS verify_entitlement_qty,
    COUNT(device_id) AS device_total_qty,           -- 设备数
    NULL AS offline_verify_qty
  FROM dim.dim_opr_device_df s                      -- 来源表「设备维度」
  WHERE s.travel_date = '${bizdate}'                -- 只取当日分区
  GROUP BY tenant_id, device_id                     -- 按粒度键汇总
),
all_src AS (                                        -- 各来源字段已对齐，UNION ALL 合并（比多表 FULL JOIN 少 shuffle）
  SELECT * FROM src_device_status_log
  UNION ALL
  SELECT * FROM src_verify
  UNION ALL
  SELECT * FROM src_device
)
INSERT OVERWRITE TABLE dws.dws_opr_device_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  u.tenant_id,                                      -- 租户ID
  u.device_id,                                      -- 设备ID
  SUM(u.online_minute_qty) AS online_minute_qty,    -- 设备在线时长
  SUM(u.offline_times_qty) AS offline_times_qty,    -- 设备离线次数
  SUM(u.verify_entitlement_qty) AS verify_entitlement_qty,  -- 核销权益次数
  SUM(u.device_total_qty) AS device_total_qty,      -- 设备数
  SUM(u.offline_verify_qty) AS offline_verify_qty,  -- 离线核销次数
  CURRENT_TIMESTAMP() AS etl_time                   -- ETL 加载时间
FROM all_src u
GROUP BY u.tenant_id, u.device_id;                  -- 按粒度键汇总
