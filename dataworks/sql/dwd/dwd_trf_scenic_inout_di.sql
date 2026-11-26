-- ================================================================================================
-- dwd.dwd_trf_scenic_inout_di  出入园明细
-- 粒度：1行=1次过闸 / 入园验证
-- 分区：travel_date（YYYYMMDD）
-- 调度：每日，依赖上游 ODS 当日分区与相关维表
-- 上游：ods_trf_device_inout_journal_di、ods_ord_report_terminal_pass_di、dim_trf_gate_f
-- 替代旧任务 3 个（上线对数一致后下线）：
--   · 业务工厂/票务数据/出入园/出入园数据校验工作流/dwd_minutely_inout_detail_d_i（SERVERLESS_SPARK_SQL，cron 00 23 04 * * ?）
--   · 数据平台/平台湖仓工作流/出入园数据/dwd_trf_tourist_in_out_details_di（SERVERLESS_SPARK_SQL，cron 00 00 00 * * ?）
--   · 数据平台/平台湖仓工作流/景区实时客流/tmp_src_trf_scenic_access_record_hrs_f（DI，cron 00 00 00 * * ?）
-- 业务规则 / 修正：
--   · 闸机进出流水；待确认：roll_type 1=进 2=出（旧 dim_input_group_gate_d_f 未写码值）
-- ================================================================================================
INSERT OVERWRITE TABLE dwd.dwd_trf_scenic_inout_di PARTITION (travel_date = '${bizdate}')
SELECT
    CAST(land_id AS BIGINT)                                      AS scenic_id,
    CAST(device_key AS STRING)                                   AS terminal_no,
    CASE roll_type WHEN '1' THEN 'IN' WHEN '2' THEN 'OUT' ELSE 'OTHER' END AS inout_type,
    create_time                                                  AS inout_time,
    CAST(num AS BIGINT)                                          AS person_qty,
    CAST(NULL AS STRING)                                         AS fulltime,   -- 待确认：来源未同步（旧字段 dwd_minutely_inout_detail_d_i.fulltime）
    CAST(sid AS BIGINT)                                          AS supplier_id,
    device_key,
    roll_type                                                    AS roll,
    num,
    CAST(NULL AS BIGINT)                                         AS all_qty,   -- 待确认：来源未同步（旧字段 dwd_minutely_inout_detail_d_i.all_num）
    CAST(NULL AS BIGINT)                                         AS fulldate,   -- 待确认：来源未同步（旧字段 dwd_minutely_inout_detail_d_i.fulldate）
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time
FROM ods.ods_trf_device_inout_journal_di
WHERE travel_date = '${bizdate}'
