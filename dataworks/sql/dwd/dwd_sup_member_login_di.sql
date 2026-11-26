-- ================================================================================================
-- dwd.dwd_sup_member_login_di  商户登录明细
-- 粒度：1行=1次登录
-- 分区：travel_date（YYYYMMDD）
-- 调度：每日，依赖上游 ODS 当日分区与相关维表
-- 上游：ods_sup_member_login_log_di
-- 替代旧任务 1 个（上线对数一致后下线）：
--   · 数据中台/数仓明细层(DWD)/dwd_用户域/购买套餐、应用模块/dwd_company_login_d_f（EMR_SPARK_SQL，cron 00 30 00 * * ?）
-- 业务规则 / 修正：
--   · 只保留登录事实；IP / 浏览器 / 系统不进 DWD
-- ================================================================================================
INSERT OVERWRITE TABLE dwd.dwd_sup_member_login_di PARTITION (travel_date = '${bizdate}')
SELECT
    login_time,
    CAST(mid AS BIGINT)                                          AS member_id,
    '${bizdate}'                                                 AS stat_date,
    CAST(mid AS BIGINT)                                          AS user_id,
    login_source,
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time
FROM ods.ods_sup_member_login_log_di
WHERE travel_date = '${bizdate}'
