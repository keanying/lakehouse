"""标准化规则：业务源表 → 业务域 / ODS 表名；旧字段名 → 标准字段名。依据 docs/规范/数仓命名规范.md 与 PFT3.0 的做法。"""
import re

# ---------------------------------------------------------------- 业务域（9 个，规范固定）
DOMAINS = {'ord': '订单、预订（订单 / 票 / 游客 / 核销 / 年卡 / 一卡通）', 'fin': '财务、结算（账户 / 交易流水 / 提现 / 发票 / 收款配置）',
           'prd': '产品（景区 / 门票 / 价格 / 资源中心产品）', 'cus': '用户、游客（游客身份 / 实名 / 客群洞察）',
           'sup': '供应商（商户 / 分销商 / 员工 / 权限 / CRM 客户 / 合同）', 'trf': '流量、渠道（分销 / OTA / 开放平台 / 出入园客流）',
           'opr': '运营（应用模块 / 短信 / 业态：停车·零售·酒店 / 公共码表 / 内部管理）', 'mkt': '营销、活动（优惠券 / 秒杀 / 拼团 / 砍价 / 营销短信 / 舆情）',
           'inv': '库存（本系统无独立库存表）'}

# 业务源库：数据源名 → (库说明, 默认业务域)；同一个库的多个数据源名（BI_ 前缀）合并
SOURCE_DB = {
    'POLAR_myuu': ('票务核心库 myuu', None), 'history_': ('票务核心库历史分表 history_YYYYMM', 'ord'),
    'ECS_pft_business_case': ('年卡 / 一卡通业务库', 'ord'), 'ecs_pft001': ('平台业务库 pft001（模块套餐 / 发票 / 收款 / 员工）', 'opr'),
    'ecs_pft002': ('微商城营销库 pft002', 'mkt'), 'RDS_pft_open_cooperate': ('业态通对接库（停车 / 零售 / 酒店）', 'opr'),
    'BI_RDS_pft_open_cooperate': ('业态通对接库（停车 / 零售 / 酒店）', 'opr'), 'POLAR_rcenter': ('资源中心库', 'prd'),
    'RDS_summary': ('报表汇总库 summary', 'ord'), 'BI_RDS_summary': ('报表汇总库 summary', 'ord'), 'history_summary_history': ('报表汇总库历史年表', 'ord'),
    'pft_open': ('开放平台库', 'trf'), 'RDS_oa_ecology': ('OA 泛微库', 'opr'), 'BI_RDS_oa_ecology': ('OA 泛微库', 'opr'),
    'RDS_crm_erp': ('CRM 库', 'sup'), 'RDS_BI_Business': ('BI 业务配置库', 'opr'), 'BI_RDS_bi_datav': ('BI 大屏库 bi_datav', 'opr'),
    'RDS_pft_ai': ('AI 分析结果库', 'cus'), 'POLAR_base_server': ('基础服务库（地区 / 号段 / 证件地区）', 'opr'),
    'rds_distri_center': ('分销中心库', 'trf'), 'POLAR_auth_center': ('实名认证库', 'cus'), 'vscreen_data_middle_bi_batch': ('大屏项目库', 'opr'),
    'RDS_open_data_api': ('数据开放接口库', 'trf'), 'ECS_summary_eco_mms': ('分销汇总库', 'trf'), 'pterminalmanager_data_middle_bi_batch': ('终端管理库', 'trf'),
    'RDS_data_center': ('数据中心库', 'sup'), 'pft_logging': ('日志库', 'sup'), 'POLAR_platform': ('平台库', 'ord'),
    'RDS_selectdb_report': ('SelectDB 报表库', 'ord'), 'RDS_it_project': ('IT 项目库', 'opr'),
}

# 源表名 → 业务域（优先于库的默认域）
TABLE_DOMAIN = [
    (r'^(uu_ss_order|uu_order_|order_aids_split|order_user_info|pft_order_|uu_order_fx_details|uu_ss_order_team|uu_order_terminal_change|pft_report_(order|checked)|pft_dc_daycount|r_report_dwm)', 'ord'),
    (r'^(uu_land|uu_jq_ticket|uu_product_price|pft_package_tickets|pft_special_ticket|pft_management_(land|resource))', 'prd'),
    (r'^(pft_member|pft_supplier_extinfo|pft_customer_certification|user_auth_info|user_info|pft_special_user_config|pft_staff|pft_authority_|pft_member_access|pft_cooperation_other|pft_crm_|c_member_authorize|pft_login_log|cus_fielddata|project_contract|uf_)', 'sup'),
    (r'^(pft_account_|pft_trade_journal|pft_wd_cash|pft_auto_withdraw|deposite_config|exclusive_account_|pft_invoice|pft_merchant_|pft_rebate|pft_card_order_(refund_)?journal)', 'fin'),
    (r'^(pft_sms_|pft_common_dict|excel_task|pft_module|pft_package_product|hrm|kq_|formtable_main|datav_|dim_|sbs_|company_report_date|quarter_first_date|package_|third_purchase|culture_tourism|resource_center_|country_region|global_phone|identity_area|region_area)', 'opr'),
    (r'^(parking_|retail_|hotel_)', 'opr'),
    (r'^(pft_annual|pft_allinone|pft_park_card|pft_external_code_order|pft_mall_order)', 'ord'),
    (r'^(pft_all_dis|pft_wx_new_reseller|pft_wx_open|pft_evolute_group|pft_price_group|pft_distribute_order|all_api_order|api_|pft_con_sys|pft_tb_bind|uu_qunar|scenic_inout|pft_device_inout|pft_resource_recommend|pft_resource_ota|ads_sup_ota|ads_trf_social)', 'trf'),
    (r'^(pft_coupon|pft_cut_price|pft_group_booking|pft_seckill|pft_posters|pft_material|pft_marketing_sms|marketing_test)', 'mkt'),
    (r'^(identity_info|tourist_|ads_scenic_customer_insight)', 'cus'),
    (r'^pft_resource_', 'prd'),
]

# 源表名 → 标准实体名（去掉 uu_ / pft_ 前缀；拼音、编号表给出英文名）
ENTITY = {
    'uu_ss_order': 'order', 'uu_ss_order_team': 'team_order', 'uu_ss_order_team_link': 'team_order_link', 'uu_order_addon': 'order_addon',
    'order_aids_split': 'order_distribution_split', 'order_user_info': 'order_ticket_taker', 'pft_order_track': 'order_track',
    'pft_order_tourist_track': 'order_traveler_track', 'uu_order_tourist_info': 'order_traveler', 'uu_order_tourist_info_extend': 'order_traveler_ext',
    'uu_order_apply_info': 'order_apply', 'uu_order_fx_details': 'order_distribution_detail', 'uu_land': 'scenic', 'uu_jq_ticket': 'ticket',
    'uu_product_price': 'ticket_price', 'pft_member': 'member', 'pft_member_extinfo': 'member_ext', 'pft_member_relationship': 'member_relation',
    'pft_trade_journal': 'trade_journal', 'pft_wd_cash': 'withdraw', 'uu_qunar_use': 'qunar_verify', 'uu_order_terminal_change': 'order_terminal_change',
    'pft_report_order_two': 'report_order_summary', 'pft_report_checked_two': 'report_verify_summary', 'pft_report_order_two_hour': 'report_order_summary_hour',
    'pft_report_checked_two_hour': 'report_verify_summary_hour', 'pft_report_terminal_pass': 'report_terminal_pass', 'pft_report_terminal_pass_hour': 'report_terminal_pass_hour',
    'pft_report_annual_card_order': 'report_annual_card_order', 'pft_report_annual_card_checked': 'report_annual_card_verify', 'terminal_branch_summary': 'report_terminal_branch',
    'pft_dc_daycount_info': 'scenic_daily_count', 'pft_dc_daycount_two': 'scenic_daily_count_v2', 'pft_dc_daycount_info_history': 'scenic_daily_count_history',
    'r_report_dwm_common': 'report_dwm_common', 'hrmresource': 'hr_staff', 'hrmdepartment': 'hr_department', 'hrmdepartmentdefined': 'hr_department_ext',
    'hrmcity': 'hr_city', 'hrmprovince': 'hr_province', 'hrmjobtitles': 'hr_job_title', 'hrmeducationlevel': 'hr_education_level',
    'cus_fielddata': 'crm_custom_field', 'project_contract': 'contract', 'pft_crm_account': 'crm_account', 'pft_crm_sales_order': 'crm_sales_order',
    'c_member_authorize': 'member_authorize', 'pft_login_log': 'member_login_log',
}
PINYIN = {'uf_xkhjjdtz': ('oa_customer_visit_ledger', '新客户拜访台账（拼音表名）'), 'uf_httzbd': ('oa_contract_ledger', '合同台账'),
          'uf_cpxxbd': ('oa_product_info_form', '产品信息表单'), 'uf_jxkhd': ('oa_performance_review', '绩效考核单'),
          'uf_xctzbd': ('oa_travel_ledger', '行程台账'), 'uf_yybht': ('oa_reply_contract', '应用补充合同'), 'uf_zwht': ('oa_foreign_contract', '外文合同')}


def domain_of(ds, table):
    for p, d in TABLE_DOMAIN:
        if re.search(p, table):
            return d
    for k, (_, d) in SOURCE_DB.items():
        if ds == k or (k.endswith('_') and str(ds).startswith(k)):
            if d:
                return d
    return 'opr'


def logical_source(ds, table):
    """业务库分表 / 历史库 / BI_ 数据源别名 → 逻辑源 (库, 表)"""
    ds = str(ds)
    t = re.sub(r'_(20\d\d)(_?\d\d)?$', '', table)                          # pft_report_order_two_2022 → pft_report_order_two
    if ds.startswith('history_') and ds != 'history_summary_history':
        ds = 'POLAR_myuu'
    if ds == 'history_summary_history':
        ds = 'RDS_summary'
    ds = {'BI_RDS_pft_open_cooperate': 'RDS_pft_open_cooperate', 'BI_RDS_summary': 'RDS_summary', 'BI_RDS_oa_ecology': 'RDS_oa_ecology'}.get(ds, ds)
    return ds, t


def entity_of(table):
    if table in ENTITY:
        return ENTITY[table]
    if table in PINYIN:
        return PINYIN[table][0]
    m = re.match(r'formtable_main_(\d+)(_dt(\d+))?$', table)
    if m:
        return f'oa_form_{m.group(1)}' + (f'_detail{m.group(3)}' if m.group(2) else '')
    m = re.match(r'kq_(.*)$', table)
    if m:
        return 'hr_attendance_' + m.group(1)
    e = re.sub(r'^(uu_|pft_|t_)', '', table)
    e = re.sub(r'^(ads|dim|dws|dwd)_(sup|trf|prd|cus|opr|ord|mkt|fin)_', '', e)   # AI 库里的结果表
    e = re.sub(r'^(ads|dim)_', '', e)
    return re.sub(r'_(mo|di|df)$', '', e)


# ---------------------------------------------------------------- 字段名标准化
COL = {
    'ordernum': 'order_no', 'orderid': 'order_no', 'order_id': 'order_no', 'main_order_id': 'main_order_no', 'team_order_id': 'team_order_no',
    'remotenum': 'remote_order_no', 'remote_order_id': 'remote_order_no', 'trade_order_id': 'trade_order_no',
    'lid': 'scenic_id', 'land_id': 'scenic_id', 'land_name': 'scenic_name', 'land_type': 'scenic_type', 'land_type_name': 'scenic_type_name',
    'land_province': 'scenic_province_name', 'land_city': 'scenic_city_name', 'land_country': 'scenic_district_name', 'land_topic': 'scenic_topic',
    'land_publisher_id': 'scenic_supplier_id', 'land_publisher_name': 'scenic_supplier_name', 'p_type': 'scenic_type',
    'tid': 'ticket_id', 'main_tid': 'main_ticket_id', 'ticket_fullname': 'ticket_name', 'pid': 'product_id', 'certnum': 'resource_id',
    'aid': 'supplier_id', 'sid': 'supplier_id', 'sup_id': 'supplier_id', 'apply_did': 'origin_supplier_id',
    'member': 'buyer_id', 'fid': 'member_id', 'booker_id': 'buyer_id', 'booker_name': 'buyer_name', 'booker_type': 'buyer_type',
    'salerid': 'seller_id', 'saler_id': 'seller_id', 'reseller_id': 'distributor_id', 'opid': 'operator_id', 'oper_member': 'operator_id', 'operate_id': 'operator_id',
    'tnum': 'ticket_qty', 'ticket_num': 'ticket_qty', 'order_ticket': 'order_ticket_qty', 'tprice': 'ticket_price_amt', 'totalmoney': 'order_amt',
    'ordertime': 'order_time', 'booking_time': 'order_time', 'playtime': 'play_date', 'play_time': 'play_date', 'dtime': 'verify_time',
    'ctime': 'cancel_time', 'begintime': 'valid_start_time', 'endtime': 'valid_end_time', 'begin_time': 'valid_start_time', 'end_time': 'valid_end_time',
    'status': 'order_status', 'paymode': 'pay_mode', 'pay_way': 'pay_mode', 'ordermode': 'order_mode', 'ordername': 'taker_name',
    'ordertel': 'taker_phone', 'contacttel': 'contact_phone', 'personid': 'taker_id_card_no', 'id_card': 'id_card_no', 'idcard': 'id_card_no',
    'code': 'voucher_code', 'verify_code': 'voucher_code', 'visitors': 'visitor_qty', 'onsale': 'discount_type', 'unioncheck': 'withdraw_type',
    'callback': 'callback_flag', 'remsg': 'sms_resend_limit_qty', 'smserror': 'sms_error_code', 'sync_state': 'sync_status',
    'branchterminal': 'branch_terminal_no', 'branch_terminal': 'branch_terminal_no', 'terminal': 'terminal_no', 'stat_date': 'stat_date',
    'province': 'province_name', 'city': 'city_name', 'country': 'district_name', 'district': 'district_name',
    'sale_money': 'sale_amt', 'cost_money': 'cost_amt', 'paid_amount': 'paid_amt', 'payment_money': 'pay_amt', 'order_pay_amount': 'order_pay_amt',
    'order_num': 'order_qty', 'paid_count': 'paid_order_qty', 'verify_num': 'verify_order_qty', 'verify_ticket': 'verify_ticket_qty',
    'cancel_num': 'cancel_order_qty', 'cancel_ticket': 'cancel_ticket_qty', 'revoke_num': 'revoke_order_qty', 'revoke_ticket': 'revoke_ticket_qty',
    'left_num': 'remain_ticket_qty', 'print_num': 'print_ticket_qty', 'total': 'total_qty', 'sex': 'gender', 'requestid': 'oa_request_id',
    'dw_ins_time': 'etl_time', 'inserttime': 'etl_time', 'insert_time': 'etl_time', 'year': 'year_no', 'month': 'month_no', 'week': 'week_no',
}
# 客户确认的核心 ID 含义（权威标注）：旧字段名 → (标准字段名, 中文名, 关联维表)
ID_ANN = {'sid': ('supplier_id', '供应商ID（租户ID）', 'dim_sup_member_df'), 'lid': ('scenic_id', '景区ID', 'dim_prd_scenic_df'),
          'pid': ('product_id', '产品ID', ''), 'tid': ('ticket_id', '票ID', 'dim_prd_ticket_df')}
STD_ANN = {v[0]: (v[1], v[2]) for v in ID_ANN.values()}
# 前缀形式统一说法（同一字段在各表只用一种中文名）
PREFIXED_ANN = {'origin_supplier_id': '原始（顶级）供应商ID（租户ID）', 'scenic_supplier_id': '景区发布供应商ID（租户ID）',
                'resource_center_supplier_id': '资源中心供应商ID（租户ID）', 'mall_supplier_id': '微商城供应商ID（租户ID）',
                'main_ticket_id': '套票主票票ID', 'sub_ticket_id': '套票子票票ID', 'card_product_id': '年卡产品ID', 'resource_scenic_id': '业态景区ID'}


def id_comment(name, old=''):
    """标准字段名的中文名按客户标注统一：supplier_id / scenic_id / product_id / ticket_id 及其前缀形式（main_ / sub_ / origin_ …）"""
    if name in STD_ANN:
        cn, dim = STD_ANN[name]
        return cn + (f'，关联 {dim}' if dim else '')
    if name in PREFIXED_ANN:
        return PREFIXED_ANN[name]
    m = re.fullmatch(r'(\w+?)_(supplier_id|scenic_id|product_id|ticket_id)', name)
    if m and old:
        o = re.sub(r'门票\s*[iI][dD]|票类ID|门票ID', '票ID', old)
        o = re.sub(r'([iI][dD])', 'ID', o)
        if m.group(2) == 'supplier_id' and '租户' not in o and re.search(r'供应商\s*ID', o):
            o = re.sub(r'供应商\s*ID', '供应商ID（租户ID）', o, count=1)
        return o
    return None


SENSITIVE = re.compile(r'(phone|mobile$|tel$|id_card|idcard|personid|id_number|card_no|bank_no|address|passport|email|password|pwd)', re.I)
DROP = re.compile(r'^(password|pwd|passwd|salt|secret)$', re.I)


def std_col(c):
    """旧字段名 → (标准字段名, 是否改名)"""
    c0 = c.lower().strip('`')
    if c0 in ID_ANN:
        return ID_ANN[c0][0], True
    if re.search(r'(^|_)(sid|lid|pid|tid)(_|$)', c0) and c0 not in COL:      # main_tid → main_ticket_id
        n = re.sub(r'(?<![a-z])(sid|lid|pid|tid)(?![a-z])', lambda m: ID_ANN[m.group(1)][0], c0)
        return n, True
    if c0 in COL:
        return COL[c0], COL[c0] != c0
    n = c0
    n = re.sub(r'_(money|amount)$', '_amt', n)
    n = re.sub(r'_(num|count|cnt)$', '_qty', n)
    n = re.sub(r'^(mo|no_mo)_', lambda m: {'mo': 'main_', 'no_mo': 'sub_'}[m.group(1)], n)
    n = re.sub(r'(?<=_)ticket$', 'ticket_qty', n) if re.search(r'^(sub_|main_)?(cancel|verify|finish|revoke|order|print)_ticket$', n) else n
    return n, n != c0


HIVE_TYPE = {'INT': 'BIGINT', 'TINYINT': 'INT', 'SMALLINT': 'INT', 'MEDIUMINT': 'BIGINT', 'VARCHAR': 'STRING', 'CHAR': 'STRING', 'TEXT': 'STRING',
             'DATETIME': 'STRING', 'TIMESTAMP': 'STRING', 'DATE': 'STRING', 'DOUBLE': 'DECIMAL(20,4)', 'FLOAT': 'DECIMAL(20,4)'}


def std_type(t):
    t = (t or 'STRING').upper()
    base = re.sub(r'\(.*$', '', t)
    if base == 'DECIMAL':
        return t
    return HIVE_TYPE.get(base, t if base in ('BIGINT', 'STRING', 'INT', 'DECIMAL', 'BOOLEAN') else 'STRING')
