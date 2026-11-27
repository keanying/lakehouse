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
INSERT OVERWRITE TABLE dwd.dwd_sup_crm_sales_order_df PARTITION (travel_date = '${bizdate}')
SELECT
    CAST(id AS BIGINT)                                           AS crm_order_id,
    name                                                         AS crm_order_name,
    account_id                                                   AS crm_account_id,
    account_id__r                                                AS crm_account_name,
    new_opportunity_id                                           AS opportunity_id,
    owner_department_id,
    owner_department,
    field_2uy29__c                                               AS customer_type,
    field_8ys5r__c                                               AS scenic_type,
    field_xjw8n__c                                               AS province_name,
    field_jfo4a__c                                               AS city_name,
    CAST(field_a4xac__c AS INT)                                  AS standard_contract_flag,
    CAST(field_aril1__c AS INT)                                  AS installment_flag,
    life_status,
    receipt_status,
    logistics_status,
    CAST(order_amount AS DECIMAL(18,2))                          AS order_amt,
    CAST(product_amount AS DECIMAL(18,2))                        AS product_amt,
    CAST(payment_amount AS DECIMAL(18,2))                        AS payment_amt,
    CAST(receipt_amount AS DECIMAL(18,2))                        AS receipt_amt,
    CAST(no_receipt_amount AS DECIMAL(18,2))                     AS no_receipt_amt,
    CAST(refund_amount AS DECIMAL(18,2))                         AS refund_amt,
    order_time,
    create_time,
    last_modified_time,
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time
FROM ods.ods_sup_crm_sales_order_df
WHERE travel_date = '${bizdate}'
