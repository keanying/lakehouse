-- ================================================================================================
-- dim.dim_sup_contract_df  合同维度
-- 粒度：1行=1份合同
-- 分区：无分区
-- 调度：每日，ODS 全部完成后；维表之间按上游顺序
-- 上游：ods_sup_contract_df、ods_sup_oa_contract_ledger_df
-- 替代旧任务 4 个（上线对数一致后下线）：
--   · 业务工厂/内部信息/DIM/dim_contract_d_f（EMR_SPARK_SQL，cron 00 07 00 * * ?）
--   · 业务工厂/内部信息/DIM/dim_contract_id_d_f（EMR_SPARK_SQL，cron 00 09 00 * * ?）
--   · 业务工厂/内部信息/DWS/dws_contract_d_f_workflow/tmp_contract_d_f（EMR_SPARK_SQL，cron 00 00 00 * * ?）
--   · 业务工厂/内部信息/DWS/dws_contract_d_f_workflow/dws_contract_d_f（EMR_SPARK_SQL，cron 00 00 00 * * ?）
-- 业务规则 / 修正：
--   · 过渡期从旧表 dim_contract_d_f 平移：旧逻辑由多张中间表 / 外部采集加工，字段与 ODS 不能直接对应；字段口径按字典，上线顺序：先平移保证下游可切换，再按字段清单把「待确认」逐个改为从 ODS 计算后下线旧链路
-- ================================================================================================
INSERT OVERWRITE TABLE dim.dim_sup_contract_df
SELECT
    contract_no,
    CAST(NULL AS BIGINT)                                         AS company_id,   -- 待确认：来源未同步
    id,
    contract_name,
    contrac_type,
    land_name                                                    AS scenic_name,
    project_name,
    part_a_name,
    cooperate_type,
    is_new_renewal,
    project_period,
    province                                                     AS province_name,
    city                                                         AS city_name,
    bid_win_time,
    cor_type,
    business_type,
    third_party_money                                            AS third_party_amt,
    mt,
    CAST(contract_amount AS BIGINT)                              AS contract_amt,
    CAST(pre_pay_amount AS BIGINT)                               AS pre_pay_amt,
    pre_pay_pay_period,
    CAST(dev_arrival_amount AS BIGINT)                           AS dev_arrival_amt,
    dev_arrival_pay_period,
    CAST(check_and_accept_amount AS BIGINT)                      AS check_and_accept_amt,
    check_and_accept_pay_period,
    CAST(warranty_amount AS BIGINT)                              AS warranty_amt,
    warranty_amount_start_offset,
    warranty_start_offset,
    warranty_period,
    warranty_start_date,
    warranty_end_date,
    maintenance_amount_appoint,
    CAST(maintenance_amount AS BIGINT)                           AS maintenance_amt,
    maintenance_period,
    maintenance_start_date,
    maintenance_end_date,
    CAST(software_amount AS BIGINT)                              AS software_amt,
    CAST(device_amount AS BIGINT)                                AS device_amt,
    CAST(fix_train_amount AS BIGINT)                             AS fix_train_amt,
    CAST(freight_amount AS BIGINT)                               AS freight_amt,
    pre_pay_percent,
    dev_arrival_percent,
    check_and_accept_percent,
    warranty_percent,
    maintenance_percent,
    achievements_divide,
    apply_sub_department,
    apply_sub_department_id,
    apply_department,
    applier,
    applier_id,
    create_time,
    sign_date,
    begin_time                                                   AS valid_start_time,
    end_time                                                     AS valid_end_time,
    user_id,
    package_name,
    user_name,
    user_company_name,
    project_manage,
    project_status,
    CAST(NULL AS BIGINT)                                         AS billed_amt,   -- 待确认：来源未同步（旧字段 tmp_contract_d_f.billed_amount）
    CAST(NULL AS BIGINT)                                         AS pre_pay_billed,   -- 待确认：来源未同步（旧字段 tmp_contract_d_f.pre_pay_billed）
    CAST(NULL AS BIGINT)                                         AS dev_arrival_billed,   -- 待确认：来源未同步（旧字段 tmp_contract_d_f.dev_arrival_billed）
    CAST(NULL AS BIGINT)                                         AS check_and_accept_billed,   -- 待确认：来源未同步（旧字段 tmp_contract_d_f.check_and_accept_billed）
    CAST(NULL AS BIGINT)                                         AS warranty_billed,   -- 待确认：来源未同步（旧字段 tmp_contract_d_f.warranty_billed）
    CAST(NULL AS BIGINT)                                         AS maintenance_billed,   -- 待确认：来源未同步（旧字段 tmp_contract_d_f.maintenance_billed）
    CAST(NULL AS BIGINT)                                         AS software_billed,   -- 待确认：来源未同步（旧字段 tmp_contract_d_f.software_billed）
    CAST(NULL AS BIGINT)                                         AS device_billed,   -- 待确认：来源未同步（旧字段 tmp_contract_d_f.device_billed）
    CAST(NULL AS BIGINT)                                         AS fix_train_billed,   -- 待确认：来源未同步（旧字段 tmp_contract_d_f.fix_train_billed）
    CAST(NULL AS BIGINT)                                         AS maintenance_billed_actual,   -- 待确认：来源未同步（旧字段 tmp_contract_d_f.maintenance_billed_actual）
    CAST(NULL AS BIGINT)                                         AS pre_pay_finish_amt,   -- 待确认：来源未同步（旧字段 tmp_contract_d_f.pre_pay_finish_amount）
    CAST(NULL AS STRING)                                         AS pre_pay_finish_date,   -- 待确认：来源未同步（旧字段 tmp_contract_d_f.pre_pay_finish_date）
    CAST(NULL AS BIGINT)                                         AS dev_arrival_finish_amt,   -- 待确认：来源未同步（旧字段 tmp_contract_d_f.dev_arrival_finish_amount）
    CAST(NULL AS STRING)                                         AS dev_arrival_finish_date,   -- 待确认：来源未同步（旧字段 tmp_contract_d_f.dev_arrival_finish_date）
    CAST(NULL AS BIGINT)                                         AS check_and_accept_finish_amt,   -- 待确认：来源未同步（旧字段 tmp_contract_d_f.check_and_accept_finish_amount）
    CAST(NULL AS STRING)                                         AS check_and_accept_finish_date,   -- 待确认：来源未同步（旧字段 tmp_contract_d_f.check_and_accept_finish_date）
    CAST(NULL AS BIGINT)                                         AS warranty_finish_amt,   -- 待确认：来源未同步（旧字段 tmp_contract_d_f.warranty_finish_amount）
    CAST(NULL AS STRING)                                         AS warranty_finish_date,   -- 待确认：来源未同步（旧字段 tmp_contract_d_f.warranty_finish_date）
    CAST(NULL AS BIGINT)                                         AS maintenance_finish_amt,   -- 待确认：来源未同步（旧字段 tmp_contract_d_f.maintenance_finish_amount）
    CAST(NULL AS STRING)                                         AS maintenance_finish_date,   -- 待确认：来源未同步（旧字段 tmp_contract_d_f.maintenance_finish_date）
    CAST(NULL AS BIGINT)                                         AS paid_amt,   -- 待确认：来源未同步（旧字段 tmp_contract_d_f.paid_amount）
    CAST(NULL AS BIGINT)                                         AS not_paid_amt,   -- 待确认：来源未同步（旧字段 tmp_contract_d_f.not_paid_amount）
    CAST(NULL AS STRING)                                         AS erp_no,   -- 待确认：来源未同步（旧字段 tmp_contract_d_f.erp_no）
    CAST(NULL AS STRING)                                         AS logistics_no,   -- 待确认：来源未同步（旧字段 tmp_contract_d_f.logistics_no）
    CAST(NULL AS STRING)                                         AS by_post_date,   -- 待确认：来源未同步（旧字段 tmp_contract_d_f.by_post_date）
    CAST(NULL AS STRING)                                         AS final_check_date,   -- 待确认：来源未同步（旧字段 tmp_contract_d_f.final_check_date）
    CAST(NULL AS STRING)                                         AS final_check_no,   -- 待确认：来源未同步（旧字段 tmp_contract_d_f.final_check_no）
    CAST(NULL AS STRING)                                         AS pre_pay_pay_end_date,   -- 待确认：来源未同步（旧字段 tmp_contract_d_f.pre_pay_pay_end_date）
    CAST(NULL AS STRING)                                         AS dev_arrival_pay_end_date,   -- 待确认：来源未同步（旧字段 tmp_contract_d_f.dev_arrival_pay_end_date）
    CAST(NULL AS STRING)                                         AS check_and_accept_pay_end_date,   -- 待确认：来源未同步（旧字段 tmp_contract_d_f.check_and_accept_pay_end_date）
    CAST(NULL AS STRING)                                         AS warranty_pay_end_date,   -- 待确认：来源未同步（旧字段 tmp_contract_d_f.warranty_pay_end_date）
    CAST(NULL AS STRING)                                         AS maintenance_pay_end_date,   -- 待确认：来源未同步（旧字段 tmp_contract_d_f.maintenance_pay_end_date）
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time
FROM dim_contract_d_f
WHERE pt = ${bizdate}   -- 过渡期：读旧表，按字段清单逐步改为从 ODS 计算
