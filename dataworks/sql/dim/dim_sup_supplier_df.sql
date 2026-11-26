-- ================================================================================================
-- dim.dim_sup_supplier_df  供应商维度
-- 粒度：1行=1个供应商（租户，sid）
-- 分区：无分区
-- 调度：每日，ODS 全部完成后；维表之间按上游顺序
-- 上游：dim_sup_member_df、ods_sup_member_ext_df、ods_sup_supplier_extinfo_df、ods_sup_customer_certification_df、dim_prd_scenic_df、dim_prd_ticket_df、dim_sup_member_relation_zip
-- 替代旧任务 4 个（上线对数一致后下线）：
--   · 数据平台/平台湖仓工作流/经营数据/dim_cus_core_attributes_df（SERVERLESS_SPARK_SQL，cron 00 00 00 * * ?）
--   · 数据平台/平台湖仓工作流/经营数据/dim_cus_user_customer_info_df（SERVERLESS_SPARK_SQL，cron 00 00 00 * * ?）
--   · 业务工厂/客户数据大屏/大连文化中心/dim_bloc_company_d_f（EMR_SPARK_SQL，cron 00 30 00 * * ?）
--   · 业务工厂/商户数据中心/开通服务的商户及景区/ods_c_land_authorize_d_f（EMR_SPARK_SQL，cron 00 05 00 * * ?）
-- 业务规则 / 修正：
--   · 替代 dim_user_d_f 中供应商部分与 dws_cus_company_prod_d_f 的产品统计；sid = 供应商ID（租户ID）
-- 性能：
--   · 景区数 / 在售票数 / 分销商数各自先按供应商聚合成一行，再与供应商关联（旧任务先关联后 COUNT DISTINCT）
-- ================================================================================================
WITH sup AS (
    SELECT member_id AS supplier_id, member_name, customer_id, register_time, test_flag
    FROM dim.dim_sup_member_df
    WHERE supplier_flag = 1 OR member_type_code = '0'
),
ext AS (
    SELECT CAST(fid AS BIGINT) AS supplier_id, com_name, short_company_name, corp_kind, format_type, types, province, city, contract_model
    FROM ods.ods_sup_member_ext_df WHERE travel_date = '${bizdate}'
),
member_raw AS (SELECT CAST(id AS BIGINT) AS supplier_id, CAST(salesid AS BIGINT) AS signer_id, CAST(kefuid AS BIGINT) AS servicer_id FROM ods.ods_sup_member_df WHERE travel_date = '${bizdate}'),
cert AS (   -- 同一客户多次提交认证，取最近一次
    SELECT customer_id, certi_status
    FROM (SELECT CAST(customer_id AS BIGINT) AS customer_id, certi_status, ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY apply_time DESC) AS rn
          FROM ods.ods_sup_customer_certification_df WHERE travel_date = '${bizdate}') t
    WHERE rn = 1
),
enable AS (SELECT CAST(fid AS BIGINT) AS supplier_id, MIN(enable_time) AS enable_time FROM ods.ods_sup_supplier_extinfo_df WHERE travel_date = '${bizdate}' GROUP BY CAST(fid AS BIGINT)),
scenic AS (SELECT supplier_id, COUNT(1) AS scenic_qty FROM dim.dim_prd_scenic_df GROUP BY supplier_id),
ticket AS (
    SELECT supplier_id, SUM(IF(ticket_status = '1', 1, 0)) AS onsale_ticket_qty, MIN(update_time) AS first_ticket_time
    FROM dim.dim_prd_ticket_df GROUP BY supplier_id
),
distributor AS (   -- 拉链表当前有效：end_date = '99991231'
    SELECT supplier_id, COUNT(DISTINCT distributor_id) AS distributor_qty
    FROM dim.dim_sup_member_relation_zip WHERE end_date = '99991231' GROUP BY supplier_id
)
INSERT OVERWRITE TABLE dim.dim_sup_supplier_df
SELECT
    s.supplier_id,
    s.member_name                                                    AS supplier_name,
    e.com_name                                                       AS company_name,
    e.short_company_name                                             AS company_short_name,
    s.customer_id,
    e.corp_kind                                                      AS company_type_code,
    e.format_type                                                    AS business_type,
    e.types                                                          AS supplier_level,
    e.province                                                       AS province_code,
    e.city                                                           AS city_code,
    c.certi_status                                                   AS certify_status,
    e.contract_model,
    en.enable_time                                                   AS enable_date,
    s.register_time,
    mr.signer_id,
    mr.servicer_id,
    COALESCE(sc.scenic_qty, 0)                                       AS scenic_qty,
    COALESCE(tk.onsale_ticket_qty, 0)                                AS onsale_ticket_qty,
    COALESCE(d.distributor_qty, 0)                                   AS distributor_qty,
    tk.first_ticket_time,
    s.test_flag,
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time
FROM sup s
LEFT JOIN ext e          ON e.supplier_id  = s.supplier_id
LEFT JOIN member_raw mr  ON mr.supplier_id = s.supplier_id
LEFT JOIN cert c         ON c.customer_id  = s.customer_id
LEFT JOIN enable en      ON en.supplier_id = s.supplier_id
LEFT JOIN scenic sc      ON sc.supplier_id = s.supplier_id
LEFT JOIN ticket tk      ON tk.supplier_id = s.supplier_id
LEFT JOIN distributor d  ON d.supplier_id  = s.supplier_id
