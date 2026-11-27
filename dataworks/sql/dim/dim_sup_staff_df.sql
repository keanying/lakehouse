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
INSERT OVERWRITE TABLE dim.dim_sup_staff_df                                       -- 整表覆盖写入
SELECT
    CAST(NULL AS BIGINT)                                         AS staff_id,     -- 员工ID｜待确认：来源未同步
    CAST(NULL AS STRING)                                         AS staff_name,   -- 员工名称｜待确认：来源未同步
    CAST(NULL AS BIGINT)                                         AS department_id,  -- 部门ID｜待确认：来源未同步
    stat_date,                                                                    -- 统计日期
    plat_staff_id,                                                                -- 平台员工ID
    plat_staff_name,                                                              -- 平台员工名称
    plat_staff_department,                                                        -- 平台员工部门
    plat_staff_role,                                                              -- 平台员工角色
    plat_staff_group,                                                             -- 平台员工组
    plat_staff_status,                                                            -- 平台员工状态
    plat_staff_team2_oa,                                                          -- 平台员工team2OA（待确认）
    plat_staff_team1_oa,                                                          -- 平台员工team1OA（待确认）
    plat_staff_team_oa,                                                           -- 平台员工团队OA
    plat_staff_department_oa,                                                     -- 平台员工部门OA
    CAST(NULL AS BIGINT)                                         AS staff_group_id,  -- 员工组ID｜待确认：来源未同步（旧字段 dim_staff_group_d_f.staff_group_id）
    CAST(NULL AS STRING)                                         AS staff_group_name,  -- 员工组名称｜待确认：来源未同步（旧字段 dim_staff_group_d_f.staff_group_name）
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time           -- ETL 加载时间
FROM dim_plat_staff_d_f
WHERE pt = '${bizdate}'                                                           -- 过渡期：读旧表，按字段清单逐步改为从 ODS 计算
