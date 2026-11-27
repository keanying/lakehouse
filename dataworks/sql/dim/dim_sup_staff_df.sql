-- ================================================================================================
-- dim.dim_sup_staff_df  员工维度
-- 粒度：1行=1个员工（平台员工 / OA 人员）
-- 分区：无分区
-- 调度：每日，ODS 全部完成后；维表之间按上游顺序
-- 上游：ods_sup_staff_df
-- 替代旧任务 2 个（上线对数一致后下线）：
--   · 数据中台/数据维度(DIM)/dim_用户域/dim_plat_staff_d_f（EMR_SPARK_SQL，cron 00 30 00 * * ?）
--   · 数据中台/数据维度(DIM)/dim_用户域/dim_staff_group_d_f（EMR_SPARK_SQL，cron 00 06 00 * * ?）
-- 业务规则 / 修正：
--   · 过渡期从旧表 dim_plat_staff_d_f 平移：旧逻辑由多张中间表 / 外部采集加工，字段与 ODS 不能直接对应；字段口径按字典，上线顺序：先平移保证下游可切换，再按字段清单把「待确认」逐个改为从 ODS 计算后下线旧链路
-- ================================================================================================
INSERT OVERWRITE TABLE dim.dim_sup_staff_df
SELECT
    CAST(NULL AS BIGINT)                                         AS staff_id,   -- 待确认：来源未同步
    CAST(NULL AS STRING)                                         AS staff_name,   -- 待确认：来源未同步
    CAST(NULL AS BIGINT)                                         AS department_id,   -- 待确认：来源未同步
    stat_date,
    plat_staff_id,
    plat_staff_name,
    plat_staff_department,
    plat_staff_role,
    plat_staff_group,
    plat_staff_status,
    plat_staff_team2_oa,
    plat_staff_team1_oa,
    plat_staff_team_oa,
    plat_staff_department_oa,
    CAST(NULL AS BIGINT)                                         AS staff_group_id,   -- 待确认：来源未同步（旧字段 dim_staff_group_d_f.staff_group_id）
    CAST(NULL AS STRING)                                         AS staff_group_name,   -- 待确认：来源未同步（旧字段 dim_staff_group_d_f.staff_group_name）
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time
FROM dim_plat_staff_d_f
WHERE pt = '${bizdate}'   -- 过渡期：读旧表，按字段清单逐步改为从 ODS 计算
