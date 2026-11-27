-- ================================================================================================
-- dim.dim_trf_gate_f  闸机 / 终端维度
-- 粒度：1行=1个终端（闸机 / 手持机）
-- 分区：无分区
-- 调度：每日，ODS 全部完成后；维表之间按上游顺序
-- 上游：ods_trf_device_inout_journal_di
-- 业务规则 / 修正：
--   · 主表 ods.ods_trf_device_inout_journal_di（同名字段命中最多）；仍无来源的字段标「待确认」
-- ================================================================================================
INSERT OVERWRITE TABLE dim.dim_trf_gate_f                                         -- 整表覆盖写入
SELECT
    CAST(land_id AS BIGINT)                                      AS scenic_id,    -- 景区ID
    CAST(NULL AS STRING)                                         AS terminal_no,  -- 终端编号｜待确认：来源未同步
    CAST(NULL AS BIGINT)                                         AS gate_group_id,  -- 闸机组ID｜待确认：来源未同步
    id,                                                                           -- 主键ID
    CAST(sid AS BIGINT)                                          AS supplier_id,  -- 供应商ID（租户ID）
    CAST(tid AS BIGINT)                                          AS ticket_id,    -- 票ID
    num,                                                                          -- 单次出入园数量
    device_key,                                                                   -- 设备特征码
    roll_type,                                                                    -- 类型
    create_day,                                                                   -- 年月日
    create_time,                                                                  -- 创建时间
    node_id,                                                                      -- 节点id
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time           -- ETL 加载时间
FROM ods.ods_trf_device_inout_journal_di
WHERE travel_date = '${bizdate}'                                                  -- 只取当日分区
