-- ================================================================================================
-- dim.dim_trf_gate_f  闸机 / 终端维度
-- 粒度：1行=1个终端（闸机 / 手持机，按设备特征码）
-- 分区：无分区
-- 调度：每日，ODS 全部完成后；维表之间按上游顺序
-- 上游：ods_trf_device_inout_journal_di
-- 业务规则 / 修正：
--   · 流水只有设备特征码、没有设备主表：维表按「昨日维表 ∪ 今日流水」滚动，属性取最新非空，首次上线用全量历史流水初始化一次
--   · 旧表的 单次数量 / 进出类型 / 创建时间 等是流水字段，在 dwd_trf_scenic_inout_di（出入园明细）
-- ================================================================================================
INSERT OVERWRITE TABLE dim.dim_trf_gate_f                                         -- 整表覆盖写入
SELECT
    device_key                                                   AS terminal_no,  -- 终端编号（设备特征码）
    CAST(node_id AS BIGINT)                                      AS gate_group_id,  -- 闸机组（节点）ID
    CAST(land_id AS BIGINT)                                      AS scenic_id,    -- 景区ID
    CAST(sid AS BIGINT)                                          AS supplier_id,  -- 供应商ID（租户ID）
    CAST(site_id AS BIGINT)                                      AS site_id,      -- 站点ID
    first_seen_time,                                                              -- 首次出现时间（首条出入园记录）
    last_seen_time,                                                               -- 最近出现时间
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time           -- ETL 加载时间
FROM (
        SELECT device_key,
               MAX(node_id) AS node_id,                                           -- 通道id
               MAX(land_id) AS land_id,                                           -- 景区id
               MAX(sid) AS sid,                                                   -- 供应商ID（租户ID）
               MAX(site_id) AS site_id,                                           -- 站点ID
               MIN(first_seen_time) AS first_seen_time,                           -- 首次出现时间（首条出入园记录）
               MAX(last_seen_time) AS last_seen_time                              -- 最近出现时间
        FROM (SELECT terminal_no AS device_key, gate_group_id AS node_id, scenic_id AS land_id, supplier_id AS sid, site_id, first_seen_time, last_seen_time
              FROM dim.dim_trf_gate_f                                             -- 昨日维表（全量）
              UNION ALL
              SELECT device_key,
                     node_id,
                     land_id,
                     sid,
                     site_id,                                                     -- 站点ID
                     FROM_UNIXTIME(create_time) AS first_seen_time,               -- 首次出现时间（首条出入园记录）
                     FROM_UNIXTIME(create_time) AS last_seen_time                 -- 最近出现时间
              FROM ods.ods_trf_device_inout_journal_di WHERE travel_date = '${bizdate}') u  -- 今日流水
        GROUP BY device_key                                                       -- 按粒度键汇总
    ) t
