-- ================================================================================================
-- ads.ads_cus_landtravel_verify_di  景旅纵横认证核验日报
-- 粒度：1行=1天×供应商
-- 分区：travel_date（YYYYMMDD）
-- 调度：每日，依赖上游 DWS 当日分区；完成后回流 / 服务层读取
-- 上游：ods_ord_order_traveler_track_di、dwd_ord_traveler_di、ods_sup_user_auth_info_df、ods_sup_user_info_df、ods_sup_special_user_config_df、ods_cus_tourist_auth_info_df、ods_cus_tourist_info_df、ods_cus_identity_info_df、dwd_opr_sms_send_di、ods_fin_invoice_records_df、dim_sup_member_df、ods_opr_module_used_df、dwd_opr_package_open_di、dim_opr_module_package_df、ods_sup_member_access_account_df
-- 替代旧任务 1 个（上线对数一致后下线）：
--   · 业务工厂/内部信息/财务部/景旅纵横/ads_cus_landtravel_d_f（EMR_SPARK_SQL，cron 00 00 00 * * ?）
-- 业务规则 / 修正：
--   · 替代旧 ads_cus_landtravel_d_f 及 6 张 cache_landtravel_* 中间表：旧表每天全量重算近 366 天（快照分区），标准按核验日增量，历史在分区里
--   · 旧表 20 个预留列：spare_field1 / 2 改为有含义的列名，spare_field3（居住证）并入 jl_verify_num_13，其余恒为空串不再保留
--   · 平台用户认证表的证件号为明文：只在本 SQL 内哈希（与游客明细同算法 SHA2(UPPER(证件号))）后关联，不落表
-- 性能：
--   · 认证类别先按证件哈希打标（每人一行 MAX 标志）再与当日核验关联，避免多条认证记录放大
--   · 短信 / 开票只读当日，按供应商预聚合
-- ================================================================================================
WITH v AS (                                                             -- 当日核验（入园）游客：游客轨迹 track_action = 1，按 供应商 × 游客证件哈希
    SELECT CAST(t.apply_did AS BIGINT) AS supplier_id,                  -- 供应商ID（租户ID）
           tr.id_card_hash,
           SUM(t.tnum) AS verify_num                                    -- 核验（入园）人数
    FROM (SELECT ordernum, idx, apply_did, tnum FROM ods.ods_ord_order_traveler_track_di
          WHERE travel_date = '${bizdate}'                              -- 只取当日分区
            AND track_action = 1
            AND FROM_UNIXTIME(insert_time, 'yyyyMMdd') = '${bizdate}') t
    LEFT JOIN (SELECT order_no, traveler_seq, id_card_hash FROM dwd.dwd_ord_traveler_di
               WHERE travel_date BETWEEN DATE_FORMAT(DATE_SUB(TO_DATE('${bizdate}', 'yyyyMMdd'), 366), 'yyyyMMdd')
                 AND '${bizdate}') tr
           ON tr.order_no = t.ordernum AND tr.traveler_seq = CAST(t.idx AS INT)  -- 按 ordernum→order_no 关联
    GROUP BY CAST(t.apply_did AS BIGINT), tr.id_card_hash               -- 按粒度键汇总
),
u AS (                                                                  -- 景区纵横认证：平台用户的有效身份认证（认证类型编号 + 类别说明，如「2老年人」），每个证件打 17 个类别标志
    SELECT id_card_hash,
           MAX(IF(identity_item LIKE '%1大陆居民身份证%', 1, 0)) AS f1,
           MAX(IF(identity_item LIKE '%2老年人%', 1, 0)) AS f2,
           MAX(IF(identity_item LIKE '%3儿童%', 1, 0)) AS f3,
           MAX(IF(identity_item LIKE '%4残疾人%', 1, 0)) AS f4,
           MAX(IF(identity_item LIKE '%5参保本地人%', 1, 0)) AS f5,
           MAX(IF(identity_item LIKE '%6大学生%', 1, 0)) AS f6,
           MAX(IF(identity_item LIKE '%7港澳居民居住证%', 1, 0)) AS f7,
           MAX(IF(identity_item LIKE '%8台湾居民居住证%', 1, 0)) AS f8,
           MAX(IF(identity_item LIKE '%9港澳居民来往内地通行证%', 1, 0)) AS f9,
           MAX(IF(identity_item LIKE '%10台湾居民来往内地通行证%', 1, 0)) AS f10,
           MAX(IF(identity_item LIKE '%11外国人永久居留身份证%', 1, 0)) AS f11,
           MAX(IF(identity_item LIKE '%12中国公民普通护照(华侨)%', 1, 0)) AS f12,
           MAX(IF(identity_item LIKE '%13医生%', 1, 0)) AS f13,
           MAX(IF(identity_item LIKE '%14护士%', 1, 0)) AS f14,
           MAX(IF(identity_item LIKE '%15中小学生%', 1, 0)) AS f15,
           MAX(IF(identity_item LIKE '%16退役军人%', 1, 0)) AS f16,
           MAX(IF(identity_item LIKE '%17教师%', 1, 0)) AS f17
    FROM (SELECT SHA2(UPPER(b.id_no), 256) AS id_card_hash,             -- 明文证件号即时哈希，不输出
                 CONCAT(a.identity_type, c.tag_desc) AS identity_item
          FROM ods.ods_sup_user_auth_info_df a                          -- 主表「用户授权信息」
          JOIN ods.ods_sup_user_info_df b ON b.id = a.user_id AND b.travel_date = '${bizdate}'
          LEFT JOIN ods.ods_sup_special_user_config_df c                -- 关联「特殊用户配置」
            ON c.id = a.identity_type AND c.travel_date = '${bizdate}'  -- 按 identity_type→id 关联
          WHERE a.travel_date = '${bizdate}' AND a.status = 1 AND COALESCE(b.id_no, '') <> '') x  -- 只取当日分区，并按条件过滤
    GROUP BY id_card_hash                                               -- 按粒度键汇总
),
j AS (                                                                  -- 景旅认证：游客的有效身份认证（身份编号 + 身份名称，如「2港澳人」），每个证件打 13 个类别标志
    SELECT id_card_hash,
           MAX(IF(identity_item LIKE '%1大陆居民%', 1, 0)) AS j1,
           MAX(IF(identity_item LIKE '%2港澳人%', 1, 0)) AS j2,
           MAX(IF(identity_item LIKE '%3台湾人%', 1, 0)) AS j3,
           MAX(IF(identity_item LIKE '%4外国人%', 1, 0)) AS j4,
           MAX(IF(identity_item LIKE '%5残疾人%', 1, 0)) AS j5,
           MAX(IF(identity_item LIKE '%6参保人%', 1, 0)) AS j6,
           MAX(IF(identity_item LIKE '%7退伍军人%', 1, 0)) AS j7,
           MAX(IF(identity_item LIKE '%8大学生%', 1, 0)) AS j8,
           MAX(IF(identity_item LIKE '%9医生%', 1, 0)) AS j9,
           MAX(IF(identity_item LIKE '%10护士%', 1, 0)) AS j10,
           MAX(IF(identity_item LIKE '%11教师%', 1, 0)) AS j11,
           MAX(IF(identity_item LIKE '%12中小学生%', 1, 0)) AS j12,
           MAX(IF(identity_item LIKE '%13居住证%', 1, 0)) AS j13
    FROM (SELECT SUBSTRING_INDEX(b.certificate_no, '#', -1) AS id_card_hash,  -- ODS 证件号已脱敏为 前缀#哈希
                 CONCAT(a.identity_id, c.name) AS identity_item
          FROM ods.ods_cus_tourist_auth_info_df a                       -- 主表「游客授权信息」
          JOIN ods.ods_cus_tourist_info_df b ON b.id = a.tourist_id AND b.travel_date = '${bizdate}'
          LEFT JOIN ods.ods_cus_identity_info_df c ON c.id = a.identity_id AND c.travel_date = '${bizdate}'
          WHERE a.travel_date = '${bizdate}' AND a.status = 1 AND COALESCE(b.certificate_no, '') <> '') x  -- 只取当日分区，并按条件过滤
    GROUP BY id_card_hash                                               -- 按粒度键汇总
),
sms AS (                                                                -- 当日短信发送量（按计费条数）
    SELECT supplier_id, SUM(sms_qty) AS msgcnt                          -- 当日短信发送量
    FROM dwd.dwd_opr_sms_send_di
    WHERE travel_date = '${bizdate}'                                    -- 只取当日分区
    GROUP BY supplier_id                                                -- 按粒度键汇总
),
inv AS (                                                                -- 当日开票数（景旅 APP 来源 source = jlzh_app）
    SELECT CAST(sid AS BIGINT) AS supplier_id,                          -- 供应商ID（租户ID）
           COUNT(DISTINCT id) AS records_num,                           -- 当日开票数
           COUNT(DISTINCT IF(source = 'jlzh_app', id, NULL)) AS jl_records_num  -- 当日景旅 APP 开票数
    FROM ods.ods_fin_invoice_records_df
    WHERE travel_date = '${bizdate}' AND FROM_UNIXTIME(add_time, 'yyyyMMdd') = '${bizdate}'  -- 只取当日分区，并按条件过滤
    GROUP BY CAST(sid AS BIGINT)                                        -- 按粒度键汇总
),
md AS (                                                                 -- 开通特定人员模块（模块 325）：单独开通，或所开套餐包含该模块
    SELECT member_id FROM ods.ods_opr_module_used_df WHERE travel_date = '${bizdate}' AND module_id = 325
    UNION
    SELECT p.member_id
    FROM dwd.dwd_opr_package_open_di p
    JOIN dim.dim_opr_module_package_df k ON k.package_id = p.package_id AND k.module_id = 325
),
ac AS (                                                                 -- 开通身份动态码核销（接入应用 134）
    SELECT DISTINCT CAST(sid AS BIGINT) AS member_id FROM ods.ods_sup_member_access_account_df WHERE travel_date = '${bizdate}' AND app_id = 134
)
INSERT OVERWRITE TABLE ads.ads_cus_landtravel_verify_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT /*+ BROADCAST(md, ac) */
    v.supplier_id,                                                      -- 供应商ID（租户ID）
    '${bizdate}' AS verify_date,                                        -- 核验日期
    MAX(m.member_name) AS user_name,                                    -- 客户名称
    MAX(m.account) AS user_account,                                     -- 账号
    MAX(sv.member_name) AS servicer,                                    -- 客服（账号名称）
    SUM(v.verify_num) AS verify_num,                                    -- 核验（入园）人数
    MAX(COALESCE(sms.msgcnt, 0)) AS msgcnt,                             -- 当日短信发送量
    MAX(COALESCE(inv.records_num, 0)) AS records_num,                   -- 当日开票数
    MAX(COALESCE(inv.jl_records_num, 0)) AS jl_records_num,             -- 当日景旅 APP 开票数
    SUM(v.verify_num * COALESCE(u.f1, 0)) AS verify_num_1,              -- 景区纵横认证-1大陆居民身份证 核验人数
    SUM(v.verify_num * COALESCE(u.f2, 0)) AS verify_num_2,              -- 景区纵横认证-2老年人 核验人数
    SUM(v.verify_num * COALESCE(u.f3, 0)) AS verify_num_3,              -- 景区纵横认证-3儿童 核验人数
    SUM(v.verify_num * COALESCE(u.f4, 0)) AS verify_num_4,              -- 景区纵横认证-4残疾人 核验人数
    SUM(v.verify_num * COALESCE(u.f5, 0)) AS verify_num_5,              -- 景区纵横认证-5参保本地人 核验人数
    SUM(v.verify_num * COALESCE(u.f6, 0)) AS verify_num_6,              -- 景区纵横认证-6大学生 核验人数
    SUM(v.verify_num * COALESCE(u.f7, 0)) AS verify_num_7,              -- 景区纵横认证-7港澳居民居住证 核验人数
    SUM(v.verify_num * COALESCE(u.f8, 0)) AS verify_num_8,              -- 景区纵横认证-8台湾居民居住证 核验人数
    SUM(v.verify_num * COALESCE(u.f9, 0)) AS verify_num_9,              -- 景区纵横认证-9港澳居民来往内地通行证 核验人数
    SUM(v.verify_num * COALESCE(u.f10, 0)) AS verify_num_10,            -- 景区纵横认证-10台湾居民来往内地通行证 核验人数
    SUM(v.verify_num * COALESCE(u.f11, 0)) AS verify_num_11,            -- 景区纵横认证-11外国人永久居留身份证 核验人数
    SUM(v.verify_num * COALESCE(u.f12, 0)) AS verify_num_12,            -- 景区纵横认证-12中国公民普通护照(华侨) 核验人数
    SUM(v.verify_num * COALESCE(u.f13, 0)) AS verify_num_13,            -- 景区纵横认证-13医生 核验人数
    SUM(v.verify_num * COALESCE(u.f14, 0)) AS verify_num_14,            -- 景区纵横认证-14护士 核验人数
    SUM(v.verify_num * COALESCE(u.f15, 0)) AS verify_num_15,            -- 景区纵横认证-15中小学生 核验人数
    SUM(v.verify_num * COALESCE(u.f16, 0)) AS verify_num_16,            -- 景区纵横认证-16退役军人 核验人数
    SUM(v.verify_num * COALESCE(u.f17, 0)) AS verify_num_17,            -- 景区纵横认证-17教师 核验人数
    SUM(v.verify_num * COALESCE(j.j1, 0)) AS jl_verify_num_1,           -- 景旅认证-1大陆居民 核验人数
    SUM(v.verify_num * COALESCE(j.j2, 0)) AS jl_verify_num_2,           -- 景旅认证-2港澳人 核验人数
    SUM(v.verify_num * COALESCE(j.j3, 0)) AS jl_verify_num_3,           -- 景旅认证-3台湾人 核验人数
    SUM(v.verify_num * COALESCE(j.j4, 0)) AS jl_verify_num_4,           -- 景旅认证-4外国人 核验人数
    SUM(v.verify_num * COALESCE(j.j5, 0)) AS jl_verify_num_5,           -- 景旅认证-5残疾人（福建省） 核验人数
    SUM(v.verify_num * COALESCE(j.j6, 0)) AS jl_verify_num_6,           -- 景旅认证-6参保人（福建省） 核验人数
    SUM(v.verify_num * COALESCE(j.j7, 0)) AS jl_verify_num_7,           -- 景旅认证-7退伍军人（福建省） 核验人数
    SUM(v.verify_num * COALESCE(j.j8, 0)) AS jl_verify_num_8,           -- 景旅认证-8大学生（全国） 核验人数
    SUM(v.verify_num * COALESCE(j.j9, 0)) AS jl_verify_num_9,           -- 景旅认证-9医生（福建省） 核验人数
    SUM(v.verify_num * COALESCE(j.j10, 0)) AS jl_verify_num_10,         -- 景旅认证-10护士（福建省） 核验人数
    SUM(v.verify_num * COALESCE(j.j11, 0)) AS jl_verify_num_11,         -- 景旅认证-11教师（福建省） 核验人数
    SUM(v.verify_num * COALESCE(j.j12, 0)) AS jl_verify_num_12,         -- 景旅认证-12中小学生
    SUM(v.verify_num * COALESCE(j.j13, 0)) AS jl_verify_num_13,         -- 景旅认证-13居住证 核验人数
    MAX(IF(md.member_id IS NOT NULL, '特定人员模块', '')) AS special_person_module_flag,  -- 是否开通特定人员模块
    MAX(IF(ac.member_id IS NOT NULL, '身份动态码核销', '')) AS identity_code_verify_flag,  -- 是否开通身份动态码核销
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time  -- ETL 加载时间
FROM v
JOIN dim.dim_sup_member_df m ON m.member_id = v.supplier_id AND m.supplier_flag = 1  -- 只统计供应商（同旧口径）
LEFT JOIN dim.dim_sup_member_df sv ON sv.member_id = m.servicer_id
LEFT JOIN u ON u.id_card_hash = v.id_card_hash
LEFT JOIN j ON j.id_card_hash = v.id_card_hash
LEFT JOIN sms ON sms.supplier_id = v.supplier_id
LEFT JOIN inv ON inv.supplier_id = v.supplier_id
LEFT JOIN (SELECT DISTINCT member_id FROM md) md ON md.member_id = v.supplier_id
LEFT JOIN ac ON ac.member_id = v.supplier_id
GROUP BY v.supplier_id                                                  -- 按粒度键汇总
