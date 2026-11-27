"""项目专用报表：客户 / 内部部门专项需求，按标准表重写（旧表名、列名沿用，下游直接使用）。

- ads_prd_attraction_visitor_stats_di：西安博物院客群日报（省内外 / 港澳台 / 境外 / 老人儿童 / 晨练 / 特殊人群 / 散约 / 现场 / 提前预约 / 本月复购）
- ads_cus_landtravel_verify_di：景旅纵横认证核验日报（按认证身份类别的核验人数、短信量、开票数）
- ads_prd_resource_center_assessment_df / _detail_df：资源中心考核（财务部，按月 × 省 × 考核区域）

项目参数（供应商、景区、票、渠道、阈值、内部账号）集中写在每段 SQL 开头的 cfg / 注释里，变更只改这里。
个人信息：证件号只以哈希参与关联（平台用户认证表的明文证件号在 SQL 内即时哈希，不落表），不输出姓名 / 手机 / 证件。
"""
import etl_core

B, I, S, D = 'BIGINT', 'INT', 'STRING', 'DECIMAL(18,2)'
NOW = etl_core.NOW
BIZ = "TO_DATE('${bizdate}', 'yyyyMMdd')"
MON1 = "CONCAT(SUBSTR('${bizdate}', 1, 6), '01')"            # 本月 1 日（yyyyMMdd）
SPECS = []


def spec(name, cn, grain, up, note, fields, legacy, part='travel_date'):
    SPECS.append({'name': name, 'cn': cn, 'grain': grain, 'up': up, 'note': note, 'fields': fields, 'legacy': legacy, 'part': part})


# ============================================================================ 西安博物院客群日报
AVS = [('in_province_qty', '省内游客入园人数（客源省 = 陕西）'), ('out_province_qty', '省外游客入园人数（境内、非陕西、非港澳台）'),
       ('hmt_qty', '港澳台游客入园人数'), ('foreign_qty', '境外游客入园人数（境外证件）'), ('elderly_qty', '老人入园人数（≥65 岁）'),
       ('children_qty', '儿童入园人数（≤6 岁）'), ('morning_exercise_qty', '晨练人员入园人数（晨练票）'), ('special_group_qty', '特殊人群入园人数（特殊人群票）'),
       ('online_booking_qty', '散约入园人数（线上第三方渠道预约）'), ('onsite_booking_qty', '现场预约入园人数（现场 / 云票务 / 平台渠道）'),
       ('in_park_qty', '实际入园人数（首次入园游客）'), ('advance_book_qty', '提前预约人数（游玩日 = 统计日的已支付票数）'),
       ('month_repeat_book_qty', '本月重复预订游客数（本月下单 ≥2 次）'), ('month_repeat_track_qty', '本月重复核销游客数（本月核销 ≥2 单）'),
       ('month_verify_total_qty', '本月累计入园人数（月初至统计日）')]
spec('ads_prd_attraction_visitor_stats_di', '西安博物院客群日报', '1行=1天×供应商（西安博物院）',
     'ods_ord_order_traveler_track_di、ods_ord_order_traveler_ext_di、dwd_ord_traveler_di、dwd_ord_order_di',
     '项目专用（AI 客群日报，回流 RDS_pft_ai）：按当日首次入园游客统计客源地、年龄、特定票、预约渠道，以及提前预约与本月复购；'
     '参数：供应商 38322930、景区 714738、本省 610000、晨练票 5373157、特殊人群票 5376735',
     [('supplier_id', B, '粒度键', '供应商ID（旧 apply_did）'), ('verify_date', S, '时间', '入园日期（yyyy-MM-dd）')]
     + [(n, B, '指标', cm) for n, cm in AVS],
     [r'^ads_prd_attraction_visitor_stats_d[if]$'])


@etl_core.sql('ads_prd_attraction_visitor_stats_di', why=[
    '替代旧 ads_prd_attraction_visitor_stats_di / _df 两套同逻辑脚本：游客属性改用标准游客明细（客源地、年龄已在 DWD 解析），不再在报表里重复解析证件 / 手机号',
    '修正：旧逻辑游客属性只关联「当日下单」的游客，提前几天下单的入园游客没有客源地 / 年龄（省内外合计小于入园人数）；改为关联近 90 天下单的游客',
    '修正：旧「本月重复核销」把证件、手机都为空的游客合成同一个人（md5(\'-\'-\'-\')）计入复购；改为必须有证件或手机标识',
    '口径差异（上线前与客户核对）：客源地标准为「证件优先、手机号段次之」（旧为手机优先）；境外标准按境外证件（旧另按手机国际区号）；'
    '散约旧为 OTA 渠道配置里 target_id = 2022 的聚合渠道，标准渠道维表不保留 target_id，按下单渠道 20（第三方 / OTA 对接）统计'],
    perf=['游客轨迹只读当日 / 本月分区并在源头过滤供应商与动作', '游客明细只取关联需要的列，按 订单号 + 游客序号 等值关联'])
def _():
    first_used = """apply_did = 38322930                                              -- 西安博物院（供应商）
      AND track_action IN (1, 4)                                        -- 入园核销类动作（沿用旧口径）
      AND COALESCE(msg, '') NOT LIKE '%过期%'                           -- 剔除过期票的核销提示
      AND CAST(GET_JSON_OBJECT(ext_content, '$.is_first_used') AS INT) = 1   -- 只计首次入园"""
    return """
WITH vt AS (   -- 当日首次入园的游客（游客轨迹 1 行 = 1 位游客 1 次动作）
    SELECT ordernum AS order_no, CAST(idx AS INT) AS traveler_seq, tid AS ticket_id, CAST(apply_did AS BIGINT) AS supplier_id
    FROM ods.ods_ord_order_traveler_track_di
    WHERE travel_date = '${bizdate}'
      AND FROM_UNIXTIME(insert_time, 'yyyyMMdd') = '${bizdate}'
      AND """ + first_used + """
),
tr AS (   -- 游客属性：近 90 天下单的游客明细（客源省、证件类型、年龄、下单渠道、证件 / 手机哈希）
    SELECT order_no, traveler_seq, scenic_id, CAST(province_code AS STRING) AS province_code, id_card_type, age, order_mode,
           IF(id_card_hash IS NULL AND phone_hash IS NULL, NULL, CONCAT(COALESCE(id_card_hash, '-'), '-', COALESCE(phone_hash, '-'))) AS person_key,
           travel_date AS order_date
    FROM dwd.dwd_ord_traveler_di
    WHERE travel_date BETWEEN DATE_FORMAT(DATE_SUB(""" + BIZ + """, 90), 'yyyyMMdd') AND '${bizdate}'
),
ext AS (   -- 下单时登记的年龄（游客扩展信息；旧口径优先用它，无则用证件解析年龄）
    SELECT orderid AS order_no, CAST(idx AS INT) AS traveler_seq, MAX(CAST(GET_JSON_OBJECT(ext_info, '$.age') AS INT)) AS ext_age
    FROM ods.ods_ord_order_traveler_ext_di
    WHERE travel_date BETWEEN DATE_FORMAT(DATE_SUB(""" + BIZ + """, 90), 'yyyyMMdd') AND '${bizdate}'
      AND apply_did = 38322930
    GROUP BY orderid, idx
),
d AS (   -- 当日入园客群
    SELECT vt.supplier_id,
           SUM(IF(tr.province_code = '610000', 1, 0))                                            AS in_province_qty,
           SUM(IF(tr.province_code NOT IN ('610000', '710000', '810000', '820000') AND COALESCE(tr.id_card_type, '') <> '2', 1, 0)) AS out_province_qty,
           SUM(IF(tr.province_code IN ('710000', '810000', '820000'), 1, 0))                     AS hmt_qty,          -- 台湾 / 香港 / 澳门
           SUM(IF(tr.id_card_type = '2', 1, 0))                                                 AS foreign_qty,      -- 证件类型 2 = 境外证件
           SUM(IF(COALESCE(e.ext_age, tr.age) >= 65, 1, 0))                                     AS elderly_qty,
           SUM(IF(COALESCE(e.ext_age, tr.age) <= 6, 1, 0))                                      AS children_qty,
           SUM(IF(vt.ticket_id = 5373157, 1, 0))                                                AS morning_exercise_qty,   -- 晨练票
           SUM(IF(vt.ticket_id = 5376735, 1, 0))                                                AS special_group_qty,      -- 特殊人群票
           SUM(IF(tr.order_mode = 20, 1, 0))                                                    AS online_booking_qty,     -- 第三方 / OTA 对接下单
           SUM(IF(tr.order_mode IN (0, 3, 10), 1, 0))                                           AS onsite_booking_qty,     -- 平台 / 现场 / 云票务下单
           COUNT(1)                                                                              AS in_park_qty
    FROM vt
    LEFT JOIN tr ON tr.order_no = vt.order_no AND tr.traveler_seq = vt.traveler_seq
    LEFT JOIN ext e ON e.order_no = vt.order_no AND e.traveler_seq = vt.traveler_seq
    GROUP BY vt.supplier_id
),
adv AS (   -- 提前预约：游玩日 = 统计日、近 10 天内下单且已支付的票数（景区 714738）
    SELECT SUM(ticket_qty) AS advance_book_qty
    FROM dwd.dwd_ord_order_di
    WHERE travel_date BETWEEN DATE_FORMAT(DATE_SUB(""" + BIZ + """, 10), 'yyyyMMdd') AND '${bizdate}'
      AND supplier_id = 38322930
      AND scenic_id = 714738
      AND pay_status = '1'
      AND play_date = DATE_FORMAT(""" + BIZ + """, 'yyyy-MM-dd')
),
mvt AS (   -- 本月 1 日至统计日的首次入园游客
    SELECT ordernum AS order_no, CAST(idx AS INT) AS traveler_seq
    FROM ods.ods_ord_order_traveler_track_di
    WHERE travel_date BETWEEN """ + MON1 + """ AND '${bizdate}'
      AND """ + first_used + """
),
mtr AS (   -- 本月下单的游客（证件 / 手机哈希作为同一游客的标识）
    SELECT order_no, traveler_seq, scenic_id, person_key FROM tr WHERE order_date >= """ + MON1 + """ AND person_key IS NOT NULL
),
rb AS (   -- 本月重复预订：同一游客本月在景区 714738 下单 ≥2 次
    SELECT COUNT(1) AS month_repeat_book_qty
    FROM (SELECT person_key FROM mtr WHERE scenic_id = 714738 GROUP BY person_key HAVING COUNT(1) > 1) x
),
rt AS (   -- 本月重复核销：同一游客本月核销 ≥2 张不同订单
    SELECT COUNT(1) AS month_repeat_track_qty
    FROM (SELECT t.person_key
          FROM mvt v
          JOIN mtr t ON t.order_no = v.order_no AND t.traveler_seq = v.traveler_seq
          GROUP BY t.person_key
          HAVING COUNT(DISTINCT v.order_no) > 1) x
),
mv AS (SELECT COUNT(1) AS month_verify_total_qty FROM mvt)
INSERT OVERWRITE TABLE ads.ads_prd_attraction_visitor_stats_di PARTITION (travel_date = '${bizdate}')
SELECT /*+ BROADCAST(adv, rb, rt, mv) */
    d.supplier_id,
    DATE_FORMAT(""" + BIZ + """, 'yyyy-MM-dd') AS verify_date,
    d.in_province_qty,
    d.out_province_qty,
    d.hmt_qty,
    d.foreign_qty,
    d.elderly_qty,
    d.children_qty,
    d.morning_exercise_qty,
    d.special_group_qty,
    d.online_booking_qty,
    d.onsite_booking_qty,
    d.in_park_qty,
    COALESCE(adv.advance_book_qty, 0) AS advance_book_qty,
    COALESCE(rb.month_repeat_book_qty, 0) AS month_repeat_book_qty,
    COALESCE(rt.month_repeat_track_qty, 0) AS month_repeat_track_qty,
    COALESCE(mv.month_verify_total_qty, 0) AS month_verify_total_qty,
    """ + NOW + """
FROM d
CROSS JOIN adv
CROSS JOIN rb
CROSS JOIN rt
CROSS JOIN mv
"""


# ============================================================================ 景旅纵横认证核验日报
UV = ['1大陆居民身份证', '2老年人', '3儿童', '4残疾人', '5参保本地人', '6大学生', '7港澳居民居住证', '8台湾居民居住证', '9港澳居民来往内地通行证',
      '10台湾居民来往内地通行证', '11外国人永久居留身份证', '12中国公民普通护照(华侨)', '13医生', '14护士', '15中小学生', '16退役军人', '17教师']
JV = ['1大陆居民', '2港澳人', '3台湾人', '4外国人', '5残疾人（福建省）', '6参保人（福建省）', '7退伍军人（福建省）', '8大学生（全国）', '9医生（福建省）',
      '10护士（福建省）', '11教师（福建省）', '12中小学生（福建省）', '13居住证']
_k = lambda x: x.split('（')[0]           # 匹配用的身份关键字（去掉括号说明）
spec('ads_cus_landtravel_verify_di', '景旅纵横认证核验日报', '1行=1天×供应商',
     'ods_ord_order_traveler_track_di、dwd_ord_traveler_di、ods_sup_user_auth_info_df、ods_sup_user_info_df、ods_sup_special_user_config_df、'
     'ods_cus_tourist_auth_info_df、ods_cus_tourist_info_df、ods_cus_identity_info_df、dwd_opr_sms_send_di、ods_fin_invoice_records_df、'
     'dim_sup_member_df、ods_opr_module_used_df、dwd_opr_package_open_di、dim_opr_module_package_df、ods_sup_member_access_account_df',
     '财务部「景旅纵横」专项：供应商每日核验（入园）人数，按游客在平台的身份认证类别拆分（景区纵横认证 17 类、景旅认证 13 类），'
     '并带当日短信量、开票数，以及是否开通特定人员模块 / 身份动态码核销',
     [('supplier_id', B, '粒度键', '供应商ID（旧 apply_did）'), ('verify_date', S, '时间', '核验日期（旧 insertdate，yyyyMMdd）'),
      ('user_name', S, '维度属性', '客户名称'), ('user_account', S, '维度属性', '账号'), ('servicer', S, '维度属性', '客服（账号名称）'),
      ('verify_num', B, '指标', '核验（入园）人数'), ('msgcnt', B, '指标', '当日短信发送量（条，按计费条数）'),
      ('records_num', B, '指标', '当日开票数'), ('jl_records_num', B, '指标', '当日景旅 APP 开票数')]
     + [(f'verify_num_{i}', B, '指标', f'景区纵横认证-{x} 核验人数') for i, x in enumerate(UV, 1)]
     + [(f'jl_verify_num_{i}', B, '指标', f'景旅认证-{x} 核验人数') for i, x in enumerate(JV, 1)]
     + [('special_person_module_flag', S, '维度属性', '是否开通特定人员模块（模块 325，单开或套餐内）：「特定人员模块」/ 空（旧 spare_field1）'),
        ('identity_code_verify_flag', S, '维度属性', '是否开通身份动态码核销（接入应用 134）：「身份动态码核销」/ 空（旧 spare_field2）')],
     ['ads_cus_landtravel_d_f', r'^cache_landtravel_'])


@etl_core.sql('ads_cus_landtravel_verify_di', why=[
    '替代旧 ads_cus_landtravel_d_f 及 6 张 cache_landtravel_* 中间表：旧表每天全量重算近 366 天（快照分区），标准按核验日增量，历史在分区里',
    '旧表 20 个预留列：spare_field1 / 2 改为有含义的列名，spare_field3（居住证）并入 jl_verify_num_13，其余恒为空串不再保留',
    '平台用户认证表的证件号为明文：只在本 SQL 内哈希（与游客明细同算法 SHA2(UPPER(证件号))）后关联，不落表'],
    perf=['认证类别先按证件哈希打标（每人一行 MAX 标志）再与当日核验关联，避免多条认证记录放大', '短信 / 开票只读当日，按供应商预聚合'])
def _():
    uv = ',\n           '.join(f"MAX(IF(identity_item LIKE '%{_k(x)}%', 1, 0)) AS f{i}" for i, x in enumerate(UV, 1))
    jv = ',\n           '.join(f"MAX(IF(identity_item LIKE '%{_k(x)}%', 1, 0)) AS j{i}" for i, x in enumerate(JV, 1))
    sv = ',\n    '.join(f'SUM(v.verify_num * COALESCE(u.f{i}, 0)) AS verify_num_{i}' for i in range(1, len(UV) + 1))
    sj = ',\n    '.join(f'SUM(v.verify_num * COALESCE(j.j{i}, 0)) AS jl_verify_num_{i}' for i in range(1, len(JV) + 1))
    return """
WITH v AS (   -- 当日核验（入园）游客：游客轨迹 track_action = 1，按 供应商 × 游客证件哈希
    SELECT CAST(t.apply_did AS BIGINT) AS supplier_id, tr.id_card_hash, SUM(t.tnum) AS verify_num
    FROM (SELECT ordernum, idx, apply_did, tnum FROM ods.ods_ord_order_traveler_track_di
          WHERE travel_date = '${bizdate}' AND track_action = 1 AND FROM_UNIXTIME(insert_time, 'yyyyMMdd') = '${bizdate}') t
    LEFT JOIN (SELECT order_no, traveler_seq, id_card_hash FROM dwd.dwd_ord_traveler_di
               WHERE travel_date BETWEEN DATE_FORMAT(DATE_SUB(""" + BIZ + """, 366), 'yyyyMMdd') AND '${bizdate}') tr
           ON tr.order_no = t.ordernum AND tr.traveler_seq = CAST(t.idx AS INT)
    GROUP BY CAST(t.apply_did AS BIGINT), tr.id_card_hash
),
u AS (   -- 景区纵横认证：平台用户的有效身份认证（认证类型编号 + 类别说明，如「2老年人」），每个证件打 17 个类别标志
    SELECT id_card_hash,
           """ + uv + """
    FROM (SELECT SHA2(UPPER(b.id_no), 256) AS id_card_hash,              -- 明文证件号即时哈希，不输出
                 CONCAT(a.identity_type, c.tag_desc) AS identity_item
          FROM ods.ods_sup_user_auth_info_df a
          JOIN ods.ods_sup_user_info_df b ON b.id = a.user_id AND b.travel_date = '${bizdate}'
          LEFT JOIN ods.ods_sup_special_user_config_df c ON c.id = a.identity_type AND c.travel_date = '${bizdate}'
          WHERE a.travel_date = '${bizdate}' AND a.status = 1 AND COALESCE(b.id_no, '') <> '') x
    GROUP BY id_card_hash
),
j AS (   -- 景旅认证：游客的有效身份认证（身份编号 + 身份名称，如「2港澳人」），每个证件打 13 个类别标志
    SELECT id_card_hash,
           """ + jv + """
    FROM (SELECT SUBSTRING_INDEX(b.certificate_no, '#', -1) AS id_card_hash,  -- ODS 证件号已脱敏为 前缀#哈希
                 CONCAT(a.identity_id, c.name) AS identity_item
          FROM ods.ods_cus_tourist_auth_info_df a
          JOIN ods.ods_cus_tourist_info_df b ON b.id = a.tourist_id AND b.travel_date = '${bizdate}'
          LEFT JOIN ods.ods_cus_identity_info_df c ON c.id = a.identity_id AND c.travel_date = '${bizdate}'
          WHERE a.travel_date = '${bizdate}' AND a.status = 1 AND COALESCE(b.certificate_no, '') <> '') x
    GROUP BY id_card_hash
),
sms AS (   -- 当日短信发送量（按计费条数）
    SELECT supplier_id, SUM(sms_qty) AS msgcnt
    FROM dwd.dwd_opr_sms_send_di
    WHERE travel_date = '${bizdate}'
    GROUP BY supplier_id
),
inv AS (   -- 当日开票数（景旅 APP 来源 source = jlzh_app）
    SELECT CAST(sid AS BIGINT) AS supplier_id, COUNT(DISTINCT id) AS records_num, COUNT(DISTINCT IF(source = 'jlzh_app', id, NULL)) AS jl_records_num
    FROM ods.ods_fin_invoice_records_df
    WHERE travel_date = '${bizdate}' AND FROM_UNIXTIME(add_time, 'yyyyMMdd') = '${bizdate}'
    GROUP BY CAST(sid AS BIGINT)
),
md AS (   -- 开通特定人员模块（模块 325）：单独开通，或所开套餐包含该模块
    SELECT member_id FROM ods.ods_opr_module_used_df WHERE travel_date = '${bizdate}' AND module_id = 325
    UNION
    SELECT p.member_id
    FROM dwd.dwd_opr_package_open_di p
    JOIN dim.dim_opr_module_package_df k ON k.package_id = p.package_id AND k.module_id = 325
),
ac AS (   -- 开通身份动态码核销（接入应用 134）
    SELECT DISTINCT CAST(sid AS BIGINT) AS member_id FROM ods.ods_sup_member_access_account_df WHERE travel_date = '${bizdate}' AND app_id = 134
)
INSERT OVERWRITE TABLE ads.ads_cus_landtravel_verify_di PARTITION (travel_date = '${bizdate}')
SELECT /*+ BROADCAST(md, ac) */
    v.supplier_id,
    '${bizdate}' AS verify_date,
    MAX(m.member_name) AS user_name,
    MAX(m.account) AS user_account,
    MAX(sv.member_name) AS servicer,
    SUM(v.verify_num) AS verify_num,
    MAX(COALESCE(sms.msgcnt, 0)) AS msgcnt,
    MAX(COALESCE(inv.records_num, 0)) AS records_num,
    MAX(COALESCE(inv.jl_records_num, 0)) AS jl_records_num,
    """ + sv + """,
    """ + sj + """,
    MAX(IF(md.member_id IS NOT NULL, '特定人员模块', '')) AS special_person_module_flag,
    MAX(IF(ac.member_id IS NOT NULL, '身份动态码核销', '')) AS identity_code_verify_flag,
    """ + NOW + """
FROM v
JOIN dim.dim_sup_member_df m ON m.member_id = v.supplier_id AND m.supplier_flag = 1      -- 只统计供应商（同旧口径）
LEFT JOIN dim.dim_sup_member_df sv ON sv.member_id = m.servicer_id
LEFT JOIN u ON u.id_card_hash = v.id_card_hash
LEFT JOIN j ON j.id_card_hash = v.id_card_hash
LEFT JOIN sms ON sms.supplier_id = v.supplier_id
LEFT JOIN inv ON inv.supplier_id = v.supplier_id
LEFT JOIN (SELECT DISTINCT member_id FROM md) md ON md.member_id = v.supplier_id
LEFT JOIN ac ON ac.member_id = v.supplier_id
GROUP BY v.supplier_id
"""


# ============================================================================ 资源中心考核
RCA = [('active_num', '新增激活用户数（首单，供货商 + 采购商）'), ('enter_num', '新增入驻用户数'), ('ticket_num', '新增手动供应票种数'),
       ('ticket_active_num', '新增启用票类（首单）'), ('land_num', '新增手动供应产品数'), ('land_active_num', '新增启用产品数（首单）'),
       ('active_10_num', '新增激活用户数（第 10 单）'), ('land_active_10_num', '新增激活产品数（第 10 单）'), ('active_purchase_num', '新增激活采购商数（累计 ≥10 单，按首单月）'),
       ('trade_purchase_num', '交易采购商数'), ('order_pay_amount', 'GMV（预订金额，元，按景区省）'), ('cutchain_pay_amount', '断连 GMV（元，按景区省）'),
       ('order_pay_cg_amount', '采购商 GMV（元，按采购商省）'), ('cutchain_pay_cg_amount', '采购商断连 GMV（元，按采购商省）'),
       ('land_num_depart', '新增唯一产品数（部门考核，按业态景区去重）'), ('land_num_depart_direct', '新增唯一产品数-直签'), ('land_num_depart_third', '新增唯一产品数-第三方'),
       ('land_num_company', '当月新上架资源景区数（景区 × 上架商）'), ('land_num_depart_direct_10', '新增唯一产品数-直签（第 10 单）'),
       ('land_num_depart_third_10', '新增唯一产品数-第三方（第 10 单）'), ('land_purchase_num_10', '累计交易 10 单采购商数（达到第 10 单的月份）'),
       ('land_num_250', '新增标杆景区供货商数（单月 ≥250 单，首次达标月）'), ('noland_num_750', '新增标杆旅行社供货商数（单月 ≥750 单，首次达标月）'),
       ('purchase_account_10', '新增标杆采购商数（单月预订 ≥10 万元，首次达标月）'), ('purchase_account_10_add', '累计交易超过 10 单的采购商数（当月有第 10 单及以后的订单）'),
       ('profit', '利润（元，指定上架账号已完结订单：(售价 − 成本) × 票数）')]
_RCA_DIMS = [('booking_month', S, '粒度键', '考核月份（yyyy-MM）'), ('belong_area', S, '粒度键', '考核区域'), ('province', S, '粒度键', '省'),
             ('import_province', I, '维度属性', '是否重点省：1-是')]
spec('ads_prd_resource_center_assessment_df', '资源中心考核指标', '1行=1个考核月×考核区域×省（全量重算）',
     'dwd_prd_resource_order_di、dim_prd_resource_df、dim_prd_scenic_df、dim_sup_member_df、dim_opr_dict_f、ods_prd_resource_amount_operation_track_df、'
     'ods_opr_resource_center_auto_get_user_df、ods_opr_resource_center_district_df、ods_sup_member_relation_df、dwd_ord_order_distribution_di',
     '财务部资源中心考核（2022 年起每月）：新增激活 / 入驻 / 上架 / 启用、第 10 单激活、交易采购商、GMV 与断连 GMV、唯一产品（直签 / 第三方）、标杆供货商 / 采购商、指定账号利润；'
     '按省归属考核区域（区域表 + 2026-05 起的区域调整规则）',
     _RCA_DIMS + [(n, D if n.endswith(('amount', 'profit')) else B, '指标', cm) for n, cm in RCA],
     ['ads_res_center_assessment_province2022_d_f'], part='')
spec('ads_prd_resource_center_assessment_detail_df', '资源中心考核明细', '1行=1个考核对象（产品 / 采购商 / 供货商）×考核类型',
     'dwd_prd_resource_order_di、dim_prd_resource_df、dim_prd_scenic_df、dim_sup_member_df、ods_opr_resource_center_district_df',
     '资源中心考核里「第 10 单 / 标杆」类指标的对象清单，供财务部核对每个计数对应的产品、采购商、供货商',
     [('booking_month', S, '粒度键', '达标日期（yyyy-MM-dd）'), ('belong_area', S, '粒度键', '考核区域'), ('province', S, '粒度键', '省'),
      ('resource_land_id', B, '粒度键', '考核对象ID（产品为业态景区ID，采购商 / 供货商为账号ID）'), ('type', S, '粒度键', '考核类型（与考核指标表的中文类型一致）'),
      ('resource_land_name', S, '维度属性', '考核对象名称')],
     ['ads_res_center_assessment_province2022_detail_d_f'], part='')

# 内部 / 测试账号（不计入驻）、利润统计的上架账号：旧 SQL 中的常量，集中在此
RCA_INTERNAL = "46992, 13912747, 12041060, 14475274, 16753023, 23604282, 24443195, 7309895, 32343705, 38320338, 38322741, 38335458"
RCA_PROFIT_ACC = "'65129163', '5902514', '71065544'"
_BASE = """
ro AS (   -- 资源中心订单（2022 年起全部日分区）；land_id = 业态景区（同一景区多个上架商只算一个产品）
    SELECT order_no, order_time, SUBSTR(order_time, 1, 7) AS mon, ticket_id, scenic_id,
           COALESCE(resource_land_id, scenic_id) AS land_id, COALESCE(resource_land_name, scenic_name) AS land_name, scenic_province_name AS land_prov,
           supplier_id AS sup_id, resource_center_supplier_name AS sup_name, resource_center_supplier_account AS sup_account, resource_center_supplier_province AS sup_prov,
           purchase_member_id AS pur_id, resource_center_purchase_name AS pur_name, resource_center_purchase_province AS pur_prov,
           booking_qty, booking_pay_amt, cost_price, sale_price, order_status, order_no_land
    FROM dwd.dwd_prd_resource_order_di
    WHERE travel_date >= '20220101'
),
rp AS (   -- 资源中心上架商品：手动供应 = 上架商不在「自动获取资源」名单；land_id 同上
    SELECT r.resource_id, r.ticket_id, r.scenic_id, r.supplier_id, r.province_name AS land_prov, r.resource_type, r.add_time,
           COALESCE(s.resource_scenic_id, r.scenic_id) AS land_id, COALESCE(s.resource_scenic_name, s.scenic_name) AS land_name,
           IF(a.user_id IS NULL, 1, 0) AS manual_flag
    FROM dim.dim_prd_resource_df r
    LEFT JOIN dim.dim_prd_scenic_df s ON s.scenic_id = r.scenic_id
    LEFT JOIN (SELECT DISTINCT user_id FROM ods.ods_opr_resource_center_auto_get_user_df WHERE travel_date = '${bizdate}') a ON a.user_id = r.supplier_id
),
ent AS (   -- 入驻：资源中心资金账户首笔入驻操作（op_type = 1）的月份；剔除内部 / 测试账号
    SELECT member_id, MIN(FROM_UNIXTIME(add_time, 'yyyy-MM')) AS mon
    FROM ods.ods_prd_resource_amount_operation_track_df
    WHERE travel_date = '${bizdate}' AND op_type = 1 AND member_id NOT IN (""" + RCA_INTERNAL + """)
    GROUP BY member_id
),
lf AS (   -- 每个业态景区的首个上架资源：资源类型（1-第三方 2-直签）与上架时间（旧 pm = 1）
    SELECT land_id, land_name, land_prov, resource_type, add_time
    FROM (SELECT rp.*, ROW_NUMBER() OVER (PARTITION BY land_id ORDER BY add_time) AS pm FROM rp) t
    WHERE pm = 1
),
lf10 AS (   -- 首个资源上架之后、该业态景区的第 10 张订单
    SELECT * FROM (
        SELECT lf.land_id, lf.land_name, lf.resource_type, ro.land_prov, ro.order_time,
               ROW_NUMBER() OVER (PARTITION BY lf.land_id ORDER BY ro.order_time) AS pm
        FROM lf JOIN ro ON ro.land_id = lf.land_id AND ro.order_time >= lf.add_time
        WHERE lf.resource_type IN (1, 2)) t
    WHERE pm = 10
),
p10 AS (   -- 采购商（按省）累计第 10 张订单（2022 年起）
    SELECT * FROM (SELECT pur_id, pur_name, pur_prov, order_time, ROW_NUMBER() OVER (PARTITION BY pur_prov, pur_id ORDER BY order_time) AS pm FROM ro) t
    WHERE pm = 10
),
sm AS (   -- 供货商月订单数（标杆：景区类单月 ≥250，非景区类单月 ≥750；须已入驻）
    SELECT ro.mon, ro.sup_prov, ro.sup_id, MAX(ro.sup_name) AS sup_name, COUNT(1) AS fcount, MAX(m.corp_kind_type) AS corp_kind_type
    FROM ro
    JOIN ent e ON e.member_id = ro.sup_id
    LEFT JOIN dim.dim_sup_member_df m ON m.member_id = ro.sup_id
    GROUP BY ro.mon, ro.sup_prov, ro.sup_id
),
bench AS (   -- 首次达标的月份（同一供货商只算一次）
    SELECT * FROM (
        SELECT sm.*, IF(corp_kind_type = 1, '新增标杆景区供货商数', '新增标杆旅行社供货商数') AS kpi,
               ROW_NUMBER() OVER (PARTITION BY sup_prov, sup_id, IF(corp_kind_type = 1, 1, 0) ORDER BY mon) AS pm
        FROM sm
        WHERE (corp_kind_type = 1 AND fcount >= 250) OR (COALESCE(corp_kind_type, -1) <> 1 AND fcount >= 750)) t
    WHERE pm = 1
),
area AS (   -- 省 → 考核区域、是否重点省
    SELECT province, MAX(district) AS district, MAX(CAST(import_province AS INT)) AS import_province
    FROM ods.ods_opr_resource_center_district_df WHERE travel_date = '${bizdate}' GROUP BY province
)"""
# 区域调整：2026-05 起原「陈娟芳」区域拆给两位负责人（旧 SQL 规则原样保留）
AREA = """CASE WHEN a.district IS NULL THEN '未知'
         WHEN k.booking_month >= '2026-05' AND a.district = '陈娟芳' THEN
              CASE WHEN k.province IN ('浙江省', '江苏省', '上海市', '湖南省', '海南省') THEN '林丰'
                   WHEN k.province IN ('湖北省', '山西省', '河北省', '安徽省', '河南省') THEN '王佳鑫' END
         ELSE a.district END"""


@etl_core.sql('ads_prd_resource_center_assessment_df', why=[
    '替代旧 ads_res_center_assessment_province2022_d_f：旧表依赖 dws_resource_center_user / land_summary / land_attr_detail / ticket_summary、'
    'ads_resource_center_order / cutchain_order 等 8 张中间表，改为从资源中心订单明细、资源商品维度直接计算（中间口径在 CTE 里一处定义）',
    '26 个指标先算成「月 × 省 × 类型 × 值」竖表再转宽表，与旧 SQL 的 UNION 结构一一对应，类型名沿用旧中文名便于对数',
    '断连 GMV：分销关系里「资源中心关系（类型 4）被断开（状态 1）后、又建立的普通分销关系（类型 0、状态 0）」上的订单，同旧 cutchain 口径',
    '「当月发生交易 SPU 数」沿用旧 SQL 实际口径：按资源景区上架月份计数（景区 × 上架商）'],
    perf=['订单明细只读一次（ro），其余 CTE 复用；窗口排序都在订单级一次完成', '区域表、自动供应名单 BROADCAST'])
def _():
    return """
WITH """ + _BASE.strip() + """,
cut AS (   -- 断连订单：资源中心关系断开后重新建立的普通分销关系（卖家 → 买家）上的订单
    SELECT DISTINCT d.order_no
    FROM dwd.dwd_ord_order_distribution_di d
    JOIN (SELECT r1.parent_id, r1.son_id
          FROM ods.ods_sup_member_relation_df r1
          JOIN ods.ods_sup_member_relation_df r2
            ON r2.parent_id = r1.parent_id AND r2.son_id = r1.son_id AND r2.travel_date = '${bizdate}'
           AND r2.status = 1 AND r2.ship_type = 4                           -- 资源中心关系，已断开
          WHERE r1.travel_date = '${bizdate}' AND r1.status = 0 AND r1.ship_type = 0   -- 普通分销关系，有效
            AND r1.rectime >= r2.cuttime                                     -- 断开之后重新建立
          GROUP BY r1.parent_id, r1.son_id) b
      ON b.parent_id = d.seller_id AND b.son_id = d.buyer_id
    WHERE d.travel_date > DATE_FORMAT(DATE_SUB(""" + BIZ + """, 732), 'yyyyMMdd')    -- 近 2 年（同旧口径）
),
co AS (SELECT ro.* FROM ro JOIN cut ON cut.order_no = ro.order_no),
st AS (SELECT dict_code FROM dim.dim_opr_dict_f WHERE dict_type = 'order_status' AND dict_name IN ('已使用，特产时为确认收货', '订单完结')),
k AS (   -- 竖表：月 × 省 × 考核类型 × 值
    -- 新增激活：用户（供货商 / 采购商任一身份）首单月份
    SELECT SUBSTR(MIN(order_time), 1, 7) AS booking_month, MAX(prov) AS province, '新增激活' AS kpi, user_id AS obj_id
    FROM (SELECT sup_id AS user_id, sup_prov AS prov, order_time FROM ro UNION ALL SELECT pur_id, pur_prov, order_time FROM ro) u
    GROUP BY user_id
    UNION ALL
    -- 新增入驻（账号 38302503 归福建省，同旧口径）
    SELECT e.mon, IF(e.member_id = 38302503, '福建省', m.province_name), '新增入驻', e.member_id
    FROM ent e LEFT JOIN dim.dim_sup_member_df m ON m.member_id = e.member_id
    UNION ALL
    SELECT SUBSTR(MIN(order_time), 1, 7), MAX(land_prov), '新增启用票类', ticket_id FROM ro GROUP BY ticket_id
    UNION ALL
    SELECT SUBSTR(MIN(order_time), 1, 7), MAX(land_prov), '新增启用产品数', scenic_id FROM ro GROUP BY scenic_id
    UNION ALL
    SELECT SUBSTR(MIN(add_time), 1, 7), MAX(land_prov), '新增票类', ticket_id FROM rp WHERE manual_flag = 1 GROUP BY ticket_id
    UNION ALL
    SELECT SUBSTR(MIN(add_time), 1, 7), MAX(land_prov), '新增产品数', scenic_id FROM rp WHERE manual_flag = 1 GROUP BY scenic_id
    UNION ALL
    SELECT SUBSTR(MIN(add_time), 1, 7), MAX(land_prov), '新增唯一产品数（部门考核）', land_id FROM rp WHERE manual_flag = 1 GROUP BY land_id
    UNION ALL
    SELECT SUBSTR(add_time, 1, 7), land_prov, IF(resource_type = 2, '新增唯一产品数（部门考核）-直签', '新增唯一产品数（部门考核）-第三方'), land_id
    FROM lf WHERE resource_type IN (1, 2)
    UNION ALL
    SELECT SUBSTR(MIN(add_time), 1, 7), MAX(land_prov), '当月发生交易SPU数', CONCAT(land_id, '-', supplier_id) FROM rp GROUP BY land_id, supplier_id
    UNION ALL
    -- 第 10 单激活：用户两种身份的订单合并排序
    SELECT SUBSTR(order_time, 1, 7), prov, '新增订单≥10用户数', user_id
    FROM (SELECT u.*, ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY order_time) AS rn
          FROM (SELECT sup_id AS user_id, sup_prov AS prov, order_time FROM ro UNION ALL SELECT pur_id, pur_prov, order_time FROM ro) u) t
    WHERE rn = 10
    UNION ALL
    SELECT SUBSTR(order_time, 1, 7), land_prov, '新增订单≥10产品数', scenic_id FROM ro WHERE order_no_land = 10
    UNION ALL
    SELECT mon, pur_prov, '交易采购商数', pur_id FROM ro GROUP BY mon, pur_prov, pur_id
    UNION ALL
    -- 新增激活采购商：累计 ≥10 单的采购商，计在首单月份
    SELECT SUBSTR(MIN(order_time), 1, 7), MAX(pur_prov), '新增激活采购商数', pur_id FROM ro GROUP BY pur_id HAVING COUNT(1) >= 10
    UNION ALL
    SELECT SUBSTR(order_time, 1, 7), land_prov, IF(resource_type = 2, '新增唯一产品数（部门考核）-直签（大于10单）', '新增唯一产品数（部门考核）-第三方（大于10单）'), land_id
    FROM lf10
    UNION ALL
    SELECT SUBSTR(order_time, 1, 7), pur_prov, '累计交易10单采购商数', pur_id FROM p10
    UNION ALL
    SELECT mon, sup_prov, kpi, sup_id FROM bench
    UNION ALL
    -- 新增标杆采购商：单月预订 ≥10 万元，首次达标月
    SELECT mon, pur_prov, '新增标杆采购商数', pur_id
    FROM (SELECT mon, pur_prov, pur_id, ROW_NUMBER() OVER (PARTITION BY pur_prov, pur_id ORDER BY mon) AS pm
          FROM (SELECT mon, pur_prov, pur_id FROM ro GROUP BY mon, pur_prov, pur_id HAVING SUM(booking_pay_amt) >= 100000) x) t
    WHERE pm = 1
    UNION ALL
    -- 累计超过 10 单：当月有第 10 单及以后订单的采购商
    SELECT DISTINCT SUBSTR(order_time, 1, 7), pur_prov, '累计交易超过10单采购商数', pur_id
    FROM (SELECT pur_id, pur_prov, order_time, ROW_NUMBER() OVER (PARTITION BY pur_prov, pur_id ORDER BY order_time) AS pm FROM ro) t
    WHERE pm >= 10
),
amt AS (   -- 金额类：GMV / 断连 GMV（按景区省、按采购商省）、指定账号利润
    SELECT mon AS booking_month, land_prov AS province, 'GMV' AS kpi, SUM(booking_pay_amt) AS v FROM ro GROUP BY mon, land_prov
    UNION ALL SELECT mon, pur_prov, 'GMV-采购商', SUM(booking_pay_amt) FROM ro GROUP BY mon, pur_prov
    UNION ALL SELECT mon, land_prov, '断连GMV', SUM(booking_pay_amt) FROM co GROUP BY mon, land_prov
    UNION ALL SELECT mon, pur_prov, '断连GMV-采购商', SUM(booking_pay_amt) FROM co GROUP BY mon, pur_prov
    UNION ALL
    SELECT mon, land_prov, '利润', SUM((COALESCE(sale_price, 0) - COALESCE(cost_price, 0)) * COALESCE(booking_qty, 0))
    FROM ro
    WHERE sup_account IN (""" + RCA_PROFIT_ACC + """) AND mon >= '2025-01' AND order_status IN (SELECT dict_code FROM st)
    GROUP BY mon, land_prov
),
kv AS (   -- 计数类按对象去重后与金额类合并
    SELECT booking_month, province, kpi, CAST(COUNT(DISTINCT obj_id) AS DECIMAL(18,2)) AS v FROM k GROUP BY booking_month, province, kpi
    UNION ALL
    SELECT booking_month, province, kpi, CAST(ROUND(v, 2) AS DECIMAL(18,2)) FROM amt
)
INSERT OVERWRITE TABLE ads.ads_prd_resource_center_assessment_df
SELECT /*+ BROADCAST(a) */
    k.booking_month,
    """ + AREA + """ AS belong_area,
    k.province,
    MAX(a.import_province) AS import_province,
""" + ',\n'.join(f"    CAST(SUM(IF(k.kpi = '{t}', k.v, 0)) AS {'DECIMAL(18,2)' if n.endswith(('amount', 'profit')) else 'BIGINT'}) AS {n}"
                 for n, t in [('active_num', '新增激活'), ('enter_num', '新增入驻'), ('ticket_num', '新增票类'), ('ticket_active_num', '新增启用票类'),
                              ('land_num', '新增产品数'), ('land_active_num', '新增启用产品数'), ('active_10_num', '新增订单≥10用户数'),
                              ('land_active_10_num', '新增订单≥10产品数'), ('active_purchase_num', '新增激活采购商数'), ('trade_purchase_num', '交易采购商数'),
                              ('order_pay_amount', 'GMV'), ('cutchain_pay_amount', '断连GMV'), ('order_pay_cg_amount', 'GMV-采购商'),
                              ('cutchain_pay_cg_amount', '断连GMV-采购商'), ('land_num_depart', '新增唯一产品数（部门考核）'),
                              ('land_num_depart_direct', '新增唯一产品数（部门考核）-直签'), ('land_num_depart_third', '新增唯一产品数（部门考核）-第三方'),
                              ('land_num_company', '当月发生交易SPU数'), ('land_num_depart_direct_10', '新增唯一产品数（部门考核）-直签（大于10单）'),
                              ('land_num_depart_third_10', '新增唯一产品数（部门考核）-第三方（大于10单）'), ('land_purchase_num_10', '累计交易10单采购商数'),
                              ('land_num_250', '新增标杆景区供货商数'), ('noland_num_750', '新增标杆旅行社供货商数'), ('purchase_account_10', '新增标杆采购商数'),
                              ('purchase_account_10_add', '累计交易超过10单采购商数'), ('profit', '利润')]) + """,
    """ + NOW + """
FROM kv k
LEFT JOIN area a ON a.province = k.province
WHERE k.booking_month >= '2022-01'
GROUP BY k.booking_month, """ + AREA.replace('\n', '\n             ') + """, k.province
"""


@etl_core.sql('ads_prd_resource_center_assessment_detail_df', why=[
    '替代旧 ads_res_center_assessment_province2022_detail_d_f：与考核指标表共用同一套 CTE 口径（第 10 单产品、第 10 单采购商、标杆供货商 / 采购商），对象清单与计数一一对应'],
    perf=['与考核指标表同源 CTE，订单明细只读一次'])
def _():
    return """
WITH """ + _BASE.strip() + """,
obj AS (
    SELECT SUBSTR(order_time, 1, 10) AS booking_month, land_prov AS province, land_id AS obj_id, land_name AS obj_name,
           IF(resource_type = 2, '新增唯一产品数（部门考核）-直签（大于10单）', '新增唯一产品数（部门考核）-第三方（大于10单）') AS kpi
    FROM lf10
    UNION ALL
    SELECT SUBSTR(order_time, 1, 10), pur_prov, pur_id, pur_name, '累计交易10单采购商数' FROM p10
    UNION ALL
    SELECT CONCAT(mon, '-01'), sup_prov, sup_id, sup_name, kpi FROM bench
    UNION ALL
    SELECT CONCAT(mon, '-01'), pur_prov, pur_id, pur_name, '新增标杆采购商数'
    FROM (SELECT mon, pur_prov, pur_id, MAX(pur_name) AS pur_name, ROW_NUMBER() OVER (PARTITION BY pur_prov, pur_id ORDER BY mon) AS pm
          FROM ro GROUP BY mon, pur_prov, pur_id HAVING SUM(booking_pay_amt) >= 100000) t
    WHERE pm = 1
)
INSERT OVERWRITE TABLE ads.ads_prd_resource_center_assessment_detail_df
SELECT DISTINCT
    o.booking_month,
    COALESCE(a.district, '未知') AS belong_area,
    o.province,
    o.obj_id AS resource_land_id,
    o.kpi AS type,
    o.obj_name AS resource_land_name,
    """ + NOW + """
FROM obj o
LEFT JOIN area a ON a.province = o.province
WHERE o.booking_month >= '2022-01-01'
"""


# 导出对照：旧列 → 本模块的列（field_map.XREF 用）
LANDTRAVEL_SPARE = {'spare_field1': 'special_person_module_flag', 'spare_field2': 'identity_code_verify_flag', 'spare_field3': 'jl_verify_num_13'}


def register(model):
    """新增项目报表；把旧表从原先粗归并的标准表（客户公司宽表 / 资源中心汇总）里移出，归到本模块的表"""
    mine = {p for s in SPECS for p in s['legacy']}
    by = {s['name']: s for s in model.T}
    for s in model.T:
        s['legacy'] = [p for p in s['legacy'] if p not in mine and p not in ('ads_prd_attraction_visitor_stats_di',)]
    for s in SPECS:
        if s['name'] in by:
            by[s['name']].update(s)
        else:
            model.T.insert(0, s)        # 放在最前：旧表归并时优先认领
