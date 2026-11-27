-- dwd.dwd_opr_device_status_log_di  设备状态变更明细
-- 粒度：1行=1次设备状态/心跳变化
-- 来源：ods_opr_device_df（今日、昨日两个日快照）
-- 生成方式：手写（结构不适合按字段自动翻译）；业务规则：
--   · 设备表是日全量快照：今日状态与昨日不同（或新设备）即记一条变更；变更前 = 昨日状态，变更后 = 今日状态
--   · 前一状态持续时长 = 本次变更时间 − 上一次变更时间（取历史变更明细，没有则取设备创建时间）
--   · 口径说明：日快照只能看到日终状态，一天内多次切换只记最终一次
-- 性能：
--   · 只读两个快照分区 + 近 400 天变更明细的每设备最大变更时间

WITH t AS (
    SELECT id, device_no, tenant_id, device_type, device_group_id, poi_id, device_status, last_heartbeat, update_time, create_time
    FROM ods.ods_opr_device_df WHERE travel_date = '${bizdate}'
),
y AS (
    SELECT id, device_status FROM ods.ods_opr_device_df WHERE travel_date = DATE_FORMAT(DATE_SUB(TO_DATE('${bizdate}', 'yyyyMMdd'), 1), 'yyyyMMdd')
),
last_chg AS (
    SELECT device_id, MAX(change_time) AS last_change_time
    FROM dwd.dwd_opr_device_status_log_di WHERE travel_date >= DATE_FORMAT(DATE_SUB(TO_DATE('${bizdate}', 'yyyyMMdd'), 400), 'yyyyMMdd') AND travel_date < '${bizdate}'
    GROUP BY device_id                                                            -- 按粒度键汇总
)
INSERT OVERWRITE TABLE dwd.dwd_opr_device_status_log_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
    t.id AS device_id, t.device_no, t.tenant_id, t.device_type, t.device_group_id, t.poi_id,
    y.device_status                                               AS before_status,  -- 变更前状态
    t.device_status                                               AS after_status,  -- 变更后状态
    t.last_heartbeat                                              AS last_heartbeat_time,  -- 最后心跳时间
    t.update_time                                                 AS change_time,  -- 状态变更时间
    ROUND((UNIX_TIMESTAMP(t.update_time) - UNIX_TIMESTAMP(COALESCE(lc.last_change_time, t.create_time))) / 60, 2) AS status_minute_qty,  -- 前一状态持续时长（分钟）
    CURRENT_TIMESTAMP() AS etl_time                                               -- ETL 加载时间
FROM t
LEFT JOIN y ON y.id = t.id
LEFT JOIN last_chg lc ON lc.device_id = t.id
WHERE y.id IS NULL OR y.device_status <> t.device_status;
