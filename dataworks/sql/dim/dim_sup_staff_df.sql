-- ================================================================================================
-- dim.dim_sup_staff_df  员工维度
-- 粒度：1行=1个平台员工（签单 / 客服 / 区域人员）
-- 分区：无分区
-- 调度：每日，ODS 全部完成后；维表之间按上游顺序
-- 上游：ods_sup_staff_df、ods_opr_staff_group_df
-- 替代旧任务 2 个（上线对数一致后下线）：
--   · 数据中台/数据维度(DIM)/dim_用户域/dim_plat_staff_d_f（EMR_SPARK_SQL，cron 00 30 00 * * ?）
--   · 数据中台/数据维度(DIM)/dim_用户域/dim_staff_group_d_f（EMR_SPARK_SQL，cron 00 06 00 * * ?）
-- 业务规则 / 修正：
--   · 旧 dim_plat_staff_d_f 的 OA 部门 / 一二级团队来自 OA 人员表，OA 链路客户确认下线，这些列不再提供；平台侧部门以员工组代替
--   · 旧表 stat_date（统计日期）与分区重复，不再保留
-- ================================================================================================
INSERT OVERWRITE TABLE dim.dim_sup_staff_df                                       -- 整表覆盖写入
SELECT
    CAST(id AS BIGINT)                                           AS staff_id,     -- 员工ID
    CAST(st_memberid AS BIGINT)                                  AS staff_member_id,  -- 员工在平台的账号ID
    st_name                                                      AS staff_name,   -- 员工姓名
    CAST(st_type AS INT)                                         AS staff_type,   -- 人员类型
    CAST(st_status AS INT)                                       AS staff_status,  -- 状态
    CAST(st_group AS BIGINT)                                     AS staff_group_id,  -- 员工组ID
    staff_group_name,                                                             -- 员工组名称
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time           -- ETL 加载时间
FROM (
        SELECT s.*, g.staff_group_name
        FROM ods.ods_sup_staff_df s                                               -- 来源表「员工」
        LEFT JOIN (SELECT staff_group_id, MAX(staff_group_name) AS staff_group_name FROM ods.ods_opr_staff_group_df
                   WHERE travel_date = '${bizdate}' GROUP BY staff_group_id) g ON g.staff_group_id = s.st_group  -- 只取当日分区｜员工组码表，先去重
        WHERE s.travel_date = '${bizdate}'                                        -- 只取当日分区
    ) t
