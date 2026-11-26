-- ================================================================================================
-- ads.ads_sup_customer_company_df  客户公司属性（财务）
-- 粒度：1行=1个 CRM 客户公司
-- 分区：无分区
-- 调度：每日，依赖上游 DWS 当日分区；完成后回流 / 服务层读取
-- 上游：dim_sup_company_df、dws_sup_member_di、dws_sup_contract_di
-- 替代旧任务 2 个（上线对数一致后下线）：
--   · 业务工厂/内部信息/财务部/客户属性cus_company/ads_cus_company_d_f（EMR_SPARK_SQL，cron 00 00 06 * * ?）
--   · 业务工厂/内部信息/财务部/景旅纵横/ads_cus_landtravel_d_f（EMR_SPARK_SQL，cron 00 00 00 * * ?）
-- 业务规则 / 修正：
--   · CRM 客户公司 → 平台账号（user_id）→ 商户日汇总；一个公司多个账号时位图合并去重
-- ================================================================================================
INSERT OVERWRITE TABLE ads.ads_sup_customer_company_df
SELECT
    c.company_id,
    CAST(0 AS DECIMAL(18,2))                                         AS contract_amt,    -- 待确认：合同 → CRM 客户的对应（合同台账 pft_user_id_list）上线前确认
    CAST(0 AS DECIMAL(18,2))                                         AS invoice_amt,     -- 待确认：同上
    CAST(0 AS DECIMAL(18,2))                                         AS payback_amt,     -- 待确认：同上
    BITMAP_UNION(l.login_member_qty)                                 AS login_member_bitmap,
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time
FROM (SELECT DISTINCT company_id, user_id FROM dim.dim_sup_company_df) c
LEFT JOIN (SELECT member_id, BITMAP_UNION(login_member_qty) AS login_member_qty FROM dws.dws_sup_member_di WHERE travel_date = '${bizdate}' GROUP BY member_id) l
       ON l.member_id = c.user_id
GROUP BY c.company_id
