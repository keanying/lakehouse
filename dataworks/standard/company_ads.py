"""客户公司属性宽表（财务部客户属性 cus_company）：旧 dim_cus_company_d_f 按标准表重写。

粒度：1 行 = 1 个平台账号（商户）× 统计日快照。下游（it_project / Oracle 的 cus_company、dim_cus_company_d_f）直接使用，
列名沿用旧表；旧表 25 个预留列（spare_field1~25）按实际含义改名，常量 / 恒空列不再保留（导出对照见 field_map 别名）。
来源全部是标准表：商户维度、CRM 客户维度、分销关系拉链、门票 / 资源 / 景区维度、套餐 / 模块开通明细、登录明细、短信明细；
三类没有业务过程的配置 / 操作日志（海报、物料中心扫码、报表下载、票务系统绑定）直接按 ODS 汇总。
"""
import json
import pathlib

import etl_core

B, I, S, D = 'BIGINT', 'INT', 'STRING', 'DECIMAL(18,2)'
FLAGS = json.loads(pathlib.Path(__file__).with_name('module_flags.json').read_text(encoding='utf-8'))
BIZ = "TO_DATE('${bizdate}', 'yyyyMMdd')"
P = "travel_date = '${bizdate}'"
COLS = []          # (字段, 类型, 类别, 注释, 表达式)


def c(n, ty, cat, cm, e):
    COLS.append((n, ty, cat, cm, e))


# ---------------------------------------------------------------- 账号 / 客户基础
c('user_id', B, '粒度键', '平台账号ID', 'm.member_id')
c('user_account_id', B, '维度属性', '支付账户ID', 'm.pay_account_id')
c('user_customer_id', B, '维度属性', '平台客户ID', 'm.customer_id')
c('user_account', S, '维度属性', '登录账号（旧 spare_field10）', 'm.account')
c('user_name', S, '维度属性', '账号名称', 'm.member_name')
c('user_company_name', S, '维度属性', '公司名称', 'm.company_name')
c('customer_name', S, '维度属性', '客户名称（CRM 客户名，无则公司名）', 'COALESCE(k.company_name, m.company_name)')
c('customer_mobile_hash', S, '维度属性', '客户联系人手机号哈希（旧表为明文，改存哈希）', 'm.contact_phone_hash')
c('user_type_code', S, '状态类型', '账号类型编码', 'm.member_type_code')
c('user_type', S, '维度属性', '账号类型：供应商 / 分销商 / 其他', "CASE WHEN m.supplier_flag = 1 THEN '供应商' WHEN m.distributor_flag = 1 THEN '分销商' ELSE '其他' END")
c('user_is_test', S, '状态类型', '正式 / 测试', "IF(m.test_flag = 1, '测试', '正式')")
c('user_status', S, '状态类型', '账号状态', "CASE m.member_status WHEN '0' THEN '正常' WHEN '1' THEN '禁用' WHEN '2' THEN '删除' WHEN '3' THEN '未审核' ELSE m.member_status END")
c('customer_certi_status_code', I, '状态类型', '资质认证状态编码', 'm.certi_status')
c('customer_certi_status', S, '维度属性', '资质认证状态', "CASE m.certi_status WHEN 0 THEN '未认证' WHEN 1 THEN '审核中' WHEN 2 THEN '已认证' WHEN 3 THEN '认证未通过' END")
c('customer_country', S, '维度属性', '客户国家', "COALESCE(k.country_name, '中国')")
c('customer_province', S, '维度属性', '客户省', 'COALESCE(m.province_name, k.province_name)')
c('customer_city', S, '维度属性', '客户市', 'COALESCE(m.city_name, k.city_name)')
c('customer_type_code', I, '状态类型', '客户类型编码（公司类型）', 'm.corp_kind_type')
c('customer_type', S, '维度属性', '客户类型（酒店 / 景区 / 旅行社 …）', "CASE m.corp_kind_type WHEN 0 THEN '酒店' WHEN 1 THEN '景区' WHEN 2 THEN '旅行社' ELSE '其他' END")
c('user_land_topic', I, '状态类型', '公司业态', 'm.format_type')
c('user_level', I, '状态类型', '客户级别', 'm.member_level')
c('user_contract_model_code', I, '状态类型', '合作模式编码', 'm.contract_model_type')
c('user_contract_model', S, '维度属性', '合作模式', "CASE m.contract_model_type WHEN 0 THEN '无' WHEN 1 THEN '套餐' WHEN 2 THEN '票务' ELSE CAST(m.contract_model_type AS STRING) END")
c('signer_id', B, '维度属性', '签单人（员工平台账号ID）', 'm.signer_id')
c('signer', S, '维度属性', '签单人姓名', 'sg.member_name')
c('servicer_id', B, '维度属性', '客服 / 客户成功经理（员工平台账号ID）', 'm.servicer_id')
c('servicer', S, '维度属性', '客服姓名', 'sv.member_name')
c('user_regist_time', S, '时间', '注册时间', 'm.register_time')
c('user_contarct_firstdate', S, '时间', '首次合作（协议开始）日期', 'm.protocol_start_date')
c('user_login_lasttime', S, '时间', '最近登录时间', 'm.last_login_time')
c('cooperation_customer_level', S, '维度属性', 'CRM 合作客户等级（旧 spare_field19）', 'k.account_level')
c('cooperation_content', S, '维度属性', '合作内容（旧 spare_field16）', 'm.cooperation_content')
c('product_open_list', S, '维度属性', '已开通产品类型（旧 spare_field11）', 'm.product_type_list')
# ---------------------------------------------------------------- 合作伙伴
c('first_add_distributor_time', S, '时间', '首次添加分销商时间', 'pa.first_add_time')
c('end_edit_distributor_time', S, '时间', '最后添加分销商时间', 'pa.last_add_time')
c('partner_num_supp', I, '度量', '供应商数（为本账号供货的上级）', 'COALESCE(ps.partner_num_supp, 0)')
c('partner_num_ota', I, '度量', 'OTA 分销商数', 'COALESCE(pa.partner_num_ota, 0)')
c('partner_num_dist', I, '度量', '分销商数', 'COALESCE(pa.partner_num_dist, 0)')
c('partner_num_staff', I, '度量', '员工账号数（从属关系）', 'COALESCE(pa.partner_num_staff, 0)')
c('partner_num_ticket_system', I, '度量', '绑定的线下票务系统数（旧 spare_field5 同口径）', 'COALESCE(tsys.sys_qty, 0)')
c('partner_ticket_system_list', S, '维度属性', '绑定的票务系统名称列表', 'tsys.sys_list')
# ---------------------------------------------------------------- 产品
PROD = [('first_add_ticket_time', S, '时间', '最早编辑票时间（票维度无创建时间，取最早更新时间）', 'pr.first_edit_time'),
        ('end_edit_ticket_time', S, '时间', '最后编辑票时间', 'pr.last_edit_time')]
for kind, cn in (('ticket', '票种'), ('land', '产品'), ('resource', '资源')):
    a_ = 'rs' if kind == 'resource' else 'pr'
    PROD += [(f'onsale_{kind}_num_self', I, '度量', f'在售自供应{cn}数（上架且未过期）', f'COALESCE({a_}.onsale_{kind}, 0)'),
             (f'off_shelf_{kind}_num_self', I, '度量', f'下架自供应{cn}数', f'COALESCE({a_}.off_{kind}, 0)'),
             (f'overdue_{kind}_num_self', I, '度量', f'上架但已过期的自供应{cn}数', f'COALESCE({a_}.overdue_{kind}, 0)')]
    for per, pcn in (('curr_week', '本周'), ('curr_month', '本月'), ('curr_quarter', '本季')):
        PROD.append((f'add_{kind}_num_self_{per}', I, '度量', f'{pcn}新编辑自供应{cn}数', f'COALESCE({a_}.add_{kind}_{per}, 0)'))
    PROD.append((f'{kind}_num_dist', I, '度量', f'分销{cn}数（上级供应商在售、本账号可分销）', f'COALESCE(pd.dist_{kind}, 0)'))
PROD.append(('product_type_qty', I, '度量', '发布的产品类型数（旧 spare_field3）', 'COALESCE(pr.product_type_qty, 0)'))
for x in PROD:
    c(*x)
# ---------------------------------------------------------------- 套餐
c('amount_package', D, '度量', '套餐实收合计（元）', 'COALESCE(pk.amount_package, 0)')
c('user_package_num_buy', I, '度量', '购买套餐次数', 'COALESCE(pk.num_buy, 0)')
c('user_package_num_used', I, '度量', '已用完（已到期）套餐次数', 'COALESCE(pk.num_used, 0)')
PK = {'first_supplier': '第一次合作供应商套餐', 'first': '第一次套餐', 'curr': '当前套餐', 'last': '上次套餐', 'next': '下个套餐', 'end': '最终套餐'}
for k_, cn in PK.items():
    a = f'p_{k_}'
    c(f'user_{k_}_package_id', B, '维度属性', f'{cn}ID', f'{a}.package_id')
    c(f'user_{k_}_package_name', S, '维度属性', f'{cn}名称', f'{a}.package_name')
    c(f'user_{k_}_package_adddate', S, '时间', f'{cn}签约（开通）日期', f'TO_DATE({a}.open_time)')
    c(f'user_{k_}_package_begindate', S, '时间', f'{cn}开始日期', f'TO_DATE({a}.valid_start_time)')
    c(f'user_{k_}_package_enddate', S, '时间', f'{cn}结束日期', f'TO_DATE({a}.valid_end_time)')
    c(f'user_{k_}_package_price', D, '度量', f'{cn}标价（元）', f'{a}.package_price_amt')
    c(f'user_{k_}_package_pay_amt', D, '度量', f'{cn}实收（元）', f'{a}.package_pay_amt')
    c(f'user_{k_}_package_role', S, '维度属性', f'{cn}角色', f"CASE {a}.package_role WHEN 0 THEN '供应商' WHEN 1 THEN '分销商' END")
    c(f'user_{k_}_package_classify_name', S, '维度属性', f'{cn}分类（套餐组）', f'{a}.classify_name')
    if k_ in ('curr', 'last'):
        c(f'user_{k_}_package_diff_month', I, '度量', f'{cn}周期（月）', f'CAST(CEIL(MONTHS_BETWEEN({a}.valid_end_time, {a}.valid_start_time)) AS INT)')
        c(f'user_{k_}_package_avg_pay_amt', D, '度量', f'{cn}月均实收（元）',
          f'CAST({a}.package_pay_amt / NULLIF(CEIL(MONTHS_BETWEEN({a}.valid_end_time, {a}.valid_start_time)), 0) AS DECIMAL(18,2))')
    if k_ in ('curr', 'next'):
        c(f'user_{k_}_package_signer', S, '维度属性', f'{cn}签单人', f'{a}.sale_man_name')
        prev = 'p_last' if k_ == 'curr' else 'p_curr'
        c(f'user_{k_}_package_prepay_months', D, '度量', f'{cn}提前续费月数 =（签约日 − 上一套餐结束日）/ 30',
          f'CAST(DATEDIFF(TO_DATE({a}.open_time), TO_DATE({prev}.valid_end_time)) / 30 AS DECIMAL(18,2))')
        c(f'user_{k_}_package_contract_model', I, '状态类型', f'{cn}合作模式', f'{a}.cooperation_mode')
# ---------------------------------------------------------------- 登录
PERIODS = [('curr_week', '本周'), ('last_week', '上周'), ('curr_month', '本月'), ('last_month', '上月'), ('curr_quarter', '本季'), ('last_quarter', '上季'), ('60_day', '近 60 天')]
for per, pcn in PERIODS:
    for src, scn in (('plat', '平台'), ('terminal', '终端')):
        c(f'login_num_{src}_{per}', I, '度量', f'{pcn}登录{scn}次数', f'COALESCE(lg.n_{src}_{per}, 0)')
        c(f'login_date_num_{src}_{per}', I, '度量', f'{pcn}登录{scn}天数', f'COALESCE(lg.d_{src}_{per}, 0)')
# ---------------------------------------------------------------- 应用开通
for mid, flag, cn in FLAGS:
    c(flag, I, '状态类型', f'是否开通「{cn}」（模块 {mid}，单开或套餐内含，当前有效）', f'COALESCE(md.{flag}, 0)')
# ---------------------------------------------------------------- 营销与运营使用（旧预留列）
c('poster_push_qty', B, '度量', '海报推广次数（旧 spare_field2）', 'COALESCE(ops.poster_qty, 0)')
c('ota_distributor_qty', B, '度量', '正式 OTA 分销商数（旧 spare_field4）', 'COALESCE(pa.partner_num_ota, 0)')
c('sales_report_download_qty', B, '度量', '销售报表下载次数（旧 spare_field6）', 'COALESCE(ops.download_qty, 0)')
c('material_scan_qty', B, '度量', '物料中心扫码次数（旧 spare_field7）', 'COALESCE(ops.scan_qty, 0)')
c('sms_qty', B, '度量', '订单短信条数（累计，旧 spare_field8）', 'COALESCE(sm.sms_qty, 0)')
c('marketing_sms_task_qty', B, '度量', '营销短信任务数（累计，旧 spare_field9）', 'COALESCE(sm.mkt_task_qty, 0)')
c('concat_all_open', S, '维度属性', '已开通应用列表（中文，顿号分隔）', 'md.open_list')
c('concat_all_null', S, '维度属性', '未开通应用列表', 'md.null_list')
c('first_order_month', S, '时间', '首单月份（考核窗口起点）', 'kh.first_month')
c('new_media_order_num_kh', B, '度量', '首单起 3 个月新媒体（抖音 / 快手 …账号标签）订单数', 'COALESCE(kh.new_media_qty, 0)')
c('pft_land_prod_num_kh', B, '度量', '首单起 3 个月发布的产品类型数', 'COALESCE(kh.land_type_qty, 0)')
c('pft_wlzx_scan_num_kh', B, '度量', '首单起 3 个月新建物料的扫码次数', 'COALESCE(kh.scan_qty, 0)')
c('pft_marking_sms_num_kh', B, '度量', '首单起 3 个月营销短信任务数', 'COALESCE(kh.mkt_sms_qty, 0)')
c('pft_sms_sign_apply_num_kh', B, '度量', '首单起 3 个月短信抬头自定义（审核通过）次数', 'COALESCE(kh.sign_qty, 0)')
c('pft_sms_diy_apply_num_kh', B, '度量', '首单起 3 个月短信模板自定义（审核通过且启用）次数', 'COALESCE(kh.diy_qty, 0)')
c('stat_date', S, '时间', '统计日期', "'${bizdate}'")

NAMES = [x[0] for x in COLS]
ALIAS = {'spare_field2': 'poster_push_qty', 'spare_field3': 'product_type_qty', 'spare_field4': 'ota_distributor_qty', 'spare_field5': 'partner_num_ticket_system',
         'spare_field6': 'sales_report_download_qty', 'spare_field7': 'material_scan_qty', 'spare_field8': 'sms_qty', 'spare_field9': 'marketing_sms_task_qty',
         'spare_field10': 'user_account', 'spare_field11': 'product_open_list', 'spare_field12': 'login_num_plat_60_day', 'spare_field13': 'login_num_terminal_60_day',
         'spare_field14': 'login_date_num_plat_60_day', 'spare_field15': 'login_date_num_terminal_60_day', 'spare_field16': 'cooperation_content',
         'spare_field17': 'is_open_xcxfxy', 'spare_field18': 'is_open_fxkc', 'spare_field19': 'cooperation_customer_level',
         'customer_mobile': 'customer_mobile_hash', 'first_add_time': 'first_add_distributor_time', 'end_edit_time': 'end_edit_distributor_time',
         'ticket_system_list': 'partner_ticket_system_list', 'ticket_num_self': 'onsale_ticket_num_self', 'land_num_self': 'onsale_land_num_self',
         'resource_num_self': 'onsale_resource_num_self', 'sum_pay_amount_package': 'amount_package',
         'user_next_package_begin_date': 'user_next_package_begindate', 'user_next_package_end_date': 'user_next_package_enddate',
         'user_next_package_add_date': 'user_next_package_adddate', 'user_curr_package_begin_date': 'user_curr_package_begindate',
         'user_curr_package_end_date': 'user_curr_package_enddate', 'user_curr_package_add_date': 'user_curr_package_adddate',
         'user_last_package_begin_date': 'user_last_package_begindate', 'user_last_package_end_date': 'user_last_package_enddate',
         'user_last_package_add_date': 'user_last_package_adddate'}
DROPPED = {'spare_field1': '旧表恒为 0（是否开通手持机，旧逻辑已注释）', 'pft_storage_section_num_kh': '旧口径恒为 0（分时预约来源表在旧 SQL 中已注释）', **{f'spare_field{i}': '旧表恒为空的预留列' for i in range(20, 26)}}

# 时间边界
WS = f"DATE_SUB({BIZ}, PMOD(DATEDIFF({BIZ}, '1900-01-01'), 7))"          # 本周一（1900-01-01 为周一）
MS = f"TRUNC({BIZ}, 'MM')"
QS = f"ADD_MONTHS(TRUNC({BIZ}, 'YEAR'), (QUARTER({BIZ}) - 1) * 3)"
RANGE = {'curr_week': (WS, BIZ), 'last_week': (f'DATE_SUB({WS}, 7)', f'DATE_SUB({WS}, 1)'), 'curr_month': (MS, BIZ),
         'last_month': (f'ADD_MONTHS({MS}, -1)', f'DATE_SUB({MS}, 1)'), 'curr_quarter': (QS, BIZ),
         'last_quarter': (f'ADD_MONTHS({QS}, -3)', f'DATE_SUB({QS}, 1)'), '60_day': (f'DATE_SUB({BIZ}, 59)', BIZ)}


def _login():
    parts = []
    for per, (a, b) in RANGE.items():
        for src, code in (('plat', '1'), ('terminal', '2')):
            cond = f"login_source = '{code}' AND login_date BETWEEN {a} AND {b}"
            parts.append(f'COUNT(IF({cond}, 1, NULL)) AS n_{src}_{per}')
            parts.append(f'COUNT(DISTINCT IF({cond}, login_date, NULL)) AS d_{src}_{per}')
    return ',\n           '.join(parts)


def _flags():
    x = [f'MAX(IF(module_id = {mid}, 1, 0)) AS {flag}' for mid, flag, _ in FLAGS]
    x.append("CONCAT_WS('、', " + ', '.join(f"IF(MAX(IF(module_id = {mid}, 1, 0)) = 1, '{cn}', NULL)" for mid, _, cn in FLAGS) + ') AS open_list')
    x.append("CONCAT_WS('、', " + ', '.join(f"IF(MAX(IF(module_id = {mid}, 1, 0)) = 0, '{cn}', NULL)" for mid, _, cn in FLAGS) + ') AS null_list')
    return ',\n           '.join(x)


def _prod():
    per = {'curr_week': WS, 'curr_month': MS, 'curr_quarter': QS}
    t_on = f"ticket_status = '1' AND COALESCE(TO_DATE(max_expiration_date), {BIZ}) >= {BIZ}"
    t_over = f"ticket_status = '1' AND TO_DATE(max_expiration_date) < {BIZ}"
    t_off = "ticket_status = '2'"
    x = [f'MIN(update_time) AS first_edit_time', 'MAX(update_time) AS last_edit_time',
         f'COUNT(DISTINCT IF({t_on}, ticket_id, NULL)) AS onsale_ticket', f'COUNT(DISTINCT IF({t_on}, scenic_id, NULL)) AS onsale_land',
         f'COUNT(DISTINCT IF({t_off}, ticket_id, NULL)) AS off_ticket', f'COUNT(DISTINCT IF({t_off}, scenic_id, NULL)) AS off_land',
         f'COUNT(DISTINCT IF({t_over}, ticket_id, NULL)) AS overdue_ticket', f'COUNT(DISTINCT IF({t_over}, scenic_id, NULL)) AS overdue_land']
    for p_, s_ in per.items():
        x += [f"COUNT(DISTINCT IF(TO_DATE(update_time) >= {s_}, ticket_id, NULL)) AS add_ticket_{p_}",
              f"COUNT(DISTINCT IF(TO_DATE(update_time) >= {s_}, scenic_id, NULL)) AS add_land_{p_}"]
    return ',\n           '.join(x)


def _res():
    per = {'curr_week': WS, 'curr_month': MS, 'curr_quarter': QS}
    r_on = f"resource_status = 1 AND COALESCE(TO_DATE(max_expiration_date), {BIZ}) >= {BIZ}"
    x = [f'COUNT(DISTINCT IF({r_on}, resource_id, NULL)) AS onsale_resource', 'COUNT(DISTINCT IF(resource_status = 0, resource_id, NULL)) AS off_resource',
         f'COUNT(DISTINCT IF(resource_status = 1 AND TO_DATE(max_expiration_date) < {BIZ}, resource_id, NULL)) AS overdue_resource']
    x += [f"COUNT(DISTINCT IF(TO_DATE(update_time) >= {s_}, resource_id, NULL)) AS add_resource_{p_}" for p_, s_ in per.items()]
    return ',\n           '.join(x)


def _pk(alias, where, order):
    return (f"{alias} AS (SELECT * FROM (SELECT h.*, ROW_NUMBER() OVER (PARTITION BY member_id ORDER BY {order}) AS rk FROM pkh h WHERE {where}) t WHERE rk = 1)")


SEL = ',\n    '.join(f'{e:<70} AS {n}' if e != n else n for n, _, _, _, e in COLS)


@etl_core.sql('ads_sup_customer_company_df', why=[
    '替代旧 dim_cus_company_d_f（财务部客户属性）及其 4 张中间表（套餐 / 登录 / 合作伙伴 / 产品），全部改从标准表计算',
    '旧表 110 个应用开通标志逐个 CASE 硬编码：模块 ID 与标志名迁入 module_flags.json，SQL 按配置生成',
    '旧金额单位为分，标准统一为元；客户手机号明文改存哈希'],
    perf=['套餐 / 登录各读一次历史（登录只读近两个季度分区），先按账号聚合再一次性关联，宽表不放大', '小维表与码表 BROADCAST'])
def _():
    return f"""
WITH m AS (SELECT * FROM dim.dim_sup_member_df),
k AS (   -- CRM 客户：同一平台账号多条取最近成交
    SELECT * FROM (SELECT d.*, ROW_NUMBER() OVER (PARTITION BY member_id ORDER BY last_deal_time DESC) AS rk FROM dim.dim_sup_company_df d WHERE member_id IS NOT NULL) t
    WHERE rk = 1
),
rel AS (SELECT * FROM dim.dim_sup_member_relation_zip WHERE end_date = '99991231'),
pa AS (   -- 作为上级：分销商 / OTA / 员工
    SELECT r.parent_id AS member_id,
           MIN(IF(r.son_type = '0' AND r.relationship_type = '0', r.add_time, NULL)) AS first_add_time,
           MAX(IF(r.son_type = '0' AND r.relationship_type = '0', r.add_time, NULL)) AS last_add_time,
           COUNT(DISTINCT IF(r.son_type = '0' AND r.relationship_type = '0', r.son_id, NULL)) AS partner_num_dist,
           COUNT(DISTINCT IF(r.son_type = '0' AND r.relationship_type = '0' AND sm.ota_flag = 1 AND sm.test_flag = 0, r.son_id, NULL)) AS partner_num_ota,
           COUNT(DISTINCT IF(r.son_type = '2' AND r.relationship_type = '1', r.son_id, NULL)) AS partner_num_staff
    FROM rel r LEFT JOIN m sm ON sm.member_id = r.son_id
    GROUP BY r.parent_id
),
ps AS (SELECT son_id AS member_id, COUNT(DISTINCT parent_id) AS partner_num_supp FROM rel WHERE relationship_type = '0' GROUP BY son_id),   -- 作为下级：供应商数
tsys AS (   -- 绑定的票务系统（配置表，无业务过程，直接按 ODS）
    SELECT b.pft_memberid AS member_id, COUNT(DISTINCT b.cid) AS sys_qty, CONCAT_WS('、', SORT_ARRAY(COLLECT_SET(s.name))) AS sys_list
    FROM ods.ods_trf_con_sys_member_df b
    LEFT JOIN ods.ods_trf_con_sys_df s ON s.id = b.cid AND s.{P}
    WHERE b.{P} AND b.status = 0
    GROUP BY b.pft_memberid
),
pr AS (   -- 自供应门票 / 产品
    SELECT supplier_id AS member_id,
           {_prod()},
           COUNT(DISTINCT sc.scenic_type_code) AS product_type_qty
    FROM dim.dim_prd_ticket_df t
    LEFT JOIN (SELECT scenic_id AS sid_, scenic_type_code FROM dim.dim_prd_scenic_df) sc ON sc.sid_ = t.scenic_id
    WHERE t.ticket_status <> '6'
    GROUP BY supplier_id
),
rs AS (   -- 自供应资源（资源中心上架）
    SELECT supplier_id AS member_id,
           {_res()}
    FROM dim.dim_prd_resource_df
    GROUP BY supplier_id
),
pd AS (   -- 分销：上级供应商在售的票 / 产品 / 资源
    SELECT r.son_id AS member_id,
           COUNT(DISTINCT IF(t.ticket_status = '1', t.ticket_id, NULL)) AS dist_ticket,
           COUNT(DISTINCT IF(t.ticket_status = '1', t.scenic_id, NULL)) AS dist_land,
           COUNT(DISTINCT rr.resource_id) AS dist_resource
    FROM rel r
    JOIN dim.dim_prd_ticket_df t ON t.supplier_id = r.parent_id
    LEFT JOIN dim.dim_prd_resource_df rr ON rr.supplier_id = r.parent_id AND rr.ticket_id = t.ticket_id AND rr.resource_status = 1
    WHERE r.relationship_type = '0'
    GROUP BY r.son_id
),
pkh AS (   -- 套餐开通历史（全部分区）+ 套餐分类
    SELECT o.*, c.classify_name
    FROM dwd.dwd_opr_package_open_di o
    LEFT JOIN (SELECT package_id, MAX(package_classify_name) AS classify_name FROM dim.dim_opr_module_package_df WHERE package_id > 0 GROUP BY package_id) c
           ON c.package_id = o.package_id
    WHERE o.travel_date <= '${{bizdate}}' AND COALESCE(o.stop_type, 0) <> 1             -- 作废的不算
),
pk AS (
    SELECT member_id, SUM(package_pay_amt) AS amount_package, COUNT(1) AS num_buy, COUNT(IF(TO_DATE(valid_end_time) < {BIZ}, 1, NULL)) AS num_used
    FROM pkh GROUP BY member_id
),
{_pk('p_first', '1 = 1', 'valid_start_time, open_time')},
{_pk('p_first_supplier', 'package_role = 0', 'valid_start_time, open_time')},
{_pk('p_curr', f'TO_DATE(valid_start_time) <= {BIZ} AND TO_DATE(valid_end_time) >= {BIZ}', 'valid_start_time DESC, open_time DESC')},
{_pk('p_last', f'TO_DATE(valid_end_time) < {BIZ}', 'valid_end_time DESC, open_time DESC')},
{_pk('p_next', f'TO_DATE(valid_start_time) > {BIZ}', 'valid_start_time, open_time')},
{_pk('p_end', '1 = 1', 'valid_end_time DESC, open_time DESC')},
lg AS (   -- 登录：近两个季度分区
    SELECT member_id,
           {_login()}
    FROM (SELECT member_id, CAST(login_source AS STRING) AS login_source, TO_DATE(login_time) AS login_date FROM dwd.dwd_sup_member_login_di
          WHERE travel_date >= DATE_FORMAT(ADD_MONTHS({QS}, -3), 'yyyyMMdd') AND travel_date <= '${{bizdate}}') t
    GROUP BY member_id
),
md AS (   -- 当前有效的应用模块：单独开通 + 当前套餐内含模块
    SELECT member_id,
           {_flags()}
    FROM (SELECT member_id, module_id FROM (
              SELECT member_id, module_id, valid_end_time, stop_type,
                     ROW_NUMBER() OVER (PARTITION BY member_id, module_id ORDER BY open_time DESC) AS rk
              FROM dwd.dwd_opr_module_open_di WHERE travel_date <= '${{bizdate}}') u
          WHERE rk = 1 AND TO_DATE(valid_end_time) >= {BIZ} AND COALESCE(stop_type, 0) = 0
          UNION ALL
          SELECT c.member_id, d.module_id FROM p_curr c JOIN dim.dim_opr_module_package_df d ON d.package_id = c.package_id) x
    GROUP BY member_id
),
ops AS (   -- 营销 / 运营使用：海报、报表下载、物料扫码（配置 / 操作日志，无业务过程，直接按 ODS）
    SELECT member_id, SUM(poster_qty) AS poster_qty, SUM(download_qty) AS download_qty, SUM(scan_qty) AS scan_qty
    FROM (SELECT member_id, COUNT(1) AS poster_qty, 0 AS download_qty, 0 AS scan_qty FROM ods.ods_mkt_posters_df WHERE {P} GROUP BY member_id
          UNION ALL SELECT fid, 0, SUM(download), 0 FROM ods.ods_opr_excel_task_df WHERE {P} GROUP BY fid
          UNION ALL SELECT sid, 0, 0, SUM(count_num) FROM ods.ods_mkt_material_center_df WHERE {P} GROUP BY sid) o
    GROUP BY member_id
),
fo AS (   -- 首单月：作为供应商第一次有预订的月份（考核窗口 = 首单月起 3 个月）
    SELECT supplier_id AS member_id, TRUNC(TO_DATE(MIN(travel_date), 'yyyyMMdd'), 'MM') AS ws
    FROM dws.dws_ord_scenic_ticket_trade_di WHERE travel_date <= '${{bizdate}}' AND order_order_qty > 0 GROUP BY supplier_id
),
kh AS (
    SELECT fo.member_id, DATE_FORMAT(fo.ws, 'yyyy-MM') AS first_month,
           MAX(nm.qty) AS new_media_qty, MAX(lt.qty) AS land_type_qty, MAX(sc.qty) AS scan_qty, MAX(ms.qty) AS mkt_sms_qty, MAX(sg.qty) AS sign_qty, MAX(dy.qty) AS diy_qty
    FROM fo
    LEFT JOIN (SELECT t.supplier_id, COUNT(DISTINCT t.order_no) AS qty, MIN(f.ws) AS ws_ FROM dwd.dwd_mkt_order_tag_di t JOIN fo f ON f.member_id = t.supplier_id
               WHERE t.marketing_type LIKE 'NEW_MEDIA%' AND TO_DATE(t.order_time) >= f.ws AND TO_DATE(t.order_time) < ADD_MONTHS(f.ws, 3) GROUP BY t.supplier_id) nm
           ON nm.supplier_id = fo.member_id
    LEFT JOIN (SELECT s.supplier_id, COUNT(DISTINCT s.scenic_type_code) AS qty FROM dim.dim_prd_scenic_df s JOIN fo f ON f.member_id = s.supplier_id
               WHERE TO_DATE(s.create_time) >= f.ws AND TO_DATE(s.create_time) < ADD_MONTHS(f.ws, 3) GROUP BY s.supplier_id) lt ON lt.supplier_id = fo.member_id
    LEFT JOIN (SELECT m.sid, SUM(m.count_num) AS qty FROM ods.ods_mkt_material_center_df m JOIN fo f ON f.member_id = m.sid
               WHERE m.{P} AND TO_DATE(FROM_UNIXTIME(m.create_time)) >= f.ws AND TO_DATE(FROM_UNIXTIME(m.create_time)) < ADD_MONTHS(f.ws, 3) GROUP BY m.sid) sc ON sc.sid = fo.member_id
    LEFT JOIN (SELECT k.supplier_id, COUNT(1) AS qty FROM dwd.dwd_mkt_sms_task_di k JOIN fo f ON f.member_id = k.supplier_id
               WHERE TO_DATE(k.create_time) >= f.ws AND TO_DATE(k.create_time) < ADD_MONTHS(f.ws, 3) GROUP BY k.supplier_id) ms ON ms.supplier_id = fo.member_id
    LEFT JOIN (SELECT a.member_id, COUNT(1) AS qty FROM ods.ods_opr_sms_sign_apply_df a JOIN fo f ON f.member_id = a.member_id
               WHERE a.{P} AND a.state = 2 AND TO_DATE(FROM_UNIXTIME(a.create_time)) >= f.ws AND TO_DATE(FROM_UNIXTIME(a.create_time)) < ADD_MONTHS(f.ws, 3)
               GROUP BY a.member_id) sg ON sg.member_id = fo.member_id
    LEFT JOIN (SELECT a.member_id, COUNT(1) AS qty FROM ods.ods_opr_sms_diy_apply_df a JOIN fo f ON f.member_id = a.member_id
               WHERE a.{P} AND a.state = 2 AND a.use_state = 1 AND a.is_delete = 0
                 AND TO_DATE(FROM_UNIXTIME(a.create_time)) >= f.ws AND TO_DATE(FROM_UNIXTIME(a.create_time)) < ADD_MONTHS(f.ws, 3)
               GROUP BY a.member_id) dy ON dy.member_id = fo.member_id
    GROUP BY fo.member_id, fo.ws
),
sm AS (   -- 短信：订单短信条数、营销短信任务数（累计）
    SELECT supplier_id AS member_id, SUM(sms_qty) AS sms_qty, SUM(mkt_task_qty) AS mkt_task_qty
    FROM (SELECT supplier_id, SUM(sms_qty) AS sms_qty, 0 AS mkt_task_qty FROM dwd.dwd_opr_sms_send_di WHERE travel_date <= '${{bizdate}}' GROUP BY supplier_id
          UNION ALL SELECT supplier_id, 0, COUNT(1) FROM dwd.dwd_mkt_sms_task_di WHERE travel_date <= '${{bizdate}}' GROUP BY supplier_id) s
    GROUP BY supplier_id
)
INSERT OVERWRITE TABLE ads.ads_sup_customer_company_df PARTITION (travel_date = '${{bizdate}}')
SELECT /*+ BROADCAST(sg, sv) */
    {SEL},
    {etl_core.NOW}
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
WHERE m.supplier_flag = 1 OR m.distributor_flag = 1                            -- 只要商户（供应商 / 分销商）账号
"""


def register(model):
    """替换模型里的 ads_sup_customer_company_df；旧客户属性表从 CRM 维度移到本表"""
    by = {s['name']: s for s in model.T}
    sp = by['ads_sup_customer_company_df']
    sp.update(grain='1行=1个平台商户账号（统计日快照）',
              up='dim_sup_member_df、dim_sup_company_df、dws_ord_scenic_ticket_trade_di、dwd_mkt_order_tag_di、ods_opr_sms_sign_apply_df、ods_opr_sms_diy_apply_df、dim_sup_member_relation_zip、dim_prd_ticket_df、dim_prd_scenic_df、dim_prd_resource_df、dim_opr_module_package_df、'
                 'dwd_opr_package_open_di、dwd_opr_module_open_di、dwd_sup_member_login_di、dwd_opr_sms_send_di、dwd_mkt_sms_task_di、'
                 'ods_trf_con_sys_member_df、ods_trf_con_sys_df、ods_mkt_posters_df、ods_opr_excel_task_df、ods_mkt_material_center_df',
              cn='客户公司属性（财务部客户属性宽表）',
              note='财务部 / IT 使用的商户客户属性宽表：账号与客户基础、合作伙伴、产品、套餐（首次 / 当前 / 上次 / 下次 / 最终）、登录频次、110 个应用开通标志、营销运营使用；'
                   '列名沿用旧表供下游直接使用；旧预留列改为有含义的名字，恒空 / 恒 0 列去掉',
              fields=[(n, ty, '粒度键' if cat == '粒度键' else ('指标' if cat == '度量' else cat), cm) for n, ty, cat, cm, _ in COLS],
              legacy=sp['legacy'] + ['dim_cus_company_d_f', 'dws_cus_company_login_d_f', 'dws_cus_company_prod_d_f', 'dws_company_package_it_d_f'])
    dim = by.get('dim_sup_company_df')
    if dim:
        dim['legacy'] = [x for x in dim['legacy'] if x != 'dim_cus_company_d_f']
