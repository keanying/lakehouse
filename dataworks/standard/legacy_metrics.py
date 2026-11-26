"""旧系统导出（hive_to_db）应用层模型的指标解码：字段名 → 标准指标 + 维度取值；公式 → 口径特征。"""
import re

ACT = [('after_sale', 'after_sale'), ('payment', 'pay'), ('paid', 'pay'), ('pay', 'pay'), ('cancel', 'cancel'), ('verify', 'verify'), ('checked', 'verify'),
       ('finish', 'finish'), ('revoke', 'revoke'), ('print', 'print'), ('take', 'print'), ('refund', 'cancel'), ('booking', 'order'), ('book', 'order'),
       ('order', 'order')]
MEAS = [('ticket_avg_price', 'avg_ticket_price'), ('avg_price', 'avg_ticket_price'), ('refund_money', 'refund_amt'), ('income_money', 'income_amt'),
        ('profit_money', 'profit_amt'), ('cost_money', 'cost_amt'), ('sale_money', 'sale_amt'), ('payment_money', 'sale_amt'), ('amount', 'sale_amt'),
        ('money', 'sale_amt'), ('ticket_count', 'ticket_qty'), ('ticket_num', 'ticket_qty'), ('ticket', 'ticket_qty'), ('order_count', 'order_qty'),
        ('order_num', 'order_qty'), ('count', 'order_qty'), ('num', 'order_qty'), ('tourist_count', 'traveler_qty'), ('total', 'traveler_qty')]
AGE = {'0to7': '0-7', '8to17': '8-17', '18to27': '18-27', '28to40': '28-40', '41to60': '41-60', '61plus': '61+'}
ADV = {'0': '当天', '1': '1', '2to3': '2-3', '4to7': '4-7', '7plus': '7+'}
FELLOW = {'1': '1', '2': '2-4', '3': '5-9', '4': '10+'}
DIM = {r'^(lid|land_id|scenic_id)$': 'scenic_id', r'^(tid|ticket_id)$': 'ticket_id', r'^(sid|aid|apply_did|sup_id|supplier_id)$': 'supplier_id',
       r'^(pid|product_id)$': 'product_id', r'^p_type$': 'product_type', r'^(channel_id|ordermode|channel_class\d_id|order_mode)$': 'order_mode',
       r'^(pay_channel_id|paymode|pay_mode)$': 'pay_mode', r'^(province|province_code|province_name)$': 'province_code', r'^(city|city_code|city_name)$': 'city_code',
       r'^(reseller_id|distributor_id|fid)$': 'distributor_id', r'^(year|month|week|quarter|date|stat_date|fulldate|day|hour)$': '统计周期（时间表）',
       r'^(terminal|terminal_no|branch_terminal)$': 'terminal_no', r'_name$|fullname$': '维度名称（关联维表）', r'^(country|district)$': 'district_code'}


DOMAIN = [(r'retail|sixun|yinbao|xisland', {'order_qty': 'retail_order_qty', 'ticket_qty': 'retail_item_qty', 'sale_amt': 'retail_sale_amt', 'refund_amt': 'retail_refund_amt'}),
          (r'park', {'order_qty': 'park_entry_qty', 'sale_amt': 'park_fee_amt'}),
          (r'account_trans|trade_account', {'sale_amt': 'account_income_amt'}),
          (r'annual_card', {'order_qty': 'card_sale_qty', 'ticket_qty': 'card_sale_qty', 'sale_amt': 'card_sale_amt'}),
          (r'terminal_pass|inout|in_out|enter_into|passenger_flow', {'order_qty': 'enter_qty', 'ticket_qty': 'enter_qty', 'traveler_qty': 'enter_qty'}),
          (r'resource_center|res_center', {'order_qty': 'resource_order_qty'}),
          (r'hotel', {'sale_amt': 'hotel_revenue_amt'})]


def decode(col, table=''):
    """字段名（+ 所在表名定业务域）→ dict(metric, role, dims, cum) 或 None（非指标列）"""
    d = _decode(col)
    if not d:
        return None
    for p, mp in DOMAIN:
        if re.search(p, table or ''):
            meas = re.sub(r'^(order|pay|cancel|verify|finish|revoke|print|after_sale)_', '', d['metric'])
            if meas in mp:
                d['metric'] = mp[meas]
            break
    return d


def _decode(col):
    c = col.lower()
    d = {'role': 'ALL', 'dims': {}, 'cum': False}
    if c.endswith('_all'):
        d['cum'] = True
        c = c[:-4]
    m = re.match(r'^(no_mo|mo)_(.*)$', c)
    if m:
        d['role'] = 'SUB' if m.group(1) == 'no_mo' else 'MAIN'
        c = m.group(2)
    m = re.match(r'^(male|female)_age_(\w+?)$', c) or re.match(r'^(unknown)$', c)
    if m:
        d['dims']['gender'] = {'male': 'M', 'female': 'F', 'unknown': 'U'}[m.group(1)]
        if m.lastindex and m.lastindex > 1:
            d['dims']['age_group'] = AGE.get(m.group(2), m.group(2))
        d['metric'] = 'traveler_qty'
        return d
    m = re.match(r'^group_(\d)$', c)
    if m:
        d['dims']['fellow_group'] = FELLOW.get(m.group(1), m.group(1))
        d['metric'] = 'traveler_qty'
        return d
    m = re.match(r'^(.*?)_(0|1|2to3|4to7|7plus)$', c)
    if m and re.search(r'order|amount|ticket', m.group(1)):
        d['dims']['advance_day_group'] = ADV[m.group(2)]
        c = m.group(1)
    act = next((a for k, a in ACT if re.search(rf'(^|_){k}(_|$)', c)), None)
    meas = next((v for k, v in MEAS if c.endswith(k)), None)
    if not meas:
        return None
    if meas in ('traveler_qty',):
        d['metric'] = 'traveler_qty'
        return d
    act = act or 'order'
    if c in ('paid_amount', 'payment_money', 'pay_amount') or c.startswith('pay_'):
        act = 'pay'
    if act == 'after_sale' and meas == 'sale_amt':
        meas = 'refund_amt'
    d['metric'] = f'{act}_{meas}'
    return d


def dim_of(col):
    for p, v in DIM.items():
        if re.search(p, col.lower()):
            return v
    return None


def features(f):
    """公式 → 口径特征（用来区分同一指标的不同算法）"""
    s = re.sub(r'\b\w+\.', '', f or '')
    s = re.sub(r'\s+', ' ', s)
    feats = []
    if re.search(r'COUNT\(DISTINCT', s, re.I):
        k = re.search(r'COUNT\(DISTINCT\s*(?:CASE.*?THEN\s*)?(\w+)', s, re.I)
        feats.append(f'去重计数 {k.group(1) if k else ""}')
    elif re.search(r'COUNT\(', s, re.I):
        feats.append('行计数')
    if re.search(r'SUM\(', s, re.I):
        k = re.findall(r'SUM\(\s*(?:CASE.*?THEN\s*|IF\([^,]*,\s*)?([\w*+\-/ ()]+?)[\s,)]', s, re.I)
        feats.append('求和 ' + '、'.join(sorted(set(x.strip() for x in k if x.strip())))[:60])
    if re.search(r'/\s*100\b', s):
        feats.append('分→元')
    conds = re.findall(r'(\w*status\w*|\w*state\w*|is_test|ordermode|paymode|order_type|is_team|track_action|action)\s*(?:=|IN|<>|!=|NOT IN)\s*\(?[^)\s]*', s, re.I)
    if conds:
        feats.append('条件 ' + '、'.join(sorted(set(re.sub(r'\s+', '', x) for x in conds)))[:80])
    if not feats:
        feats.append('透传 ' + s[:40])
    return '；'.join(feats)
