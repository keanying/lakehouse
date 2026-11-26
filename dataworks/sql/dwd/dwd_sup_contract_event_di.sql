-- ================================================================================================
-- dwd.dwd_sup_contract_event_di  合同事件明细
-- 粒度：1行=1个合同事件（开票 / 回款 / 验收 / 回访 / 岗位变更）
-- 分区：travel_date（YYYYMMDD）
-- 调度：每日，依赖上游 ODS 当日分区与相关维表
-- 上游：ods_opr_oa_form_111_detail1_df、ods_opr_oa_form_111_df、ods_opr_oa_form_115_df、ods_opr_oa_form_134_df、ods_opr_oa_form_136_df、ods_opr_oa_form_170_df、ods_opr_oa_form_176_detail2_df、ods_opr_oa_form_176_df、ods_opr_oa_form_194_df、ods_opr_oa_form_211_df、ods_opr_oa_form_212_df、ods_opr_oa_form_213_detail1_df、ods_opr_oa_form_213_df、ods_opr_oa_form_233_df、ods_opr_oa_form_236_df、ods_opr_oa_form_258_detail1_df、ods_opr_oa_form_265_df、ods_opr_oa_form_268_detail2_df、ods_opr_oa_form_268_detail3_df、ods_opr_oa_form_268_detail4_df、ods_opr_oa_form_268_detail5_df、ods_opr_oa_form_268_df、ods_opr_oa_form_274_df、ods_opr_oa_form_277_df、ods_opr_oa_form_37_df、ods_opr_oa_form_48_df、ods_opr_oa_form_53_df、ods_opr_oa_form_93_detail1_df、ods_opr_oa_form_93_df、ods_sup_contract_df、dim_sup_contract_df
-- 替代旧任务 7 个（上线对数一致后下线）：
--   · 业务工厂/内部信息/DWD/dwd_project_bill_d_f（EMR_SPARK_SQL，cron 00 05 00 * * ?）
--   · 业务工厂/内部信息/DWS/dws_contract_d_f_workflow/dwd_project_bill_d_f（EMR_SPARK_SQL，cron 00 00 00 * * ?）
--   · 业务工厂/内部信息/DWD/dwd_project_by_post_d_f（EMR_SPARK_SQL，cron 00 22 00 * * ?）
--   · 业务工厂/内部信息/DWS/dws_contract_d_f_workflow/dwd_project_by_post_d_f（EMR_SPARK_SQL，cron 00 00 00 * * ?）
--   · 业务工厂/内部信息/DWD/dwd_project_call_back_d_f（EMR_SPARK_SQL，cron 00 07 00 * * ?）
--   · 业务工厂/内部信息/DWS/dws_contract_d_f_workflow/dwd_project_call_back_d_f（EMR_SPARK_SQL，cron 00 00 00 * * ?）
--   · 业务工厂/内部信息/DWS/dws_contract_d_f_workflow/dwd_project_check_d_f（EMR_SPARK_SQL，cron 00 00 00 * * ?）
-- 业务规则 / 修正：
--   · 合同签订 / 开票 / 回款三类事件 UNION ALL：合同台账 + OA 开票申请（表单 111）+ OA 回款登记（表单 265）
--   · 源为全量快照，按事件日期 = bizdate 取当日事件
-- ================================================================================================
INSERT OVERWRITE TABLE dwd.dwd_sup_contract_event_di PARTITION (travel_date = '${bizdate}')
-- (1) ods_sup_contract_df
SELECT
    contract_no,
    'SIGN'                                                       AS event_type,
    sign_date                                                    AS event_time,
    CAST(contrcat_amount AS DECIMAL(18,2))                       AS event_amt,
    '合同'                                                         AS amount_type,
    CAST(NULL AS STRING)                                         AS bill_date,   -- 待确认：来源未同步（旧字段 dwd_project_bill_d_f.bill_date）
    CAST(NULL AS BIGINT)                                         AS bill_amt,   -- 待确认：来源未同步（旧字段 dwd_project_bill_d_f.bill_amount）
    CAST(NULL AS BIGINT)                                         AS pre_pay_amt,   -- 待确认：来源未同步（旧字段 dwd_project_bill_d_f.pre_pay_amount）
    CAST(NULL AS BIGINT)                                         AS dev_arrival_amt,   -- 待确认：来源未同步（旧字段 dwd_project_bill_d_f.dev_arrival_amount）
    CAST(NULL AS BIGINT)                                         AS check_and_accept_amt,   -- 待确认：来源未同步（旧字段 dwd_project_bill_d_f.check_and_accept_amount）
    CAST(NULL AS BIGINT)                                         AS warranty_amt,   -- 待确认：来源未同步（旧字段 dwd_project_bill_d_f.warranty_amount）
    CAST(NULL AS BIGINT)                                         AS maintenance_amt,   -- 待确认：来源未同步（旧字段 dwd_project_bill_d_f.maintenance_amount）
    CAST(NULL AS BIGINT)                                         AS bill_device_amt,   -- 待确认：来源未同步（旧字段 dwd_project_bill_d_f.bill_device_amount）
    CAST(NULL AS BIGINT)                                         AS bill_software_amt,   -- 待确认：来源未同步（旧字段 dwd_project_bill_d_f.bill_software_amount）
    CAST(NULL AS BIGINT)                                         AS bill_other_amt,   -- 待确认：来源未同步（旧字段 dwd_project_bill_d_f.bill_other_amount）
    CAST(NULL AS BIGINT)                                         AS bill_maintenance_amt,   -- 待确认：来源未同步（旧字段 dwd_project_bill_d_f.bill_maintenance_amount）
    CAST(NULL AS STRING)                                         AS remark,   -- 待确认：来源未同步（旧字段 dwd_project_bill_d_f.remark）
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time
FROM ods.ods_sup_contract_df
WHERE travel_date = '${bizdate}'
  AND DATE_FORMAT(sign_date, 'yyyyMMdd') = '${bizdate}'   -- 全量快照取当日事件
UNION ALL
-- (2) ods_opr_oa_form_111_df
SELECT
    htbh                                                         AS contract_no,
    'INVOICE'                                                    AS event_type,
    kprq                                                         AS event_time,
    CAST(kpje AS DECIMAL(18,2))                                  AS event_amt,
    '开票'                                                         AS amount_type,
    kprq                                                         AS bill_date,
    CAST(kpje AS DECIMAL(18,2))                                  AS bill_amt,
    CAST(NULL AS BIGINT)                                         AS pre_pay_amt,
    CAST(NULL AS BIGINT)                                         AS dev_arrival_amt,
    CAST(NULL AS BIGINT)                                         AS check_and_accept_amt,
    CAST(NULL AS BIGINT)                                         AS warranty_amt,
    CAST(NULL AS BIGINT)                                         AS maintenance_amt,
    CAST(NULL AS BIGINT)                                         AS bill_device_amt,
    CAST(NULL AS BIGINT)                                         AS bill_software_amt,
    CAST(NULL AS BIGINT)                                         AS bill_other_amt,
    CAST(NULL AS BIGINT)                                         AS bill_maintenance_amt,
    CAST(NULL AS STRING)                                         AS remark,
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time
FROM ods.ods_opr_oa_form_111_df
WHERE travel_date = '${bizdate}'
  AND DATE_FORMAT(kprq, 'yyyyMMdd') = '${bizdate}'   -- 全量快照取当日事件
UNION ALL
-- (3) ods_opr_oa_form_265_df
SELECT
    htbh                                                         AS contract_no,
    'PAYBACK'                                                    AS event_type,
    hkrq                                                         AS event_time,
    CAST(hkje AS DECIMAL(18,2))                                  AS event_amt,
    hklx                                                         AS amount_type,
    CAST(NULL AS STRING)                                         AS bill_date,
    CAST(NULL AS BIGINT)                                         AS bill_amt,
    CAST(NULL AS BIGINT)                                         AS pre_pay_amt,
    CAST(NULL AS BIGINT)                                         AS dev_arrival_amt,
    CAST(NULL AS BIGINT)                                         AS check_and_accept_amt,
    CAST(NULL AS BIGINT)                                         AS warranty_amt,
    CAST(NULL AS BIGINT)                                         AS maintenance_amt,
    CAST(NULL AS BIGINT)                                         AS bill_device_amt,
    CAST(NULL AS BIGINT)                                         AS bill_software_amt,
    CAST(NULL AS BIGINT)                                         AS bill_other_amt,
    CAST(NULL AS BIGINT)                                         AS bill_maintenance_amt,
    CAST(NULL AS STRING)                                         AS remark,
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time
FROM ods.ods_opr_oa_form_265_df
WHERE travel_date = '${bizdate}'
  AND DATE_FORMAT(hkrq, 'yyyyMMdd') = '${bizdate}'   -- 全量快照取当日事件
