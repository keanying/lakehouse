-- ================================================================================================
-- dim.dim_cus_user_df  统一用户维度
-- 粒度：1行=1个用户（游客 / 会员 / 客户）
-- 分区：无分区
-- 调度：每日，ODS 全部完成后；维表之间按上游顺序
-- 上游：dim_cus_tourist_df、dim_sup_member_df、dim_sup_company_df
-- 业务规则 / 修正：
--   · 旧系统游客、会员、CRM 客户三套 ID 各自统计，没有统一用户视图
-- 性能：
--   · 三类用户 UNION ALL，无关联
-- ================================================================================================
INSERT OVERWRITE TABLE dim.dim_cus_user_df         -- 整表覆盖写入
SELECT user_key,                                   -- 用户键 = 类型前缀 + 源ID
       user_type,                                  -- 用户类型
       source_id,                                  -- 源ID
       user_name_mask,                             -- 名称（游客为掩码）
       member_id,                                  -- 关联会员ID
       customer_id,                                -- 关联 CRM 客户ID
       province_code,                              -- 所在 / 客源省
       first_active_date,                          -- 首次活跃日期
       last_active_date,                           -- 最近活跃日期
       status,                                     -- 状态
       test_flag,                                  -- 是否测试
       DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time  -- ETL 加载时间
FROM (
    -- 游客：证件号哈希
    SELECT CONCAT('T:', tourist_key) AS user_key,  -- 用户键 = 类型前缀 + 源ID
           'TOURIST' AS user_type,                 -- 用户类型
           tourist_key AS source_id,               -- 源ID
           CAST(NULL AS STRING) AS user_name_mask,  -- 名称（游客为掩码）：本来源无，补空对齐 UNION ALL
           CAST(NULL AS BIGINT) AS member_id,      -- 关联会员ID：本来源无，补空对齐 UNION ALL
           CAST(NULL AS BIGINT) AS customer_id,    -- 关联 CRM 客户ID：本来源无，补空对齐 UNION ALL
           source_province_code AS province_code,  -- 所在 / 客源省
           first_order_date AS first_active_date,  -- 首次活跃日期
           GREATEST(COALESCE(last_order_date, ''), COALESCE(last_visit_date, '')) AS last_active_date,  -- 最近活跃日期
           'ACTIVE' AS status,                     -- 状态
           0 AS test_flag                          -- 是否测试：本来源无，补空对齐 UNION ALL
    FROM dim.dim_cus_tourist_df
    UNION ALL
    -- 会员：平台账号
    SELECT CONCAT('M:', member_id),
           'MEMBER',
           CAST(member_id AS STRING),
           CONCAT(SUBSTR(member_name, 1, 1), '**'),
           member_id,                              -- 关联会员ID
           customer_id,                            -- 关联 CRM 客户ID
           CAST(NULL AS STRING),
           SUBSTR(register_time, 1, 10),
           SUBSTR(last_login_time, 1, 10),
           member_status,
           test_flag                               -- 是否测试
    FROM dim.dim_sup_member_df
    UNION ALL
    -- CRM 客户
    SELECT CONCAT('C:', company_id),
           'CUSTOMER',
           CAST(company_id AS STRING),
           CONCAT(SUBSTR(company_name, 1, 1), '**'),
           user_id,
           user_customer_id,
           customer_province,
           SUBSTR(user_regist_time, 1, 10),
           SUBSTR(user_login_lasttime, 1, 10),
           user_status,
           IF(user_is_test = '测试', 1, 0)
    FROM dim.dim_sup_company_df
) u                                                -- 各来源合并后的明细
