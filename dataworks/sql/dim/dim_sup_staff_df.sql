-- ================================================================================================
-- dim.dim_sup_staff_df  员工维度
-- 粒度：1行=1个员工（平台员工 / OA 人员）
-- 分区：无分区
-- 调度：每日，ODS 全部完成后；维表之间按上游顺序
-- 上游：ods_opr_hr_staff_df、ods_opr_hr_department_df、ods_sup_staff_df
-- 替代旧任务 4 个（上线对数一致后下线）：
--   · 数据中台/数据维度(DIM)/dim_用户域/dim_plat_staff_d_f（EMR_SPARK_SQL，cron 00 30 00 * * ?）
--   · 数据中台/数据维度(DIM)/dim_用户域/dim_staff_group_d_f（EMR_SPARK_SQL，cron 00 06 00 * * ?）
--   · 业务工厂/内部信息/DWD/dwd_staff_basic_d_f（EMR_SPARK_SQL，cron 00 24 00 * * ?）
--   · 业务工厂/内部信息/DIM/dim_oa_department_d_f（EMR_SPARK_SQL，cron 00 14 00 * * ?）
-- 业务规则 / 修正：
--   · 过渡期从旧表 dwd_staff_basic_d_f 平移：旧逻辑由多张中间表 / 外部采集加工，字段与 ODS 不能直接对应；字段口径按字典，上线顺序：先平移保证下游可切换，再按字段清单把「待确认」逐个改为从 ODS 计算后下线旧链路
-- ================================================================================================
INSERT OVERWRITE TABLE dim.dim_sup_staff_df
SELECT
    staff_id,
    CAST(NULL AS STRING)                                         AS staff_name,   -- 待确认：来源未同步
    CAST(NULL AS BIGINT)                                         AS department_id,   -- 待确认：来源未同步
    CAST(NULL AS STRING)                                         AS stat_date,   -- 待确认：来源未同步（旧字段 dim_plat_staff_d_f.stat_date）
    CAST(NULL AS BIGINT)                                         AS plat_staff_id,   -- 待确认：来源未同步（旧字段 dim_plat_staff_d_f.plat_staff_id）
    CAST(NULL AS STRING)                                         AS plat_staff_name,   -- 待确认：来源未同步（旧字段 dim_plat_staff_d_f.plat_staff_name）
    CAST(NULL AS STRING)                                         AS plat_staff_department,   -- 待确认：来源未同步（旧字段 dim_plat_staff_d_f.plat_staff_department）
    CAST(NULL AS STRING)                                         AS plat_staff_role,   -- 待确认：来源未同步（旧字段 dim_plat_staff_d_f.plat_staff_role）
    CAST(NULL AS STRING)                                         AS plat_staff_group,   -- 待确认：来源未同步（旧字段 dim_plat_staff_d_f.plat_staff_group）
    CAST(NULL AS STRING)                                         AS plat_staff_status,   -- 待确认：来源未同步（旧字段 dim_plat_staff_d_f.plat_staff_status）
    CAST(NULL AS STRING)                                         AS plat_staff_team2_oa,   -- 待确认：来源未同步（旧字段 dim_plat_staff_d_f.plat_staff_team2_oa）
    CAST(NULL AS STRING)                                         AS plat_staff_team1_oa,   -- 待确认：来源未同步（旧字段 dim_plat_staff_d_f.plat_staff_team1_oa）
    CAST(NULL AS STRING)                                         AS plat_staff_team_oa,   -- 待确认：来源未同步（旧字段 dim_plat_staff_d_f.plat_staff_team_oa）
    CAST(NULL AS STRING)                                         AS plat_staff_department_oa,   -- 待确认：来源未同步（旧字段 dim_plat_staff_d_f.plat_staff_department_oa）
    departmentname_id,
    departmentname,
    lv1_team_id,
    lv1_team,
    lv2_team_id,
    lv2_team,
    full_dep_name,
    amb_level1,
    amb_level2,
    amb_level3,
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time
FROM dwd_staff_basic_d_f
WHERE pt = ${bizdate}   -- 过渡期：读旧表，按字段清单逐步改为从 ODS 计算
