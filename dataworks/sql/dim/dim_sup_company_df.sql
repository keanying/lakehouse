-- ================================================================================================
-- dim.dim_sup_company_df  CRM 客户公司维度
-- 粒度：1行=1个 CRM 客户公司（纷享销客客户，未删除）
-- 分区：无分区
-- 调度：每日，ODS 全部完成后；维表之间按上游顺序
-- 上游：ods_sup_crm_account_df、ods_opr_crm_home_area_df
-- 替代旧任务 2 个（上线对数一致后下线）：
--   · 业务工厂/内部信息/财务部/客户属性cus_company/crm_to_hive_dim_crm_home_area_d_f（DI，cron 00 00 06 * * ?）
--   · 业务工厂/内部信息/财务部/客户属性cus_company/dws_cus_pft_crm_account_d_f（EMR_SPARK_SQL，cron 00 00 00 * * ?）
-- 业务规则 / 修正：
--   · 原表把平台账号级的客户属性宽表（套餐 / 登录 / 合作伙伴 / 产品 / 应用开通）挂在本维度，按粒度拆开：本表只放 CRM 客户公司属性，宽表移到 ads_sup_customer_company_df
--   · CRM 表 174 列中自定义备用列（option1~ 等）与联系人电话 / 地址（个人信息）不进维度
-- ================================================================================================
INSERT OVERWRITE TABLE dim.dim_sup_company_df                                     -- 整表覆盖写入
SELECT
    CAST(id AS BIGINT)                                           AS company_id,   -- CRM 客户ID
    account_no                                                   AS company_no,   -- CRM 客户编号
    name                                                         AS company_name,  -- 客户名称
    field_0w21l__c                                               AS platform_account,  -- 平台账号 / ID / 手机
    IF(field_0w21l__c RLIKE '^[0-9]{3,10}$', CAST(field_0w21l__c AS BIGINT), NULL) AS member_id,  -- 平台账号ID（平台账号原文为纯数字时）
    account_type,                                                                 -- 客户分类
    account_level,                                                                -- 客户类型（合作客户等级）
    field_41liw__c                                               AS customer_attribute,  -- 客户属性
    field_mvq72__c                                               AS cooperation_attribute,  -- 合作属性
    record_type,                                                                  -- 业务类型
    account_source,                                                               -- 客户来源
    industry_level1,                                                              -- 一级行业
    industry_level2,                                                              -- 二级行业
    field_nz4yo__c                                               AS main_category,  -- 主营类目
    field_4h84y__c                                               AS scenic_type,  -- 景区类型
    field_0ut89__c                                               AS scenic_level,  -- 景区等级
    field_5q3iq__c                                               AS travel_agency_type,  -- 旅行社类型
    country__r                                                   AS country_name,  -- 国家
    province                                                     AS province_code,  -- 省编码
    province__r                                                  AS province_name,  -- 省
    city                                                         AS city_code,    -- 市编码
    city__r                                                      AS city_name,    -- 市
    district__r                                                  AS district_name,  -- 区县
    owner__r                                                     AS owner_name,   -- 负责人
    owner_department,                                                             -- 负责人主属部门
    home_area_group,                                                              -- 归属区域组（按负责人部门）
    lv1_team,                                                                     -- 一级团队
    lv2_team,                                                                     -- 二级团队
    lv3_team,                                                                     -- 三级团队
    deal_status,                                                                  -- 成交状态
    life_status,                                                                  -- 生命状态
    biz_status,                                                                   -- 分配状态
    field_tkx02__c                                               AS first_deal_date,  -- 首签成单日期
    last_deal_closed_time                                        AS last_deal_time,  -- 最后一次成交时间
    CAST(last_deal_closed_amount AS DECIMAL(18,2))               AS last_deal_amt,  -- 最后一次成交金额（元）
    last_followed_time,                                                           -- 最后跟进时间
    high_seas_name,                                                               -- 所属公海
    uniform_social_credit_code                                   AS credit_code,  -- 统一社会信用代码
    create_time,                                                                  -- 创建时间
    last_modified_time,                                                           -- 最后修改时间
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time           -- ETL 加载时间
FROM (
        SELECT a.*, h.home_area_group, h.lv1_team, h.lv2_team, h.lv3_team
        FROM ods.ods_sup_crm_account_df a                                         -- 主表「CRM账户」
        LEFT JOIN (SELECT department, MAX(home_area_group) AS home_area_group, MAX(lv1_team) AS lv1_team, MAX(lv2_team) AS lv2_team, MAX(lv3_team) AS lv3_team
                   FROM ods.ods_opr_crm_home_area_df WHERE travel_date = '${bizdate}' GROUP BY department) h ON h.department = a.owner_department  -- 部门 → 归属区域 / 团队
        WHERE a.travel_date = '${bizdate}' AND COALESCE(a.is_deleted, 0) = 0      -- 只取当日分区，并按条件过滤
    ) t
