-- ================================================================================================
-- ads.ads_sup_customer_company_df  客户公司属性（财务部客户属性宽表）
-- 粒度：1行=1个平台商户账号（统计日快照）
-- 分区：无分区
-- 调度：每日，依赖上游 DWS 当日分区；完成后回流 / 服务层读取
-- 上游：dim_sup_member_df、dim_sup_company_df、dws_ord_scenic_ticket_trade_di、dwd_mkt_order_tag_di、ods_opr_sms_sign_apply_df、ods_opr_sms_diy_apply_df、dim_sup_member_relation_zip、dim_prd_ticket_df、dim_prd_scenic_df、dim_prd_resource_df、dim_opr_module_package_df、dwd_opr_package_open_di、dwd_opr_module_open_di、dwd_sup_member_login_di、dwd_opr_sms_send_di、dwd_mkt_sms_task_di、ods_trf_con_sys_member_df、ods_trf_con_sys_df、ods_mkt_posters_df、ods_opr_excel_task_df、ods_mkt_material_center_df
-- 替代旧任务 2 个（上线对数一致后下线）：
--   · 业务工厂/内部信息/财务部/客户属性cus_company/ads_cus_company_d_f（EMR_SPARK_SQL，cron 00 00 06 * * ?）
--   · 业务工厂/内部信息/财务部/客户属性cus_company/dim_cus_company_d_f（EMR_SPARK_SQL，cron 00 00 06 * * ?）
-- 业务规则 / 修正：
--   · 替代旧 dim_cus_company_d_f（财务部客户属性）及其 4 张中间表（套餐 / 登录 / 合作伙伴 / 产品），全部改从标准表计算
--   · 旧表 110 个应用开通标志逐个 CASE 硬编码：模块 ID 与标志名迁入 module_flags.json，SQL 按配置生成
--   · 旧金额单位为分，标准统一为元；客户手机号明文改存哈希
-- 性能：
--   · 套餐 / 登录各读一次历史（登录只读近两个季度分区），先按账号聚合再一次性关联，宽表不放大
--   · 小维表与码表 BROADCAST
-- ================================================================================================
WITH m AS (SELECT * FROM dim.dim_sup_member_df),
k AS (                                                                            -- CRM 客户：同一平台账号多条取最近成交
    SELECT * FROM (SELECT d.*, ROW_NUMBER() OVER (PARTITION BY member_id ORDER BY last_deal_time DESC) AS rk  -- 优先级序号（1 = 生效）
        FROM dim.dim_sup_company_df d WHERE member_id IS NOT NULL) t
    WHERE rk = 1
),
rel AS (SELECT * FROM dim.dim_sup_member_relation_zip WHERE end_date = '99991231'),
pa AS (                                                                           -- 作为上级：分销商 / OTA / 员工
    SELECT r.parent_id AS member_id,                                              -- 供应商ID
           MIN(IF(r.son_type = '0' AND r.relationship_type = '0', r.add_time, NULL)) AS first_add_time,
           MAX(IF(r.son_type = '0' AND r.relationship_type = '0', r.add_time, NULL)) AS last_add_time,
           COUNT(DISTINCT IF(
               r.son_type = '0' AND r.relationship_type = '0',
               r.son_id,
               NULL
           )) AS partner_num_dist,                                                -- 分销商数
           COUNT(DISTINCT IF(
               r.son_type = '0' AND r.relationship_type = '0' AND sm.ota_flag = 1 AND sm.test_flag = 0,
               r.son_id,
               NULL
           )) AS partner_num_ota,                                                 -- OTA 分销商数
           COUNT(DISTINCT IF(
               r.son_type = '2' AND r.relationship_type = '1',
               r.son_id,
               NULL
           )) AS partner_num_staff                                                -- 员工账号数（从属关系）
    FROM rel r LEFT JOIN m sm ON sm.member_id = r.son_id
    GROUP BY r.parent_id                                                          -- 按粒度键汇总
),
ps AS (SELECT son_id AS member_id, COUNT(DISTINCT parent_id) AS partner_num_supp FROM rel WHERE relationship_type = '0' GROUP BY son_id),  -- 作为下级：供应商数
tsys AS (                                                                         -- 绑定的票务系统（配置表，无业务过程，直接按 ODS）
    SELECT b.pft_memberid AS member_id,                                           -- 供应商ID
           COUNT(DISTINCT b.cid) AS sys_qty,
           CONCAT_WS('、', SORT_ARRAY(COLLECT_SET(s.name))) AS sys_list
    FROM ods.ods_trf_con_sys_member_df b
    LEFT JOIN ods.ods_trf_con_sys_df s ON s.id = b.cid AND s.travel_date = '${bizdate}'
    WHERE b.travel_date = '${bizdate}' AND b.status = 0                           -- 只取当日分区，并按条件过滤
    GROUP BY b.pft_memberid                                                       -- 按粒度键汇总
),
pr AS (                                                                           -- 自供应门票 / 产品
    SELECT supplier_id AS member_id,                                              -- 供应商ID
           MIN(update_time) AS first_edit_time,
           MAX(update_time) AS last_edit_time,
           COUNT(DISTINCT IF(
               ticket_status = '1' AND COALESCE(TO_DATE(max_expiration_date), TO_DATE('${bizdate}', 'yyyyMMdd')) >= TO_DATE('${bizdate}', 'yyyyMMdd'),
               ticket_id,
               NULL
           )) AS onsale_ticket,
           COUNT(DISTINCT IF(
               ticket_status = '1' AND COALESCE(TO_DATE(max_expiration_date), TO_DATE('${bizdate}', 'yyyyMMdd')) >= TO_DATE('${bizdate}', 'yyyyMMdd'),
               scenic_id,
               NULL
           )) AS onsale_land,
           COUNT(DISTINCT IF(ticket_status = '2', ticket_id, NULL)) AS off_ticket,
           COUNT(DISTINCT IF(ticket_status = '2', scenic_id, NULL)) AS off_land,
           COUNT(DISTINCT IF(
               ticket_status = '1' AND TO_DATE(max_expiration_date) < TO_DATE('${bizdate}', 'yyyyMMdd'),
               ticket_id,
               NULL
           )) AS overdue_ticket,
           COUNT(DISTINCT IF(
               ticket_status = '1' AND TO_DATE(max_expiration_date) < TO_DATE('${bizdate}', 'yyyyMMdd'),
               scenic_id,
               NULL
           )) AS overdue_land,
           COUNT(DISTINCT IF(
               TO_DATE(update_time) >= DATE_SUB(TO_DATE('${bizdate}', 'yyyyMMdd'), PMOD(DATEDIFF(TO_DATE('${bizdate}', 'yyyyMMdd'), '1900-01-01'), 7)),
               ticket_id,
               NULL
           )) AS add_ticket_curr_week,
           COUNT(DISTINCT IF(
               TO_DATE(update_time) >= DATE_SUB(TO_DATE('${bizdate}', 'yyyyMMdd'), PMOD(DATEDIFF(TO_DATE('${bizdate}', 'yyyyMMdd'), '1900-01-01'), 7)),
               scenic_id,
               NULL
           )) AS add_land_curr_week,
           COUNT(DISTINCT IF(
               TO_DATE(update_time) >= TRUNC(TO_DATE('${bizdate}', 'yyyyMMdd'), 'MM'),
               ticket_id,
               NULL
           )) AS add_ticket_curr_month,
           COUNT(DISTINCT IF(
               TO_DATE(update_time) >= TRUNC(TO_DATE('${bizdate}', 'yyyyMMdd'), 'MM'),
               scenic_id,
               NULL
           )) AS add_land_curr_month,
           COUNT(DISTINCT IF(
               TO_DATE(update_time) >= ADD_MONTHS(TRUNC(TO_DATE('${bizdate}', 'yyyyMMdd'), 'YEAR'), (QUARTER(TO_DATE('${bizdate}', 'yyyyMMdd'))
                   - 1) * 3),
               ticket_id,
               NULL
           )) AS add_ticket_curr_quarter,
           COUNT(DISTINCT IF(
               TO_DATE(update_time) >= ADD_MONTHS(TRUNC(TO_DATE('${bizdate}', 'yyyyMMdd'), 'YEAR'), (QUARTER(TO_DATE('${bizdate}', 'yyyyMMdd'))
                   - 1) * 3),
               scenic_id,
               NULL
           )) AS add_land_curr_quarter,
           COUNT(DISTINCT sc.scenic_type_code) AS product_type_qty                -- 发布的产品类型数
    FROM dim.dim_prd_ticket_df t
    LEFT JOIN (SELECT scenic_id AS sid_, scenic_type_code FROM dim.dim_prd_scenic_df) sc  -- 关联「景区维度」按键聚合
      ON sc.sid_ = t.scenic_id                                                    -- 按 scenic_id→sid_ 关联
    WHERE t.ticket_status <> '6'
    GROUP BY supplier_id                                                          -- 按粒度键汇总
),
rs AS (                                                                           -- 自供应资源（资源中心上架）
    SELECT supplier_id AS member_id,                                              -- 供应商ID
           COUNT(DISTINCT IF(
               resource_status = 1 AND COALESCE(TO_DATE(max_expiration_date), TO_DATE('${bizdate}', 'yyyyMMdd')) >= TO_DATE('${bizdate}', 'yyyyMMdd'),
               resource_id,
               NULL
           )) AS onsale_resource,
           COUNT(DISTINCT IF(resource_status = 0, resource_id, NULL)) AS off_resource,
           COUNT(DISTINCT IF(
               resource_status = 1 AND TO_DATE(max_expiration_date) < TO_DATE('${bizdate}', 'yyyyMMdd'),
               resource_id,
               NULL
           )) AS overdue_resource,
           COUNT(DISTINCT IF(
               TO_DATE(update_time) >= DATE_SUB(TO_DATE('${bizdate}', 'yyyyMMdd'), PMOD(DATEDIFF(TO_DATE('${bizdate}', 'yyyyMMdd'), '1900-01-01'), 7)),
               resource_id,
               NULL
           )) AS add_resource_curr_week,
           COUNT(DISTINCT IF(
               TO_DATE(update_time) >= TRUNC(TO_DATE('${bizdate}', 'yyyyMMdd'), 'MM'),
               resource_id,
               NULL
           )) AS add_resource_curr_month,
           COUNT(DISTINCT IF(
               TO_DATE(update_time) >= ADD_MONTHS(TRUNC(TO_DATE('${bizdate}', 'yyyyMMdd'), 'YEAR'), (QUARTER(TO_DATE('${bizdate}', 'yyyyMMdd'))
                   - 1) * 3),
               resource_id,
               NULL
           )) AS add_resource_curr_quarter
    FROM dim.dim_prd_resource_df
    GROUP BY supplier_id                                                          -- 按粒度键汇总
),
pd AS (                                                                           -- 分销：上级供应商在售的票 / 产品 / 资源
    SELECT r.son_id AS member_id,                                                 -- 供应商ID
           COUNT(DISTINCT IF(t.ticket_status = '1', t.ticket_id, NULL)) AS dist_ticket,
           COUNT(DISTINCT IF(t.ticket_status = '1', t.scenic_id, NULL)) AS dist_land,
           COUNT(DISTINCT rr.resource_id) AS dist_resource
    FROM rel r
    JOIN dim.dim_prd_ticket_df t ON t.supplier_id = r.parent_id
    LEFT JOIN dim.dim_prd_resource_df rr                                          -- 关联「资源中心资源维度」
      ON rr.supplier_id = r.parent_id AND rr.ticket_id = t.ticket_id AND rr.resource_status = 1  -- 按 parent_id→supplier_id、ticket_id 关联
    WHERE r.relationship_type = '0'
    GROUP BY r.son_id                                                             -- 按粒度键汇总
),
pkh AS (                                                                          -- 套餐开通历史（全部分区）+ 套餐分类
    SELECT o.*, c.classify_name
    FROM dwd.dwd_opr_package_open_di o
    LEFT JOIN (SELECT package_id, MAX(package_classify_name) AS classify_name
        FROM dim.dim_opr_module_package_df WHERE package_id > 0 GROUP BY package_id) c
           ON c.package_id = o.package_id                                         -- 按 package_id 关联
    WHERE o.travel_date <= '${bizdate}' AND COALESCE(o.stop_type, 0) <> 1         -- 累计口径：取截至统计日的全部分区｜作废的不算
),
pk AS (
    SELECT member_id,
           SUM(package_pay_amt) AS amount_package,                                -- 套餐实收合计（元）
           COUNT(1) AS num_buy,
           COUNT(IF(TO_DATE(valid_end_time) < TO_DATE('${bizdate}', 'yyyyMMdd'), 1, NULL)) AS num_used
    FROM pkh GROUP BY member_id
),
p_first AS (SELECT * FROM (SELECT h.*, ROW_NUMBER()
    OVER (PARTITION BY member_id ORDER BY valid_start_time, open_time) AS rk FROM pkh h WHERE 1 = 1) t WHERE rk = 1),
p_first_supplier AS (SELECT * FROM (SELECT h.*, ROW_NUMBER()
    OVER (PARTITION BY member_id ORDER BY valid_start_time, open_time) AS rk FROM pkh h WHERE package_role = 0) t WHERE rk = 1),
p_curr AS (SELECT * FROM (SELECT h.*, ROW_NUMBER()
    OVER (PARTITION BY member_id ORDER BY valid_start_time DESC, open_time DESC) AS rk  -- 优先级序号（1 = 生效）
        FROM pkh h WHERE TO_DATE(valid_start_time) <= TO_DATE('${bizdate}', 'yyyyMMdd')
            AND TO_DATE(valid_end_time) >= TO_DATE('${bizdate}', 'yyyyMMdd')) t WHERE rk = 1),
p_last AS (SELECT * FROM (SELECT h.*, ROW_NUMBER()
    OVER (PARTITION BY member_id ORDER BY valid_end_time DESC, open_time DESC) AS rk  -- 优先级序号（1 = 生效）
        FROM pkh h WHERE TO_DATE(valid_end_time) < TO_DATE('${bizdate}', 'yyyyMMdd')) t WHERE rk = 1),
p_next AS (SELECT * FROM (SELECT h.*, ROW_NUMBER()
    OVER (PARTITION BY member_id ORDER BY valid_start_time, open_time) AS rk      -- 优先级序号（1 = 生效）
        FROM pkh h WHERE TO_DATE(valid_start_time) > TO_DATE('${bizdate}', 'yyyyMMdd')) t WHERE rk = 1),
p_end AS (SELECT * FROM (SELECT h.*, ROW_NUMBER()
    OVER (PARTITION BY member_id ORDER BY valid_end_time DESC, open_time DESC) AS rk FROM pkh h WHERE 1 = 1) t WHERE rk = 1),
lg AS (                                                                           -- 登录：近两个季度分区
    SELECT member_id,
           COUNT(IF(
               login_source = '1' AND login_date BETWEEN DATE_SUB(TO_DATE('${bizdate}', 'yyyyMMdd'), PMOD(DATEDIFF(TO_DATE('${bizdate}', 'yyyyMMdd'), '1900-01-01'), 7))
                   AND TO_DATE('${bizdate}', 'yyyyMMdd'),
               1,
               NULL
           )) AS n_plat_curr_week,
           COUNT(DISTINCT IF(
               login_source = '1' AND login_date BETWEEN DATE_SUB(TO_DATE('${bizdate}', 'yyyyMMdd'), PMOD(DATEDIFF(TO_DATE('${bizdate}', 'yyyyMMdd'), '1900-01-01'), 7))
                   AND TO_DATE('${bizdate}', 'yyyyMMdd'),
               login_date,
               NULL
           )) AS d_plat_curr_week,
           COUNT(IF(
               login_source = '2' AND login_date BETWEEN DATE_SUB(TO_DATE('${bizdate}', 'yyyyMMdd'), PMOD(DATEDIFF(TO_DATE('${bizdate}', 'yyyyMMdd'), '1900-01-01'), 7))
                   AND TO_DATE('${bizdate}', 'yyyyMMdd'),
               1,
               NULL
           )) AS n_terminal_curr_week,
           COUNT(DISTINCT IF(
               login_source = '2' AND login_date BETWEEN DATE_SUB(TO_DATE('${bizdate}', 'yyyyMMdd'), PMOD(DATEDIFF(TO_DATE('${bizdate}', 'yyyyMMdd'), '1900-01-01'), 7))
                   AND TO_DATE('${bizdate}', 'yyyyMMdd'),
               login_date,
               NULL
           )) AS d_terminal_curr_week,
           COUNT(IF(
               login_source = '1' AND login_date BETWEEN DATE_SUB(DATE_SUB(TO_DATE('${bizdate}', 'yyyyMMdd'), PMOD(DATEDIFF(TO_DATE('${bizdate}', 'yyyyMMdd'), '1900-01-01'), 7)), 7)
                   AND DATE_SUB(DATE_SUB(TO_DATE('${bizdate}', 'yyyyMMdd'), PMOD(DATEDIFF(TO_DATE('${bizdate}', 'yyyyMMdd'), '1900-01-01'), 7)), 1),
               1,
               NULL
           )) AS n_plat_last_week,
           COUNT(DISTINCT IF(
               login_source = '1' AND login_date BETWEEN DATE_SUB(DATE_SUB(TO_DATE('${bizdate}', 'yyyyMMdd'), PMOD(DATEDIFF(TO_DATE('${bizdate}', 'yyyyMMdd'), '1900-01-01'), 7)), 7)
                   AND DATE_SUB(DATE_SUB(TO_DATE('${bizdate}', 'yyyyMMdd'), PMOD(DATEDIFF(TO_DATE('${bizdate}', 'yyyyMMdd'), '1900-01-01'), 7)), 1),
               login_date,
               NULL
           )) AS d_plat_last_week,
           COUNT(IF(
               login_source = '2' AND login_date BETWEEN DATE_SUB(DATE_SUB(TO_DATE('${bizdate}', 'yyyyMMdd'), PMOD(DATEDIFF(TO_DATE('${bizdate}', 'yyyyMMdd'), '1900-01-01'), 7)), 7)
                   AND DATE_SUB(DATE_SUB(TO_DATE('${bizdate}', 'yyyyMMdd'), PMOD(DATEDIFF(TO_DATE('${bizdate}', 'yyyyMMdd'), '1900-01-01'), 7)), 1),
               1,
               NULL
           )) AS n_terminal_last_week,
           COUNT(DISTINCT IF(
               login_source = '2' AND login_date BETWEEN DATE_SUB(DATE_SUB(TO_DATE('${bizdate}', 'yyyyMMdd'), PMOD(DATEDIFF(TO_DATE('${bizdate}', 'yyyyMMdd'), '1900-01-01'), 7)), 7)
                   AND DATE_SUB(DATE_SUB(TO_DATE('${bizdate}', 'yyyyMMdd'), PMOD(DATEDIFF(TO_DATE('${bizdate}', 'yyyyMMdd'), '1900-01-01'), 7)), 1),
               login_date,
               NULL
           )) AS d_terminal_last_week,
           COUNT(IF(
               login_source = '1' AND login_date BETWEEN TRUNC(TO_DATE('${bizdate}', 'yyyyMMdd'), 'MM') AND TO_DATE('${bizdate}', 'yyyyMMdd'),
               1,
               NULL
           )) AS n_plat_curr_month,
           COUNT(DISTINCT IF(
               login_source = '1' AND login_date BETWEEN TRUNC(TO_DATE('${bizdate}', 'yyyyMMdd'), 'MM') AND TO_DATE('${bizdate}', 'yyyyMMdd'),
               login_date,
               NULL
           )) AS d_plat_curr_month,
           COUNT(IF(
               login_source = '2' AND login_date BETWEEN TRUNC(TO_DATE('${bizdate}', 'yyyyMMdd'), 'MM') AND TO_DATE('${bizdate}', 'yyyyMMdd'),
               1,
               NULL
           )) AS n_terminal_curr_month,
           COUNT(DISTINCT IF(
               login_source = '2' AND login_date BETWEEN TRUNC(TO_DATE('${bizdate}', 'yyyyMMdd'), 'MM') AND TO_DATE('${bizdate}', 'yyyyMMdd'),
               login_date,
               NULL
           )) AS d_terminal_curr_month,
           COUNT(IF(
               login_source = '1' AND login_date BETWEEN ADD_MONTHS(TRUNC(TO_DATE('${bizdate}', 'yyyyMMdd'), 'MM'), -1)
                   AND DATE_SUB(TRUNC(TO_DATE('${bizdate}', 'yyyyMMdd'), 'MM'), 1),
               1,
               NULL
           )) AS n_plat_last_month,
           COUNT(DISTINCT IF(
               login_source = '1' AND login_date BETWEEN ADD_MONTHS(TRUNC(TO_DATE('${bizdate}', 'yyyyMMdd'), 'MM'), -1)
                   AND DATE_SUB(TRUNC(TO_DATE('${bizdate}', 'yyyyMMdd'), 'MM'), 1),
               login_date,
               NULL
           )) AS d_plat_last_month,
           COUNT(IF(
               login_source = '2' AND login_date BETWEEN ADD_MONTHS(TRUNC(TO_DATE('${bizdate}', 'yyyyMMdd'), 'MM'), -1)
                   AND DATE_SUB(TRUNC(TO_DATE('${bizdate}', 'yyyyMMdd'), 'MM'), 1),
               1,
               NULL
           )) AS n_terminal_last_month,
           COUNT(DISTINCT IF(
               login_source = '2' AND login_date BETWEEN ADD_MONTHS(TRUNC(TO_DATE('${bizdate}', 'yyyyMMdd'), 'MM'), -1)
                   AND DATE_SUB(TRUNC(TO_DATE('${bizdate}', 'yyyyMMdd'), 'MM'), 1),
               login_date,
               NULL
           )) AS d_terminal_last_month,
           COUNT(IF(
               login_source = '1' AND login_date BETWEEN ADD_MONTHS(TRUNC(TO_DATE('${bizdate}', 'yyyyMMdd'), 'YEAR'), (QUARTER(TO_DATE('${bizdate}', 'yyyyMMdd'))
                   - 1) * 3) AND TO_DATE('${bizdate}', 'yyyyMMdd'),
               1,
               NULL
           )) AS n_plat_curr_quarter,
           COUNT(DISTINCT IF(
               login_source = '1' AND login_date BETWEEN ADD_MONTHS(TRUNC(TO_DATE('${bizdate}', 'yyyyMMdd'), 'YEAR'), (QUARTER(TO_DATE('${bizdate}', 'yyyyMMdd'))
                   - 1) * 3) AND TO_DATE('${bizdate}', 'yyyyMMdd'),
               login_date,
               NULL
           )) AS d_plat_curr_quarter,
           COUNT(IF(
               login_source = '2' AND login_date BETWEEN ADD_MONTHS(TRUNC(TO_DATE('${bizdate}', 'yyyyMMdd'), 'YEAR'), (QUARTER(TO_DATE('${bizdate}', 'yyyyMMdd'))
                   - 1) * 3) AND TO_DATE('${bizdate}', 'yyyyMMdd'),
               1,
               NULL
           )) AS n_terminal_curr_quarter,
           COUNT(DISTINCT IF(
               login_source = '2' AND login_date BETWEEN ADD_MONTHS(TRUNC(TO_DATE('${bizdate}', 'yyyyMMdd'), 'YEAR'), (QUARTER(TO_DATE('${bizdate}', 'yyyyMMdd'))
                   - 1) * 3) AND TO_DATE('${bizdate}', 'yyyyMMdd'),
               login_date,
               NULL
           )) AS d_terminal_curr_quarter,
           COUNT(IF(
               login_source = '1' AND login_date BETWEEN ADD_MONTHS(ADD_MONTHS(TRUNC(TO_DATE('${bizdate}', 'yyyyMMdd'), 'YEAR'), (QUARTER(TO_DATE('${bizdate}', 'yyyyMMdd'))
                   - 1) * 3), -3) AND DATE_SUB(ADD_MONTHS(TRUNC(TO_DATE('${bizdate}', 'yyyyMMdd'),
                   'YEAR'), (QUARTER(TO_DATE('${bizdate}', 'yyyyMMdd')) - 1) * 3), 1),
               1,
               NULL
           )) AS n_plat_last_quarter,
           COUNT(DISTINCT IF(
               login_source = '1' AND login_date BETWEEN ADD_MONTHS(ADD_MONTHS(TRUNC(TO_DATE('${bizdate}', 'yyyyMMdd'), 'YEAR'), (QUARTER(TO_DATE('${bizdate}', 'yyyyMMdd'))
                   - 1) * 3), -3) AND DATE_SUB(ADD_MONTHS(TRUNC(TO_DATE('${bizdate}', 'yyyyMMdd'),
                   'YEAR'), (QUARTER(TO_DATE('${bizdate}', 'yyyyMMdd')) - 1) * 3), 1),
               login_date,
               NULL
           )) AS d_plat_last_quarter,
           COUNT(IF(
               login_source = '2' AND login_date BETWEEN ADD_MONTHS(ADD_MONTHS(TRUNC(TO_DATE('${bizdate}', 'yyyyMMdd'), 'YEAR'), (QUARTER(TO_DATE('${bizdate}', 'yyyyMMdd'))
                   - 1) * 3), -3) AND DATE_SUB(ADD_MONTHS(TRUNC(TO_DATE('${bizdate}', 'yyyyMMdd'),
                   'YEAR'), (QUARTER(TO_DATE('${bizdate}', 'yyyyMMdd')) - 1) * 3), 1),
               1,
               NULL
           )) AS n_terminal_last_quarter,
           COUNT(DISTINCT IF(
               login_source = '2' AND login_date BETWEEN ADD_MONTHS(ADD_MONTHS(TRUNC(TO_DATE('${bizdate}', 'yyyyMMdd'), 'YEAR'), (QUARTER(TO_DATE('${bizdate}', 'yyyyMMdd'))
                   - 1) * 3), -3) AND DATE_SUB(ADD_MONTHS(TRUNC(TO_DATE('${bizdate}', 'yyyyMMdd'),
                   'YEAR'), (QUARTER(TO_DATE('${bizdate}', 'yyyyMMdd')) - 1) * 3), 1),
               login_date,
               NULL
           )) AS d_terminal_last_quarter,
           COUNT(IF(
               login_source = '1' AND login_date BETWEEN DATE_SUB(TO_DATE('${bizdate}', 'yyyyMMdd'), 59) AND TO_DATE('${bizdate}', 'yyyyMMdd'),
               1,
               NULL
           )) AS n_plat_60_day,
           COUNT(DISTINCT IF(
               login_source = '1' AND login_date BETWEEN DATE_SUB(TO_DATE('${bizdate}', 'yyyyMMdd'), 59) AND TO_DATE('${bizdate}', 'yyyyMMdd'),
               login_date,
               NULL
           )) AS d_plat_60_day,
           COUNT(IF(
               login_source = '2' AND login_date BETWEEN DATE_SUB(TO_DATE('${bizdate}', 'yyyyMMdd'), 59) AND TO_DATE('${bizdate}', 'yyyyMMdd'),
               1,
               NULL
           )) AS n_terminal_60_day,
           COUNT(DISTINCT IF(
               login_source = '2' AND login_date BETWEEN DATE_SUB(TO_DATE('${bizdate}', 'yyyyMMdd'), 59) AND TO_DATE('${bizdate}', 'yyyyMMdd'),
               login_date,
               NULL
           )) AS d_terminal_60_day
    FROM (SELECT member_id, CAST(login_source AS STRING) AS login_source, TO_DATE(login_time) AS login_date FROM dwd.dwd_sup_member_login_di
          WHERE travel_date >= DATE_FORMAT(ADD_MONTHS(ADD_MONTHS(TRUNC(TO_DATE('${bizdate}', 'yyyyMMdd'), 'YEAR'), (QUARTER(TO_DATE('${bizdate}', 'yyyyMMdd'))
              - 1) * 3), -3), 'yyyyMMdd')
            AND travel_date <= '${bizdate}') t                                    -- 累计口径：取截至统计日的全部分区
    GROUP BY member_id                                                            -- 按粒度键汇总
),
md AS (                                                                           -- 当前有效的应用模块：单独开通 + 当前套餐内含模块
    SELECT member_id,
           MAX(IF(module_id = 1, 1, 0)) AS is_open_wsc,                           -- 是否开通「微商城（旧版）」
           MAX(IF(module_id = 2, 1, 0)) AS is_open_hbtg,                          -- 是否开通「海报推广」
           MAX(IF(module_id = 3, 1, 0)) AS is_open_sjlp,                          -- 是否开通「数据罗盘」
           MAX(IF(module_id = 5, 1, 0)) AS is_open_qmyx,                          -- 是否开通「全民营销」
           MAX(IF(module_id = 9, 1, 0)) AS is_open_yspzd,                         -- 是否开通「云售票终端」
           MAX(IF(module_id = 10, 1, 0)) AS is_open_miniyzd,                      -- 是否开通「MINI云终端」
           MAX(IF(module_id = 11, 1, 0)) AS is_open_znyzj,                        -- 是否开通「智能云闸机」
           MAX(IF(module_id = 12, 1, 0)) AS is_open_lyykt,                        -- 是否开通「旅游一卡通」
           MAX(IF(module_id = 13, 1, 0)) AS is_open_ljgg,                         -- 是否开通「链接广告」
           MAX(IF(module_id = 15, 1, 0)) AS is_open_zzsqpj,                       -- 是否开通「自助售取票机」
           MAX(IF(module_id = 16, 1, 0)) AS is_open_appxz,                        -- 是否开通「APP下载」
           MAX(IF(module_id = 17, 1, 0)) AS is_open_xxpwxt,                       -- 是否开通「线下票务系统」
           MAX(IF(module_id = 18, 1, 0)) AS is_open_jdxd,                         -- 是否开通「计调下单」
           MAX(IF(module_id = 20, 1, 0)) AS is_open_yhqjb,                        -- 是否开通「优惠券(旧版)」
           MAX(IF(module_id = 21, 1, 0)) AS is_open_lynk,                         -- 是否开通「旅游年卡」
           MAX(IF(module_id = 22, 1, 0)) AS is_open_b2cscpcd,                     -- 是否开通「B2C商城
           MAX(IF(module_id = 23, 1, 0)) AS is_open_jszdrz,                       -- 是否开通「结算自动入帐」
           MAX(IF(module_id = 25, 1, 0)) AS is_open_otaptfx,                      -- 是否开通「OTA平台分销」
           MAX(IF(module_id = 26, 1, 0)) AS is_open_typtfx,                       -- 是否开通「同业平台分销」
           MAX(IF(module_id = 27, 1, 0)) AS is_open_fxdsfcp,                      -- 是否开通「分销第三方产品」
           MAX(IF(module_id = 29, 1, 0)) AS is_open_wqglxt,                       -- 是否开通「温泉管理系统」
           MAX(IF(module_id = 35, 1, 0)) AS is_open_jqpwxt,                       -- 是否开通「景区票务系统」
           MAX(IF(module_id = 36, 1, 0)) AS is_open_yqykt,                        -- 是否开通「园区一卡通」
           MAX(IF(module_id = 37, 1, 0)) AS is_open_zfxcp,                        -- 是否开通「转分销产品」
           MAX(IF(module_id = 39, 1, 0)) AS is_open_dzfp,                         -- 是否开通「电子发票」
           MAX(IF(module_id = 40, 1, 0)) AS is_open_xsqg,                         -- 是否开通「限时抢购」
           MAX(IF(module_id = 41, 1, 0)) AS is_open_dsjfx,                        -- 是否开通「大数据分析」
           MAX(IF(module_id = 42, 1, 0)) AS is_open_flgl,                         -- 是否开通「返利管理」
           MAX(IF(module_id = 43, 1, 0)) AS is_open_mygxdj,                       -- 是否开通「蚂蚁供销对接」
           MAX(IF(module_id = 44, 1, 0)) AS is_open_yzwscdj,                      -- 是否开通「有赞微商城对接」
           MAX(IF(module_id = 45, 1, 0)) AS is_open_kjwsc,                        -- 是否开通「砍价(微商城)」
           MAX(IF(module_id = 46, 1, 0)) AS is_open_ptwsc,                        -- 是否开通「拼团(微商城)」
           MAX(IF(module_id = 47, 1, 0)) AS is_open_miniyxcx,                     -- 是否开通「MiNi云小程序」
           MAX(IF(module_id = 48, 1, 0)) AS is_open_jfsc,                         -- 是否开通「积分商城」
           MAX(IF(module_id = 51, 1, 0)) AS is_open_fxzy,                         -- 是否开通「分销专员」
           MAX(IF(module_id = 52, 1, 0)) AS is_open_hytx,                         -- 是否开通「会员体系」
           MAX(IF(module_id = 55, 1, 0)) AS is_open_zghxf,                        -- 是否开通「公众号吸粉」
           MAX(IF(module_id = 56, 1, 0)) AS is_open_hbffl,                        -- 是否开通「红包翻翻乐」
           MAX(IF(module_id = 57, 1, 0)) AS is_open_zyzx,                         -- 是否开通「资源中心」
           MAX(IF(module_id = 58, 1, 0)) AS is_open_wxzxwsc,                      -- 是否开通「微信直销
           MAX(IF(module_id = 59, 1, 0)) AS is_open_xcxsc,                        -- 是否开通「小程序商城」
           MAX(IF(module_id = 60, 1, 0)) AS is_open_yhq,                          -- 是否开通「优惠券」
           MAX(IF(module_id = 61, 1, 0)) AS is_open_fsyy,                         -- 是否开通「分时预约」
           MAX(IF(module_id = 62, 1, 0)) AS is_open_gzhyx,                        -- 是否开通「公众号营销」
           MAX(IF(module_id = 63, 1, 0)) AS is_open_xcxpro,                       -- 是否开通「小程序Pro」
           MAX(IF(module_id = 65, 1, 0)) AS is_open_xfxzy,                        -- 是否开通「新分销专员」
           MAX(IF(module_id = 66, 1, 0)) AS is_open_rlzx,                         -- 是否开通「人脸中心」
           MAX(IF(module_id = 67, 1, 0)) AS is_open_ckgl,                         -- 是否开通「窗口管理」
           MAX(IF(module_id = 68, 1, 0)) AS is_open_zpgl,                         -- 是否开通「纸票管理」
           MAX(IF(module_id = 69, 1, 0)) AS is_open_btglgysb,                     -- 是否开通「报团管理
           MAX(IF(module_id = 70, 1, 0)) AS is_open_btglfxsb,                     -- 是否开通「报团管理
           MAX(IF(module_id = 71, 1, 0)) AS is_open_schygl,                       -- 是否开通「商城会员管理」
           MAX(IF(module_id = 72, 1, 0)) AS is_open_yqjs,                         -- 是否开通「园区计时」
           MAX(IF(module_id = 73, 1, 0)) AS is_open_jqsjlp,                       -- 是否开通「景区数据罗盘」
           MAX(IF(module_id = 74, 1, 0)) AS is_open_dlymdj,                       -- 是否开通「独立域名搭建」
           MAX(IF(module_id = 75, 1, 0)) AS is_open_wbmfmgl,                      -- 是否开通「外部码发码管理」
           MAX(IF(module_id = 76, 1, 0)) AS is_open_typtfxjcb,                    -- 是否开通「同业平台分销(基础版)」
           MAX(IF(module_id = 77, 1, 0)) AS is_open_wxkq,                         -- 是否开通「微信卡券」
           MAX(IF(module_id = 78, 1, 0)) AS is_open_gpxzhbmd,                     -- 是否开通「购票限制(黑白名单)」
           MAX(IF(module_id = 79, 1, 0)) AS is_open_crysjtj,                      -- 是否开通「出入园数据统计」
           MAX(IF(module_id = 80, 1, 0)) AS is_open_csyy21wm,                     -- 是否开通「测试应用21
           MAX(IF(module_id = 81, 1, 0)) AS is_open_ylcs,                         -- 是否开通「依赖测试」
           MAX(IF(module_id = 82, 1, 0)) AS is_open_csyyw,                        -- 是否开通「测试应用w」
           MAX(IF(module_id = 83, 1, 0)) AS is_open_qwechb,                       -- 是否开通「qwe_chb」
           MAX(IF(module_id = 84, 1, 0)) AS is_open_cssy,                         -- 是否开通「测试使用」
           MAX(IF(module_id = 85, 1, 0)) AS is_open_zdgl,                         -- 是否开通「终端管理」
           MAX(IF(module_id = 86, 1, 0)) AS is_open_lxssjlp,                      -- 是否开通「旅行社数据罗盘」
           MAX(IF(module_id = 87, 1, 0)) AS is_open_dxttzdy,                      -- 是否开通「短信抬头自定义」
           MAX(IF(module_id = 88, 1, 0)) AS is_openzdydxmb,                       -- 是否开通「自定义短信模板」
           MAX(IF(module_id = 89, 1, 0)) AS is_open_lyxd,                         -- 是否开通「旅游小店」
           MAX(IF(module_id = 90, 1, 0)) AS is_open_xypgl,                        -- 是否开通「协议票管理」
           MAX(IF(module_id = 91, 1, 0)) AS is_open_tstdyy,                       -- 是否开通「特殊团队预约」
           MAX(IF(module_id = 92, 1, 0)) AS is_open_smyzbzb,                      -- 是否开通「扫码验证-标准版」
           MAX(IF(module_id = 93, 1, 0)) AS is_open_smyzzyb,                      -- 是否开通「扫码验证-专业版」
           MAX(IF(module_id = 94, 1, 0)) AS is_open_wlzx,                         -- 是否开通「物料中心」
           MAX(IF(module_id = 95, 1, 0)) AS is_open_wpttbfx,                      -- 是否开通「微平台图表分析」
           MAX(IF(module_id = 96, 1, 0)) AS is_open_dyglgysb,                     -- 是否开通「导游管理(供应商版)」
           MAX(IF(module_id = 97, 1, 0)) AS is_open_dyglfxsb,                     -- 是否开通「导游管理(分销商版)」
           MAX(IF(module_id = 176, 1, 0)) AS is_open_yxdx,                        -- 是否开通「营销短信」
           MAX(IF(module_id = 177, 1, 0)) AS is_open_test,                        -- 是否开通「test」
           MAX(IF(module_id = 178, 1, 0)) AS is_open_gpqz,                        -- 是否开通「购票前置」
           MAX(IF(module_id = 179, 1, 0)) AS is_open_ddxxyc,                      -- 是否开通「订单信息隐藏」
           MAX(IF(module_id = 180, 1, 0)) AS is_open_kjgp,                        -- 是否开通「快捷购票」
           MAX(IF(module_id = 181, 1, 0)) AS is_open_xmtfx,                       -- 是否开通「新媒体分销」
           MAX(IF(module_id = 182, 1, 0)) AS is_open_flglx,                       -- 是否开通「返利管理（新）」
           MAX(IF(module_id = 183, 1, 0)) AS is_open_bbyy,                        -- 是否开通「报表应用」
           MAX(IF(module_id = 184, 1, 0)) AS is_open_csyywm,                      -- 是否开通「测试应用
           MAX(IF(module_id = 185, 1, 0)) AS is_open_tdyy,                        -- 是否开通「团队预约」
           MAX(IF(module_id = 186, 1, 0)) AS is_open_fxskjgp,                     -- 是否开通「分销商快捷购票」
           MAX(IF(module_id = 187, 1, 0)) AS is_open_plzzbb,                      -- 是否开通「票类纸质报表」
           MAX(IF(module_id = 243, 1, 0)) AS is_open_qplfx,                       -- 是否开通「全品类分销」
           MAX(IF(module_id = 244, 1, 0)) AS is_open_tgdm,                        -- 是否开通「团购导码」
           MAX(IF(module_id = 245, 1, 0)) AS is_open_xcxzxjq,                     -- 是否开通「小程序中心(景区)」
           MAX(IF(module_id = 246, 1, 0)) AS is_open_xcxzxlxsb,                   -- 是否开通「小程序中心(旅行社版)」
           MAX(IF(module_id = 247, 1, 0)) AS is_open_jyjcsj,                      -- 是否开通「经营基础数据」
           MAX(IF(module_id = 248, 1, 0)) AS is_open_jyfxsj,                      -- 是否开通「经营分析数据」
           MAX(IF(module_id = 249, 1, 0)) AS is_open_ycjs,                        -- 是否开通「游船计时」
           MAX(IF(module_id = 250, 1, 0)) AS is_open_jyxpbg,                      -- 是否开通「经营小飘报告」
           MAX(IF(module_id = 251, 1, 0)) AS is_open_jyhysj,                      -- 是否开通「经营行业数据」
           MAX(IF(module_id = 252, 1, 0)) AS is_open_tysy,                        -- 是否开通「统一收银」
           MAX(IF(module_id = 254, 1, 0)) AS is_open_xykt,                        -- 是否开通「新一卡通」
           MAX(IF(module_id = 255, 1, 0)) AS is_open_hyzx,                        -- 是否开通「会员中心」
           MAX(IF(module_id = 256, 1, 0)) AS is_open_xcxzxnkb,                    -- 是否开通「小程序中心
           MAX(IF(module_id = 257, 1, 0)) AS is_open_jdgl,                        -- 是否开通「酒店管理」
           MAX(IF(module_id = 258, 1, 0)) AS is_open_zhdl,                        -- 是否开通「智慧导览」
           MAX(IF(module_id = 259, 1, 0)) AS is_open_jfgl,                        -- 是否开通「积分管理」
           MAX(IF(module_id = 265, 1, 0)) AS is_open_fzbbx,                       -- 是否开通「分账报表(新)」
           MAX(IF(module_id = 308, 1, 0)) AS is_open_xcxfxy,                      -- 是否开通「小程序分销员」
           MAX(IF(module_id = 298, 1, 0)) AS is_open_fxkc,                        -- 是否开通「分销库存」
           MAX(IF(module_id = 332, 1, 0)) AS is_open_cwph,                        -- 是否开通「财务平衡」
           CONCAT_WS('、', IF(
               MAX(IF(module_id = 1, 1, 0)) = 1,
               '微商城（旧版）',
               NULL
           ), IF(MAX(IF(module_id = 2, 1, 0)) = 1,
           '海报推广',
           NULL), IF(MAX(IF(module_id = 3, 1, 0)) = 1,
           '数据罗盘',
           NULL), IF(MAX(IF(module_id = 5, 1, 0)) = 1,
           '全民营销',
           NULL), IF(MAX(IF(module_id = 9, 1, 0)) = 1,
           '云售票终端',
           NULL), IF(MAX(IF(module_id = 10, 1, 0)) = 1,
           'MINI云终端',
           NULL), IF(MAX(IF(module_id = 11, 1, 0)) = 1,
           '智能云闸机',
           NULL), IF(MAX(IF(module_id = 12, 1, 0)) = 1,
           '旅游一卡通',
           NULL), IF(MAX(IF(module_id = 13, 1, 0)) = 1,
           '链接广告',
           NULL), IF(MAX(IF(module_id = 15, 1, 0)) = 1,
           '自助售取票机',
           NULL), IF(MAX(IF(module_id = 16, 1, 0)) = 1,
           'APP下载',
           NULL), IF(MAX(IF(module_id = 17, 1, 0)) = 1,
           '线下票务系统',
           NULL), IF(MAX(IF(module_id = 18, 1, 0)) = 1,
           '计调下单',
           NULL), IF(MAX(IF(module_id = 20, 1, 0)) = 1,
           '优惠券(旧版)',
           NULL), IF(MAX(IF(module_id = 21, 1, 0)) = 1,
           '旅游年卡',
           NULL), IF(MAX(IF(module_id = 22, 1, 0)) = 1,
           'B2C商城（PC端）',
           NULL), IF(MAX(IF(module_id = 23, 1, 0)) = 1,
           '结算自动入帐',
           NULL), IF(MAX(IF(module_id = 25, 1, 0)) = 1,
           'OTA平台分销',
           NULL), IF(MAX(IF(module_id = 26, 1, 0)) = 1,
           '同业平台分销',
           NULL), IF(MAX(IF(module_id = 27, 1, 0)) = 1,
           '分销第三方产品',
           NULL), IF(MAX(IF(module_id = 29, 1, 0)) = 1,
           '温泉管理系统',
           NULL), IF(MAX(IF(module_id = 35, 1, 0)) = 1,
           '景区票务系统',
           NULL), IF(MAX(IF(module_id = 36, 1, 0)) = 1,
           '园区一卡通',
           NULL), IF(MAX(IF(module_id = 37, 1, 0)) = 1,
           '转分销产品',
           NULL), IF(MAX(IF(module_id = 39, 1, 0)) = 1,
           '电子发票',
           NULL), IF(MAX(IF(module_id = 40, 1, 0)) = 1,
           '限时抢购',
           NULL), IF(MAX(IF(module_id = 41, 1, 0)) = 1,
           '大数据分析',
           NULL), IF(MAX(IF(module_id = 42, 1, 0)) = 1,
           '返利管理',
           NULL), IF(MAX(IF(module_id = 43, 1, 0)) = 1,
           '蚂蚁供销对接',
           NULL), IF(MAX(IF(module_id = 44, 1, 0)) = 1,
           '有赞微商城对接',
           NULL), IF(MAX(IF(module_id = 45, 1, 0)) = 1,
           '砍价(微商城)',
           NULL), IF(MAX(IF(module_id = 46, 1, 0)) = 1,
           '拼团(微商城)',
           NULL), IF(MAX(IF(module_id = 47, 1, 0)) = 1,
           'MiNi云小程序',
           NULL), IF(MAX(IF(module_id = 48, 1, 0)) = 1,
           '积分商城',
           NULL), IF(MAX(IF(module_id = 51, 1, 0)) = 1,
           '分销专员',
           NULL), IF(MAX(IF(module_id = 52, 1, 0)) = 1,
           '会员体系',
           NULL), IF(MAX(IF(module_id = 55, 1, 0)) = 1,
           '公众号吸粉',
           NULL), IF(MAX(IF(module_id = 56, 1, 0)) = 1,
           '红包翻翻乐',
           NULL), IF(MAX(IF(module_id = 57, 1, 0)) = 1,
           '资源中心',
           NULL), IF(MAX(IF(module_id = 58, 1, 0)) = 1,
           '微信直销（微商城）',
           NULL), IF(MAX(IF(module_id = 59, 1, 0)) = 1,
           '小程序商城',
           NULL), IF(MAX(IF(module_id = 60, 1, 0)) = 1,
           '优惠券',
           NULL), IF(MAX(IF(module_id = 61, 1, 0)) = 1,
           '分时预约',
           NULL), IF(MAX(IF(module_id = 62, 1, 0)) = 1,
           '公众号营销',
           NULL), IF(MAX(IF(module_id = 63, 1, 0)) = 1,
           '小程序Pro',
           NULL), IF(MAX(IF(module_id = 65, 1, 0)) = 1,
           '新分销专员',
           NULL), IF(MAX(IF(module_id = 66, 1, 0)) = 1,
           '人脸中心',
           NULL), IF(MAX(IF(module_id = 67, 1, 0)) = 1,
           '窗口管理',
           NULL), IF(MAX(IF(module_id = 68, 1, 0)) = 1,
           '纸票管理',
           NULL), IF(MAX(IF(module_id = 69, 1, 0)) = 1,
           '报团管理（供应商版）',
           NULL), IF(MAX(IF(module_id = 70, 1, 0)) = 1,
           '报团管理（分销商版）',
           NULL), IF(MAX(IF(module_id = 71, 1, 0)) = 1,
           '商城会员管理',
           NULL), IF(MAX(IF(module_id = 72, 1, 0)) = 1,
           '园区计时',
           NULL), IF(MAX(IF(module_id = 73, 1, 0)) = 1,
           '景区数据罗盘',
           NULL), IF(MAX(IF(module_id = 74, 1, 0)) = 1,
           '独立域名搭建',
           NULL), IF(MAX(IF(module_id = 75, 1, 0)) = 1,
           '外部码发码管理',
           NULL), IF(MAX(IF(module_id = 76, 1, 0)) = 1,
           '同业平台分销(基础版)',
           NULL), IF(MAX(IF(module_id = 77, 1, 0)) = 1,
           '微信卡券',
           NULL), IF(MAX(IF(module_id = 78, 1, 0)) = 1,
           '购票限制(黑白名单)',
           NULL), IF(MAX(IF(module_id = 79, 1, 0)) = 1,
           '出入园数据统计',
           NULL), IF(MAX(IF(module_id = 80, 1, 0)) = 1,
           '测试应用21（勿买）',
           NULL), IF(MAX(IF(module_id = 81, 1, 0)) = 1,
           '依赖测试',
           NULL), IF(MAX(IF(module_id = 82, 1, 0)) = 1,
           '测试应用w',
           NULL), IF(MAX(IF(module_id = 83, 1, 0)) = 1,
           'qwe_chb',
           NULL), IF(MAX(IF(module_id = 84, 1, 0)) = 1,
           '测试使用',
           NULL), IF(MAX(IF(module_id = 85, 1, 0)) = 1,
           '终端管理',
           NULL), IF(MAX(IF(module_id = 86, 1, 0)) = 1,
           '旅行社数据罗盘',
           NULL), IF(MAX(IF(module_id = 87, 1, 0)) = 1,
           '短信抬头自定义',
           NULL), IF(MAX(IF(module_id = 88, 1, 0)) = 1,
           '自定义短信模板',
           NULL), IF(MAX(IF(module_id = 89, 1, 0)) = 1,
           '旅游小店',
           NULL), IF(MAX(IF(module_id = 90, 1, 0)) = 1,
           '协议票管理',
           NULL), IF(MAX(IF(module_id = 91, 1, 0)) = 1,
           '特殊团队预约',
           NULL), IF(MAX(IF(module_id = 92, 1, 0)) = 1,
           '扫码验证-标准版',
           NULL), IF(MAX(IF(module_id = 93, 1, 0)) = 1,
           '扫码验证-专业版',
           NULL), IF(MAX(IF(module_id = 94, 1, 0)) = 1,
           '物料中心',
           NULL), IF(MAX(IF(module_id = 95, 1, 0)) = 1,
           '微平台图表分析',
           NULL), IF(MAX(IF(module_id = 96, 1, 0)) = 1,
           '导游管理(供应商版)',
           NULL), IF(MAX(IF(module_id = 97, 1, 0)) = 1,
           '导游管理(分销商版)',
           NULL), IF(MAX(IF(module_id = 176, 1, 0)) = 1,
           '营销短信',
           NULL), IF(MAX(IF(module_id = 177, 1, 0)) = 1,
           'test',
           NULL), IF(MAX(IF(module_id = 178, 1, 0)) = 1,
           '购票前置',
           NULL), IF(MAX(IF(module_id = 179, 1, 0)) = 1,
           '订单信息隐藏',
           NULL), IF(MAX(IF(module_id = 180, 1, 0)) = 1,
           '快捷购票',
           NULL), IF(MAX(IF(module_id = 181, 1, 0)) = 1,
           '新媒体分销',
           NULL), IF(MAX(IF(module_id = 182, 1, 0)) = 1,
           '返利管理（新）',
           NULL), IF(MAX(IF(module_id = 183, 1, 0)) = 1,
           '报表应用',
           NULL), IF(MAX(IF(module_id = 184, 1, 0)) = 1,
           '测试应用（勿买）',
           NULL), IF(MAX(IF(module_id = 185, 1, 0)) = 1,
           '团队预约',
           NULL), IF(MAX(IF(module_id = 186, 1, 0)) = 1,
           '分销商快捷购票',
           NULL), IF(MAX(IF(module_id = 187, 1, 0)) = 1,
           '票类纸质报表',
           NULL), IF(MAX(IF(module_id = 243, 1, 0)) = 1,
           '全品类分销',
           NULL), IF(MAX(IF(module_id = 244, 1, 0)) = 1,
           '团购导码',
           NULL), IF(MAX(IF(module_id = 245, 1, 0)) = 1,
           '小程序中心(景区)',
           NULL), IF(MAX(IF(module_id = 246, 1, 0)) = 1,
           '小程序中心(旅行社版)',
           NULL), IF(MAX(IF(module_id = 247, 1, 0)) = 1,
           '经营基础数据',
           NULL), IF(MAX(IF(module_id = 248, 1, 0)) = 1,
           '经营分析数据',
           NULL), IF(MAX(IF(module_id = 249, 1, 0)) = 1,
           '游船计时',
           NULL), IF(MAX(IF(module_id = 250, 1, 0)) = 1,
           '经营小飘报告',
           NULL), IF(MAX(IF(module_id = 251, 1, 0)) = 1,
           '经营行业数据',
           NULL), IF(MAX(IF(module_id = 252, 1, 0)) = 1,
           '统一收银',
           NULL), IF(MAX(IF(module_id = 254, 1, 0)) = 1,
           '新一卡通',
           NULL), IF(MAX(IF(module_id = 255, 1, 0)) = 1,
           '会员中心',
           NULL), IF(MAX(IF(module_id = 256, 1, 0)) = 1,
           '小程序中心（年卡版）',
           NULL), IF(MAX(IF(module_id = 257, 1, 0)) = 1,
           '酒店管理',
           NULL), IF(MAX(IF(module_id = 258, 1, 0)) = 1,
           '智慧导览',
           NULL), IF(MAX(IF(module_id = 259, 1, 0)) = 1,
           '积分管理',
           NULL), IF(MAX(IF(module_id = 265, 1, 0)) = 1,
           '分账报表(新)',
           NULL), IF(MAX(IF(module_id = 308, 1, 0)) = 1,
           '小程序分销员',
           NULL), IF(MAX(IF(module_id = 298, 1, 0)) = 1,
           '分销库存',
           NULL), IF(MAX(IF(module_id = 332, 1, 0)) = 1,
           '财务平衡',
           NULL)) AS open_list,
           CONCAT_WS('、', IF(
               MAX(IF(module_id = 1, 1, 0)) = 0,
               '微商城（旧版）',
               NULL
           ), IF(MAX(IF(module_id = 2, 1, 0)) = 0,
           '海报推广',
           NULL), IF(MAX(IF(module_id = 3, 1, 0)) = 0,
           '数据罗盘',
           NULL), IF(MAX(IF(module_id = 5, 1, 0)) = 0,
           '全民营销',
           NULL), IF(MAX(IF(module_id = 9, 1, 0)) = 0,
           '云售票终端',
           NULL), IF(MAX(IF(module_id = 10, 1, 0)) = 0,
           'MINI云终端',
           NULL), IF(MAX(IF(module_id = 11, 1, 0)) = 0,
           '智能云闸机',
           NULL), IF(MAX(IF(module_id = 12, 1, 0)) = 0,
           '旅游一卡通',
           NULL), IF(MAX(IF(module_id = 13, 1, 0)) = 0,
           '链接广告',
           NULL), IF(MAX(IF(module_id = 15, 1, 0)) = 0,
           '自助售取票机',
           NULL), IF(MAX(IF(module_id = 16, 1, 0)) = 0,
           'APP下载',
           NULL), IF(MAX(IF(module_id = 17, 1, 0)) = 0,
           '线下票务系统',
           NULL), IF(MAX(IF(module_id = 18, 1, 0)) = 0,
           '计调下单',
           NULL), IF(MAX(IF(module_id = 20, 1, 0)) = 0,
           '优惠券(旧版)',
           NULL), IF(MAX(IF(module_id = 21, 1, 0)) = 0,
           '旅游年卡',
           NULL), IF(MAX(IF(module_id = 22, 1, 0)) = 0,
           'B2C商城（PC端）',
           NULL), IF(MAX(IF(module_id = 23, 1, 0)) = 0,
           '结算自动入帐',
           NULL), IF(MAX(IF(module_id = 25, 1, 0)) = 0,
           'OTA平台分销',
           NULL), IF(MAX(IF(module_id = 26, 1, 0)) = 0,
           '同业平台分销',
           NULL), IF(MAX(IF(module_id = 27, 1, 0)) = 0,
           '分销第三方产品',
           NULL), IF(MAX(IF(module_id = 29, 1, 0)) = 0,
           '温泉管理系统',
           NULL), IF(MAX(IF(module_id = 35, 1, 0)) = 0,
           '景区票务系统',
           NULL), IF(MAX(IF(module_id = 36, 1, 0)) = 0,
           '园区一卡通',
           NULL), IF(MAX(IF(module_id = 37, 1, 0)) = 0,
           '转分销产品',
           NULL), IF(MAX(IF(module_id = 39, 1, 0)) = 0,
           '电子发票',
           NULL), IF(MAX(IF(module_id = 40, 1, 0)) = 0,
           '限时抢购',
           NULL), IF(MAX(IF(module_id = 41, 1, 0)) = 0,
           '大数据分析',
           NULL), IF(MAX(IF(module_id = 42, 1, 0)) = 0,
           '返利管理',
           NULL), IF(MAX(IF(module_id = 43, 1, 0)) = 0,
           '蚂蚁供销对接',
           NULL), IF(MAX(IF(module_id = 44, 1, 0)) = 0,
           '有赞微商城对接',
           NULL), IF(MAX(IF(module_id = 45, 1, 0)) = 0,
           '砍价(微商城)',
           NULL), IF(MAX(IF(module_id = 46, 1, 0)) = 0,
           '拼团(微商城)',
           NULL), IF(MAX(IF(module_id = 47, 1, 0)) = 0,
           'MiNi云小程序',
           NULL), IF(MAX(IF(module_id = 48, 1, 0)) = 0,
           '积分商城',
           NULL), IF(MAX(IF(module_id = 51, 1, 0)) = 0,
           '分销专员',
           NULL), IF(MAX(IF(module_id = 52, 1, 0)) = 0,
           '会员体系',
           NULL), IF(MAX(IF(module_id = 55, 1, 0)) = 0,
           '公众号吸粉',
           NULL), IF(MAX(IF(module_id = 56, 1, 0)) = 0,
           '红包翻翻乐',
           NULL), IF(MAX(IF(module_id = 57, 1, 0)) = 0,
           '资源中心',
           NULL), IF(MAX(IF(module_id = 58, 1, 0)) = 0,
           '微信直销（微商城）',
           NULL), IF(MAX(IF(module_id = 59, 1, 0)) = 0,
           '小程序商城',
           NULL), IF(MAX(IF(module_id = 60, 1, 0)) = 0,
           '优惠券',
           NULL), IF(MAX(IF(module_id = 61, 1, 0)) = 0,
           '分时预约',
           NULL), IF(MAX(IF(module_id = 62, 1, 0)) = 0,
           '公众号营销',
           NULL), IF(MAX(IF(module_id = 63, 1, 0)) = 0,
           '小程序Pro',
           NULL), IF(MAX(IF(module_id = 65, 1, 0)) = 0,
           '新分销专员',
           NULL), IF(MAX(IF(module_id = 66, 1, 0)) = 0,
           '人脸中心',
           NULL), IF(MAX(IF(module_id = 67, 1, 0)) = 0,
           '窗口管理',
           NULL), IF(MAX(IF(module_id = 68, 1, 0)) = 0,
           '纸票管理',
           NULL), IF(MAX(IF(module_id = 69, 1, 0)) = 0,
           '报团管理（供应商版）',
           NULL), IF(MAX(IF(module_id = 70, 1, 0)) = 0,
           '报团管理（分销商版）',
           NULL), IF(MAX(IF(module_id = 71, 1, 0)) = 0,
           '商城会员管理',
           NULL), IF(MAX(IF(module_id = 72, 1, 0)) = 0,
           '园区计时',
           NULL), IF(MAX(IF(module_id = 73, 1, 0)) = 0,
           '景区数据罗盘',
           NULL), IF(MAX(IF(module_id = 74, 1, 0)) = 0,
           '独立域名搭建',
           NULL), IF(MAX(IF(module_id = 75, 1, 0)) = 0,
           '外部码发码管理',
           NULL), IF(MAX(IF(module_id = 76, 1, 0)) = 0,
           '同业平台分销(基础版)',
           NULL), IF(MAX(IF(module_id = 77, 1, 0)) = 0,
           '微信卡券',
           NULL), IF(MAX(IF(module_id = 78, 1, 0)) = 0,
           '购票限制(黑白名单)',
           NULL), IF(MAX(IF(module_id = 79, 1, 0)) = 0,
           '出入园数据统计',
           NULL), IF(MAX(IF(module_id = 80, 1, 0)) = 0,
           '测试应用21（勿买）',
           NULL), IF(MAX(IF(module_id = 81, 1, 0)) = 0,
           '依赖测试',
           NULL), IF(MAX(IF(module_id = 82, 1, 0)) = 0,
           '测试应用w',
           NULL), IF(MAX(IF(module_id = 83, 1, 0)) = 0,
           'qwe_chb',
           NULL), IF(MAX(IF(module_id = 84, 1, 0)) = 0,
           '测试使用',
           NULL), IF(MAX(IF(module_id = 85, 1, 0)) = 0,
           '终端管理',
           NULL), IF(MAX(IF(module_id = 86, 1, 0)) = 0,
           '旅行社数据罗盘',
           NULL), IF(MAX(IF(module_id = 87, 1, 0)) = 0,
           '短信抬头自定义',
           NULL), IF(MAX(IF(module_id = 88, 1, 0)) = 0,
           '自定义短信模板',
           NULL), IF(MAX(IF(module_id = 89, 1, 0)) = 0,
           '旅游小店',
           NULL), IF(MAX(IF(module_id = 90, 1, 0)) = 0,
           '协议票管理',
           NULL), IF(MAX(IF(module_id = 91, 1, 0)) = 0,
           '特殊团队预约',
           NULL), IF(MAX(IF(module_id = 92, 1, 0)) = 0,
           '扫码验证-标准版',
           NULL), IF(MAX(IF(module_id = 93, 1, 0)) = 0,
           '扫码验证-专业版',
           NULL), IF(MAX(IF(module_id = 94, 1, 0)) = 0,
           '物料中心',
           NULL), IF(MAX(IF(module_id = 95, 1, 0)) = 0,
           '微平台图表分析',
           NULL), IF(MAX(IF(module_id = 96, 1, 0)) = 0,
           '导游管理(供应商版)',
           NULL), IF(MAX(IF(module_id = 97, 1, 0)) = 0,
           '导游管理(分销商版)',
           NULL), IF(MAX(IF(module_id = 176, 1, 0)) = 0,
           '营销短信',
           NULL), IF(MAX(IF(module_id = 177, 1, 0)) = 0,
           'test',
           NULL), IF(MAX(IF(module_id = 178, 1, 0)) = 0,
           '购票前置',
           NULL), IF(MAX(IF(module_id = 179, 1, 0)) = 0,
           '订单信息隐藏',
           NULL), IF(MAX(IF(module_id = 180, 1, 0)) = 0,
           '快捷购票',
           NULL), IF(MAX(IF(module_id = 181, 1, 0)) = 0,
           '新媒体分销',
           NULL), IF(MAX(IF(module_id = 182, 1, 0)) = 0,
           '返利管理（新）',
           NULL), IF(MAX(IF(module_id = 183, 1, 0)) = 0,
           '报表应用',
           NULL), IF(MAX(IF(module_id = 184, 1, 0)) = 0,
           '测试应用（勿买）',
           NULL), IF(MAX(IF(module_id = 185, 1, 0)) = 0,
           '团队预约',
           NULL), IF(MAX(IF(module_id = 186, 1, 0)) = 0,
           '分销商快捷购票',
           NULL), IF(MAX(IF(module_id = 187, 1, 0)) = 0,
           '票类纸质报表',
           NULL), IF(MAX(IF(module_id = 243, 1, 0)) = 0,
           '全品类分销',
           NULL), IF(MAX(IF(module_id = 244, 1, 0)) = 0,
           '团购导码',
           NULL), IF(MAX(IF(module_id = 245, 1, 0)) = 0,
           '小程序中心(景区)',
           NULL), IF(MAX(IF(module_id = 246, 1, 0)) = 0,
           '小程序中心(旅行社版)',
           NULL), IF(MAX(IF(module_id = 247, 1, 0)) = 0,
           '经营基础数据',
           NULL), IF(MAX(IF(module_id = 248, 1, 0)) = 0,
           '经营分析数据',
           NULL), IF(MAX(IF(module_id = 249, 1, 0)) = 0,
           '游船计时',
           NULL), IF(MAX(IF(module_id = 250, 1, 0)) = 0,
           '经营小飘报告',
           NULL), IF(MAX(IF(module_id = 251, 1, 0)) = 0,
           '经营行业数据',
           NULL), IF(MAX(IF(module_id = 252, 1, 0)) = 0,
           '统一收银',
           NULL), IF(MAX(IF(module_id = 254, 1, 0)) = 0,
           '新一卡通',
           NULL), IF(MAX(IF(module_id = 255, 1, 0)) = 0,
           '会员中心',
           NULL), IF(MAX(IF(module_id = 256, 1, 0)) = 0,
           '小程序中心（年卡版）',
           NULL), IF(MAX(IF(module_id = 257, 1, 0)) = 0,
           '酒店管理',
           NULL), IF(MAX(IF(module_id = 258, 1, 0)) = 0,
           '智慧导览',
           NULL), IF(MAX(IF(module_id = 259, 1, 0)) = 0,
           '积分管理',
           NULL), IF(MAX(IF(module_id = 265, 1, 0)) = 0,
           '分账报表(新)',
           NULL), IF(MAX(IF(module_id = 308, 1, 0)) = 0,
           '小程序分销员',
           NULL), IF(MAX(IF(module_id = 298, 1, 0)) = 0,
           '分销库存',
           NULL), IF(MAX(IF(module_id = 332, 1, 0)) = 0,
           '财务平衡',
           NULL)) AS null_list
    FROM (SELECT member_id, module_id FROM (
              SELECT member_id, module_id, valid_end_time, stop_type,
                     ROW_NUMBER() OVER (PARTITION BY member_id, module_id ORDER BY open_time DESC) AS rk  -- 优先级序号（1 = 生效）
              FROM dwd.dwd_opr_module_open_di WHERE travel_date <= '${bizdate}') u  -- 累计口径：取截至统计日的全部分区
          WHERE rk = 1
            AND TO_DATE(valid_end_time) >= TO_DATE('${bizdate}', 'yyyyMMdd')
            AND COALESCE(stop_type, 0) = 0
          UNION ALL
          SELECT c.member_id,
                 d.module_id FROM p_curr c JOIN dim.dim_opr_module_package_df d ON d.package_id = c.package_id) x
    GROUP BY member_id                                                            -- 按粒度键汇总
),
ops AS (                                                                          -- 营销 / 运营使用：海报、报表下载、物料扫码（配置 / 操作日志，无业务过程，直接按 ODS）
    SELECT member_id,
           SUM(poster_qty) AS poster_qty,
           SUM(download_qty) AS download_qty,
           SUM(scan_qty) AS scan_qty
    FROM (SELECT member_id, COUNT(1) AS poster_qty, 0 AS download_qty, 0 AS scan_qty
        FROM ods.ods_mkt_posters_df WHERE travel_date = '${bizdate}' GROUP BY member_id
          UNION ALL SELECT fid,
          0,
          SUM(download),
          0 FROM ods.ods_opr_excel_task_df WHERE travel_date = '${bizdate}' GROUP BY fid
          UNION ALL SELECT sid,
          0,
          0,
          SUM(count_num) FROM ods.ods_mkt_material_center_df WHERE travel_date = '${bizdate}' GROUP BY sid) o
    GROUP BY member_id                                                            -- 按粒度键汇总
),
fo AS (                                                                           -- 首单月：作为供应商第一次有预订的月份（考核窗口 = 首单月起 3 个月）
    SELECT supplier_id AS member_id,                                              -- 供应商ID
           TRUNC(TO_DATE(MIN(travel_date), 'yyyyMMdd'), 'MM') AS ws
    FROM dws.dws_ord_scenic_ticket_trade_di WHERE travel_date <= '${bizdate}' AND order_order_qty > 0 GROUP BY supplier_id  -- 累计口径：取截至统计日的全部分区
),
kh AS (
    SELECT fo.member_id, DATE_FORMAT(fo.ws, 'yyyy-MM') AS first_month,
           MAX(nm.qty) AS new_media_qty,
           MAX(lt.qty) AS land_type_qty,
           MAX(sc.qty) AS scan_qty,
           MAX(ms.qty) AS mkt_sms_qty,
           MAX(sg.qty) AS sign_qty,
           MAX(dy.qty) AS diy_qty
    FROM fo
    LEFT JOIN (SELECT t.supplier_id, COUNT(DISTINCT t.order_no) AS qty, MIN(f.ws) AS ws_
        FROM dwd.dwd_mkt_order_tag_di t JOIN fo f ON f.member_id = t.supplier_id
               WHERE t.marketing_type LIKE 'NEW_MEDIA%'
                 AND TO_DATE(t.order_time) >= f.ws
                 AND TO_DATE(t.order_time) < ADD_MONTHS(f.ws, 3) GROUP BY t.supplier_id) nm
           ON nm.supplier_id = fo.member_id                                       -- 按 member_id→supplier_id 关联
    LEFT JOIN (SELECT s.supplier_id, COUNT(DISTINCT s.scenic_type_code) AS qty FROM dim.dim_prd_scenic_df s JOIN fo f ON f.member_id = s.supplier_id
               WHERE TO_DATE(s.create_time) >= f.ws
                 AND TO_DATE(s.create_time) < ADD_MONTHS(f.ws, 3) GROUP BY s.supplier_id) lt ON lt.supplier_id = fo.member_id
    LEFT JOIN (SELECT m.sid, SUM(m.count_num) AS qty FROM ods.ods_mkt_material_center_df m JOIN fo f ON f.member_id = m.sid
               WHERE m.travel_date = '${bizdate}'                                 -- 只取当日分区
                 AND TO_DATE(FROM_UNIXTIME(m.create_time)) >= f.ws
                 AND TO_DATE(FROM_UNIXTIME(m.create_time)) < ADD_MONTHS(f.ws, 3) GROUP BY m.sid) sc ON sc.sid = fo.member_id
    LEFT JOIN (SELECT k.supplier_id, COUNT(1) AS qty FROM dwd.dwd_mkt_sms_task_di k JOIN fo f ON f.member_id = k.supplier_id
               WHERE TO_DATE(k.create_time) >= f.ws
                 AND TO_DATE(k.create_time) < ADD_MONTHS(f.ws, 3) GROUP BY k.supplier_id) ms ON ms.supplier_id = fo.member_id
    LEFT JOIN (SELECT a.member_id, COUNT(1) AS qty FROM ods.ods_opr_sms_sign_apply_df a JOIN fo f ON f.member_id = a.member_id
               WHERE a.travel_date = '${bizdate}'                                 -- 只取当日分区
                 AND a.state = 2
                 AND TO_DATE(FROM_UNIXTIME(a.create_time)) >= f.ws
                 AND TO_DATE(FROM_UNIXTIME(a.create_time)) < ADD_MONTHS(f.ws, 3)
               GROUP BY a.member_id) sg ON sg.member_id = fo.member_id            -- 按粒度键汇总
    LEFT JOIN (SELECT a.member_id, COUNT(1) AS qty FROM ods.ods_opr_sms_diy_apply_df a JOIN fo f ON f.member_id = a.member_id
               WHERE a.travel_date = '${bizdate}' AND a.state = 2 AND a.use_state = 1 AND a.is_delete = 0  -- 只取当日分区，并按条件过滤
                 AND TO_DATE(FROM_UNIXTIME(a.create_time)) >= f.ws
                   AND TO_DATE(FROM_UNIXTIME(a.create_time)) < ADD_MONTHS(f.ws, 3)
               GROUP BY a.member_id) dy ON dy.member_id = fo.member_id            -- 按粒度键汇总
    GROUP BY fo.member_id, fo.ws                                                  -- 按粒度键汇总
),
sm AS (                                                                           -- 短信：订单短信条数、营销短信任务数（累计）
    SELECT supplier_id AS member_id,                                              -- 供应商ID
           SUM(sms_qty) AS sms_qty,                                               -- 订单短信条数
           SUM(mkt_task_qty) AS mkt_task_qty
    FROM (SELECT supplier_id, SUM(sms_qty) AS sms_qty, 0 AS mkt_task_qty
        FROM dwd.dwd_opr_sms_send_di WHERE travel_date <= '${bizdate}' GROUP BY supplier_id  -- 累计口径：取截至统计日的全部分区
          UNION ALL SELECT supplier_id,
          0,
          COUNT(1) FROM dwd.dwd_mkt_sms_task_di WHERE travel_date <= '${bizdate}' GROUP BY supplier_id) s  -- 累计口径：取截至统计日的全部分区
    GROUP BY supplier_id                                                          -- 按粒度键汇总
)
INSERT OVERWRITE TABLE ads.ads_sup_customer_company_df PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT /*+ BROADCAST(sg, sv) */
    m.member_id                                                            AS user_id,  -- 平台账号ID
    m.pay_account_id                                                       AS user_account_id,  -- 支付账户ID
    m.customer_id                                                          AS user_customer_id,  -- 平台客户ID
    m.account                                                              AS user_account,  -- 登录账号
    m.member_name                                                          AS user_name,  -- 账号名称
    m.company_name                                                         AS user_company_name,  -- 公司名称
    COALESCE(k.company_name, m.company_name)                               AS customer_name,  -- 客户名称
    m.contact_phone_hash                                                   AS customer_mobile_hash,  -- 客户联系人手机号哈希
    m.member_type_code                                                     AS user_type_code,  -- 账号类型编码
    CASE
        WHEN m.supplier_flag = 1 THEN '供应商'
        WHEN m.distributor_flag = 1 THEN '分销商'
        ELSE '其他'
    END AS user_type,                                                             -- 账号类型
    IF(m.test_flag = 1, '测试', '正式')                                        AS user_is_test,  -- 正式 / 测试
    CASE m.member_status
        WHEN '0' THEN '正常'
        WHEN '1' THEN '禁用'
        WHEN '2' THEN '删除'
        WHEN '3' THEN '未审核'
        ELSE m.member_status
    END AS user_status,                                                           -- 账号状态
    m.certi_status                                                         AS customer_certi_status_code,  -- 资质认证状态编码
    CASE m.certi_status
        WHEN 0 THEN '未认证'
        WHEN 1 THEN '审核中'
        WHEN 2 THEN '已认证'
        WHEN 3 THEN '认证未通过'
    END AS customer_certi_status,                                                 -- 资质认证状态
    COALESCE(k.country_name, '中国')                                         AS customer_country,  -- 客户国家
    COALESCE(m.province_name, k.province_name)                             AS customer_province,  -- 客户省
    COALESCE(m.city_name, k.city_name)                                     AS customer_city,  -- 客户市
    m.corp_kind_type                                                       AS customer_type_code,  -- 客户类型编码（公司类型）
    CASE m.corp_kind_type WHEN 0 THEN '酒店' WHEN 1 THEN '景区' WHEN 2 THEN '旅行社' ELSE '其他' END AS customer_type,  -- 客户类型
    m.format_type                                                          AS user_land_topic,  -- 公司业态
    m.member_level                                                         AS user_level,  -- 客户级别
    m.contract_model_type                                                  AS user_contract_model_code,  -- 合作模式编码
    CASE m.contract_model_type
        WHEN 0 THEN '无'
        WHEN 1 THEN '套餐'
        WHEN 2 THEN '票务'
        ELSE CAST(m.contract_model_type AS STRING)
    END AS user_contract_model,                                                   -- 合作模式
    m.signer_id                                                            AS signer_id,  -- 签单人（员工平台账号ID）
    sg.member_name                                                         AS signer,  -- 签单人姓名
    m.servicer_id                                                          AS servicer_id,  -- 客服 / 客户成功经理
    sv.member_name                                                         AS servicer,  -- 客服姓名
    m.register_time                                                        AS user_regist_time,  -- 注册时间
    m.protocol_start_date                                                  AS user_contarct_firstdate,  -- 首次合作（协议开始）日期
    m.last_login_time                                                      AS user_login_lasttime,  -- 最近登录时间
    k.account_level                                                        AS cooperation_customer_level,  -- CRM 合作客户等级
    m.cooperation_content                                                  AS cooperation_content,  -- 合作内容
    m.product_type_list                                                    AS product_open_list,  -- 已开通产品类型
    pa.first_add_time                                                      AS first_add_distributor_time,  -- 首次添加分销商时间
    pa.last_add_time                                                       AS end_edit_distributor_time,  -- 最后添加分销商时间
    COALESCE(ps.partner_num_supp, 0)                                       AS partner_num_supp,  -- 供应商数（为本账号供货的上级）
    COALESCE(pa.partner_num_ota, 0)                                        AS partner_num_ota,  -- OTA 分销商数
    COALESCE(pa.partner_num_dist, 0)                                       AS partner_num_dist,  -- 分销商数
    COALESCE(pa.partner_num_staff, 0)                                      AS partner_num_staff,  -- 员工账号数（从属关系）
    COALESCE(tsys.sys_qty, 0)                                              AS partner_num_ticket_system,  -- 绑定的线下票务系统数
    tsys.sys_list                                                          AS partner_ticket_system_list,  -- 绑定的票务系统名称列表
    pr.first_edit_time                                                     AS first_add_ticket_time,  -- 最早编辑票时间
    pr.last_edit_time                                                      AS end_edit_ticket_time,  -- 最后编辑票时间
    COALESCE(pr.onsale_ticket, 0)                                          AS onsale_ticket_num_self,  -- 在售自供应票种数（上架且未过期）
    COALESCE(pr.off_ticket, 0)                                             AS off_shelf_ticket_num_self,  -- 下架自供应票种数
    COALESCE(pr.overdue_ticket, 0)                                         AS overdue_ticket_num_self,  -- 上架但已过期的自供应票种数
    COALESCE(pr.add_ticket_curr_week, 0)                                   AS add_ticket_num_self_curr_week,  -- 本周新编辑自供应票种数
    COALESCE(pr.add_ticket_curr_month, 0)                                  AS add_ticket_num_self_curr_month,  -- 本月新编辑自供应票种数
    COALESCE(pr.add_ticket_curr_quarter,
             0)                                AS add_ticket_num_self_curr_quarter,  -- 本季新编辑自供应票种数
    COALESCE(pd.dist_ticket, 0)                                            AS ticket_num_dist,  -- 分销票种数
    COALESCE(pr.onsale_land, 0)                                            AS onsale_land_num_self,  -- 在售自供应产品数（上架且未过期）
    COALESCE(pr.off_land, 0)                                               AS off_shelf_land_num_self,  -- 下架自供应产品数
    COALESCE(pr.overdue_land, 0)                                           AS overdue_land_num_self,  -- 上架但已过期的自供应产品数
    COALESCE(pr.add_land_curr_week, 0)                                     AS add_land_num_self_curr_week,  -- 本周新编辑自供应产品数
    COALESCE(pr.add_land_curr_month, 0)                                    AS add_land_num_self_curr_month,  -- 本月新编辑自供应产品数
    COALESCE(pr.add_land_curr_quarter, 0)                                  AS add_land_num_self_curr_quarter,  -- 本季新编辑自供应产品数
    COALESCE(pd.dist_land, 0)                                              AS land_num_dist,  -- 分销产品数
    COALESCE(rs.onsale_resource, 0)                                        AS onsale_resource_num_self,  -- 在售自供应资源数（上架且未过期）
    COALESCE(rs.off_resource, 0)                                           AS off_shelf_resource_num_self,  -- 下架自供应资源数
    COALESCE(rs.overdue_resource, 0)                                       AS overdue_resource_num_self,  -- 上架但已过期的自供应资源数
    COALESCE(rs.add_resource_curr_week, 0)                                 AS add_resource_num_self_curr_week,  -- 本周新编辑自供应资源数
    COALESCE(rs.add_resource_curr_month,
             0)                                AS add_resource_num_self_curr_month,  -- 本月新编辑自供应资源数
    COALESCE(rs.add_resource_curr_quarter,
             0)                              AS add_resource_num_self_curr_quarter,  -- 本季新编辑自供应资源数
    COALESCE(pd.dist_resource, 0)                                          AS resource_num_dist,  -- 分销资源数
    COALESCE(pr.product_type_qty, 0)                                       AS product_type_qty,  -- 发布的产品类型数
    COALESCE(pk.amount_package, 0)                                         AS amount_package,  -- 套餐实收合计（元）
    COALESCE(pk.num_buy, 0)                                                AS user_package_num_buy,  -- 购买套餐次数
    COALESCE(pk.num_used, 0)                                               AS user_package_num_used,  -- 已用完（已到期）套餐次数
    p_first_supplier.package_id                                            AS user_first_supplier_package_id,  -- 第一次合作供应商套餐ID
    p_first_supplier.package_name                                          AS user_first_supplier_package_name,  -- 第一次合作供应商套餐名称
    TO_DATE(p_first_supplier.open_time)                                    AS user_first_supplier_package_adddate,  -- 第一次合作供应商套餐签约（开通）日期
    TO_DATE(p_first_supplier.valid_start_time)                             AS user_first_supplier_package_begindate,  -- 第一次合作供应商套餐开始日期
    TO_DATE(p_first_supplier.valid_end_time)                               AS user_first_supplier_package_enddate,  -- 第一次合作供应商套餐结束日期
    p_first_supplier.package_price_amt                                     AS user_first_supplier_package_price,  -- 第一次合作供应商套餐标价（元）
    p_first_supplier.package_pay_amt                                       AS user_first_supplier_package_pay_amt,  -- 第一次合作供应商套餐实收（元）
    CASE p_first_supplier.package_role
        WHEN 0 THEN '供应商'
        WHEN 1 THEN '分销商'
    END AS user_first_supplier_package_role,                                      -- 第一次合作供应商套餐角色
    p_first_supplier.classify_name                                         AS user_first_supplier_package_classify_name,  -- 第一次合作供应商套餐分类（套餐组）
    p_first.package_id                                                     AS user_first_package_id,  -- 第一次套餐ID
    p_first.package_name                                                   AS user_first_package_name,  -- 第一次套餐名称
    TO_DATE(p_first.open_time)                                             AS user_first_package_adddate,  -- 第一次套餐签约（开通）日期
    TO_DATE(p_first.valid_start_time)                                      AS user_first_package_begindate,  -- 第一次套餐开始日期
    TO_DATE(p_first.valid_end_time)                                        AS user_first_package_enddate,  -- 第一次套餐结束日期
    p_first.package_price_amt                                              AS user_first_package_price,  -- 第一次套餐标价（元）
    p_first.package_pay_amt                                                AS user_first_package_pay_amt,  -- 第一次套餐实收（元）
    CASE p_first.package_role WHEN 0 THEN '供应商' WHEN 1 THEN '分销商' END      AS user_first_package_role,  -- 第一次套餐角色
    p_first.classify_name                                                  AS user_first_package_classify_name,  -- 第一次套餐分类（套餐组）
    p_curr.package_id                                                      AS user_curr_package_id,  -- 当前套餐ID
    p_curr.package_name                                                    AS user_curr_package_name,  -- 当前套餐名称
    TO_DATE(p_curr.open_time)                                              AS user_curr_package_adddate,  -- 当前套餐签约（开通）日期
    TO_DATE(p_curr.valid_start_time)                                       AS user_curr_package_begindate,  -- 当前套餐开始日期
    TO_DATE(p_curr.valid_end_time)                                         AS user_curr_package_enddate,  -- 当前套餐结束日期
    p_curr.package_price_amt                                               AS user_curr_package_price,  -- 当前套餐标价（元）
    p_curr.package_pay_amt                                                 AS user_curr_package_pay_amt,  -- 当前套餐实收（元）
    CASE p_curr.package_role WHEN 0 THEN '供应商' WHEN 1 THEN '分销商' END       AS user_curr_package_role,  -- 当前套餐角色
    p_curr.classify_name                                                   AS user_curr_package_classify_name,  -- 当前套餐分类（套餐组）
    CAST(CEIL(MONTHS_BETWEEN(p_curr.valid_end_time, p_curr.valid_start_time)) AS INT) AS user_curr_package_diff_month,  -- 当前套餐周期（月）
    CAST(p_curr.package_pay_amt / NULLIF(CEIL(MONTHS_BETWEEN(p_curr.valid_end_time, p_curr.valid_start_time)), 0) AS DECIMAL(18,2)) AS user_curr_package_avg_pay_amt,  -- 当前套餐月均实收（元）
    p_curr.sale_man_name                                                   AS user_curr_package_signer,  -- 当前套餐签单人
    CAST(DATEDIFF(TO_DATE(p_curr.open_time), TO_DATE(p_last.valid_end_time)) / 30 AS DECIMAL(18,2)) AS user_curr_package_prepay_months,  -- 当前套餐提前续费月数 =
    p_curr.cooperation_mode                                                AS user_curr_package_contract_model,  -- 当前套餐合作模式
    p_last.package_id                                                      AS user_last_package_id,  -- 上次套餐ID
    p_last.package_name                                                    AS user_last_package_name,  -- 上次套餐名称
    TO_DATE(p_last.open_time)                                              AS user_last_package_adddate,  -- 上次套餐签约（开通）日期
    TO_DATE(p_last.valid_start_time)                                       AS user_last_package_begindate,  -- 上次套餐开始日期
    TO_DATE(p_last.valid_end_time)                                         AS user_last_package_enddate,  -- 上次套餐结束日期
    p_last.package_price_amt                                               AS user_last_package_price,  -- 上次套餐标价（元）
    p_last.package_pay_amt                                                 AS user_last_package_pay_amt,  -- 上次套餐实收（元）
    CASE p_last.package_role WHEN 0 THEN '供应商' WHEN 1 THEN '分销商' END       AS user_last_package_role,  -- 上次套餐角色
    p_last.classify_name                                                   AS user_last_package_classify_name,  -- 上次套餐分类（套餐组）
    CAST(CEIL(MONTHS_BETWEEN(p_last.valid_end_time, p_last.valid_start_time)) AS INT) AS user_last_package_diff_month,  -- 上次套餐周期（月）
    CAST(p_last.package_pay_amt / NULLIF(CEIL(MONTHS_BETWEEN(p_last.valid_end_time, p_last.valid_start_time)), 0) AS DECIMAL(18,2)) AS user_last_package_avg_pay_amt,  -- 上次套餐月均实收（元）
    p_next.package_id                                                      AS user_next_package_id,  -- 下个套餐ID
    p_next.package_name                                                    AS user_next_package_name,  -- 下个套餐名称
    TO_DATE(p_next.open_time)                                              AS user_next_package_adddate,  -- 下个套餐签约（开通）日期
    TO_DATE(p_next.valid_start_time)                                       AS user_next_package_begindate,  -- 下个套餐开始日期
    TO_DATE(p_next.valid_end_time)                                         AS user_next_package_enddate,  -- 下个套餐结束日期
    p_next.package_price_amt                                               AS user_next_package_price,  -- 下个套餐标价（元）
    p_next.package_pay_amt                                                 AS user_next_package_pay_amt,  -- 下个套餐实收（元）
    CASE p_next.package_role WHEN 0 THEN '供应商' WHEN 1 THEN '分销商' END       AS user_next_package_role,  -- 下个套餐角色
    p_next.classify_name                                                   AS user_next_package_classify_name,  -- 下个套餐分类（套餐组）
    p_next.sale_man_name                                                   AS user_next_package_signer,  -- 下个套餐签单人
    CAST(DATEDIFF(TO_DATE(p_next.open_time), TO_DATE(p_curr.valid_end_time)) / 30 AS DECIMAL(18,2)) AS user_next_package_prepay_months,  -- 下个套餐提前续费月数 =
    p_next.cooperation_mode                                                AS user_next_package_contract_model,  -- 下个套餐合作模式
    p_end.package_id                                                       AS user_end_package_id,  -- 最终套餐ID
    p_end.package_name                                                     AS user_end_package_name,  -- 最终套餐名称
    TO_DATE(p_end.open_time)                                               AS user_end_package_adddate,  -- 最终套餐签约（开通）日期
    TO_DATE(p_end.valid_start_time)                                        AS user_end_package_begindate,  -- 最终套餐开始日期
    TO_DATE(p_end.valid_end_time)                                          AS user_end_package_enddate,  -- 最终套餐结束日期
    p_end.package_price_amt                                                AS user_end_package_price,  -- 最终套餐标价（元）
    p_end.package_pay_amt                                                  AS user_end_package_pay_amt,  -- 最终套餐实收（元）
    CASE p_end.package_role WHEN 0 THEN '供应商' WHEN 1 THEN '分销商' END        AS user_end_package_role,  -- 最终套餐角色
    p_end.classify_name                                                    AS user_end_package_classify_name,  -- 最终套餐分类（套餐组）
    COALESCE(lg.n_plat_curr_week, 0)                                       AS login_num_plat_curr_week,  -- 本周登录平台次数
    COALESCE(lg.d_plat_curr_week, 0)                                       AS login_date_num_plat_curr_week,  -- 本周登录平台天数
    COALESCE(lg.n_terminal_curr_week, 0)                                   AS login_num_terminal_curr_week,  -- 本周登录终端次数
    COALESCE(lg.d_terminal_curr_week,
             0)                                   AS login_date_num_terminal_curr_week,  -- 本周登录终端天数
    COALESCE(lg.n_plat_last_week, 0)                                       AS login_num_plat_last_week,  -- 上周登录平台次数
    COALESCE(lg.d_plat_last_week, 0)                                       AS login_date_num_plat_last_week,  -- 上周登录平台天数
    COALESCE(lg.n_terminal_last_week, 0)                                   AS login_num_terminal_last_week,  -- 上周登录终端次数
    COALESCE(lg.d_terminal_last_week,
             0)                                   AS login_date_num_terminal_last_week,  -- 上周登录终端天数
    COALESCE(lg.n_plat_curr_month, 0)                                      AS login_num_plat_curr_month,  -- 本月登录平台次数
    COALESCE(lg.d_plat_curr_month, 0)                                      AS login_date_num_plat_curr_month,  -- 本月登录平台天数
    COALESCE(lg.n_terminal_curr_month, 0)                                  AS login_num_terminal_curr_month,  -- 本月登录终端次数
    COALESCE(lg.d_terminal_curr_month,
             0)                                  AS login_date_num_terminal_curr_month,  -- 本月登录终端天数
    COALESCE(lg.n_plat_last_month, 0)                                      AS login_num_plat_last_month,  -- 上月登录平台次数
    COALESCE(lg.d_plat_last_month, 0)                                      AS login_date_num_plat_last_month,  -- 上月登录平台天数
    COALESCE(lg.n_terminal_last_month, 0)                                  AS login_num_terminal_last_month,  -- 上月登录终端次数
    COALESCE(lg.d_terminal_last_month,
             0)                                  AS login_date_num_terminal_last_month,  -- 上月登录终端天数
    COALESCE(lg.n_plat_curr_quarter, 0)                                    AS login_num_plat_curr_quarter,  -- 本季登录平台次数
    COALESCE(lg.d_plat_curr_quarter,
             0)                                    AS login_date_num_plat_curr_quarter,  -- 本季登录平台天数
    COALESCE(lg.n_terminal_curr_quarter, 0)                                AS login_num_terminal_curr_quarter,  -- 本季登录终端次数
    COALESCE(lg.d_terminal_curr_quarter,
             0)                                AS login_date_num_terminal_curr_quarter,  -- 本季登录终端天数
    COALESCE(lg.n_plat_last_quarter, 0)                                    AS login_num_plat_last_quarter,  -- 上季登录平台次数
    COALESCE(lg.d_plat_last_quarter,
             0)                                    AS login_date_num_plat_last_quarter,  -- 上季登录平台天数
    COALESCE(lg.n_terminal_last_quarter, 0)                                AS login_num_terminal_last_quarter,  -- 上季登录终端次数
    COALESCE(lg.d_terminal_last_quarter,
             0)                                AS login_date_num_terminal_last_quarter,  -- 上季登录终端天数
    COALESCE(lg.n_plat_60_day, 0)                                          AS login_num_plat_60_day,  -- 近 60 天登录平台次数
    COALESCE(lg.d_plat_60_day, 0)                                          AS login_date_num_plat_60_day,  -- 近 60 天登录平台天数
    COALESCE(lg.n_terminal_60_day, 0)                                      AS login_num_terminal_60_day,  -- 近 60 天登录终端次数
    COALESCE(lg.d_terminal_60_day, 0)                                      AS login_date_num_terminal_60_day,  -- 近 60 天登录终端天数
    COALESCE(md.is_open_wsc, 0)                                            AS is_open_wsc,  -- 是否开通「微商城（旧版）」
    COALESCE(md.is_open_hbtg, 0)                                           AS is_open_hbtg,  -- 是否开通「海报推广」
    COALESCE(md.is_open_sjlp, 0)                                           AS is_open_sjlp,  -- 是否开通「数据罗盘」
    COALESCE(md.is_open_qmyx, 0)                                           AS is_open_qmyx,  -- 是否开通「全民营销」
    COALESCE(md.is_open_yspzd, 0)                                          AS is_open_yspzd,  -- 是否开通「云售票终端」
    COALESCE(md.is_open_miniyzd, 0)                                        AS is_open_miniyzd,  -- 是否开通「MINI云终端」
    COALESCE(md.is_open_znyzj, 0)                                          AS is_open_znyzj,  -- 是否开通「智能云闸机」
    COALESCE(md.is_open_lyykt, 0)                                          AS is_open_lyykt,  -- 是否开通「旅游一卡通」
    COALESCE(md.is_open_ljgg, 0)                                           AS is_open_ljgg,  -- 是否开通「链接广告」
    COALESCE(md.is_open_zzsqpj, 0)                                         AS is_open_zzsqpj,  -- 是否开通「自助售取票机」
    COALESCE(md.is_open_appxz, 0)                                          AS is_open_appxz,  -- 是否开通「APP下载」
    COALESCE(md.is_open_xxpwxt, 0)                                         AS is_open_xxpwxt,  -- 是否开通「线下票务系统」
    COALESCE(md.is_open_jdxd, 0)                                           AS is_open_jdxd,  -- 是否开通「计调下单」
    COALESCE(md.is_open_yhqjb, 0)                                          AS is_open_yhqjb,  -- 是否开通「优惠券(旧版)」
    COALESCE(md.is_open_lynk, 0)                                           AS is_open_lynk,  -- 是否开通「旅游年卡」
    COALESCE(md.is_open_b2cscpcd, 0)                                       AS is_open_b2cscpcd,  -- 是否开通「B2C商城
    COALESCE(md.is_open_jszdrz, 0)                                         AS is_open_jszdrz,  -- 是否开通「结算自动入帐」
    COALESCE(md.is_open_otaptfx, 0)                                        AS is_open_otaptfx,  -- 是否开通「OTA平台分销」
    COALESCE(md.is_open_typtfx, 0)                                         AS is_open_typtfx,  -- 是否开通「同业平台分销」
    COALESCE(md.is_open_fxdsfcp, 0)                                        AS is_open_fxdsfcp,  -- 是否开通「分销第三方产品」
    COALESCE(md.is_open_wqglxt, 0)                                         AS is_open_wqglxt,  -- 是否开通「温泉管理系统」
    COALESCE(md.is_open_jqpwxt, 0)                                         AS is_open_jqpwxt,  -- 是否开通「景区票务系统」
    COALESCE(md.is_open_yqykt, 0)                                          AS is_open_yqykt,  -- 是否开通「园区一卡通」
    COALESCE(md.is_open_zfxcp, 0)                                          AS is_open_zfxcp,  -- 是否开通「转分销产品」
    COALESCE(md.is_open_dzfp, 0)                                           AS is_open_dzfp,  -- 是否开通「电子发票」
    COALESCE(md.is_open_xsqg, 0)                                           AS is_open_xsqg,  -- 是否开通「限时抢购」
    COALESCE(md.is_open_dsjfx, 0)                                          AS is_open_dsjfx,  -- 是否开通「大数据分析」
    COALESCE(md.is_open_flgl, 0)                                           AS is_open_flgl,  -- 是否开通「返利管理」
    COALESCE(md.is_open_mygxdj, 0)                                         AS is_open_mygxdj,  -- 是否开通「蚂蚁供销对接」
    COALESCE(md.is_open_yzwscdj, 0)                                        AS is_open_yzwscdj,  -- 是否开通「有赞微商城对接」
    COALESCE(md.is_open_kjwsc, 0)                                          AS is_open_kjwsc,  -- 是否开通「砍价(微商城)」
    COALESCE(md.is_open_ptwsc, 0)                                          AS is_open_ptwsc,  -- 是否开通「拼团(微商城)」
    COALESCE(md.is_open_miniyxcx, 0)                                       AS is_open_miniyxcx,  -- 是否开通「MiNi云小程序」
    COALESCE(md.is_open_jfsc, 0)                                           AS is_open_jfsc,  -- 是否开通「积分商城」
    COALESCE(md.is_open_fxzy, 0)                                           AS is_open_fxzy,  -- 是否开通「分销专员」
    COALESCE(md.is_open_hytx, 0)                                           AS is_open_hytx,  -- 是否开通「会员体系」
    COALESCE(md.is_open_zghxf, 0)                                          AS is_open_zghxf,  -- 是否开通「公众号吸粉」
    COALESCE(md.is_open_hbffl, 0)                                          AS is_open_hbffl,  -- 是否开通「红包翻翻乐」
    COALESCE(md.is_open_zyzx, 0)                                           AS is_open_zyzx,  -- 是否开通「资源中心」
    COALESCE(md.is_open_wxzxwsc, 0)                                        AS is_open_wxzxwsc,  -- 是否开通「微信直销
    COALESCE(md.is_open_xcxsc, 0)                                          AS is_open_xcxsc,  -- 是否开通「小程序商城」
    COALESCE(md.is_open_yhq, 0)                                            AS is_open_yhq,  -- 是否开通「优惠券」
    COALESCE(md.is_open_fsyy, 0)                                           AS is_open_fsyy,  -- 是否开通「分时预约」
    COALESCE(md.is_open_gzhyx, 0)                                          AS is_open_gzhyx,  -- 是否开通「公众号营销」
    COALESCE(md.is_open_xcxpro, 0)                                         AS is_open_xcxpro,  -- 是否开通「小程序Pro」
    COALESCE(md.is_open_xfxzy, 0)                                          AS is_open_xfxzy,  -- 是否开通「新分销专员」
    COALESCE(md.is_open_rlzx, 0)                                           AS is_open_rlzx,  -- 是否开通「人脸中心」
    COALESCE(md.is_open_ckgl, 0)                                           AS is_open_ckgl,  -- 是否开通「窗口管理」
    COALESCE(md.is_open_zpgl, 0)                                           AS is_open_zpgl,  -- 是否开通「纸票管理」
    COALESCE(md.is_open_btglgysb, 0)                                       AS is_open_btglgysb,  -- 是否开通「报团管理
    COALESCE(md.is_open_btglfxsb, 0)                                       AS is_open_btglfxsb,  -- 是否开通「报团管理
    COALESCE(md.is_open_schygl, 0)                                         AS is_open_schygl,  -- 是否开通「商城会员管理」
    COALESCE(md.is_open_yqjs, 0)                                           AS is_open_yqjs,  -- 是否开通「园区计时」
    COALESCE(md.is_open_jqsjlp, 0)                                         AS is_open_jqsjlp,  -- 是否开通「景区数据罗盘」
    COALESCE(md.is_open_dlymdj, 0)                                         AS is_open_dlymdj,  -- 是否开通「独立域名搭建」
    COALESCE(md.is_open_wbmfmgl, 0)                                        AS is_open_wbmfmgl,  -- 是否开通「外部码发码管理」
    COALESCE(md.is_open_typtfxjcb, 0)                                      AS is_open_typtfxjcb,  -- 是否开通「同业平台分销(基础版)」
    COALESCE(md.is_open_wxkq, 0)                                           AS is_open_wxkq,  -- 是否开通「微信卡券」
    COALESCE(md.is_open_gpxzhbmd, 0)                                       AS is_open_gpxzhbmd,  -- 是否开通「购票限制(黑白名单)」
    COALESCE(md.is_open_crysjtj, 0)                                        AS is_open_crysjtj,  -- 是否开通「出入园数据统计」
    COALESCE(md.is_open_csyy21wm, 0)                                       AS is_open_csyy21wm,  -- 是否开通「测试应用21
    COALESCE(md.is_open_ylcs, 0)                                           AS is_open_ylcs,  -- 是否开通「依赖测试」
    COALESCE(md.is_open_csyyw, 0)                                          AS is_open_csyyw,  -- 是否开通「测试应用w」
    COALESCE(md.is_open_qwechb, 0)                                         AS is_open_qwechb,  -- 是否开通「qwe_chb」
    COALESCE(md.is_open_cssy, 0)                                           AS is_open_cssy,  -- 是否开通「测试使用」
    COALESCE(md.is_open_zdgl, 0)                                           AS is_open_zdgl,  -- 是否开通「终端管理」
    COALESCE(md.is_open_lxssjlp, 0)                                        AS is_open_lxssjlp,  -- 是否开通「旅行社数据罗盘」
    COALESCE(md.is_open_dxttzdy, 0)                                        AS is_open_dxttzdy,  -- 是否开通「短信抬头自定义」
    COALESCE(md.is_openzdydxmb, 0)                                         AS is_openzdydxmb,  -- 是否开通「自定义短信模板」
    COALESCE(md.is_open_lyxd, 0)                                           AS is_open_lyxd,  -- 是否开通「旅游小店」
    COALESCE(md.is_open_xypgl, 0)                                          AS is_open_xypgl,  -- 是否开通「协议票管理」
    COALESCE(md.is_open_tstdyy, 0)                                         AS is_open_tstdyy,  -- 是否开通「特殊团队预约」
    COALESCE(md.is_open_smyzbzb, 0)                                        AS is_open_smyzbzb,  -- 是否开通「扫码验证-标准版」
    COALESCE(md.is_open_smyzzyb, 0)                                        AS is_open_smyzzyb,  -- 是否开通「扫码验证-专业版」
    COALESCE(md.is_open_wlzx, 0)                                           AS is_open_wlzx,  -- 是否开通「物料中心」
    COALESCE(md.is_open_wpttbfx, 0)                                        AS is_open_wpttbfx,  -- 是否开通「微平台图表分析」
    COALESCE(md.is_open_dyglgysb, 0)                                       AS is_open_dyglgysb,  -- 是否开通「导游管理(供应商版)」
    COALESCE(md.is_open_dyglfxsb, 0)                                       AS is_open_dyglfxsb,  -- 是否开通「导游管理(分销商版)」
    COALESCE(md.is_open_yxdx, 0)                                           AS is_open_yxdx,  -- 是否开通「营销短信」
    COALESCE(md.is_open_test, 0)                                           AS is_open_test,  -- 是否开通「test」
    COALESCE(md.is_open_gpqz, 0)                                           AS is_open_gpqz,  -- 是否开通「购票前置」
    COALESCE(md.is_open_ddxxyc, 0)                                         AS is_open_ddxxyc,  -- 是否开通「订单信息隐藏」
    COALESCE(md.is_open_kjgp, 0)                                           AS is_open_kjgp,  -- 是否开通「快捷购票」
    COALESCE(md.is_open_xmtfx, 0)                                          AS is_open_xmtfx,  -- 是否开通「新媒体分销」
    COALESCE(md.is_open_flglx, 0)                                          AS is_open_flglx,  -- 是否开通「返利管理（新）」
    COALESCE(md.is_open_bbyy, 0)                                           AS is_open_bbyy,  -- 是否开通「报表应用」
    COALESCE(md.is_open_csyywm, 0)                                         AS is_open_csyywm,  -- 是否开通「测试应用
    COALESCE(md.is_open_tdyy, 0)                                           AS is_open_tdyy,  -- 是否开通「团队预约」
    COALESCE(md.is_open_fxskjgp, 0)                                        AS is_open_fxskjgp,  -- 是否开通「分销商快捷购票」
    COALESCE(md.is_open_plzzbb, 0)                                         AS is_open_plzzbb,  -- 是否开通「票类纸质报表」
    COALESCE(md.is_open_qplfx, 0)                                          AS is_open_qplfx,  -- 是否开通「全品类分销」
    COALESCE(md.is_open_tgdm, 0)                                           AS is_open_tgdm,  -- 是否开通「团购导码」
    COALESCE(md.is_open_xcxzxjq, 0)                                        AS is_open_xcxzxjq,  -- 是否开通「小程序中心(景区)」
    COALESCE(md.is_open_xcxzxlxsb, 0)                                      AS is_open_xcxzxlxsb,  -- 是否开通「小程序中心(旅行社版)」
    COALESCE(md.is_open_jyjcsj, 0)                                         AS is_open_jyjcsj,  -- 是否开通「经营基础数据」
    COALESCE(md.is_open_jyfxsj, 0)                                         AS is_open_jyfxsj,  -- 是否开通「经营分析数据」
    COALESCE(md.is_open_ycjs, 0)                                           AS is_open_ycjs,  -- 是否开通「游船计时」
    COALESCE(md.is_open_jyxpbg, 0)                                         AS is_open_jyxpbg,  -- 是否开通「经营小飘报告」
    COALESCE(md.is_open_jyhysj, 0)                                         AS is_open_jyhysj,  -- 是否开通「经营行业数据」
    COALESCE(md.is_open_tysy, 0)                                           AS is_open_tysy,  -- 是否开通「统一收银」
    COALESCE(md.is_open_xykt, 0)                                           AS is_open_xykt,  -- 是否开通「新一卡通」
    COALESCE(md.is_open_hyzx, 0)                                           AS is_open_hyzx,  -- 是否开通「会员中心」
    COALESCE(md.is_open_xcxzxnkb, 0)                                       AS is_open_xcxzxnkb,  -- 是否开通「小程序中心
    COALESCE(md.is_open_jdgl, 0)                                           AS is_open_jdgl,  -- 是否开通「酒店管理」
    COALESCE(md.is_open_zhdl, 0)                                           AS is_open_zhdl,  -- 是否开通「智慧导览」
    COALESCE(md.is_open_jfgl, 0)                                           AS is_open_jfgl,  -- 是否开通「积分管理」
    COALESCE(md.is_open_fzbbx, 0)                                          AS is_open_fzbbx,  -- 是否开通「分账报表(新)」
    COALESCE(md.is_open_xcxfxy, 0)                                         AS is_open_xcxfxy,  -- 是否开通「小程序分销员」
    COALESCE(md.is_open_fxkc, 0)                                           AS is_open_fxkc,  -- 是否开通「分销库存」
    COALESCE(md.is_open_cwph, 0)                                           AS is_open_cwph,  -- 是否开通「财务平衡」
    COALESCE(ops.poster_qty, 0)                                            AS poster_push_qty,  -- 海报推广次数
    COALESCE(pa.partner_num_ota, 0)                                        AS ota_distributor_qty,  -- 正式 OTA 分销商数
    COALESCE(ops.download_qty, 0)                                          AS sales_report_download_qty,  -- 销售报表下载次数
    COALESCE(ops.scan_qty, 0)                                              AS material_scan_qty,  -- 物料中心扫码次数
    COALESCE(sm.sms_qty, 0)                                                AS sms_qty,  -- 订单短信条数
    COALESCE(sm.mkt_task_qty, 0)                                           AS marketing_sms_task_qty,  -- 营销短信任务数
    md.open_list                                                           AS concat_all_open,  -- 已开通应用列表
    md.null_list                                                           AS concat_all_null,  -- 未开通应用列表
    kh.first_month                                                         AS first_order_month,  -- 首单月份（考核窗口起点）
    COALESCE(kh.new_media_qty, 0)                                          AS new_media_order_num_kh,  -- 首单起 3 个月新媒体
    COALESCE(kh.land_type_qty, 0)                                          AS pft_land_prod_num_kh,  -- 首单起 3 个月发布的产品类型数
    COALESCE(kh.scan_qty, 0)                                               AS pft_wlzx_scan_num_kh,  -- 首单起 3 个月新建物料的扫码次数
    COALESCE(kh.mkt_sms_qty, 0)                                            AS pft_marking_sms_num_kh,  -- 首单起 3 个月营销短信任务数
    COALESCE(kh.sign_qty, 0)                                               AS pft_sms_sign_apply_num_kh,  -- 首单起 3 个月短信抬头自定义
    COALESCE(kh.diy_qty, 0)                                                AS pft_sms_diy_apply_num_kh,  -- 首单起 3 个月短信模板自定义
    '${bizdate}'                                                           AS stat_date,  -- 统计日期
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time           -- ETL 加载时间
FROM m
LEFT JOIN k  ON k.member_id = m.member_id
LEFT JOIN m sg ON sg.member_id = m.signer_id
LEFT JOIN m sv ON sv.member_id = m.servicer_id
LEFT JOIN pa ON pa.member_id = m.member_id
LEFT JOIN ps ON ps.member_id = m.member_id
LEFT JOIN tsys ON tsys.member_id = m.member_id
LEFT JOIN pr ON pr.member_id = m.member_id
LEFT JOIN rs ON rs.member_id = m.member_id
LEFT JOIN pd ON pd.member_id = m.member_id
LEFT JOIN pk ON pk.member_id = m.member_id
LEFT JOIN p_first ON p_first.member_id = m.member_id
LEFT JOIN p_first_supplier ON p_first_supplier.member_id = m.member_id
LEFT JOIN p_curr ON p_curr.member_id = m.member_id
LEFT JOIN p_last ON p_last.member_id = m.member_id
LEFT JOIN p_next ON p_next.member_id = m.member_id
LEFT JOIN p_end  ON p_end.member_id = m.member_id
LEFT JOIN lg ON lg.member_id = m.member_id
LEFT JOIN md ON md.member_id = m.member_id
LEFT JOIN ops ON ops.member_id = m.member_id
LEFT JOIN sm ON sm.member_id = m.member_id
LEFT JOIN kh ON kh.member_id = m.member_id
WHERE m.supplier_flag = 1 OR m.distributor_flag = 1                               -- 只要商户（供应商 / 分销商）账号
