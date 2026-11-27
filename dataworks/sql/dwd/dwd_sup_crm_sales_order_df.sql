-- ================================================================================================
-- dwd.dwd_sup_crm_sales_order_df  CRM 销售订单
-- 粒度：1行=1张 CRM 销售订单（当日最新状态）
-- 分区：travel_date（YYYYMMDD）
-- 调度：每日，依赖上游 ODS 当日分区与相关维表
-- 上游：ods_sup_crm_sales_order_df
-- 业务规则 / 修正：
--   · CRM 订单回款 / 开票金额随时间变化，存全量快照；金额在 CRM 中为字符串（元），CAST 为 DECIMAL
--   · 与已下线的 OA 合同链路无关：这是 CRM（纷享）侧订单，业务仍在用（数据中心 / 客户属性）
-- ================================================================================================
INSERT OVERWRITE TABLE dwd.dwd_sup_crm_sales_order_df PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
    CAST(id AS BIGINT)                                           AS crm_order_id,  -- CRM 订单ID
    name                                                         AS crm_order_name,  -- 订单名称
    account_id                                                   AS crm_account_id,  -- CRM 客户ID
    account_id__r                                                AS crm_account_name,  -- CRM 客户名称
    new_opportunity_id                                           AS opportunity_id,  -- 商机ID
    owner_department_id,                                                          -- 负责人主属部门ID
    owner_department,                                                             -- 负责人主属部门
    field_2uy29__c                                               AS customer_type,  -- 客户类型
    field_8ys5r__c                                               AS scenic_type,  -- 景区类型
    field_xjw8n__c                                               AS province_name,  -- 省
    field_jfo4a__c                                               AS city_name,    -- 城市
    CAST(field_a4xac__c AS INT)                                  AS standard_contract_flag,  -- 是否标准合同
    CAST(field_aril1__c AS INT)                                  AS installment_flag,  -- 是否分期付
    life_status,                                                                  -- 生命状态
    receipt_status,                                                               -- 开票完成状态
    logistics_status,                                                             -- 发货状态
    CAST(order_amount AS DECIMAL(18,2))                          AS order_amt,    -- 销售金额（元）
    CAST(product_amount AS DECIMAL(18,2))                        AS product_amt,  -- 产品合计（元）
    CAST(payment_amount AS DECIMAL(18,2))                        AS payment_amt,  -- 已回款金额（元）
    CAST(receipt_amount AS DECIMAL(18,2))                        AS receipt_amt,  -- 已开票金额（元）
    CAST(no_receipt_amount AS DECIMAL(18,2))                     AS no_receipt_amt,  -- 待开票金额（元）
    CAST(refund_amount AS DECIMAL(18,2))                         AS refund_amt,   -- 已退款金额（元）
    order_time,                                                                   -- 订单时间
    create_time,                                                                  -- 创建时间
    last_modified_time,                                                           -- 最后修改时间
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time           -- ETL 加载时间
FROM ods.ods_sup_crm_sales_order_df
WHERE travel_date = '${bizdate}'                                                  -- 只取当日分区
