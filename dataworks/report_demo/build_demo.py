"""行业报告 demo：模拟数据 → 报告指标竖表 → 报告页面。

演示「取数方案」的完整链路（dataworks/docs/行业报告取数方案.md）：
1. 模拟景区维度与两期（2026 国庆 7 天 / 2025 国庆中秋 8 天）景区 × 日交易、客群、渠道、客流——数据全部随机生成，不代表任何真实经营数据；
2. 按与 sql/report/industry_report.sql 相同的规则算指标：剔除测试与异常冲量、全部 / 可比两套样本、占比、CR10 / HHI、承载率、最小样本抑制；
3. 写出竖表 metric_demo.csv（结构同 ads.ads_opr_industry_report_metric），并用它渲染 index.html。

运行：python3 dataworks/report_demo/build_demo.py
"""
import csv, json, math, pathlib, random

HERE = pathlib.Path(__file__).resolve().parent
R = random.Random(20261008)

CUR_DAYS, BASE_DAYS = 7, 8
CUR_SHAPE = [0.92, 1.18, 1.24, 1.12, 0.96, 0.78, 0.52]                # 2026-10-01 ~ 10-07（假期第 N 天）
BASE_SHAPE = [0.86, 1.10, 1.20, 1.14, 1.02, 0.88, 0.66, 0.46]          # 2025-10-01 ~ 10-08

TOPICS = {  # 主题: (占景区比例, 两期增长倍数, 平均票价 元, 本市 / 省内 / 跨省 游客结构)
    '山水自然': (0.30, 1.05, 92, (0.18, 0.37, 0.45)),
    '历史人文': (0.22, 1.08, 68, (0.22, 0.33, 0.45)),
    '博物场馆': (0.12, 1.24, 18, (0.38, 0.30, 0.32)),
    '主题乐园': (0.09, 1.10, 215, (0.30, 0.40, 0.30)),
    '古镇古村': (0.11, 0.90, 55, (0.20, 0.42, 0.38)),
    '动植物园': (0.07, 1.06, 78, (0.48, 0.36, 0.16)),
    '城市休闲': (0.09, 1.16, 45, (0.55, 0.30, 0.15)),
}
LEVELS = {'5A': (0.10, 9000), '4A': (0.32, 3200), '3A 及以下': (0.30, 1100), '未评级': (0.28, 600)}   # 占比, 日均票数中位
PROVINCES = {'浙江': 0.13, '江苏': 0.11, '四川': 0.09, '广东': 0.08, '山东': 0.07, '河南': 0.07, '安徽': 0.06, '湖南': 0.06, '湖北': 0.05,
             '福建': 0.05, '陕西': 0.05, '云南': 0.04, '江西': 0.04, '北京': 0.03, '上海': 0.03, '贵州': 0.03, '广西': 0.03, '重庆': 0.02,
             '海南': 0.006, '宁夏': 0.0025, '青海': 0.002, '西藏': 0.0015}
AGE = ['0-7', '8-17', '18-27', '28-40', '41-60', '61+']
AGE_BASE = [0.06, 0.12, 0.24, 0.31, 0.20, 0.07]
FELLOW = ['1', '2-4', '5-9', '10+']
ADV = ['当天', '1', '2-3', '4-7', '8-15', '16-30', '30+']
CHANNEL = ['OTA', '直销（自有渠道）', '分销（旅行社 / 平台）']
ORDER_CH = ['微信小程序', 'OTA 接口', '分销商平台', '售票窗口', '自助机', '官网 / H5', '其他']


def pick(d):
    tot = sum(v[0] if isinstance(v, tuple) else v for v in d.values())
    x, acc = R.random() * tot, 0
    for k, v in d.items():
        acc += v[0] if isinstance(v, tuple) else v
        if x <= acc:
            return k
    return list(d)[-1]


def norm(v):
    s = sum(v)
    return [x / s for x in v]


# ------------------------------------------------------------------ 1. 景区样本
scenic = []
for i in range(1, 931):
    lv = pick(LEVELS)
    tp = pick(TOPICS)
    status = R.random()
    sc = {'id': i, 'topic': tp, 'level': lv, 'province': pick(PROVINCES), 'test': 1 if i <= 6 else 0,
          'cap': int(LEVELS[lv][1] * R.uniform(0.9, 2.4)) if R.random() > 0.18 else 0,
          'base_day': LEVELS[lv][1] * math.exp(R.gauss(0, 0.55)),
          # 两期状态：可比 / 本期新接入 / 本期已流失
          'cur': status > 0.045, 'base': status <= 0.045 or status > 0.12}
    g = TOPICS[tp][1] * math.exp(R.gauss(0, 0.18))
    sc['cur_day'] = sc['base_day'] * g
    scenic.append(sc)
# 两家异常冲量（单日团购冲量）
for sc in R.sample([s for s in scenic if s['cur'] and s['base'] and not s['test']], 2):
    sc['spike'] = True

# ------------------------------------------------------------------ 2. 逐日交易
def daily(sc, period):
    shape = CUR_SHAPE if period == 'CUR' else BASE_SHAPE
    base = sc['cur_day'] if period == 'CUR' else sc['base_day']
    out = []
    for d, w in enumerate(shape):
        t = max(0, int(base * w * R.uniform(0.85, 1.15)))
        if period == 'CUR' and sc.get('spike') and d == 2:
            t = int(base * 40 + 8000)
        out.append(t)
    return out


rows = []   # (period, scenic, day, tickets)
for sc in scenic:
    for period in ('CUR', 'BASE'):
        if (period == 'CUR' and sc['cur']) or (period == 'BASE' and sc['base']):
            for d, t in enumerate(daily(sc, period)):
                rows.append((period, sc, d, t))

# 样本规则：剔除测试；异常 = 单日票数 > 日均 × 20 且 > 5000；可比 = 两期都有交易
for sc in scenic:
    cur_days = [t for p, s, d, t in rows if s is sc and p == 'CUR']
    sc['outlier'] = 1 if cur_days and max(cur_days) > max(sc['base_day'] * 20, 5000) else 0
    sc['comparable'] = 1 if sc['cur'] and sc['base'] else 0
valid = [r for r in rows if not r[1]['test'] and not r[1]['outlier']]

# ------------------------------------------------------------------ 3. 指标 → 竖表
M = []


def add(sec, code, name, dim_type, dim_value, sample, cur, base, n, share=False):
    yoy = (cur - base) if share else ((cur - base) * 100 / base if base else None)
    M.append({'section_code': sec, 'metric_code': code, 'metric_name': name, 'dim_type': dim_type, 'dim_value': dim_value, 'sample_type': sample,
              'cur_value': round(cur, 4), 'base_value': round(base, 4), 'yoy_rate': None if yoy is None else round(yoy, 4),
              'sample_scenic_qty': n, 'suppress_flag': 1 if n < 5 else 0})


def price_of(sc):
    p = TOPICS[sc['topic']][2] * {'5A': 1.45, '4A': 1.1, '3A 及以下': 0.8, '未评级': 0.6}[sc['level']]
    sc.setdefault('price', max(0, p * math.exp(R.gauss(0, 0.35)) if R.random() > 0.07 else 0))
    return sc['price']


for sample in ('ALL', 'COMPARABLE'):
    rs = [r for r in valid if sample == 'ALL' or r[1]['comparable']]
    agg = {}
    for p in ('CUR', 'BASE'):
        sub = [r for r in rs if r[0] == p]
        tk = sum(r[3] for r in sub)
        amt = sum(r[3] * price_of(r[1]) * (1.04 if p == 'CUR' else 1.0) for r in sub)
        days = CUR_DAYS if p == 'CUR' else BASE_DAYS
        agg[p] = {'ticket_qty': tk, 'sale_amt': amt, 'order_qty': tk / (2.6 if p == 'CUR' else 2.75),
                  'buyer_qty': tk / (2.35 if p == 'CUR' else 2.48) * 0.93, 'avg_price': amt / tk,
                  'cancel_rate': 4.6 if p == 'CUR' else 5.3, 'verify_rate': 88.9 if p == 'CUR' else 87.2, 'day_avg_ticket_qty': tk / days,
                  'n': len({r[1]['id'] for r in sub})}
    for code, name in [('ticket_qty', '预订票数（张）'), ('sale_amt', '预订金额（元）'), ('order_qty', '预订订单数（单）'), ('buyer_qty', '购票人数（人，去重）'),
                       ('avg_price', '票均价（元）'), ('cancel_rate', '退票率（%）'), ('verify_rate', '核销率（%）'), ('day_avg_ticket_qty', '日均预订票数（张）')]:
        add('S1', code, name, 'ALL', '全部', sample, agg['CUR'][code], agg['BASE'][code], agg['CUR']['n'], share=code.endswith('_rate'))

# 逐日趋势（按假期第 N 天）
for p, days in (('CUR', CUR_DAYS), ('BASE', BASE_DAYS)):
    for d in range(days):
        v = sum(r[3] for r in valid if r[0] == p and r[2] == d)
        M.append({'section_code': 'S1', 'metric_code': 'day_ticket_qty', 'metric_name': '逐日预订票数（张）', 'dim_type': 'holiday_day_no',
                  'dim_value': f'第{d + 1}天', 'sample_type': 'ALL', 'cur_value': v if p == 'CUR' else None, 'base_value': v if p == 'BASE' else None,
                  'yoy_rate': None, 'sample_scenic_qty': None, 'suppress_flag': 0})


def shares(sec, code, name, dim_type, key, rs, sample='ALL'):
    groups = {}
    for p, sc, d, t in rs:
        g = groups.setdefault(key(sc), {'CUR': 0, 'BASE': 0, 'ids': set()})
        g[p] += t
        if p == 'CUR':
            g['ids'].add(sc['id'])
    tc, tb = sum(g['CUR'] for g in groups.values()), sum(g['BASE'] for g in groups.values())
    for k, g in sorted(groups.items(), key=lambda x: -x[1]['CUR']):
        add(sec, code, name, dim_type, k, sample, g['CUR'] * 100 / tc, g['BASE'] * 100 / tb, len(g['ids']), share=True)


shares('S2', 'ticket_share', '预订票数占比（%）', 'scenic_topic', lambda s: s['topic'], valid)
shares('S2', 'ticket_share', '预订票数占比（%）', 'scenic_level', lambda s: s['level'], valid)
shares('S2', 'ticket_share', '预订票数占比（%）', 'province', lambda s: s['province'], valid)
# 主题可比增速
for tp in TOPICS:
    sub = [r for r in valid if r[1]['comparable'] and r[1]['topic'] == tp]
    c, b = sum(r[3] for r in sub if r[0] == 'CUR') / CUR_DAYS, sum(r[3] for r in sub if r[0] == 'BASE') / BASE_DAYS
    add('S2', 'day_avg_ticket_qty', '日均预订票数（张，可比景区）', 'scenic_topic', tp, 'COMPARABLE', c, b, len({r[1]['id'] for r in sub}))
# 集中度
for p in ('CUR', 'BASE'):
    pass
tot = {p: {} for p in ('CUR', 'BASE')}
for p, sc, d, t in valid:
    tot[p][sc['id']] = tot[p].get(sc['id'], 0) + t
sh = {p: sorted((v / sum(tot[p].values()) for v in tot[p].values()), reverse=True) for p in tot}
add('S2', 'cr10_share', '头部 10 景区份额 CR10（%）', 'ALL', '全部', 'ALL', sum(sh['CUR'][:10]) * 100, sum(sh['BASE'][:10]) * 100, len(sh['CUR']), share=True)
add('S2', 'hhi', '市场集中度 HHI', 'ALL', '全部', 'ALL', sum(x * x for x in sh['CUR']) * 10000, sum(x * x for x in sh['BASE']) * 10000, len(sh['CUR']))
add('S2', 'active_scenic_qty', '有交易景区数（家）', 'ALL', '全部', 'ALL', len(tot['CUR']), len(tot['BASE']), len(tot['CUR']))


def mix(sec, code, name, dim_type, labels, cur, base, n=900):
    for k, c, b in zip(labels, norm(cur), norm(base)):
        add(sec, code, name, dim_type, k, 'ALL', c * 100, b * 100, n, share=True)


# 客群（按核销游客；结构由景区主题加权，加入两期变化）
dist_c, dist_b = [0, 0, 0], [0, 0, 0]
for p, sc, d, t in valid:
    w = TOPICS[sc['topic']][3]
    tgt = dist_c if p == 'CUR' else dist_b
    adj = (0.97, 0.98, 1.06) if p == 'CUR' else (1, 1, 1)
    for i in range(3):
        tgt[i] += t * w[i] * adj[i]
n_all = len(tot['CUR'])
mix('S3', 'traveler_share', '到访游客占比（%）', 'distance', ['本市', '省内跨市', '跨省'], dist_c, dist_b, n_all)
mix('S3', 'traveler_share', '到访游客占比（%）', 'age_group', AGE, [0.065, 0.125, 0.262, 0.302, 0.183, 0.063], AGE_BASE, n_all)
mix('S3', 'traveler_share', '到访游客占比（%）', 'gender', ['女', '男', '未知'], [0.522, 0.451, 0.027], [0.514, 0.455, 0.031], n_all)
mix('S3', 'traveler_share', '到访游客占比（%）', 'fellow_group', FELLOW, [0.21, 0.55, 0.17, 0.07], [0.19, 0.54, 0.18, 0.09], n_all)
mix('S3', 'traveler_share', '到访游客占比（%）', 'team', ['散客', '团队'], [0.912, 0.088], [0.897, 0.103], n_all)
# 预订行为
mix('S4', 'advance_share', '提前预订天数分布（%）', 'advance_day_group', ADV, [0.36, 0.17, 0.14, 0.13, 0.10, 0.06, 0.04], [0.31, 0.16, 0.15, 0.14, 0.12, 0.07, 0.05], n_all)
hc = [0.4, 0.2, 0.1, 0.1, 0.2, 0.6, 1.6, 3.6, 7.2, 8.9, 8.4, 6.9, 5.8, 5.6, 5.9, 5.3, 4.7, 4.4, 4.9, 5.6, 5.9, 5.0, 3.3, 1.6]
hb = [0.5, 0.3, 0.2, 0.1, 0.2, 0.7, 1.9, 4.1, 7.6, 8.8, 8.1, 6.7, 5.6, 5.5, 5.7, 5.2, 4.6, 4.3, 4.6, 5.2, 5.4, 4.8, 3.4, 1.8]
mix('S4', 'hour_share', '下单时段分布（%）', 'stat_hour', [f'{h:02d}' for h in range(24)], hc, hb, n_all)
# 渠道
mix('S5', 'channel_share', '渠道票数占比（%）', 'channel_group', CHANNEL, [0.418, 0.392, 0.190], [0.452, 0.341, 0.207], n_all)
mix('S5', 'channel_share', '渠道票数占比（%）', 'order_channel', ORDER_CH, [0.318, 0.284, 0.152, 0.118, 0.064, 0.038, 0.026],
    [0.262, 0.311, 0.171, 0.141, 0.059, 0.031, 0.025], n_all)
# 客流与承载（只统计填了接待能力的景区）
cap = [s for s in scenic if s['cap'] and not s['test'] and not s['outlier']]
rate = {'CUR': [], 'BASE': []}
crowd = {'CUR': [0, 0], 'BASE': [0, 0]}
for p, sc, d, t in valid:
    if not sc['cap']:
        continue
    r = t * R.uniform(0.38, 0.62) * 100 / sc['cap']
    crowd[p][0] += 1 if r >= 80 else 0
    crowd[p][1] += 1
    rate[p].append((sc['id'], r))
peak = {p: {} for p in rate}
for p in rate:
    for i, r in rate[p]:
        peak[p][i] = max(peak[p].get(i, 0), r)
add('S6', 'peak_load_rate', '景区峰值承载率均值（%）', 'ALL', '全部', 'ALL', sum(peak['CUR'].values()) / len(peak['CUR']),
    sum(peak['BASE'].values()) / len(peak['BASE']), len(peak['CUR']), share=True)
add('S6', 'crowded_day_share', '承载率 ≥ 80% 的景区日占比（%）', 'ALL', '全部', 'ALL', crowd['CUR'][0] * 100 / crowd['CUR'][1],
    crowd['BASE'][0] * 100 / crowd['BASE'][1], len(peak['CUR']), share=True)
# 价格带
band = lambda p: '免费 / 0 元' if p <= 0 else '0-50 元' if p < 50 else '50-100 元' if p < 100 else '100-200 元' if p < 200 else '200 元以上'
shares('S7', 'price_band_share', '价格带票数占比（%）', 'price_band', lambda s: band(price_of(s)), valid)
# 区域（可比景区）
prov = {}
for p, sc, d, t in valid:
    if not sc['comparable']:
        continue
    g = prov.setdefault(sc['province'], {'CUR': 0, 'BASE': 0, 'ids': set()})
    g[p] += t
    g['ids'].add(sc['id'])
for k, g in sorted(prov.items(), key=lambda x: -x[1]['CUR']):
    add('S8', 'province_day_avg_ticket_qty', '省份日均预订票数（张，可比景区）', 'province', k, 'COMPARABLE', g['CUR'] / CUR_DAYS, g['BASE'] / BASE_DAYS, len(g['ids']))

# 样本说明
meta = {
    'sample_all': len(tot['CUR']), 'sample_base': len(tot['BASE']), 'comparable': sum(1 for s in scenic if s['comparable'] and not s['test'] and not s['outlier']),
    'new': sum(1 for s in scenic if s['cur'] and not s['base'] and not s['test']), 'lost': sum(1 for s in scenic if s['base'] and not s['cur'] and not s['test']),
    'test': sum(1 for s in scenic if s['test']), 'outlier': sum(1 for s in scenic if s['outlier']),
    'cap_qty': len({i for i, _ in rate['CUR']}),
    'comparable_ticket_share': round(sum(r[3] for r in valid if r[0] == 'CUR' and r[1]['comparable']) * 100 / sum(r[3] for r in valid if r[0] == 'CUR'), 1),
    'suppressed': sum(1 for m in M if m['suppress_flag']),
}

# ------------------------------------------------------------------ 4. 输出
cols = ['section_code', 'metric_code', 'metric_name', 'dim_type', 'dim_value', 'sample_type', 'cur_value', 'base_value', 'yoy_rate', 'sample_scenic_qty', 'suppress_flag']
with open(HERE / 'metric_demo.csv', 'w', newline='', encoding='utf-8-sig') as f:
    w = csv.writer(f)
    w.writerow(['report_code'] + cols)
    for m in M:
        w.writerow(['2026_national_day_demo'] + [m[c] for c in cols])
tpl = (HERE / 'template.html').read_text(encoding='utf-8')
data = json.dumps({'rows': M, 'meta': meta}, ensure_ascii=False, separators=(',', ':'))
(HERE / 'index.html').write_text(tpl.replace('__DATA__', data), encoding='utf-8')
print('竖表行数', len(M), '样本', meta)
