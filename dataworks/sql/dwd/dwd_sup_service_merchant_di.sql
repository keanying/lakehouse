-- ================================================================================================
-- dwd.dwd_sup_service_merchant_di  服务商户明细
-- 粒度：1行=1个服务商户×1个服务项目
-- 分区：travel_date（YYYYMMDD）
-- 调度：每日，依赖上游 ODS 当日分区与相关维表
-- 上游：ods_sup_member_df、ods_sup_cooperation_other_df
-- 替代旧任务 2 个（上线对数一致后下线）：
--   · 业务工厂/经营数据/服务商户/dwd_service_business_d_f（EMR_SPARK_SQL，cron 00 00 02 * * ?）
--   · 业务工厂/内部信息/市场（平台事业部）/公司BI/公司BI工作流/dwd_company_cooperation_other_d_f（EMR_SPARK_SQL，cron 00 00 00 * * ?）
-- 业务规则 / 修正：
--   · 主表 ods.ods_sup_cooperation_other_df（同名字段命中最多）；仍无来源的字段标「待确认」
-- ================================================================================================
INSERT OVERWRITE TABLE dwd.dwd_sup_service_merchant_di PARTITION (travel_date = '${bizdate}')
SELECT
    member_id,
    CAST(NULL AS STRING)                                         AS member_kind,   -- 待确认：来源未同步（旧字段 dwd_service_business_d_f.member_kind）
    CAST(NULL AS STRING)                                         AS member_type,   -- 待确认：来源未同步（旧字段 dwd_service_business_d_f.member_type）
    CAST(NULL AS STRING)                                         AS province_name,   -- 待确认：来源未同步（旧字段 dwd_service_business_d_f.province）
    CAST(NULL AS STRING)                                         AS city_name,   -- 待确认：来源未同步（旧字段 dwd_service_business_d_f.city）
    CAST(NULL AS STRING)                                         AS start_time,   -- 待确认：来源未同步（旧字段 dwd_service_business_d_f.start_time）
    CAST(NULL AS STRING)                                         AS valid_end_time,   -- 待确认：来源未同步（旧字段 dwd_service_business_d_f.end_time）
    id,
    CAST(NULL AS BIGINT)                                         AS user_id,   -- 待确认：来源未同步（旧字段 dwd_company_cooperation_other_d_f.user_id）
    cooperat_type,
    CAST(cooperat_money AS BIGINT)                               AS cooperat_amt,
    cooperat_time,
    repayment_time,
    sales_id,
    CAST(NULL AS STRING)                                         AS plat_staff_name,   -- 待确认：来源未同步（旧字段 dwd_company_cooperation_other_d_f.plat_staff_name）
    CAST(NULL AS STRING)                                         AS plat_staff_department,   -- 待确认：来源未同步（旧字段 dwd_company_cooperation_other_d_f.plat_staff_department）
    remark,
    create_time,
    update_time,
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time
FROM ods.ods_sup_cooperation_other_df
WHERE travel_date = '${bizdate}'
