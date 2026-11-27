-- ================================================================================================
-- dwd.dwd_trf_scenic_inout_di  出入园明细
-- 粒度：1行=1次过闸（入园 / 离园）
-- 分区：travel_date（YYYYMMDD）
-- 调度：每日，依赖上游 ODS 当日分区与相关维表
-- 上游：ods_trf_device_inout_journal_di
-- 替代旧任务 2 个（上线对数一致后下线）：
--   · 数据平台/平台湖仓工作流/出入园数据/dwd_trf_tourist_in_out_details_di（SERVERLESS_SPARK_SQL，cron 00 00 00 * * ?）
--   · 数据平台/平台湖仓工作流/景区实时客流/tmp_src_trf_scenic_access_record_hrs_f（DI，cron 00 00 00 * * ?）
-- 业务规则 / 修正：
--   · 修正进出方向：源表 roll_type 0 = 入园、1 = 离园（原映射为 1 进 2 出，进出人数整体错位）
--   · 当日累计（旧 all_num 来自报表库预计算 dc_daycount）改为按流水窗口累加，不再依赖预计算表
-- ================================================================================================
INSERT OVERWRITE TABLE dwd.dwd_trf_scenic_inout_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
    CAST(id AS BIGINT)                                           AS inout_id,     -- 流水ID
    CAST(land_id AS BIGINT)                                      AS scenic_id,    -- 景区ID
    CAST(sid AS BIGINT)                                          AS supplier_id,  -- 供应商ID（租户ID）
    CAST(tid AS BIGINT)                                          AS ticket_id,    -- 票ID
    device_key                                                   AS terminal_no,  -- 终端编号（设备特征码）
    CAST(node_id AS BIGINT)                                      AS gate_group_id,  -- 闸机组（节点）ID
    CAST(site_id AS BIGINT)                                      AS site_id,      -- 站点ID
    CASE roll_type WHEN 0 THEN 'IN' WHEN 1 THEN 'OUT' ELSE 'OTHER' END AS inout_type,  -- 进出方向
    CAST(num AS BIGINT)                                          AS person_qty,   -- 本次通过人数
    FROM_UNIXTIME(create_time)                                   AS inout_time,   -- 过闸时间
    FROM_UNIXTIME(create_time, 'yyyy-MM-dd')                     AS visit_date,   -- 游览日期
    CAST(FROM_UNIXTIME(create_time, 'H') AS INT)                 AS visit_hour,   -- 过闸小时（0-23）
    CAST(day_cum_qty AS BIGINT)                                  AS day_cum_qty,  -- 当日截至本次的累计人数（同景区、同方向）
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time           -- ETL 加载时间
FROM (
        SELECT j.*,
               SUM(num) OVER (
                   PARTITION BY land_id,
                   roll_type ORDER BY create_time,
                   id ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
               ) AS day_cum_qty                                                   -- 当日截至本次的累计人数（同景区、同方向）
        FROM (SELECT *, ROW_NUMBER() OVER (PARTITION BY id ORDER BY create_time DESC) AS rn  -- 同一主键多次变更，按 binlog 时间倒序编号
            FROM ods.ods_trf_device_inout_journal_di WHERE travel_date = '${bizdate}') j
        WHERE j.rn = 1                                                            -- 同一流水重复同步取一条
    ) t
