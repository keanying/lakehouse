-- ================================================================================================
-- dwd.dwd_trf_scenic_inout_di  出入园明细
-- 粒度：1行=1次过闸 / 入园验证
-- 分区：travel_date（YYYYMMDD）
-- 调度：每日，依赖上游 ODS 当日分区与相关维表
-- 上游：ods_trf_device_inout_journal_di、ods_ord_report_terminal_pass_di、dim_trf_gate_f
-- 替代旧任务 2 个（上线对数一致后下线）：
--   · 数据平台/平台湖仓工作流/出入园数据/dwd_trf_tourist_in_out_details_di（SERVERLESS_SPARK_SQL，cron 00 00 00 * * ?）
--   · 数据平台/平台湖仓工作流/景区实时客流/tmp_src_trf_scenic_access_record_hrs_f（DI，cron 00 00 00 * * ?）
-- 业务规则 / 修正：
--   · 闸机进出流水；待确认：roll_type 1=进 2=出（旧 dim_input_group_gate_d_f 未写码值）
-- ================================================================================================
INSERT OVERWRITE TABLE dwd.dwd_trf_scenic_inout_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
    CAST(land_id AS BIGINT)                                      AS scenic_id,    -- 景区ID
    CAST(device_key AS STRING)                                   AS terminal_no,  -- 终端编号
    CASE roll_type WHEN '1' THEN 'IN' WHEN '2' THEN 'OUT' ELSE 'OTHER' END AS inout_type,  -- 出入类型
    create_time                                                  AS inout_time,   -- 出入时间
    CAST(num AS BIGINT)                                          AS person_qty,   -- 人员数量
    id,                                                                           -- 主键ID
    CAST(sid AS BIGINT)                                          AS supplier_id,  -- 供应商ID（租户ID）
    CAST(NULL AS BIGINT)                                         AS qty,          -- 单次出入园数量｜待确认：来源未同步（旧字段 dwd_trf_tourist_in_out_details_di.qty）
    create_time,                                                                  -- 创建时间
    CAST(NULL AS STRING)                                         AS visit_date,   -- 游览日期｜待确认：来源未同步（旧字段 dwd_trf_tourist_in_out_details_di.visit_date）
    CAST(NULL AS BIGINT)                                         AS visit_date_hour,  -- 出入园对应小时 24小时制｜待确认：来源未同步（旧字段 dwd_trf_tourist_in_out_details_di.visit_date_hour）
    device_key,                                                                   -- 闸机特征码
    roll_type                                                    AS roll,         -- 0 入园 1 离园
    CAST(NULL AS BIGINT)                                         AS all_qty,      -- 当前的出入园总量｜待确认：来源未同步（旧字段 dwd_trf_tourist_in_out_details_di.all_num）
    num,                                                                          -- 数量
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time           -- ETL 加载时间
FROM ods.ods_trf_device_inout_journal_di
WHERE travel_date = '${bizdate}'                                                  -- 只取当日分区
