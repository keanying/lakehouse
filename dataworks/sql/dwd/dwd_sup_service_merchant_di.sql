-- ================================================================================================
-- dwd.dwd_sup_service_merchant_di  商户其他合作明细
-- 粒度：1行=1条商户其他合作（硬件 / 软件 / 其他）记录
-- 分区：travel_date（YYYYMMDD）
-- 调度：每日，依赖上游 ODS 当日分区与相关维表
-- 上游：ods_sup_cooperation_other_df、dim_sup_member_df
-- 替代旧任务 1 个（上线对数一致后下线）：
--   · 业务工厂/经营数据/服务商户/dwd_service_business_d_f（EMR_SPARK_SQL，cron 00 00 02 * * ?）
-- 业务规则 / 修正：
--   · 旧表的 服务起止时间 = 合作日期 / 回款日期；省市来自旧客户属性宽表，商户所在地在 dim_sup_company_df
-- ================================================================================================
INSERT OVERWRITE TABLE dwd.dwd_sup_service_merchant_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
    CAST(id AS BIGINT)                                           AS cooperation_id,  -- 合作记录ID
    CAST(member_id AS BIGINT)                                    AS member_id,    -- 商户ID
    member_name,                                                                  -- 商户名称（关联商户维度）
    member_type_code,                                                             -- 商户类型（关联商户维度）
    CAST(cooperat_type AS INT)                                   AS cooperation_type,  -- 合作类型
    CAST(cooperat_money AS DECIMAL(18,2)) / 100                  AS cooperation_amt,  -- 合作金额（元）
    FROM_UNIXTIME(cooperat_time, 'yyyy-MM-dd')                   AS cooperation_date,  -- 合作日期
    IF(repayment_time > 0, FROM_UNIXTIME(repayment_time, 'yyyy-MM-dd'), NULL) AS repayment_date,  -- 回款日期
    CAST(sales_id AS BIGINT)                                     AS sales_id,     -- 签单人ID
    remark,                                                                       -- 备注
    FROM_UNIXTIME(create_time)                                   AS create_time,  -- 登记时间
    FROM_UNIXTIME(update_time)                                   AS update_time,  -- 更新时间
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time           -- ETL 加载时间
FROM (
        SELECT c.*, m.member_name, m.member_type_code
        FROM ods.ods_sup_cooperation_other_df c
        LEFT JOIN dim.dim_sup_member_df m ON m.member_id = c.member_id            -- 商户名称 / 类型
        WHERE c.travel_date = '${bizdate}' AND c.is_delete = 0                    -- 只取当日分区，并按条件过滤
          AND (FROM_UNIXTIME(c.create_time, 'yyyyMMdd') = '${bizdate}' OR FROM_UNIXTIME(c.update_time, 'yyyyMMdd') = '${bizdate}')  -- 全量快照取当日新增 / 变更
    ) t
