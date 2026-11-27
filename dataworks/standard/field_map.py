"""旧数仓导出字段 → 标准模型的逐字段对照（补 legacy_metrics 解不出的字段）。

两类：
- 指标：各业务过程的专用字段名（酒店预订 / 入住、一卡通 o{n}c / o{n}a、出入园 in / out、停车、零售、账户收支、团散 …）→ 标准指标 + 维度取值；
- 非指标：时间列 → 统计周期（时间表）；维度 / 属性 / 明细列 → 在导出对应标准表的上游链路（DWS → DWD / DIM）里找到同名（或标准化后同名、别名）字段。
"""
import re

import rules

# 旧字段别名 → 标准字段（明细 / 属性列）
ALIAS = {
    'vertify_time': 'first_verify_time', 'vertify_datetime': 'verify_time', 'vertify_date': 'verify_date', 'booking_channel': 'order_mode', 'booking_date': 'order_time',
    'booking_price': 'sale_price_amt', 'distributor_price': 'sale_price_amt', 'land_publisher_id': 'supplier_id', 'resource_id': 'resource_id', 'user_id': 'member_id',
    'order_id': 'order_no', 'main_order_id': 'main_order_no', 'remote_order_id': 'remote_order_no', 'team_order_id': 'team_order_no', 'order_status_code': 'order_status',
    'order_pay_status': 'pay_status', 'booker_id': 'buyer_id', 'is_team': 'team_flag', 'ticket_taker_sex': 'gender', 'ticket_taker_age': 'age', 'sex': 'gender',
    'ticket_taker_province': 'taker_province_code', 'ticket_taker_city': 'taker_city_code', 'ticket_taker_mobile': 'taker_phone_hash', 'ticket_taker_idcard': 'taker_id_card_hash',
    'con_sys_bind': 'con_sys_bind_id', 'sys_bind_id': 'con_sys_bind_id', 'hotel_name': 'hotel_name', 'operate_id': 'operator_id', 'operator': 'operator_id',
    'sub_sid': 'supplier_id', 'sub_lid': 'scenic_id', 'sub_tid': 'ticket_id', 'sub_pid': 'product_id', 'sub_p_type': 'product_type', 'pack_type': 'order_role',
    'main_tid': 'main_ticket_id', 'main_type': 'order_role', 'pay_way': 'pay_mode', 'channel': 'order_mode', 'level': 'distribution_level',
    'card_lid': 'scenic_id', 'card_pid': 'card_product_id', 'card_tid': 'ticket_id', 'gid': 'gate_group_id', 'node_id': 'terminal_no', 'trade_account_id': 'account_id',
    'account_book_id': 'account_id', 'package_open_id': 'module_id', 'package_no': 'package_id', 'user_account_id': 'account', 'customer_mobile': 'mobile_hash',
    'insertdate': 'stat_date', 'created_at': 'stat_date', 'updated_at': 'update_time', 'update_time': 'update_time', 'dw_ins_time': 'etl_time', 'visit_date': 'stat_date',
    'operation_channel_id': 'aio_channel', 'num_type': 'fellow_group', 'age_id': 'age_group', 'age_describe': 'age_group', 'team_type': 'team_type',
    'pre_booked_days': 'advance_day_qty', 'vertify_code': 'voucher_code', 'distribute_system_type': 'distribute_system_code', 'use_coupon': 'use_coupon_flag',
    'non_refund_withdraw': 'non_refundable_flag', 'pay_funding_type': 'pay_account_type', 'ticket_taker_age': 'taker_age', 'purchase_system': 'purchase_system_code',
    'mall_supplier_account_id': 'mall_supplier_id', 'order_is_test': 'test_flag', 'resource_land_id': 'resource_id', 'distributor_type': 'buyer_type',
    'land_type': 'scenic_type_code', 'land_adcode': 'district_code', 'land_zip_code': 'zip_code', 'ticket_taker_adcode': 'taker_district_code',
    'ticket_taker_province_idcard': 'taker_province_code', 'ticket_taker_city_idcard': 'taker_city_code', 'ticket_taker_county_idcard': 'taker_district_code',
    'expiration_time': 'valid_end_time', 'add_ticket_time': 'action_time', 'order_type': 'order_role', 'distribute_1_type': 'buyer_type', 'record_id': 'order_no',
    'main_tid': 'main_ticket_id', 'site_id': 'site_id', 'product_type': 'product_type', 'p_type': 'product_type',
    'package_price': 'package_price_amt', 'package_negotiated_price': 'package_invoice_amt', 'package_achievement': 'package_performance_amt',
    'sale_man_department': 'sale_man_group', 'customer_service_department': 'customer_service_group', 'back_detail': 'repayment_record',
    'open_type_catalogue': 'open_type', 'cancel_status': 'order_status', 'distributor_is_ota': 'ota_flag', 'ticket_taker_country': 'country_code',
    'land_province': 'province_name', 'land_city': 'city_name', 'land_country': 'country_name', 'member_kind': 'member_type_code',
    'member_type': 'member_type_code', 'ticket_zip_code': 'zip_code', 'main_tid': 'main_ticket_id', 'level': 'distribute_level',
    'sub_merchant_id': 'sub_merchant_id', 'verify_amount': 'verify_sale_amt',
    'order_pay_funding_type_id': 'pay_mode', 'order_pay_channel_id': 'pay_mode', 'sales_channel_id': 'order_mode', 'travel_minute': 'stat_minute',
}
TIME = re.compile(r'^(year|month|week|quarter|day|hour|fulldate|stat_date|insertdate|created_at|booking_month|booking_date|date_type|deadline|time_range|travel_minute|pay_date|'
                  r'(vertify|booking|pay|play|expiration|cancel)_(year|month|quarter|week|hour|date)|today|yesterday|weeks|more_week)$')
DERIVE = {   # 由已有字段直接派生的属性（查询 / 回流时计算）
    'is_around': '是否周边游客 = 取票人省（dwd_ord_order_di.taker_province_code）与景区所在省（dim_prd_scenic_df.province_code）相同',
    'mall_distinguish': '是否微商城订单 = dwd_ord_order_di.mall_supplier_id 非空',
    'add_ticket_time': '加票时间 = dwd_ord_order_track_di 中 track_action = ADD_TICKET 的 action_time',
    'based_on_order': '按订单统计口径标志：出入园按核销（dwd_ord_verify_di）为 1，按闸机流水（dwd_trf_scenic_inout_di）为 0',
    'avg_stay_minutes': '平均停留时长（分钟）= ads_trf_scenic_passenger_flow_di.stay_minutes_qty / stay_person_qty（按景区 / 日汇总后相除）',
    'dimension_type': '维度类型：行转列配置（导出时把标准表的维度列名写入，如 order_mode / pay_mode / scenic_id），回流任务按配置展开',
    'dimension_value': '维度取值：与 dimension_type 配对，取标准表对应维度列的值（行转列）',
    'dimension_methods': '维度口径：行转列配置（渠道 / 支付方式等分组方式名），回流时按标准表维度列生成',
}
# 跨表引用：旧导出表里的属性列，标准里在另一张表（不在该导出对应标准表的上游链上）；(匹配 标准表 + 旧表 的正则, 标准表, 标准字段, 说明)
XREF = {
    'customer_country': [(r'channel_aids', 'ads_sup_customer_company_df', 'customer_country', '客户公司宽表')],
    'customer_province': [(r'channel_aids', 'ads_sup_customer_company_df', 'customer_province', '客户公司宽表')],
    'customer_city': [(r'channel_aids', 'ads_sup_customer_company_df', 'customer_city', '客户公司宽表')],
    'customer_type': [(r'channel_aids', 'ads_sup_customer_company_df', 'customer_type', '客户公司宽表')],
    'user_land_topic': [(r'channel_aids', 'ads_sup_customer_company_df', 'user_land_topic', '客户公司宽表')],
    'user_contract_model': [(r'package', 'dwd_opr_package_open_di', 'cooperation_mode', '套餐开通明细的合作模式'),
                            (r'channel_aids', 'ads_sup_customer_company_df', 'user_contract_model', '客户公司宽表')],
    'start_time': [(r'service_business|service_merchant', 'dwd_sup_service_merchant_di', 'cooperation_date', '合作开始日期')],
    'product_category': [(r'retail', 'dwd_opr_retail_order_di', 'goods_category', '零售商品分类（商品行带出）')],
    'age': [(r'tourist_sex_age|tourist_instance', 'dwd_ord_traveler_di', 'age', '游客明细的年龄（按岁）；汇总表只存年龄段')],
    'main_tid': [(r'report_full_summary', 'dws_ord_package_sub_ticket_di', 'main_ticket_id', '套票主票：查套票子票汇总')],
    'sub_merchant_id': [(r'report_full_summary', 'dwd_ord_allinone_card_trade_di', 'sub_merchant_id', '子商户：一卡通交易明细')],
    'spare_field1': [(r'landtravel', 'ads_cus_landtravel_verify_di', 'special_person_module_flag', '旧预留列改名：是否开通特定人员模块')],
    'spare_field2': [(r'landtravel', 'ads_cus_landtravel_verify_di', 'identity_code_verify_flag', '旧预留列改名：是否开通身份动态码核销')],
    'spare_field3': [(r'landtravel', 'ads_cus_landtravel_verify_di', 'jl_verify_num_13', '旧预留列改名：景旅认证-居住证核验人数')],
    'insertdate': [(r'landtravel', 'ads_cus_landtravel_verify_di', 'verify_date', '核验日期')],
}
XTECH = {('landtravel', r'^spare_field([4-9]|1\d|20)$'): '旧表恒为空串的预留列，不再保留'}
TECH = re.compile(r'^(id|dw_ins_time|update_time|updated_at|etl_time|payload|key|value|flat|configuration|auth_key|remark|memo)$')


def _hotel(c):
    m = re.match(r'^(booking_cancel|check_in_cancel|booking|check_in)_(count|room_num|adult|children|people|charge|pay)$', c)
    if not m:
        return None
    act = {'booking': 'booking', 'booking_cancel': 'booking_cancel', 'check_in': 'checkin', 'check_in_cancel': 'checkin_cancel'}[m.group(1)]
    meas = {'count': 'order_qty', 'room_num': 'room_qty', 'adult': 'adult_qty', 'children': 'child_qty', 'people': 'guest_qty', 'charge': 'sales_amt', 'pay': 'pay_amt'}[m.group(2)]
    return f'hotel_{act}_{meas}', {}


def _aio(c):
    m = re.match(r'^o(\d+)([ca])$', c)
    if m:
        return ('aio_trade_qty' if m.group(2) == 'c' else 'aio_trade_amt'), {'trade_type': m.group(1)}
    m = re.match(r'^(co|cr)([ca])$', c)
    if m:
        return ('aio_trade_qty' if m.group(2) == 'c' else 'aio_trade_amt'), {'trade_type': 'CONSUME' if m.group(1) == 'co' else 'REFUND（标准为负数，旧为正数）'}
    return None


# 旧 dws_cus_order_channel_aids_d_f：booking_channel（下单渠道）编码 → 字段前缀
CHANNEL = {0: 'plat', 1: 'account', 9: 'vip', 10: 'cloud', 11: 'mall', 12: 'cdm', 13: 'pc', 14: 'agm', 15: 'smart_terminal', 16: 'adj', 17: 'tb', 18: 'year_card',
           19: 'mall_plat', 20: 'ota', 21: 'pay_code', 22: 'one_card', 23: 'subticket', 24: 'group', 33: 'efuzhou', 34: 'assorted', 35: 'integral_mall', 36: 'pos',
           38: 'icbc', 39: 'bankunion', 40: 'bankunion_pos', 41: 'wft', 42: 'yb', 43: 'wx_wpf', 44: 'adj_group', 45: 'cloud_union_pay', 46: 'offline', 47: 'staff_card',
           48: 'hand_card', 49: 'desk_cloud', 50: 'app', 55: 'special', 56: 'wx_app', 57: 'dy_tik', 58: 'ali', 59: 'group_purchase_code', 60: 'jjy_year'}
CH_OF = {v: k for k, v in CHANNEL.items()}
CH_RE = '|'.join(sorted(CH_OF, key=len, reverse=True))


TAG = {'resource_center': 'RESOURCE_CENTER', 'limited_conversion': 'SECKILL', 'kj': 'CUT_PRICE', 'pt': 'GROUP_BOOKING', 'qmyx': 'ALL_DIS', 'yhq': 'COUPON',
       'external_code': 'EXTERNAL_CODE', 'pft_park_card': 'PARK_CARD', 'pft_annual_card': 'ANNUAL_CARD', 'xcx_fxzy': 'DISTRIBUTOR'}


PROD = {'mp': '门票', 'tp': '套票', 'yc': '演出', 'nk': '年卡', 'lyq': '旅游券', 'jd': '酒店', 'tc': '套餐', 'jscp': '景+产品'}


def _channel(c):
    m = re.match(r'^(new_media|ota)(?:_([a-z]+))?_(gmv|ticket_num|order_num)(?:_(kh|hz))?$', c)
    if m and (m.group(1) == 'new_media' or m.group(2)):
        met = {'gmv': 'order_sale_amt', 'ticket_num': 'order_ticket_qty', 'order_num': 'order_order_qty'}[m.group(3)]
        code = m.group(1).upper() + ('_' + m.group(2).upper() if m.group(2) else '')
        return met, {'marketing_type': code if m.group(2) else 'NEW_MEDIA_*（组内各账号标签合计）'}
    m = re.match(rf"^prod_({'|'.join(PROD)})_new_(gmv|ticket_num|order_num)$", c)
    if m:
        return {'gmv': 'order_sale_amt', 'ticket_num': 'order_ticket_qty', 'order_num': 'order_order_qty'}[m.group(2)], {'产品类型（票维度带出）': PROD[m.group(1)]}
    m = re.match(rf"^({'|'.join(TAG)})_(gmv|ticket_num|order_num)(?:_(kh|hz))?$", c)
    if m:
        return {'gmv': 'order_sale_amt', 'ticket_num': 'order_ticket_qty', 'order_num': 'order_order_qty'}[m.group(2)], {'marketing_type': TAG[m.group(1)]}
    m = re.match(rf'^(?:({CH_RE})_)?(gmv|ticket_num|order_num)(?:_(kh|hz))?$', c)
    if not m:
        m2 = re.match(r'^(gmv|ticket_num|order_num)_(frist|first|second|third)_month$', c)
        if m2:
            return {'gmv': 'order_sale_amt', 'ticket_num': 'order_ticket_qty', 'order_num': 'order_order_qty'}[m2.group(1)], {'统计周期（时间表）': f'近 3 月第 {m2.group(2)} 月'}
        return None
    met = {'gmv': 'order_sale_amt', 'ticket_num': 'order_ticket_qty', 'order_num': 'order_order_qty'}[m.group(2)]
    return met, ({'order_mode': str(CH_OF[m.group(1)])} if m.group(1) else {})


def _mps(c):
    m = re.match(r'^(net_)?(sales|verify|cancel|revoke|after_sale)_(order_qty|ticket_qty|income_amt|expense_amt|income_discount_amt|expense_discount_amt|income_fee_amt|expense_fee_amt)$', c)
    if m:
        act = {'sales': 'pay', 'verify': 'verify', 'cancel': 'cancel', 'revoke': 'revoke', 'after_sale': 'after_sale'}[m.group(2)]
        meas = m.group(3)
        note = {'派生': '净额 = 支付 − 取消 − 撤销 − 售后（查询时由原子指标计算）'} if m.group(1) else {}
        if meas in ('income_discount_amt', 'expense_discount_amt'):        # 优惠：商户视角明细 dwd_ord_mps_detail_di（收入侧 = 销售优惠，支出侧 = 采购优惠）
            return (f"{act}_{'sale' if meas.startswith('income') else 'cost'}_discount_amt", note) if act != 'after_sale' else None
        if meas == 'income_fee_amt' and act in ('cancel', 'revoke'):
            return f'{act}_fee_amt', note
        if meas == 'expense_fee_amt':                                          # 买方（采购）手续费
            return (f'{act}_cost_fee_amt', note) if act in ('cancel', 'revoke') else None
        if act == 'after_sale':
            return {'ticket_qty': ('after_sale_ticket_qty', note), 'income_amt': ('after_sale_refund_amt', note),
                    'expense_amt': ('after_sale_cost_amt', note)}.get(meas)
        return f"{act}_{ {'order_qty': 'order_qty', 'ticket_qty': 'ticket_qty', 'income_amt': 'sale_amt', 'expense_amt': 'cost_amt'}[meas]}", note
    if c in ('collect_ticket_qty', 'pickup_ticket_qty'):
        return 'print_ticket_qty', {}
    if c == 'reprint_ticket_qty':
        return 'reprint_ticket_qty', {}
    m = re.match(r'^refund_fee_(income|expense)_amt$', c)
    if m:
        return ('cancel_fee_amt', {'派生': '退款手续费 = 取消手续费 + 撤销手续费'}) if m.group(1) == 'income' else \
            ('cancel_cost_fee_amt', {'派生': '退款采购手续费 = 取消采购手续费 + 撤销采购手续费'})
    return None


def _pass(c):
    m = re.match(r'^[tm](\d{1,2})$', c)
    if m:
        return 'enter_qty', {'stat_hour': m.group(1)}
    return {'entry_park_visitors_qty': ('enter_qty', {}), 'exit_park_visitors_qty': ('exit_qty', {}), 'in_park_visitors_qty': ('in_park_qty', {}),
            'current_visitors': ('in_park_qty', {}), 'scenic_cumulative_day': ('enter_qty', {'累计': '当日累计'})}.get(c)


def _subticket(c):
    return {'pay_ticket_cnt': ('order_ticket_qty', {}), 'sub_pay_ticket_cnt': ('order_ticket_qty', {'order_role': 'SUB'}), 'pay_ticket': ('order_ticket_qty', {}),
            'sub_pay_ticket': ('order_ticket_qty', {'order_role': 'SUB'})}.get(c)


def _inout(c):
    return {'in': ('enter_qty', {}), 'out': ('exit_qty', {}), 'employee': ('enter_qty', {'person_type': 'STAFF'})}.get(c)


def _park(c):
    return {'in': ('park_entry_qty', {}), 'out': ('park_exit_qty', {}), 'being': ('park_in_lot_qty', {}), 'duration': ('park_minute_qty', {})}.get(c)


def _branch(c):
    return {'check_orders': ('verify_order_qty', {}), 'check_tickets': ('verify_ticket_qty', {}), 'check_people': ('verify_person_qty', {})}.get(c)


def _retail(c):
    return {'sale_money': ('retail_sale_amt', {}), 'sale_num': ('retail_item_qty', {}), 'payment_money': ('retail_pay_amt', {}), 'discount_amount': ('retail_discount_amt', {}),
            'cancel_payment_money': ('retail_refund_amt', {}), 'cancel_num': ('retail_refund_item_qty', {}), 'order_num': ('retail_order_qty', {}),
            'number_of_people': ('retail_customer_qty', {}), 'profit_money': ('retail_profit_amt', {}), 'cancel_profit_money': ('retail_refund_profit_amt', {})}.get(c)


def _account(c):
    return {'income': ('account_income_amt', {}), 'expense': ('account_expense_amt', {}), 'frozen_income': ('account_frozen_income_amt', {}),
            'frozen_expense': ('account_frozen_expense_amt', {}), 'available_income': ('account_available_income_amt', {}),
            'available_expense': ('account_available_expense_amt', {})}.get(c)


def _toi(c):
    m = re.match(r'^(booking|verified)_(team|indi)_(orders|tourists)$', c)
    if not m:
        return None
    a = 'order' if m.group(1) == 'booking' else 'verify'
    return (f'{a}_order_qty' if m.group(3) == 'orders' else f'{a}_ticket_qty'), {'team_type': 'TEAM' if m.group(2) == 'team' else 'INDIVIDUAL'}


def _passflow(c):
    m = re.match(r'^(1d|last_7d|last_30d|last_365d)_qty(_yoy)?$', c)
    if m:
        return 'enter_qty', {'统计周期（时间表）': m.group(1) + ('（同比）' if m.group(2) else '')}
    return {'roll': ('enter_qty', {'inout_type': 'roll'})}.get(c)


DECODERS = [(r'hotel', _hotel), (r'allinone_card|aioc', _aio), (r'channel_aids|cus_company', _channel), (r'mps_\w*report', _mps),
            (r'terminal_pass|sup_trf_tourist|passenger_flow', _pass), (r'package_sub_ticket', _subticket), (r'scenic_inout_(cycle|week)|device_inout|device_ticket', _inout), (r'scenic_park', _park),
            (r'branch_terminal', _branch), (r'retail', _retail), (r'account_trans', _account), (r'toi_count', _toi), (r'tourist_in_out_qty', _passflow)]


def decode(col, where):
    """业务过程专用字段 → (标准指标, 维度取值) 或 None"""
    c = col.lower()
    for p, fn in DECODERS:
        if re.search(p, where):
            r = fn(c)
            if r:
                return r
    return None


# 仍无法由标准模型提供的字段：按原因归类（缺口 · 原因），在消费清单里计入「待补口径」
GAP = [
    (r'channel_aids|cus_company', r'^pft_\w+_num_kh$|concat_all|customer_mobile', '客户属性页专用拼接 / 计数（产品数、扫码、存储、短信申请）或敏感明文，需业务确认是否保留'),
    (r'user_package', r'.', '套餐合同 / 回款 / 业绩字段：随 OA 合同链路下线，CRM 销售订单（dwd_sup_crm_sales_order_df）可替代时再对'),
    (r'order_forck|order_verify|order_draw|tourists_source', r'.', '订单明细宽表的派生属性（是否周边 / 国家 / 邮编 / 会员类别 / 取消状态等）：查询时关联维表，或需补维度属性'),
    (r'report_full_summary', r'.', '套票主票 / 分销层级 / 子商户 / 站点：在套票子票汇总与分销链明细里有，交易汇总不带（避免放大），查询改用对应表'),
    (r'.', r'.', '旧表结构字段（行转列配置 / 项目专用），未纳入标准模型'),
]


def gap_reason(col, where):
    for tp, cp, why in GAP:
        if re.search(tp, where) and re.search(cp, col.lower()):
            return why
    return ''


import project_ads  # noqa: E402
VERBATIM = {s_['name'] for s_ in project_ads.SPECS}     # 项目报表：列名沿用旧表，导出列按同名直接对应


def make_resolver(tables, fields):
    """非指标字段：时间列 / 维度属性 / 明细列 → 标准表字段"""
    cols = {}
    for f in fields:
        cols.setdefault(str(f[1]).split('.', 1)[-1], set()).add(f[4])
    up = {t['name']: [u.strip() for u in re.split('、', t['up'] or '') if u.strip()] for t in tables}

    def chain(t, seen=None):
        seen = seen if seen is not None else []
        if t in seen or t not in up:
            return seen
        seen.append(t)
        for u in up[t]:
            if not u.startswith('ods_'):
                chain(u, seen)
        return seen
    dims = [t['name'] for t in tables if t['layer'] == 'DIM']

    def resolve(col, std, where=''):
        c = col.lower()
        for pat, xt, xc, why in XREF.get(c, ()):
            if re.search(pat, f'{std} {where}') and xc in cols.get(xt, ()):
                return '属性 / 明细字段', f'→ {xt}.{xc}（{why}）'
        for (wp, cp), why in XTECH.items():
            if re.search(wp, f'{std} {where}') and re.match(cp, c):
                return '技术列', why
        if c == 'name' and re.search('sbs_foundation', where):
            return '属性 / 明细字段', '外部大屏配置（vscreen 数据中台 sbs_foundation_data）原样同步：景区大屏的配置项名称，不进标准模型'
        if TIME.match(c):
            return '统计周期（时间表）', '时间列：查询时关联 dim_opr_period_f / dim_opr_date_f'
        import company_ads
        if c in company_ads.DROPPED:
            return '技术列', '旧表预留列已去掉：' + company_ads.DROPPED[c]
        if c in company_ads.ALIAS:
            cands_ = [company_ads.ALIAS[c]]
            for t in chain(std) + dims:
                if cands_[0] in cols.get(t, ()):
                    return '属性 / 明细字段', f'→ {t}.{cands_[0]}（旧列 {c} 改名）'
        if c in DERIVE:
            return '属性 / 明细字段', '派生：' + DERIVE[c]
        if TECH.match(c):
            return '技术列', '主键 / 加载时间 / 扩展报文，迁移时按目标表结构生成'
        cands = [c, ALIAS.get(c, ''), rules.std_col(c)[0]]
        cands += [x + '_id' for x in cands if x] + [x[:-3] for x in cands if x.endswith('_id')]
        for t in chain(std) + dims:
            for x in cands:
                if x and x in cols.get(t, ()):
                    return '属性 / 明细字段', f'→ {t}.{x}'
        return None
    resolve.cols = cols
    return resolve
