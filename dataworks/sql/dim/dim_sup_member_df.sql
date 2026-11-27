-- ================================================================================================
-- dim.dim_sup_member_df  会员（平台账号）维度
-- 粒度：1行=1个平台账号（pft_member）
-- 分区：无分区
-- 调度：每日，ODS 全部完成后；维表之间按上游顺序
-- 上游：ods_sup_member_df、ods_sup_member_ext_df、ods_sup_customer_certification_df、ods_sup_member_product_config_df、ods_opr_region_area_df、ods_sup_member_relation_df、ods_prd_scenic_df、ods_opr_distribute_system_type_df、ods_opr_datav_auth_df、ods_trf_tb_bind_df、ods_fin_merchant_payment_method_df
-- 替代旧任务 9 个（上线对数一致后下线）：
--   · 数据中台/数据维度(DIM)/dim_用户域/dim_user_d_f（EMR_SPARK_SQL，cron 00 00 01 * * ?）
--   · 数据平台/DIM/dim_cus_member_info_df（SERVERLESS_SPARK_SQL，cron 00 14 00 * * ?）
--   · 数据平台/平台湖仓工作流/经营数据/dim_cus_member_info_df（SERVERLESS_SPARK_SQL，cron 00 00 00 * * ?）
--   · 数据中台/数据维度(DIM)/dim_用户域/dim_user_datav_d_f（EMR_SPARK_SQL，cron 00 29 00 * * ?）
--   · 数据中台/数据维度(DIM)/dim_用户域/dim_thirdsystem_d_f（EMR_SPARK_SQL，cron 00 30 00 * * ?）
--   · 数据中台/数据维度(DIM)/dim_用户域/dim_user_thirdsystem_d_f（EMR_SPARK_SQL，cron 00 00 01 * * ?）
--   · 数据平台/平台湖仓工作流/经营数据/dwd_cus_qualification_auth_df（EMR_SPARK_SQL，cron 00 00 00 * * ?）
--   · 数据平台/平台湖仓工作流/经营数据/dwd_cus_user_base_bind_df（EMR_SPARK_SQL，cron 00 00 00 * * ?）
--   · 数据中台/DIM/dim_sid_white_list_d_f（EMR_SPARK_SQL，cron 00 35 00 * * ?）
-- 业务规则 / 修正：
--   · 替代 dim_user_d_f 等：旧任务同步了银行卡号 / 支付宝账号等敏感字段并全部落维表，这里不再引入
--   · 旧测试账号判定有三种写法（分组 / 名称含“测试” / 测试用户库），统一为 group_id IN (2,3)
-- 性能：
--   · 分销平台识别是 LIKE 非等值关联：模式表很小，BROADCAST 后按最长匹配取一条，避免一账号多行
--   · 供应商 / 分销商 / 大屏 / 淘宝标识用 LEFT SEMI 风格的去重子查询，避免一对多放大
-- ================================================================================================
WITH member AS (
    SELECT CAST(id AS BIGINT) AS member_id,                                       -- 会员ID（平台账号ID）
           dname,
           account,                                                               -- 登录账号
           dtype,
           status,
           dcodeurl,
           CAST(customer_id AS BIGINT) AS customer_id,                            -- CRM 客户ID
           mobile, reg_source, creattime, lasttime, group_id, account_id, salesid, kefuid
    FROM ods.ods_sup_member_df
    WHERE travel_date = '${bizdate}'                                              -- 只取当日分区
),
ext AS (
    SELECT CAST(fid AS BIGINT) AS member_id,                                      -- 会员ID（平台账号ID）
           com_name,
           province,
           city,
           country,
           corp_kind,
           contract_model,
           types,
           format_type,                                                           -- 公司业态
           protocol_start,
           protocol_end,
           contract_subject, GET_JSON_OBJECT(ext, '$.cooperation_content') AS coop_content
    FROM ods.ods_sup_member_ext_df WHERE travel_date = '${bizdate}'
),
cert AS (                                                                         -- 资质认证：同一客户多次申请取最近一条
    SELECT customer_id, certi_status, pass_time
    FROM (SELECT CAST(customer_id AS BIGINT) AS customer_id, certi_status, pass_time,
                 ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY apply_time DESC) AS rn  -- 去重序号（1 = 最新）
          FROM ods.ods_sup_customer_certification_df WHERE travel_date = '${bizdate}') t
    WHERE rn = 1
),
ptype AS (                                                                        -- 已开通的产品类型（未删除、已开通），码值转中文后拼接
    SELECT CAST(fid AS BIGINT) AS member_id,                                      -- 会员ID（平台账号ID）
           CONCAT_WS(';', SORT_ARRAY(COLLECT_SET(CASE product_type WHEN 'A' THEN '景区' WHEN 'B' THEN '线路' WHEN 'C' THEN '酒店' WHEN 'F' THEN '套票'
               WHEN 'G' THEN '餐饮' WHEN 'I' THEN '年卡' WHEN 'H' THEN '演出'
                   WHEN 'J' THEN '特产' WHEN 'K' THEN '计时产品' WHEN 'Q' THEN '旅游券' ELSE '其他' END))) AS product_type_list  -- 已开通的产品类型
    FROM ods.ods_sup_member_product_config_df
    WHERE travel_date = '${bizdate}' AND is_deleted = 0 AND open_status = 1       -- 只取当日分区，并按条件过滤
    GROUP BY CAST(fid AS BIGINT)                                                  -- 按粒度键汇总
),
-- 对接分销平台：账号二维码链接匹配平台特征串；多条命中取特征串最长（最具体）的一条
dsys AS (
    SELECT member_id, distribute_system_type
    FROM (
        SELECT /*+ BROADCAST(p) */ m.member_id, p.distribute_system_type,
               ROW_NUMBER() OVER (PARTITION BY m.member_id ORDER BY LENGTH(p.dcodeurl_like) DESC) AS rn  -- 去重序号（1 = 最新）
        FROM member m
        JOIN (SELECT dcodeurl_like, distribute_system_type
            FROM ods.ods_opr_distribute_system_type_df WHERE travel_date = '${bizdate}' AND dcodeurl_like <> '') p
          ON m.dcodeurl LIKE CONCAT('%', p.dcodeurl_like, '%')
        WHERE m.dcodeurl <> ''
    ) t
    WHERE rn = 1
),
supplier AS (                                                                     -- 发布过景区即为供应商（不依赖 dim_prd_scenic_df，避免维表互相依赖）
    SELECT DISTINCT CAST(apply_did AS BIGINT) AS member_id FROM ods.ods_prd_scenic_df WHERE travel_date = '${bizdate}'
),
distributor AS (                                                                  -- 存在有效（status=0）分销关系的下级
    SELECT DISTINCT CAST(son_id AS BIGINT) AS member_id FROM ods.ods_sup_member_relation_df WHERE travel_date = '${bizdate}' AND status = '0'
),
datav AS (SELECT DISTINCT CAST(user_id AS BIGINT) AS member_id FROM ods.ods_opr_datav_auth_df WHERE travel_date = '${bizdate}'),
taobao AS (SELECT DISTINCT CAST(id2 AS BIGINT) AS member_id FROM ods.ods_trf_tb_bind_df WHERE travel_date = '${bizdate}'),
collect AS (                                                                      -- 独立收款渠道可能多条：合并成一个字段
    SELECT CAST(member_id AS BIGINT) AS member_id,                                -- 会员ID（平台账号ID）
           CONCAT_WS('、', SORT_ARRAY(COLLECT_SET(channel_name))) AS self_collect_way  -- 独立收款方式
    FROM ods.ods_fin_merchant_payment_method_df
    WHERE travel_date = '${bizdate}'                                              -- 只取当日分区
    GROUP BY CAST(member_id AS BIGINT)                                            -- 按粒度键汇总
)
INSERT OVERWRITE TABLE dim.dim_sup_member_df                                      -- 整表覆盖写入
SELECT
    m.member_id,                                                                  -- 会员ID（平台账号ID）
    m.dname                                                          AS member_name,  -- 账号名称
    m.account,                                                                    -- 登录账号
    m.dtype                                                          AS member_type_code,  -- 账号类型
    m.status                                                         AS member_status,  -- 账号状态
    IF(s.member_id IS NOT NULL, 1, 0)                                AS supplier_flag,  -- 是否供应商
    IF(d.member_id IS NOT NULL, 1, 0)                                AS distributor_flag,  -- 是否分销商
    -- 3034 为南京途牛（历史硬编码，保留）；其余按对接平台类型
    IF(m.member_id = 3034 OR ds.distribute_system_type = 'OTA', 1, 0) AS ota_flag,  -- 是否对接分销平台（OTA / API）
    CASE WHEN m.member_id = 3034 THEN 'OTA'
         WHEN m.dcodeurl <> '' THEN COALESCE(ds.distribute_system_type, 'OTHER')
    END                                                              AS distribute_system_code,  -- 对接分销平台编码
    m.customer_id,                                                                -- CRM 客户ID
    e.com_name                                                       AS company_name,  -- 公司名称
    SUBSTRING_INDEX(m.mobile, '#', -1)                               AS contact_phone_hash,  -- 联系人手机号哈希
    m.reg_source                                                     AS register_source,  -- 注册来源
    m.creattime                                                      AS register_time,  -- 注册时间
    m.lasttime                                                       AS last_login_time,  -- 最近登录时间
    IF(dv.member_id IS NOT NULL, 1, 0)                               AS datav_open_flag,  -- 是否开通数据大屏
    IF(tb.member_id IS NOT NULL, 1, 0)                               AS taobao_bind_flag,  -- 是否绑定淘宝
    c.self_collect_way,                                                           -- 独立收款方式
    CAST(e.province AS STRING)                                       AS province_code,  -- 商户（公司）所在省编码
    rp.region_name                                                   AS province_name,  -- 商户所在省
    CAST(e.city AS STRING)                                           AS city_code,  -- 商户（公司）所在市编码
    rc.region_name                                                   AS city_name,  -- 商户所在市
    e.corp_kind                                                      AS corp_kind_type,  -- 公司类型
    CAST(e.country AS STRING)                                        AS district_code,  -- 商户所在区县编码
    m.account_id                                                     AS pay_account_id,  -- 支付账户ID
    m.salesid                                                        AS signer_id,  -- 签约销售（员工平台账号ID）
    m.kefuid                                                         AS servicer_id,  -- 客服 / 客户成功经理
    e.contract_model                                                 AS contract_model_type,  -- 合作模式
    e.types                                                          AS member_level,  -- 客户级别
    e.format_type                                                    AS format_type,  -- 公司业态
    e.contract_subject                                               AS contract_subject_type,  -- 合作主体
    e.protocol_start                                                 AS protocol_start_date,  -- 协议开始日期（首次合作）
    e.protocol_end                                                   AS protocol_end_date,  -- 协议结束日期
    CONCAT_WS(',', TRANSFORM(SPLIT(e.coop_content, ','), x -> CASE x WHEN '1' THEN '分销平台系统' WHEN '2' THEN '商城小程序系统' WHEN '3' THEN '短信合作'
        WHEN '4' THEN '年卡系统' WHEN '5' THEN '一卡通系统' WHEN '6' THEN '云票务系统' WHEN '7' THEN '手持机合作' WHEN '8' THEN '自助机合作' WHEN '9' THEN '闸机合作'
        WHEN '10' THEN '票务系统硬件' WHEN '11' THEN '停车场系统'
            WHEN '12' THEN '收银系统' WHEN '13' THEN '一机游' WHEN '14' THEN '全域旅游' WHEN '15' THEN '综管平台' ELSE x END))
                                                                     AS cooperation_content,  -- 合作内容
    ce.certi_status                                                  AS certi_status,  -- 资质认证状态
    ce.pass_time                                                     AS certi_pass_time,  -- 资质认证通过时间
    pt.product_type_list,                                                         -- 已开通的产品类型
    IF(m.group_id IN ('2', '3'), 1, 0)                               AS test_flag,  -- 是否测试账号
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time           -- ETL 加载时间
FROM member m
LEFT JOIN ext         e  ON e.member_id  = m.member_id
LEFT JOIN dsys        ds ON ds.member_id = m.member_id
LEFT JOIN supplier    s  ON s.member_id  = m.member_id
LEFT JOIN distributor d  ON d.member_id  = m.member_id
LEFT JOIN datav       dv ON dv.member_id = m.member_id
LEFT JOIN taobao      tb ON tb.member_id = m.member_id
LEFT JOIN collect     c  ON c.member_id  = m.member_id
LEFT JOIN cert        ce ON ce.customer_id = m.customer_id
LEFT JOIN ptype       pt ON pt.member_id = m.member_id
LEFT JOIN (SELECT area_code, MAX(area_name) AS region_name FROM ods.ods_opr_region_area_df WHERE travel_date = '${bizdate}' GROUP BY area_code) rp  -- 关联「国家的地区表」按键聚合
       ON rp.area_code = CAST(e.province AS STRING)                               -- 公司所在省 → 省名
LEFT JOIN (SELECT area_code, MAX(area_name) AS region_name FROM ods.ods_opr_region_area_df WHERE travel_date = '${bizdate}' GROUP BY area_code) rc  -- 关联「国家的地区表」按键聚合
       ON rc.area_code = CAST(e.city AS STRING)                                   -- 公司所在市 → 市名
