"""业务域 × 数据域 × 业务过程：按「业务实际在用」的数据倒推最细粒度模型。

- 数据域：与 PFT3.0 一致的 9 个前缀（表名里的业务域段），回答「是什么数据」
- 业务域：业务板块，回答「给哪块业务用」（同一张事实表可服务多个业务域）
- 业务过程：数据域下不可再拆的业务动作，一个业务过程 = 一张 DWD 原子事实表（粒度 = 业务库一行事件）
消费清单（导出回流 + 末端 ADS）沿血缘追到业务库源表，再由源表落到业务过程，据此检查每个在用指标都有最细粒度的事实表承接。
"""

# 业务域（业务板块）
BIZ = [
    ('B1', '票务分销', '门票 / 套票的下单、支付、分销链、游客、核销、取消退款——平台核心交易'),
    ('B2', '园区业态', '业态通：出入园、停车、二消零售、酒店、年卡、园区一卡通'),
    ('B3', '资源中心', '资源采购、推荐、业务员与资源变更、资源中心订单'),
    ('B4', '渠道对接', 'OTA / API 对接订单、全民分销、对接系统、码商、分销分组'),
    ('B5', 'SaaS 服务', '应用模块 / 套餐开通、短信、数据中心与大屏授权、异步报表'),
    ('B6', '营销', '抢购、拼团、砍价、优惠券、营销短信、海报物料'),
    ('B7', '财务结算', '账户交易流水、卡消费流水、开票、收款方式'),
    ('B8', '客户经营', '商户 / 供应商、CRM 客户与合同订单、拜访、认证、员工（平台内部）'),
    ('B0', '公共', '地区、证件 / 手机号归属、码表、日期等跨业务共用'),
]
BIZ_CN = {k: n for k, n, _ in BIZ}
DATA_DOM = {'ord': '交易', 'trf': '流量渠道', 'prd': '商品', 'inv': '库存', 'cus': '用户', 'sup': '商户', 'fin': '财务', 'opr': '运营', 'mkt': '营销'}

# 一致性维度（总线矩阵列）
DIMS = ['日期', '景区', '产品 / 门票', '供应商', '分销商', '游客', '下单渠道', '支付方式', '地区', '闸机 / 终端', '员工', '资源', '门店 / 商品', '账户', '活动', '应用模块']

# 业务过程：(编码, 业务域, 数据域, 名称, 粒度, 标准 DWD, ODS 来源, 关键度量, 一致性维度, 新增?)
PROC = [
    ('P01', 'B1', 'ord', '下单', '1行=1张子订单', 'dwd_ord_order_di',
     ['ods_ord_order_di', 'ods_ord_order_addon_di', 'ods_ord_order_apply_di', 'ods_ord_order_ticket_taker_di', 'ods_ord_external_code_order_df'],
     '下单票数、下单金额、成本、利润', ['日期', '景区', '产品 / 门票', '供应商', '分销商', '下单渠道', '支付方式', '地区'], False),
    ('P02', 'B1', 'ord', '订单状态流转', '1行=1次订单操作（支付 / 修改 / 取消 / 撤销 / 完结 / 取票 / 售后）', 'dwd_ord_order_track_di',
     ['ods_ord_order_track_di', 'ods_ord_order_terminal_change_di'], '支付、取消、撤销、完结、取票、售后的票数与金额', ['日期', '景区', '产品 / 门票', '供应商', '分销商', '下单渠道', '支付方式', '员工'], False),
    ('P03', 'B1', 'ord', '分销链买卖', '1行=1张订单×1级分销（买入方 / 卖出方）', 'dwd_ord_order_distribution_di',
     ['ods_ord_order_distribution_split_di', 'ods_ord_order_distribution_detail_di'], '各级买入价、卖出价、收入、支出、折扣、手续费', ['日期', '产品 / 门票', '供应商', '分销商', '支付方式'], False),
    ('P04', 'B1', 'ord', '订单游客', '1行=1张订单×1位实名游客', 'dwd_ord_traveler_di',
     ['ods_ord_order_traveler_di', 'ods_ord_order_traveler_ext_di', 'ods_ord_order_traveler_track_di'], '游客人数（客源地、性别、年龄）', ['日期', '景区', '产品 / 门票', '游客', '地区'], False),
    ('P05', 'B1', 'ord', '核销验证', '1行=1次验证（含年卡核销）', 'dwd_ord_verify_di',
     ['ods_ord_order_track_di', 'ods_ord_order_traveler_track_di'], '验证票数、人次、金额', ['日期', '景区', '产品 / 门票', '供应商', '分销商', '游客', '闸机 / 终端', '员工'], False),
    ('P06', 'B1', 'ord', '团队订单', '1行=1张团队单（当日最新状态）', 'dwd_ord_team_order_df',
     ['ods_ord_team_order_df', 'ods_ord_team_order_link_df'], '团队单数、团队人数（团散拆分）', ['日期', '景区', '供应商', '分销商', '员工'], True),
    ('P07', 'B2', 'ord', '年卡交易', '1行=1笔年卡交易（售卡 / 续费 / 补卡 / 激活 / 取消）', 'dwd_ord_annual_card_trade_di',
     ['ods_ord_annual_card_trade_di', 'ods_ord_annual_card_order_di', 'ods_ord_annual_card_renew_di', 'ods_ord_annual_card_active_apply_df'], '售卡、续费、激活张数与金额', ['日期', '景区', '产品 / 门票', '供应商', '游客'], False),
    ('P08', 'B2', 'ord', '园区一卡通消费', '1行=1笔一卡通交易（购卡 / 卡操作 / 消费 / 退款）', 'dwd_ord_allinone_card_trade_di',
     ['ods_ord_allinone_card_trades_di', 'ods_fin_card_order_journal_di', 'ods_fin_card_order_refund_journal_di', 'ods_ord_park_card_order_df'],
     '各交易类型（替代 operation1~10 透视列）笔数、金额、本金、奖励金', ['日期', '景区', '门店 / 商品', '账户', '下单渠道'], True),
    ('P09', 'B2', 'trf', '闸机出入园', '1行=1次过闸', 'dwd_trf_scenic_inout_di',
     ['ods_trf_device_inout_journal_di'], '入园 / 出园 / 在园人次（分钟 / 小时 / 日）', ['日期', '景区', '闸机 / 终端'], False),
    ('P10', 'B2', 'opr', '停车出入场', '1行=1次车辆出入场', 'dwd_opr_parking_record_di',
     ['ods_opr_parking_*'], '入场 / 出场 / 在场车次、停车时长、停车费', ['日期', '景区'], False),
    ('P11', 'B2', 'opr', '二消零售', '1行=1个零售订单商品行（含退货）', 'dwd_opr_retail_order_di',
     ['ods_opr_retail_yinbao_ticket_di', 'ods_opr_retail_sixun_order_di', 'ods_opr_retail_xisland_order_di', 'ods_opr_retail_yinbao_ticket_item_di',
      'ods_opr_retail_sixun_order_sale_detail_di', 'ods_opr_retail_xisland_order_item_di', 'ods_opr_retail_xisland_refund_order_di', 'ods_opr_retail_xisland_refund_order_item_di'], '销售额、销量、实付、优惠、退款', ['日期', '景区', '门店 / 商品', '支付方式'], False),
    ('P12', 'B2', 'opr', '酒店订单', '1行=1张酒店订单（当日最新状态）', 'dwd_opr_hotel_order_df',
     ['ods_opr_hotel_lvyun_hotel_master_df'], '预订 / 取消 / 入住的单数、间夜、人数、金额', ['日期', '景区'], True),
    ('P13', 'B3', 'prd', '资源采购', '1行=1次资源采购操作（含失败）', 'dwd_prd_resource_purchase_di',
     ['ods_prd_resource_purchase_recode_list_df'], '采购次数、采购商户数', ['日期', '资源', '供应商', '分销商'], True),
    ('P14', 'B3', 'prd', '资源中心订单', '1行=1张经资源中心采购商品产生的订单', 'dwd_prd_resource_order_di',
     ['ods_prd_resource_purchase_df'], '资源订单数、订单金额', ['日期', '资源', '供应商', '分销商'], False),
    ('P15', 'B3', 'prd', '资源变更与业务员操作', '1行=1条资源变更 / 业务员 / 金额操作记录', 'dwd_prd_resource_operation_di',
     ['ods_prd_resource_product_record_df', 'ods_prd_resource_salesman_log_df', 'ods_prd_resource_amount_operation_track_df'], '变更次数、业务员归属变化、金额操作', ['日期', '资源', '员工'], True),
    ('P16', 'B4', 'trf', 'OTA / API 对接订单', '1行=1张对接订单（含报文交互）', 'dwd_trf_api_order_di',
     ['ods_trf_all_api_order_di', 'ods_trf_api_order_track_di'], '对接订单数、对接失败数（按 OTA 平台）', ['日期', '产品 / 门票', '分销商', '下单渠道'], True),
    ('P17', 'B4', 'trf', '全民分销推广订单', '1行=1张推广 / 分销订单（当日最新状态）', 'dwd_trf_promoter_order_df',
     ['ods_trf_all_dis_orders_df', 'ods_trf_distribute_order_df'], '推广订单数、推广金额、佣金', ['日期', '产品 / 门票', '分销商'], True),
    ('P18', 'B5', 'opr', '应用模块开通', '1行=1次模块 / 套餐开通或续费', 'dwd_opr_module_open_di',
     ['ods_opr_module_used_df', 'ods_opr_module_used_ext_df', 'ods_opr_module_package_log_df', 'ods_opr_module_package_log_ext_df', 'ods_opr_module_used_log_df', 'ods_opr_package_history_df'], '开通数、续费数、套餐金额', ['日期', '供应商', '应用模块'], False),
    ('P19', 'B5', 'opr', '短信发送', '1行=1条订单短信', 'dwd_opr_sms_send_di',
     ['ods_opr_sms_journal_di'], '短信条数、计费条数', ['日期', '供应商', '产品 / 门票'], True),
    ('P20', 'B8', 'sup', '商户登录', '1行=1次登录', 'dwd_sup_member_login_di', ['ods_sup_member_login_log_di'], '登录商户数（去重）', ['日期', '供应商', '员工'], False),
    ('P21', 'B8', 'sup', 'CRM 销售订单', '1行=1张 CRM 销售订单（当日最新状态）', 'dwd_sup_crm_sales_order_df',
     ['ods_sup_crm_sales_order_df'], '销售金额、已回款、已开票、退款（CRM 侧）', ['日期', '供应商', '员工'], True),
    ('P22', 'B8', 'sup', '客户拜访', '1行=1次客户拜访或接待', 'dwd_sup_customer_visit_di', ['ods_sup_oa_customer_visit_ledger_df'], '拜访次数', ['日期', '供应商', '员工'], False),
    ('P23', 'B7', 'fin', '账户交易流水', '1行=1笔账户流水', 'dwd_fin_trade_journal_di', ['ods_fin_trade_journal_di'], '收入、支出、冻结 / 可用收支', ['日期', '供应商', '账户'], False),
    ('P24', 'B7', 'fin', '开票', '1行=1次开票申请', 'dwd_fin_invoice_di', ['ods_fin_invoice_records_df'], '开票次数、红冲次数（金额待确认）', ['日期', '供应商'], True),
    ('P25', 'B6', 'mkt', '优惠券使用', '1行=1次用券', 'dwd_mkt_coupon_use_di', ['ods_mkt_coupon_use_log_df'], '用券次数、抵扣金额', ['日期', '供应商', '游客', '活动'], True),
    ('P26', 'B6', 'mkt', '抢购参与', '1行=1次抢购参与', 'dwd_mkt_seckill_di', ['ods_mkt_seckill_log_df'], '参与人次、成交单数、成交金额', ['日期', '供应商', '产品 / 门票', '活动'], True),
    ('P27', 'B6', 'mkt', '拼团订单', '1行=1张拼团订单', 'dwd_mkt_group_booking_di', ['ods_mkt_group_booking_orders_df'], '拼团订单数（成团看开团表）', ['日期', '供应商', '产品 / 门票', '活动'], True),
    ('P28', 'B6', 'mkt', '砍价参与', '1行=1次砍价发起', 'dwd_mkt_cut_price_di', ['ods_mkt_cut_price_join_df'], '发起数、砍成数、下单数', ['日期', '供应商', '产品 / 门票', '活动'], True),
    ('P30', 'B3', 'trf', '资源中心页面访问', '1行=1次搜索 / 页面访问', 'dwd_trf_page_view_di', ['ods_prd_resource_search_history_df'], 'PV、UV', ['日期', '资源', '分销商'], False),
    ('P31', 'B8', 'sup', '服务商户签约', '1行=1个服务商户×1个服务项目', 'dwd_sup_service_merchant_di', ['ods_sup_cooperation_other_df'], '服务商户数、签单人员', ['日期', '供应商', '员工'], False),
    ('P29', 'B6', 'mkt', '营销短信任务', '1行=1个营销短信任务', 'dwd_mkt_sms_task_di', ['ods_mkt_marketing_sms_task_df'], '任务数、定时 / 即时任务数', ['日期', '供应商', '活动'], True),
]
NEW_DWD = {p[5] for p in PROC if p[9]}

# 维度来源（不是业务过程）
DIM_SRC = {
    'dim_prd_scenic_df': ['ods_prd_scenic_df', 'ods_prd_management_land_df', 'ods_prd_management_resource_df', 'ods_opr_scenic_supplier_relation_df'],
    'dim_cus_tourist_df': ['ods_cus_tourist_info_df', 'ods_cus_tourist_auth_info_df', 'ods_cus_identity_info_df'],
    'dim_prd_ticket_df': ['ods_prd_ticket_df', 'ods_prd_package_tickets_df'], 'dim_prd_ticket_price_zip': ['ods_prd_ticket_price_df'],
    'dim_prd_resource_df': ['ods_prd_resource_land_attr_df', 'ods_prd_resource_product_df', 'ods_prd_resource_supplier_attr_df', 'ods_prd_resource_user_function_df',
                            'ods_trf_resource_recommend_config_df', 'ods_trf_resource_recommend_land_df', 'ods_prd_resource_land_df'],
    'dim_sup_member_df': ['ods_sup_member_df', 'ods_sup_member_ext_df', 'ods_sup_customer_certification_df', 'ods_sup_member_authorize_df', 'ods_sup_user_info_df',
                          'ods_sup_user_auth_info_df', 'ods_sup_member_product_config_df', 'ods_sup_special_user_config_df', 'ods_sup_member_access_account_df',
                          'ods_opr_datav_auth_df', 'ods_opr_resource_center_auto_get_user_df', 'ods_opr_sms_diy_apply_df', 'ods_opr_sms_sign_apply_df'],
    'dim_sup_supplier_df': ['ods_sup_supplier_extinfo_df'], 'dim_sup_member_relation_zip': ['ods_sup_member_relation_df', 'ods_trf_evolute_group_df', 'ods_trf_evolute_group_fid_df', 'ods_trf_evolute_group_speciality_di', 'ods_trf_all_dis_recommend_df'],
    'dim_sup_company_df': ['ods_sup_crm_account_df', 'ods_opr_crm_home_area_df'], 'dim_sup_staff_df': ['ods_sup_staff_df', 'ods_opr_staff_group_df'],
    'dim_trf_channel_f': ['ods_opr_channel_df', 'ods_opr_distribute_system_type_df', 'ods_opr_third_purchase_system_df', 'ods_trf_con_sys_df', 'ods_trf_con_sys_member_df', 'ods_trf_tb_bind_df', 'ods_trf_qunar_verify_df'],
    'dim_fin_pay_channel_f': ['ods_fin_merchant_payment_method_df'], 'dwd_fin_trade_journal_di（科目属性）': ['ods_fin_account_book_subject_df'],
    'dwd_opr_retail_order_di（门店属性）': ['ods_opr_retail_sixun_shop_df'],
    'dim_opr_region_f': ['ods_opr_region_area_df', 'ods_opr_country_region_df', 'ods_opr_city_df', 'ods_opr_province_df', 'ods_opr_resource_center_district_df'],
    'dim_opr_phone_area_f': ['ods_opr_global_phone_area_df', 'ods_opr_city_phone_df'], 'dim_opr_idcard_area_f': ['ods_opr_identity_area_code_df', 'ods_opr_idcard_city_df'],
    'dim_opr_module_package_df': ['ods_opr_module_df', 'ods_opr_module_package_df', 'ods_opr_module_package_classify_df', 'ods_opr_module_package_detail_df', 'ods_opr_module_price_df',
                                  'ods_opr_package_open_type_df', 'ods_opr_package_product_config_df'],
    'dim_opr_dict_f': ['ods_opr_common_dict_df', 'ods_opr_order_status_df', 'ods_opr_land_topic_df', 'ods_opr_resource_type_df', 'ods_opr_user_short_name_df'],
    'dim_mkt_activity_df': ['ods_mkt_seckill_v2_df', 'ods_mkt_posters_df', 'ods_mkt_material_center_df', 'ods_mkt_group_booking_df', 'ods_mkt_cut_price_df',
                            'ods_mkt_group_booking_open_df', 'ods_mkt_group_booking_collect_df', 'ods_mkt_cut_price_help_df'],
}
# 业务库里已经预聚合好的报表表：最细模型从明细重算，这些只保留 ODS 供上线对数
PRECALC = ('ods_ord_report_', 'ods_ord_terminal_branch_summary', 'ods_ord_dc_daycount', 'ods_trf_scenic_inout_hour_summary', 'ods_ord_r_report_dwm_common', 'ods_ord_scenic_daily_count')
EXTERNAL = ('ods_cus_scenic_customer_insight_', 'ods_trf_ota_ctrip_')
PROJECT = ('ods_opr_sbs_', 'ods_opr_culture_tourism_task_input')         # 客户大屏专项（渡江战役 / 文旅填报）：项目专用，原样服务
LOGS = ('ods_opr_excel_task',)                                           # 平台运营日志：ODS 直接服务
# 未被在用链路使用的 ODS：按类别说明为何暂不建模（保留同步，需求来了按业务过程补 DWD）
IDLE = [('ods_fin_account_exclusive_', '财务专项账户（预存短信 / 电子凭证费）'), ('ods_fin_exclusive_account_', '财务专项账户（预存短信 / 电子凭证费）'),
        ('ods_fin_deposite_config', '财务专项账户（预存短信 / 电子凭证费）'), ('ods_fin_account_template_item', '财务专项账户（预存短信 / 电子凭证费）'),
        ('ods_fin_account_book_platform_in', '平台内账本'), ('ods_fin_auto_withdraw_setting', '提现 / 清分配置'), ('ods_fin_withdraw', '提现流水'),
        ('ods_fin_merchant_alipay', '支付服务商配置'), ('ods_fin_merchant_wepay', '支付服务商配置'), ('ods_fin_rebate', '返利活动'),
        ('ods_ord_annual_', '年卡配置 / 任务 / 特权'), ('ods_ord_mall_order_record', '微商城订单流水'), ('ods_sup_authority_role_', '权限角色配置'),
        ('ods_trf_api_doudian_token', '对接授权令牌（敏感）'), ('ods_trf_api_kuaishou_', '对接授权令牌（敏感）'), ('ods_trf_wx_', '微信公众号 / 注册分销商'),
        ('ods_trf_all_dis_df', '全民分销配置'), ('ods_trf_price_group', '价格组配置'), ('ods_trf_resource_', '资源中心推荐 / 禁售配置'),
        ('ods_prd_special_ticket', '特殊票属性'), ('ods_opr_', '平台码表 / 填报 / 备份')]


def role_of(ods, used=None, ups=None):
    """ODS → (角色, 去向)；used：被在用链路使用次数；ups：ODS → 使用它的标准表"""
    for p in PROC:
        for s in p[6]:
            if s == ods or (s.endswith('*') and ods.startswith(s[:-1])):
                return '业务过程', f'{p[0]} {p[3]} → {p[5]}'
    for d, ss in DIM_SRC.items():
        if ods in ss:
            return '维度', d
    if ods.startswith(PRECALC):
        return '报表库预计算', '从明细重算，ODS 仅供对数'
    if ods.startswith(EXTERNAL):
        return '外部数据', '原样进 ADS'
    if ods.startswith(PROJECT):
        return '项目专用', '客户大屏专项，原样服务（不进公共模型）'
    if ods.startswith(LOGS):
        return '运营日志', 'ODS 直接服务（异步报表任务）'
    if ups and ups.get(ods):
        return '属性关联', '、'.join(sorted(ups[ods]))
    if used == 0:
        why = next((w for p_, w in IDLE if ods.startswith(p_)), '')
        return '未在用', f'保留 ODS 同步，暂不建模{"（" + why + "）" if why else ""}'
    return '', ''


# ============================================================================ 消费清单 / 业务过程 / ODS 去向（build.py 调用）
DOM_BIZ = {'ord': 'B1', 'trf': 'B4', 'prd': 'B3', 'inv': 'B1', 'cus': 'B1', 'sup': 'B8', 'fin': 'B7', 'opr': 'B2', 'mkt': 'B6'}


def _sh(t):
    return str(t).lower().split('.')[-1]


def _ups(tables, _c={}):
    import re
    k = id(tables)
    if k not in _c:
        u = {}
        for t in tables:
            if t['layer'] != 'ODS':
                for x in re.split('、', t['up'] or ''):
                    u.setdefault(x.strip(), set()).add(t['name'])
        _c[k] = u
    return _c[k]


def consumption(nodes, C, mrows, ods_of_source, tables, cover=()):
    """在用的数据 = 导出回流（hive → 外部库）+ 末端 ADS（无下游、无导出，BI 直读）；沿血缘追到业务库源表 → ODS → 业务过程"""
    import collections, re
    T, S = C['tables'], C['sources']
    std = {t['name']: t for t in tables}
    std_of = {}
    for r in mrows:
        std_of.setdefault(str(r[0]).lower(), r[5])
        std_of.setdefault(_sh(r[0]), r[5])
    src_of_landing = collections.defaultdict(set)
    for k, s in S.items():
        for l in s['landing']:
            src_of_landing[l].add(k)
    memo = {}

    def down(t, seen=frozenset()):
        t = _sh(t)
        if t in memo:
            return memo[t]
        if t in seen or len(seen) > 25:
            return set()
        out = set(src_of_landing.get(t, set()))
        for w in T.get(t, {}).get('writers', []):
            if w['type'] != 'DI':
                for r in w['reads']:
                    out |= down(r, seen | {t})
        memo[t] = out
        return out
    layer = lambda t: (re.match(r'(ods|dwd|dws|dim|ads|dm|tmp|app)_', t) or [None, '其他'])[1].upper()
    items = []
    for n in nodes:
        di = n.get('di') or {}
        r, w = di.get('reader') or {}, di.get('writer') or {}
        if n['type'] == 'DI' and r.get('type') == 'hive' and w.get('type') not in ('hive', None) and r.get('tables'):
            tgt = f"{w.get('datasource')}.{_sh(w['tables'][0]) if w.get('tables') else ''}"
            items.append(('导出回流', n['path'], _sh(r['tables'][0]), f"{w.get('type')}:{tgt}", n.get('cron') or '', std_of.get(tgt.lower()) or std_of.get(_sh(r['tables'][0]), '')))
    read_by = collections.Counter(_sh(r) for n in nodes for r in n['reads'])
    exported = {x[2] for x in items}
    for t, x in sorted(T.items()):
        if x['kind'] == 'hive' and x['writers'] and t not in exported and not read_by.get(t) and layer(t) in ('ADS', 'DM', 'APP'):
            w0 = x['writers'][0]
            items.append(('末端 ADS（BI 直读）', w0['path'], t, 'Hive 直读', w0.get('cron') or '', std_of.get(t, '')))
    # 标准表 → 其上游链路里的 DWD（业务过程）
    def std_up(name, seen=frozenset()):
        if name in seen or name not in std:
            return set()
        ups = {u.strip() for u in re.split('、', std[name]['up'] or '') if u.strip()}
        out = {name} | ups
        for u in ups:
            out |= std_up(u, seen | {name})
        return out
    proc_of_dwd = {p[5]: p for p in PROC}
    fc = collections.defaultdict(collections.Counter)      # 导出目标 → 字段覆盖
    for r in cover:
        fc[str(r[0]).lower()]['总' ] += 1
        fc[str(r[0]).lower()]['未对' if r[7] in ('—', '', None) else '已对'] += 1
    rows, used_ods = [], collections.Counter()
    for kind, path, hive, tgt, cron, st in items:
        odss = sorted({ods_of_source[k] for k in down(hive) if k in ods_of_source})
        for o in odss:
            used_ods[o] += 1
        roles = {o: role_of(o, ups=_ups(tables)) for o in odss}
        procs = sorted({v[1].split(' ')[0] for v in roles.values() if v[0] == '业务过程'})
        chain = std_up(st) if st else set()
        std_procs = sorted({proc_of_dwd[d][0] for d in chain if d in proc_of_dwd})
        procs_all = sorted(set(procs) | set(std_procs))
        pinfo = [p for p in PROC if p[0] in (std_procs or procs)]     # 以标准链路为准；旧链路另读的业务过程单列
        biz = collections.Counter(p[1] for p in pinfo).most_common()
        dd = (re.match(r'(?:ods|dim|dwd|dws|ads)_([a-z]+)_', st or '') or [None, ''])[1]
        bz = [b for b, _ in biz] or ([DOM_BIZ[dd]] if dd in DOM_BIZ else [])
        unk = [o for o, v in roles.items() if not v[0]]
        lost = [p for p in procs if p not in std_procs]
        f = fc.get(tgt.split(':', 1)[-1].lower(), collections.Counter())
        if not st:
            verdict = '未映射到标准表'
        elif unk:
            verdict = f'已承接；源表未归类 {len(unk)} 张'
        elif kind != '导出回流':
            verdict = '已承接到标准表（BI 直读，字段未逐一核对）'
        elif f['未对']:
            verdict = f"已承接到标准表；{f['未对']} 个字段待按业务过程明细补口径"
        else:
            verdict = '已承接（字段逐一对到标准口径）'
        rows.append([kind, path, hive, layer(hive), tgt, cron, st, '、'.join(f'{b} {BIZ_CN[b]}' for b in bz),
                     DATA_DOM.get(dd, ''), '、'.join(f"{p[0]} {p[3]}" for p in pinfo), len(odss), '、'.join(unk),
                     f['总'] or '', f['已对'] or '', f['未对'] or '', '、'.join(lost), verdict])
    cols = ['消费方式', '旧节点', '旧 Hive 表', '旧分层', '目标（库.表）', '调度', '标准表', '业务域', '数据域', '涉及业务过程', '业务库源表（ODS）数', '未归类 ODS',
            '导出字段数', '已对到标准口径', '待补口径字段', '旧链路另读的业务过程（标准链路未用，多为关联属性 / 过滤）', '覆盖结论']
    return {'cols': cols, 'rows': rows}, used_ods


def process_rows(tables, used_ods, cons_rows):
    import collections, re
    std = {t['name'] for t in tables}
    down = collections.defaultdict(set)
    for t in tables:
        for u in re.split('、', t['up'] or ''):
            if u.strip() in std:
                down[u.strip()].add(t['name'])

    def closure(n, seen=frozenset()):
        out = set()
        for d in down.get(n, ()):
            if d not in seen:
                out |= {d} | closure(d, seen | {n})
        return out
    nuse = collections.Counter(x.split(' ')[0] for r in cons_rows for x in str(r[9]).split('、') if x)
    rows, mat = [], []
    for p in PROC:
        code, b, dd, cn, grain, dwd, srcs, meas, dims_, new = p
        ds = sorted(x for x in closure(dwd) if x.startswith(('dws_', 'ads_')))
        rows.append([code, f'{b} {BIZ_CN[b]}', f'{dd} {DATA_DOM[dd]}', cn, grain, dwd, '新增' if new else '已有', '是' if dwd in std else '否',
                     '、'.join(srcs), meas, '、'.join(dims_), '、'.join(ds) or '（明细直接服务 / 待按需汇总）', nuse.get(code, 0)])
        mat.append([code, f'{b} {BIZ_CN[b]}', cn, dwd] + ['✓' if d in dims_ else '' for d in DIMS])
    pc = {'cols': ['编码', '业务域', '数据域', '业务过程', '粒度', '标准 DWD（原子事实表）', '状态', '已生成', 'ODS 来源', '关键度量', '一致性维度', '下游 DWS / ADS', '在用消费数'], 'rows': rows}
    bm = {'cols': ['编码', '业务域', '业务过程', '事实表'] + DIMS, 'rows': mat}
    return pc, bm


def ods_rows(tables, used_ods):
    rows = []
    for t in tables:
        if t['layer'] != 'ODS':
            continue
        r, to = role_of(t['name'], used_ods.get(t['name'], 0), _ups(tables))
        dd = (t['name'].split('_') + ['', ''])[1]
        rows.append([t['name'], t['cn'], f"{dd} {DATA_DOM.get(dd, '')}", r or '未归类', to, used_ods.get(t['name'], 0), '在用' if used_ods.get(t['name']) else '未被在用链路使用'])
    return {'cols': ['ODS 表', '中文名', '数据域', '角色', '去向（业务过程 / 维度）', '在用消费链路数', '是否在用'], 'rows': rows}
