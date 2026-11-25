#!/usr/bin/env python3
"""ADS 指标体系：日粒度存储 + 时间表关联统计。

客户字典里 ADS 把统计周期写死成列（pay_1d_amt / pay_7d_amt / pay_30d_amt / pay_mtd_amt …），
只能看这几种周期，加周期就要加列。这里的做法：
  * ADS 保持日粒度（travel_date × 维度），每个基础指标只存「能跨天汇总」的日数据：
      可加 → 日值；去重 → 日 BITMAP；比率/均值 → 日分子、日分母；快照 → 日快照值；
  * 时间表 dim_opr_period_f：每个截止日 × 每种统计周期一行，给出本期 / 环比基期 / 同比基期区间；
    dim_opr_date_f 补齐节假日、半年度、同比对齐日等属性；dim_opr_holiday_period_f 维护节假日放假区间；
  * 查询时 ADS 日数据关联时间表，按区间汇总，再算日均 / 环比 / 同比 / 周同比 / 占比；
    当日、本周/上周、本月/上月、本季/上季、本半年/上半年度、本年/上年度、近7/30/90/180/365日、节假日、自定义区间都走同一套 SQL。
数据不膨胀：ADS 行数与原来相同，列数比原来更少。

build.py 调用 build() → apply_to_dictionary() 写回字典 → to_xlsx()/dict_xlsx() 导出 Excel。
"""
import re
import datetime
import collections

# ---------------------------------------------------------------- 统计周期（时间表里的 period_type_code）
# code, 名称, 分组, 本期区间, 环比基期, 同比基期, 是否在时间表中预置（自定义由前端传起止日）
PERIODS = [
    ('D1', '当日', '日', '[T, T]', '前一日 T−1', '去年同日', 1),
    ('WTD', '本周', '自然周期·至今', '[本周一, T]', '上周同期（周一至同星期几）', '去年同周同期（往前 52 周）', 1),
    ('LW', '上周', '自然周期·完整', '[上周一, 上周日]', '上上周', '去年同周（往前 52 周）', 1),
    ('MTD', '本月', '自然周期·至今', '[本月1日, T]', '上月同期（1 日至同一天，超出月末取月末）', '去年同月同期', 1),
    ('LM', '上月', '自然周期·完整', '[上月1日, 上月末]', '上上月', '去年同月', 1),
    ('QTD', '本季度', '自然周期·至今', '[本季首日, T]', '上季同期（相同天数）', '去年同季同期', 1),
    ('LQ', '上季度', '自然周期·完整', '[上季首日, 上季末]', '上上季', '去年同季', 1),
    ('HTD', '本半年', '自然周期·至今', '[本半年首日(1/1 或 7/1), T]', '上个半年同期（相同天数）', '去年同半年同期', 1),
    ('LH', '上半年度', '自然周期·完整', '最近一个完整半年（1–6 月或 7–12 月）', '再前一个半年', '去年同半年', 1),
    ('YTD', '本年', '自然周期·至今', '[1月1日, T]', '去年同期（= 同比）', '去年同期', 1),
    ('LY', '上年度', '自然周期·完整', '[去年1月1日, 去年12月31日]', '前年', '前年', 1),
    ('N7', '近7日', '滚动', '[T−6, T]', '前 7 天', '去年同期（日期减 1 年）', 1),
    ('N30', '近30日', '滚动', '[T−29, T]', '前 30 天', '去年同期', 1),
    ('N90', '近90日', '滚动', '[T−89, T]', '前 90 天', '去年同期', 1),
    ('N180', '近半年', '滚动', '[T−179, T]', '前 180 天', '去年同期', 1),
    ('N365', '近1年', '滚动', '[T−364, T]', '前 365 天', '去年同期', 1),
    ('HOL', '节假日', '节假日', '假期首日至 min(假期末日, T)；每个 holiday_period_code 一行', '节前同等天数', '去年同一假期（按假期第 N 天对齐）', 1),
    ('CUS', '自定义', '自定义', '前端传入任意起止日（可叠加日期属性：周末/寒暑假/旺季…）', '前一等长区间', '去年同期', 0),
]
PERIOD_CODE_DESC = '统计周期编码：' + '，'.join(f'{p[0]}-{p[1]}' for p in PERIODS if p[6])

# ---------------------------------------------------------------- 派生方式（查询时计算，不落 ADS）
# code, 名称, 查询结果列名, 单位, 计算方式, 适用聚合方式, 适用周期
DERIVS = [
    ('VAL', '本期值', '{s}_{k}', '同口径', '本期区间内按聚合方式汇总 ADS 日数据（可加 SUM / 去重 BITMAP_UNION_COUNT / 比率 SUM(分子)/SUM(分母) / 快照取区间末日）', 'all', 'all'),
    ('AVG', '日均值', '{s}_daily_avg_{k}', '同口径', '本期区间内日数据之和 ÷ 区间天数（快照类即区间内每日快照的平均）', 'additive,once,snapshot', 'multi'),
    ('PREV', '上期值', '{s}_prev_{k}', '同口径', '环比基期区间（时间表 prev_*）内的汇总值', 'all', 'all'),
    ('MOM', '环比增长率', '{s}_mom_rate', '%', '(本期值 − 上期值) × 100 ÷ 上期值；上期值为 0 时为空', 'additive,once,distinct,snapshot,avg', 'all'),
    ('MOMD', '环比变化', '{s}_mom_diff_rate', '百分点', '本期率 − 上期率（百分点）', 'pct', 'all'),
    ('LYV', '去年同期值', '{s}_ly_{k}', '同口径', '同比基期区间（时间表 ly_*）内的汇总值', 'all', 'all'),
    ('YOY', '同比增长率', '{s}_yoy_rate', '%', '(本期值 − 去年同期值) × 100 ÷ 去年同期值；去年同期值为 0 时为空', 'additive,once,distinct,snapshot,avg', 'all'),
    ('YOYD', '同比变化', '{s}_yoy_diff_rate', '百分点', '本期率 − 去年同期率（百分点）', 'pct', 'all'),
    ('WOW', '周同比增长率', '{s}_wow_rate', '%', '(当日值 − 上周同日值) × 100 ÷ 上周同日值（上周同日取时间表 wow_date_no）', 'additive,once,distinct,avg', 'D1'),
    ('WOWD', '周同比变化', '{s}_wow_diff_rate', '百分点', '当日率 − 上周同日率（百分点）', 'pct', 'D1'),
    ('SHR', '占比', '{s}_share_rate', '%', '带修饰词的本期值 × 100 ÷ 不带修饰词（全量）的本期值', 'additive,once,distinct', 'all'),
]
KW = ('amt', 'qty', 'rate', 'date', 'type', 'time', 'code', 'no', 'id', 'name', 'desc')
PER_TOKEN = re.compile(r'_(1d|7d|30d|90d|mtd|ytd|td|1w|1m|1h)(?=_|$)')
KIND_LABEL = {'additive': '可加', 'once': '一次性事件', 'distinct': '去重', 'pct': '比率(%)', 'avg': '均值/比值', 'snapshot': '快照'}


def stem_kw(field):
    f = PER_TOKEN.sub('', str(field))
    for k in KW:
        if f.endswith('_' + k):
            return f[:-len(k) - 1], k
    return f, ''


def kind_of(cls, unit):
    if cls == 'ratio':
        return 'pct' if unit == '%' else 'avg'
    return cls or 'additive'


def applies(deriv, kind, period, has_mod):
    if deriv[0] == 'SHR' and not has_mod:
        return False
    if deriv[5] != 'all' and kind not in deriv[5].split(','):
        return False
    if deriv[6] == 'D1' and period != 'D1':
        return False
    if deriv[6] == 'multi' and period == 'D1':
        return False
    return True


# ---------------------------------------------------------------- 区间计算（时间表生成规则，这里用于示例日期）
def _add(d, n): return d + datetime.timedelta(days=n)


def _addy(d, n):
    try:
        return d.replace(year=d.year + n)
    except ValueError:
        return d.replace(year=d.year + n, day=28)


def _pstart(d, u):
    if u == 'W': return _add(d, -d.weekday())
    if u == 'M': return d.replace(day=1)
    if u == 'Q': return d.replace(month=(d.month - 1) // 3 * 3 + 1, day=1)
    if u == 'H': return d.replace(month=1 if d.month <= 6 else 7, day=1)
    return d.replace(month=1, day=1)


def _shift(s, u, n):
    if u == 'W': return _add(s, 7 * n)
    k = {'M': 1, 'Q': 3, 'H': 6, 'Y': 12}[u] * n
    m = s.month - 1 + k
    return s.replace(year=s.year + m // 12, month=m % 12 + 1, day=1)


def ranges(code, T):
    """(本期, 环比基期, 同比基期)；节假日/自定义返回 None"""
    if code == 'D1':
        return (T, T), (_add(T, -1), _add(T, -1)), (_addy(T, -1), _addy(T, -1))
    if code[0] == 'N':
        n = int(code[1:])
        s = _add(T, -(n - 1))
        return (s, T), (_add(s, -n), _add(s, -1)), (_addy(s, -1), _addy(T, -1))
    u = {'WTD': 'W', 'LW': 'W', 'MTD': 'M', 'LM': 'M', 'QTD': 'Q', 'LQ': 'Q', 'HTD': 'H', 'LH': 'H', 'YTD': 'Y', 'LY': 'Y'}.get(code)
    if not u:
        return None
    s = _pstart(T, u)
    if code.endswith('TD'):
        n = (T - s).days
        ps = _shift(s, u, -1)
        pe = min(_add(ps, n), _add(s, -1))
        if u == 'W':
            return (s, T), (ps, pe), (_add(s, -364), _add(T, -364))
        if u == 'Y':
            return (s, T), (_addy(s, -1), _addy(T, -1)), (_addy(s, -1), _addy(T, -1))
        return (s, T), (ps, pe), (_addy(s, -1), _addy(T, -1))
    s = _shift(s, u, -1)
    e = _add(_shift(s, u, 1), -1)
    ps = _shift(s, u, -1)
    if u == 'W':
        return (s, e), (ps, _add(s, -1)), (_add(s, -364), _add(e, -364))
    return (s, e), (ps, _add(s, -1)), (_addy(s, -1), _add(_shift(_addy(s, -1), u, 1), -1))


# ---------------------------------------------------------------- 比率拆分子分母
def split_ratio(calc, cn2en):
    """'下单支付转化率 = 支付子单数*100/下单子单数，保留…' → (分子文字, 分子英文名, 分母文字, 分母英文名)"""
    rhs = str(calc).split('=', 1)[-1]
    rhs = re.split(r'[，；;。]', rhs)[0]
    rhs = re.sub(r'（按[^）]*）|\(按[^)]*\)', '', rhs).strip()
    if '/' not in rhs:
        return rhs, None, '', None
    num, den = rhs.split('/', 1)
    num = re.sub(r'\s*\*\s*100\s*', '', num).strip(' ()（）')
    den = den.strip(' ()（）')

    def find(txt):
        for cn, en in cn2en:
            if cn and cn in txt and len(cn) >= len(txt) * 0.5:
                return en
        return None
    return num, find(num), den, find(den)


# ---------------------------------------------------------------- 主流程
def build(sheets, chk, anchor=None):
    A, F, D, T = sheets['ADS业务指标'], sheets['字段清单'], sheets['DWS口径'], sheets['表清单']
    ai = {c: i for i, c in enumerate(A['cols'])}
    fi = {c: i for i, c in enumerate(F['cols'])}
    di = {c: i for i, c in enumerate(D['cols'])}
    ti = {c: i for i, c in enumerate(T['cols'])}
    sn = lambda s: re.sub(r'^\w+\.', '', str(s or '').strip())
    dcode = {r[di['口径编码']]: r for r in D['rows']}
    mclass = chk['mclass']
    en_cls = {r[di['英文名']]: mclass.get(r[di['口径编码']]) for r in D['rows']}
    cn2en = sorted(((str(r[di['中文名']]), r[di['英文名']]) for r in D['rows']), key=lambda x: -len(x[0]))
    cn2en += [(cn.replace('（GMV）', ''), en) for cn, en in cn2en if '（GMV）' in cn]
    tinfo = {sn(r[ti['表名（库.表）']]): r for r in T['rows']}
    fields = collections.defaultdict(list)
    for r in F['rows']:
        fields[sn(r[fi['表名（库.表）']])].append(r)
    fset = {(sn(r[fi['表名（库.表）']]), r[fi['字段名']]) for r in F['rows']}
    up_of = {(sn(r[fi['表名（库.表）']]), r[fi['字段名']]): r[fi['上游字段']] for r in F['rows']}

    SKIP_TABLE = {
        'ads_ord_verify_flow_hrs': '分时表：统计对象是小时，保持小时粒度',
        'ads_ord_play_date_booking_df': '分析对象是未来游玩日（play_date），按游玩日筛选，不按统计周期汇总',
        'ads_sup_tenant_trade_wk': '周报：日粒度 ADS 关联时间表 LW（上周）即可得到，建议下线',
        'ads_sup_tenant_trade_mo': '月报：日粒度 ADS 关联时间表 LM（上月）即可得到，建议下线',
        'ads_opr_package_revenue_mo': '套餐按自然月结算，保持月粒度',
    }
    SKIP_CODE = {'C032': '日环比 → 查询时派生「环比增长率」（D1）', 'C033': '周同比 → 查询时派生「周同比增长率」',
                 'C034': '月环比 → 查询时派生「环比增长率」（LM）'}

    combos = collections.OrderedDict()
    skipped = []
    for r in A['rows']:
        if r[ai['离线/实时']] != '离线':
            continue
        t = sn(r[ai['ADS表']])
        code = str(r[ai['基础口径']]).split(' ')[0]
        if t in SKIP_TABLE or code in SKIP_CODE:
            skipped.append([r[ai['指标编码']], r[ai['业务指标名']], t, r[ai['字段名']], SKIP_TABLE.get(t) or SKIP_CODE.get(code)])
            continue
        combos.setdefault((t, code, r[ai['修饰词']]), {'t': t, 'code': code, 'mod': r[ai['修饰词']], 'old': []})['old'].append(r)

    store, out_fields, problems = [], [], []
    seen_store = collections.defaultdict(dict)
    seen_q = collections.defaultdict(dict)
    for n, c in enumerate(combos.values(), 1):
        r0 = c['old'][0]
        base_row = dcode.get(c['code'])
        cls = mclass.get(c['code'], 'additive')
        unit = r0[ai['单位']]
        kind = kind_of(cls, unit)
        snap = cls == 'snapshot'
        if snap and unit == '%':
            kind = 'pct'  # 快照类比率（上座率、授信使用率）：存期末分子分母
        stem, kw = stem_kw(r0[ai['字段名']])
        kw = kw or ('rate' if unit == '%' else 'qty')
        base_cn = str(base_row[di['中文名']]) if base_row else str(r0[ai['业务指标名']])
        mod = '' if c['mod'] in ('—', '', None) else str(c['mod'])
        mod_cn = mod.split('=')[-1] if mod else ''
        name_core = mod_cn + base_cn.replace('（GMV）', '') + ('（GMV）' if base_cn.endswith('（GMV）') else '')
        ups = [u.strip() for u in str(up_of.get((c['t'], r0[ai['字段名']]), '')).split('、') if u.strip()]
        src_tabs = [sn(x) for x in re.split(r'[、,，\s]+', str(r0[ai['来源 DWS']])) if x]
        kou = base_row[di['业务口径']] if base_row else r0[ai['业务口径']]
        calc = base_row[di['计算公式']] if base_row else r0[ai['计算公式']]
        c.update(mcode=f'M{n:04d}', stem=stem, kw=kw, kind=kind, cls=cls, unit=unit, mod=mod, base_cn=name_core, kou=kou, calc=calc,
                 src=r0[ai['来源 DWS']], use=r0[ai['使用端']], old_periods=sorted({x[ai['统计周期']] for x in c['old']}),
                 old_fields=[x[ai['字段名']] for x in c['old']], store=[], fields=[])
        cond = f'（条件：{mod}）' if mod else ''

        def col(name, typ, cmt, proc, up):
            if name in seen_store[c['t']]:
                problems.append([c['t'], name, seen_store[c['t']][name], c['mcode']])
                return
            seen_store[c['t']][name] = c['mcode']
            store.append({'t': c['t'], 'm': c['mcode'], 'f': name, 'type': typ, 'cmt': cmt, 'proc': proc, 'up': up})
            c['store'].append(name)

        def dws_ref(en):
            """在来源 DWS 里找口径英文名对应的字段"""
            for u in ups:
                if u.split('.')[-1] == en:
                    return u
            for t in src_tabs:
                if (t, en) in fset:
                    return f'dws.{t}.{en}'
            return ''

        up0 = '、'.join(ups)
        if kind in ('additive', 'once'):
            col(f'{stem}_{kw}', r0[ai['数据类型']], f'{name_core}（日）：{kou}{cond}，单位：{unit}',
                f'{sn(up0) or "来源 DWS"}：当日值{cond}', up0)
            c['expr'] = {'v': f'SUM({{C}}{stem}_{kw})'}
        elif kind == 'snapshot':
            col(f'{stem}_{kw}', r0[ai['数据类型']], f'{name_core}（日快照）：{kou}{cond}，单位：{unit}',
                f'{sn(up0) or "来源 DWS"}：统计日日终快照{cond}', up0)
            c['expr'] = {'v': f'SUM({{C}}{stem}_{kw})', 'snap': 1}
        elif kind == 'distinct':
            b = f'{stem}_bitmap'
            bu = re.sub(r'_qty\b', '_bitmap', up0)
            col(b, 'BITMAP', f'{name_core}去重位图（日）：{kou}{cond}；任意区间 BITMAP_UNION_COUNT 去重，单位：人',
                f'{sn(bu) or "来源 DWS"}：当日位图{cond}', bu)
            c['expr'] = {'v': f'BITMAP_UNION_COUNT({{C}}{b})'}
        else:
            ntxt, nen, dtxt, den = split_ratio(calc, cn2en)
            nb = en_cls.get(nen) == 'distinct'
            db = en_cls.get(den) == 'distinct'
            nk = 'bitmap' if nb else (stem_kw(nen)[1] if nen else 'amt' if '金额' in ntxt else 'qty') or 'qty'
            dk = 'bitmap' if db else (stem_kw(den)[1] if den else 'amt' if '金额' in dtxt else 'qty') or 'qty'
            nn, dd = f'{stem}_numerator_{nk}', f'{stem}_denominator_{dk}'
            nu = (dws_ref(nen) if nen else '') or up0
            du = (dws_ref(den) if den else '') or up0
            if nb: nu = re.sub(r'_qty$', '_bitmap', nu)
            if db: du = re.sub(r'_qty$', '_bitmap', du)
            col(nn, 'BITMAP' if nb else ('DECIMAL(18,2)' if nk == 'amt' else 'BIGINT'),
                f'{name_core}分子（日）：{ntxt}{cond}，单位：{"人" if nb else ("元" if nk == "amt" else "个")}',
                f'{sn(nu) or "来源 DWS"}：当日值{cond}' + (f'（口径 {nen}）' if nen else ''), nu)
            col(dd, 'BITMAP' if db else ('DECIMAL(18,2)' if dk == 'amt' else 'BIGINT'),
                f'{name_core}分母（日）：{dtxt}{cond}，单位：{"人" if db else ("元" if dk == "amt" else "个")}',
                f'{sn(du) or "来源 DWS"}：当日值{cond}' + (f'（口径 {den}）' if den else ''), du)
            agg = lambda x, bm: f'BITMAP_UNION_COUNT({{C}}{x})' if bm else f'SUM({{C}}{x})'
            c['expr'] = {'v': f'{agg(nn, nb)}{" * 100" if kind == "pct" else ""} / NULLIF({agg(dd, db)}, 0)'}
            if snap:
                c['expr']['snap'] = 1

        for d in DERIVS:
            pers = [p[0] for p in PERIODS if applies(d, kind, p[0], bool(mod))]
            if not pers:
                continue
            q = d[2].format(s=stem, k=kw)
            if q in seen_q[c['t']]:
                continue
            seen_q[c['t']][q] = c['mcode']
            u = unit if d[3] == '同口径' else d[3]
            dn = {'VAL': '', 'AVG': '', 'PREV': '上期值', 'LYV': '去年同期值'}.get(d[0], d[1])
            nm = ('日均' + name_core if d[0] == 'AVG' else name_core) + dn
            out_fields.append({'t': c['t'], 'm': c['mcode'], 'code': c['code'], 'mod': mod, 'd': d[0], 'f': q, 'nm': nm, 'unit': u,
                               'kind': kind, 'pers': pers,
                               'type': 'DECIMAL(20,6)' if u in ('%', '百分点') else ('DECIMAL(18,2)' if kw == 'amt' or d[0] == 'AVG' else r0[ai['数据类型']])})
            c['fields'].append(q)

    # 占比的分母：同表同口径、不带修饰词的基础指标
    for c in combos.values():
        if c['mod']:
            b = next((x for x in combos.values() if x['t'] == c['t'] and x['code'] == c['code'] and not x['mod']), None)
            c['share_base'] = b['mcode'] if b else ''

    n_biz = sum(len(f['pers']) for f in out_fields)
    tables = collections.OrderedDict()
    for c in combos.values():
        tables.setdefault(c['t'], []).append(c)

    T0 = anchor or (datetime.date.today() - datetime.timedelta(days=1))
    fmt = lambda x: f'{x[0]:%Y-%m-%d} ~ {x[1]:%Y-%m-%d}' if x else ''
    period_rows = []
    for p in PERIODS:
        rg = ranges(p[0], T0)
        period_rows.append(list(p[:6]) + ['时间表预置' if p[6] else '前端传入起止日'] + ([fmt(rg[0]), fmt(rg[1]), fmt(rg[2])] if rg else ['', '', '']))

    # 日粒度 ADS 的 DDL
    ddl = {}
    for t, cs in tables.items():
        tr = tinfo.get(t)
        dims = [r for r in fields[t] if r[fi['字段类别']] in ('粒度键', '维度属性')]
        cols = [(r[fi['字段名']], r[fi['类型']], r[fi['字段注释']]) for r in dims]
        cols += [(s['f'], s['type'], s['cmt']) for s in store if s['t'] == t]
        cols.append(('etl_time', 'STRING', 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'))
        w = max(len(x[0]) for x in cols) + 1
        tw = max(len(str(x[1])) for x in cols) + 1
        q = lambda s: str(s).replace("'", "\\'").replace('\n', ' ')
        cn = tr[ti['表中文名']] if tr else t
        ddl[t] = (f'CREATE TABLE IF NOT EXISTS ads.{t} (\n' +
                  ',\n'.join(f"  {x[0].ljust(w)}{str(x[1]).ljust(tw)}COMMENT '{q(x[2])}'" for x in cols) +
                  f"\n)\nCOMMENT '{q(cn)}（日粒度；统计周期在查询时关联 dim_opr_period_f）'\n"
                  "PARTITIONED BY (\n  travel_date STRING COMMENT '数据日期，格式 YYYYMMDD'\n)\nSTORED AS ORC;   -- 去重位图列在 StarRocks 用 BITMAP，Hive 侧存 BINARY\n"
                  f'-- 粒度：{tr[ti["粒度"]] if tr else ""}（不变）')

    return {
        'periods': [list(p) for p in PERIODS], 'periodRows': period_rows, 'anchor': T0.isoformat(),
        'derivs': [list(d) for d in DERIVS], 'kindLabel': KIND_LABEL,
        'combos': [{k: c.get(k) for k in ('mcode', 't', 'code', 'mod', 'stem', 'kw', 'kind', 'cls', 'unit', 'base_cn', 'kou', 'calc',
                                           'src', 'use', 'old_periods', 'old_fields', 'store', 'fields', 'expr', 'share_base')}
                   for c in combos.values()],
        'store': store, 'fields': out_fields, 'skipped': skipped, 'problems': problems, 'ddl': ddl,
        'dims': {t: [r[fi['字段名']] for r in fields[t] if r[fi['字段类别']] == '粒度键'] for t in tables},
        'summary': {'combos': len(combos), 'store': len(store), 'fields': len(out_fields), 'biz': n_biz, 'tables': len(tables),
                    'oldOffline': sum(1 for r in A['rows'] if r[ai['离线/实时']] == '离线'),
                    'oldCols': sum(len(c['old']) for c in combos.values()), 'skipped': len(skipped)},
        'periodDimDDL': PERIOD_DIM_DDL, 'holidayDDL': HOLIDAY_DDL,
        '_int': {'combos': combos, 'tables': tables},
    }


def query_sql(model, t, period='N180', limit=6):
    """表级查询示例：日粒度 ADS 关联时间表，一次算出本期 / 上期 / 去年同期，再在外层派生"""
    cs = [c for c in model['combos'] if c['t'] == t][:limit]
    keys = model['dims'].get(t, [])
    R = {'cur': ('p.start_date_no', 'p.end_date_no'), 'prev': ('p.prev_start_date_no', 'p.prev_end_date_no'),
         'ly': ('p.ly_start_date_no', 'p.ly_end_date_no')}

    def ex(c, r):
        s, e = R[r]
        cond = f'a.travel_date = {e}' if c['expr'].get('snap') else f'a.travel_date BETWEEN {s} AND {e}'
        return re.sub(r'\{C\}(\w+)', lambda m: f'CASE WHEN {cond} THEN a.{m.group(1)} END', c['expr']['v'])
    inner, outer = [], []
    for c in cs:
        s, k = c['stem'], c['kw']
        inner.append(f'    -- {c["mcode"]} {c["base_cn"]}（{KIND_LABEL[c["kind"]]}）')
        for r, a in (('cur', f'{s}_{k}'), ('prev', f'{s}_prev_{k}'), ('ly', f'{s}_ly_{k}')):
            inner.append(f'    {ex(c, r)} AS {a},')
        if c['kind'] == 'pct':
            outer += [f'  {s}_{k},', f'  {s}_{k} - {s}_prev_{k} AS {s}_mom_diff_rate,', f'  {s}_{k} - {s}_ly_{k} AS {s}_yoy_diff_rate,']
        else:
            outer += [f'  {s}_{k},']
            if c['kind'] in ('additive', 'once'):
                outer.append(f'  {s}_{k} / period_day_qty AS {s}_daily_avg_{k},')
            outer += [f'  ({s}_{k} - {s}_prev_{k}) * 100 / NULLIF({s}_prev_{k}, 0) AS {s}_mom_rate,',
                      f'  ({s}_{k} - {s}_ly_{k}) * 100 / NULLIF({s}_ly_{k}, 0) AS {s}_yoy_rate,']
    kg = ''.join(f', a.{k}' for k in keys)
    pn = {p[0]: p[1] for p in PERIODS}
    return (f"-- {t}：日粒度 ADS 关联时间表 dim_opr_period_f 按统计周期汇总（示例周期：{period} {pn.get(period, '')}）\n"
            f"-- 换周期只改 period_type_code；节假日再加 holiday_period_code；自定义区间把 p.* 换成前端传入的起止日\n"
            f"-- 以下展示前 {len(cs)} 个基础指标，其余指标写法相同\n"
            "SELECT\n  period_type_code, start_date, end_date" + ''.join(f', {k}' for k in keys) + ',\n'
            + '\n'.join(outer).rstrip(',') + "\nFROM (\n  SELECT\n    p.period_type_code, p.start_date, p.end_date, p.period_day_qty" + kg + ',\n'
            + '\n'.join(inner).rstrip(',') +
            f"\n  FROM ads.{t} a\n  JOIN dim.dim_opr_period_f p\n    ON p.anchor_date_no = '${{T}}'\n   AND p.period_type_code = '{period}'\n"
            "   AND a.travel_date BETWEEN p.scan_start_date_no AND p.end_date_no   -- 只扫本期、上期、去年同期覆盖的分区\n"
            + (f"  WHERE a.{keys[0]} = ${{{keys[0]}}}\n" if keys else '') +
            f"  GROUP BY p.period_type_code, p.start_date, p.end_date, p.period_day_qty{kg}\n) x;\n\n"
            "-- 按月看趋势（任意分组：周 / 月 / 季 / 半年 / 年 / 节假日 / 周末）：关联日期表 dim_opr_date_f\n"
            f"SELECT d.month_start_date, {', '.join(ex_simple(c) for c in cs[:2])}\nFROM ads.{t} a\n"
            "JOIN dim.dim_opr_date_f d ON d.date_no = a.travel_date\nWHERE a.travel_date BETWEEN '${start_date}' AND '${end_date}'\n"
            "  -- AND d.holiday_type = 2          -- 只看法定节假日\n  -- AND d.vacation_type = 2         -- 只看暑假\n"
            "GROUP BY d.month_start_date\nORDER BY d.month_start_date;")


def ex_simple(c):
    return re.sub(r'\{C\}', 'a.', c['expr']['v']) + f' AS {c["stem"]}_{c["kw"]}'


HOLIDAY_DDL = """CREATE TABLE IF NOT EXISTS dim.dim_opr_holiday_period_f (
  holiday_period_code      STRING  COMMENT '节假日区间编码，如 2026_national_day',
  year_no                  INT     COMMENT '年份，如 2026',
  holiday_code             STRING  COMMENT '节假日编码：new_year-元旦，spring_festival-春节，qingming-清明，labour_day-劳动节，dragon_boat-端午，mid_autumn-中秋，national_day-国庆',
  holiday_name             STRING  COMMENT '节假日名称，如 国庆节；与中秋合并放假时写 国庆节·中秋节',
  start_date               STRING  COMMENT '放假首日，格式 YYYYMMDD',
  end_date                 STRING  COMMENT '放假末日，格式 YYYYMMDD',
  holiday_day_qty          INT     COMMENT '放假天数',
  adjust_workday_desc      STRING  COMMENT '调休上班日，多个用逗号分隔，格式 YYYYMMDD',
  last_year_period_code    STRING  COMMENT '同比对齐的去年区间编码；去年无同名独立假期时为空',
  etl_time                 STRING  COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '节假日放假区间（每年按国务院放假安排维护）'
STORED AS ORC;

-- dim_opr_date_f 补充字段
ALTER TABLE dim.dim_opr_date_f ADD COLUMNS (
  half_year_no             INT     COMMENT '半年：1-上半年，2-下半年',
  quarter_start_date       STRING  COMMENT '所在季度第一天，格式 yyyy-MM-dd',
  year_start_date          STRING  COMMENT '所在年第一天，格式 yyyy-MM-dd',
  holiday_period_code      STRING  COMMENT '所属节假日区间编码，关联 dim_opr_holiday_period_f；非假期为空',
  holiday_day_no           INT     COMMENT '节假日第 N 天（从 1 开始）；非假期为空',
  lunar_date_code          STRING  COMMENT '农历日期，如 正月初一（春节同比对齐用）',
  last_year_same_day_date  STRING  COMMENT '同比对齐日：假期内取去年同一假期第 N 天，否则取 364 天前（同星期），格式 yyyy-MM-dd'
);"""


PERIOD_DIM_DDL = """CREATE TABLE IF NOT EXISTS dim.dim_opr_period_f (
  anchor_date_no          STRING  COMMENT '统计截止日 T，格式 YYYYMMDD（查询时传入，通常为昨天）',
  period_type_code        STRING  COMMENT '""" + PERIOD_CODE_DESC + """',
  period_name             STRING  COMMENT '统计周期名称，如 近半年、2026 国庆节',
  holiday_period_code     STRING  COMMENT '节假日区间编码（HOL 时有值），关联 dim_opr_holiday_period_f',
  start_date_no           STRING  COMMENT '本期开始日，格式 YYYYMMDD',
  end_date_no             STRING  COMMENT '本期结束日，格式 YYYYMMDD',
  period_day_qty          INT     COMMENT '本期天数',
  prev_start_date_no      STRING  COMMENT '环比基期开始日，格式 YYYYMMDD',
  prev_end_date_no        STRING  COMMENT '环比基期结束日，格式 YYYYMMDD',
  ly_start_date_no        STRING  COMMENT '同比基期（去年同期）开始日，格式 YYYYMMDD；节假日按去年同一假期',
  ly_end_date_no          STRING  COMMENT '同比基期（去年同期）结束日，格式 YYYYMMDD',
  wow_date_no             STRING  COMMENT '周同比基准日（仅 D1）：T−7，格式 YYYYMMDD',
  scan_start_date_no      STRING  COMMENT '查询需扫描的最早分区 = min(本期、上期、去年同期开始日)，格式 YYYYMMDD',
  start_date              STRING  COMMENT '本期开始日，格式 yyyy-MM-dd（展示用）',
  end_date                STRING  COMMENT '本期结束日，格式 yyyy-MM-dd（展示用）',
  etl_time                STRING  COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '统计周期时间表：每个截止日 × 每种统计周期一行，给出本期/环比基期/同比基期区间。ADS 只存日数据，查询时关联本表按区间汇总；脚本一次生成 2020–2035 年（约 6 千行/年），节假日行按 dim_opr_holiday_period_f 生成'
STORED AS ORC;"""


def to_xlsx(model, path, xlsx_name):
    import openpyxl
    from openpyxl.styles import Font, PatternFill, Alignment
    wb = openpyxl.Workbook()
    hfill, hfont = PatternFill('solid', fgColor='1F2937'), Font(color='FFFFFF', bold=True)

    def sheet(title, cols, rows, widths=None):
        ws = wb.create_sheet(title)
        ws.append(cols)
        for c in ws[1]:
            c.fill, c.font = hfill, hfont
        for r in rows:
            ws.append(['' if v is None else v for v in r])
        ws.freeze_panes = 'A2'
        ws.auto_filter.ref = ws.dimensions
        for i, w in enumerate(widths or [18] * len(cols)):
            ws.column_dimensions[openpyxl.utils.get_column_letter(i + 1)].width = w
        return ws

    wb.remove(wb.active)
    s = model['summary']
    sheet('说明', ['项目', '内容'], [
        ['来源', f'由 {xlsx_name} 的「ADS业务指标」「DWS口径」生成（dw-dict/ads_model.py）'],
        ['思路', 'ADS 保持日粒度，只存能跨天汇总的日数据（可加日值 / 去重位图 / 比率分子分母 / 日快照）。统计周期、日均、环比、同比、占比都在查询时关联时间表 dim_opr_period_f 计算，数据不膨胀。'],
        ['基础指标', f'{s["combos"]} 个（原 {s["oldCols"]} 个按周期写死的 ADS 指标列归并而来）'],
        ['ADS 存储字段', f'{s["store"]} 个（原 {s["oldCols"]} 列）'],
        ['查询指标', f'{s["fields"]} 个（基础指标 × 派生方式：本期值/日均/上期值/环比/去年同期值/同比/周同比/占比）'],
        ['业务指标', f'{s["biz"]:,} 个（查询指标 × 适用统计周期，逐条见「业务指标清单」）'],
        ['统计周期', '时间表预置 17 种 + 自定义起止日，规则见「统计周期」'],
        ['未改造', f'{s["skipped"]} 个原指标（分时表、未来游玩日看板、月结套餐表、可下线的周/月报、已并入派生方式的环比/同比口径），见「未改造指标」'],
    ], [16, 120])
    sheet('统计周期', ['周期编码', '名称', '分组', '本期区间', '环比基期', '同比基期', '来源', f'示例本期（T={model["anchor"]}）', '示例环比基期', '示例同比基期'],
          model['periodRows'], [10, 10, 14, 36, 30, 30, 14, 26, 26, 26])
    sheet('派生方式', ['派生编码', '名称', '查询结果列名', '单位', '计算方式', '适用聚合方式', '适用周期'], model['derivs'], [10, 14, 26, 10, 70, 34, 10])
    sheet('基础指标', ['基础指标编码', 'ADS表', '口径编码', '修饰词', '指标名', '聚合方式', '单位', '业务口径', '计算公式', 'ADS 存储字段', '区间汇总表达式', '原字段（已合并）', '来源 DWS', '使用端'],
          [[c['mcode'], c['t'], c['code'], c['mod'], c['base_cn'], KIND_LABEL.get(c['kind']), c['unit'], c['kou'], c['calc'],
            '、'.join(c['store']), ex_simple(c), '、'.join(c['old_fields']), c['src'], c['use']] for c in model['combos']],
          [12, 34, 9, 20, 24, 10, 8, 50, 50, 40, 50, 50, 34, 14])
    sheet('ADS存储字段', ['ADS表', '字段名', '类型', '注释', '加工 / 来源', '上游字段', '基础指标'],
          [[x['t'], x['f'], x['type'], x['cmt'], x['proc'], x['up'], x['m']] for x in model['store']], [34, 34, 14, 70, 50, 50, 10])
    pn = {p[0]: p[1] for p in model['periods']}
    dn = {d[0]: d for d in model['derivs']}
    cm = {c['mcode']: c for c in model['combos']}
    rows = []
    for f in model['fields']:
        c = cm[f['m']]
        for p in f['pers']:
            rows.append([f"{f['m']}-{p}-{f['d']}", pn[p] + f['nm'], f['t'], f['f'], p, pn[p], dn[f['d']][1], f['unit'],
                         '前端传入起止日' if p == 'CUS' else f"关联 dim_opr_period_f（period_type_code='{p}'）",
                         ex_simple(c).split(' AS ')[0], dn[f['d']][4], f['m'], f['code'], f['mod']])
    sheet('业务指标清单', ['业务指标编码', '业务指标名', 'ADS表', '查询列名', '周期编码', '统计周期', '派生方式', '单位', '时间关联',
                       '汇总表达式（ADS 日字段）', '计算方式', '基础指标', '口径编码', '修饰词'], rows,
          [22, 36, 34, 30, 8, 10, 12, 8, 34, 50, 60, 10, 9, 18])
    sheet('未改造指标', ['原指标编码', '原指标名', 'ADS表', '字段名', '处理'], model['skipped'], [12, 30, 34, 34, 60])
    ws = sheet('表结构与查询', ['表', 'DDL', '查询示例'],
               [[t, model['ddl'][t], query_sql(model, t)] for t in model['ddl']] +
               [['dim_opr_period_f', model['periodDimDDL'], ''], ['dim_opr_holiday_period_f / dim_opr_date_f', model['holidayDDL'], '']],
               [34, 100, 100])
    for row in ws.iter_rows(min_row=2):
        for c in row:
            c.alignment = Alignment(wrap_text=True, vertical='top')
    wb.save(path)
    return len(rows)


# ---------------------------------------------------------------- 写回字典
def _ddl_cols(ddl):
    """从 CREATE TABLE / ALTER TABLE ADD COLUMNS 文本里取 (字段, 类型, 注释)"""
    return re.findall(r"^\s+(\w+)\s+([A-Z]+(?:\([\d,]+\))?)\s+COMMENT '([^']*)'", ddl, re.M)


def apply_to_dictionary(sheets, model, chk):
    """返回改造后的字典（深拷贝）：ADS 周期列合并为日字段、DWS 去重类补 BITMAP、新增时间表。
    同时返回 changed = {表名: 改造说明}，页面据此显示「改造前」对照。"""
    import copy
    S = copy.deepcopy(sheets)
    it = model['_int']
    combos, tables = it['combos'], it['tables']
    T, F, A, D, L = S['表清单'], S['字段清单'], S['ADS业务指标'], S['DWS口径'], S['分层汇总']
    ti = {c: i for i, c in enumerate(T['cols'])}
    fi = {c: i for i, c in enumerate(F['cols'])}
    ai = {c: i for i, c in enumerate(A['cols'])}
    di = {c: i for i, c in enumerate(D['cols'])}
    sn = lambda s: re.sub(r'^\w+\.', '', str(s or '').strip())
    changed = {}
    dn = {d[0]: d for d in DERIVS}

    def frow(layer, t, cn, no, name, typ, cat, cmt, proc, up):
        r = [''] * len(F['cols'])
        for k, v in (('分层', layer), ('表名（库.表）', t), ('表中文名', cn), ('序号', no), ('字段名', name), ('类型', typ),
                     ('字段类别', cat), ('字段注释', cmt), ('加工 / 来源', proc), ('上游字段', up)):
            r[fi[k]] = v
        return r

    trow = {sn(r[ti['表名（库.表）']]): r for r in T['rows']}
    by_t = collections.OrderedDict()
    for r in F['rows']:
        by_t.setdefault(sn(r[fi['表名（库.表）']]), []).append(r)

    # ---- 1. DWS 去重类口径补 BITMAP 列，SUM 上卷改 BITMAP_UNION
    for r in D['rows']:
        if chk['mclass'].get(r[di['口径编码']]) != 'distinct':
            continue
        en = r[di['英文名']]
        bm = re.sub(r'_qty$', '', en) + '_bitmap'
        for t in re.split(r'[、,，\s]+', str(r[di['落地 DWS 表']])):
            t = sn(t)
            if not t or t.endswith('_rt') or t not in by_t:
                continue
            rows = by_t[t]
            k = next((i for i, x in enumerate(rows) if x[fi['字段名']] == en), None)
            if k is None or any(x[fi['字段名']] == bm for x in rows):
                continue
            q = rows[k]
            proc = str(q[fi['加工 / 来源']])
            summed = '汇总' in proc or 'SUM' in proc.upper()
            src_t = proc.split('.')[0] if summed else ''
            new = frow(q[fi['分层']], q[fi['表名（库.表）']], q[fi['表中文名']], 0, bm, 'BITMAP', '指标',
                       f"{r[di['中文名']]}去重位图：{r[di['业务口径']]}；任意周期用 BITMAP_UNION_COUNT 去重，单位：人",
                       f'BITMAP_UNION({src_t}.{bm})' if summed else re.sub(r'count\(distinct ([^)]+)\)', r'BITMAP_UNION(TO_BITMAP(\1))', proc, flags=re.I),
                       q[fi['上游字段']].replace(en, bm) if summed else q[fi['上游字段']])
            if summed:
                q[fi['加工 / 来源']] = f'BITMAP_UNION_COUNT({bm})（原为 {proc}；改为位图后可跨周期、跨维度去重）'
                q[fi['上游字段']] = f'{q[fi["表名（库.表）"]]}.{bm}'
            rows.insert(k + 1, new)
            tr = trow[t]
            if '_bitmap' not in str(tr[ti['备注']]):
                tr[ti['备注']] = (str(tr[ti['备注']]) + '；' if tr[ti['备注']] else '') + '【改造】去重类指标新增 *_bitmap 列，支持任意统计周期去重'
            changed.setdefault(t, '去重类指标新增 BITMAP 列（任意周期去重）；SUM 上卷改为 BITMAP_UNION')

    # ---- 2. ADS 表：日粒度不变，周期列合并为可跨天汇总的日字段
    st = model['store']
    for t, cs in tables.items():
        old = by_t.get(t, [])
        if not old:
            continue
        L0, full, cn = old[0][fi['分层']], old[0][fi['表名（库.表）']], old[0][fi['表中文名']]
        rows = [list(r) for r in old if r[fi['字段类别']] in ('粒度键', '维度属性')]
        rows += [frow(L0, full, cn, 0, x['f'], x['type'], '指标', x['cmt'], x['proc'], x['up']) for x in st if x['t'] == t]
        rows.append(frow(L0, full, cn, 0, 'etl_time', 'STRING', 'ETL', 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss', '系统生成', ''))
        rows.append(frow(L0, full, cn, 0, 'travel_date', 'STRING', '分区', '数据日期，格式 YYYYMMDD', '${bizdate}', ''))
        by_t[t] = rows
        tr = trow[t]
        kinds = collections.Counter(c['kind'] for c in cs)
        nst = sum(1 for x in st if x['t'] == t)
        nb = sum(len(x['pers']) for x in model['fields'] if x['t'] == t)
        tr[ti['度量 / 口径 / 关键字段']] = (f'日粒度基础指标 {len(cs)} 个 → 存储字段 {nst} 个（' +
                                           '、'.join(f'{KIND_LABEL[k]} {v}' for k, v in kinds.items()) +
                                           f'）；统计周期、日均、环比、同比、占比在查询时关联 dim_opr_period_f 计算，可得业务指标 {nb:,} 个')
        tr[ti['备注']] = (str(tr[ti['备注']]) + '；' if tr[ti['备注']] else '') + '【改造】按周期写死的列合并为日字段（比率存分子分母、去重存位图）；周期在查询时关联时间表'
        old_n = sum(len(c['old']) for c in cs)
        changed[t] = f'日粒度不变；{old_n} 个按周期写死的指标列合并为 {nst} 个日字段（比率存分子分母、去重存位图），周期查询时关联时间表'
    for r in model['skipped']:
        t = r[2]
        if t in ('ads_sup_tenant_trade_wk', 'ads_sup_tenant_trade_mo') and t in trow and '建议下线' not in str(trow[t][ti['备注']]):
            trow[t][ti['备注']] = (str(trow[t][ti['备注']]) + '；' if trow[t][ti['备注']] else '') + f'【改造】{r[4]}'
            changed.setdefault(t, '建议下线：日粒度 ADS 关联时间表 LW/LM 即可得到周报、月报')

    # ---- 3. 新增 / 扩展日期类维表
    def add_table(name, cn, grain, src, keys, down, ddl):
        cols = _ddl_cols(ddl)
        r = [''] * len(T['cols'])
        for k, v in (('分层', 'DIM'), ('业务域', 'opr'), ('表名（库.表）', f'dim.{name}'), ('表中文名', cn), ('粒度', grain),
                     ('后缀含义', '非分区全量'), ('分区', '无分区'), ('来源', src), ('度量 / 口径 / 关键字段', keys),
                     ('上游表', ''), ('下游表', down), ('备注', '【新增】时间表：ADS 日数据查询时关联，按当日/周/月/季/半年/年/近N日/节假日/自定义区间汇总')):
            r[ti[k]] = v
        last_dim = max(i for i, x in enumerate(T['rows']) if x[ti['分层']] == 'DIM')
        T['rows'].insert(last_dim + 1, r)
        trow[name] = r
        by_t[name] = [frow('DIM', f'dim.{name}', cn, 0, c, ty, 'ETL' if c == 'etl_time' else ('粒度键' if c in keys else '维度属性'),
                           cm, '脚本生成' if 'period' in name else '人工维护（国务院放假安排）', '') for c, ty, cm in cols]
        changed[name] = '新增表'

    ads_ts = '查询时关联：' + '、'.join(tables)
    add_table('dim_opr_holiday_period_f', '节假日放假区间', '1行=1个年度×1个节假日', '人工维护（每年 12 月按国务院放假安排录入次年）',
              'holiday_period_code', 'dim_opr_period_f、dim_opr_date_f', HOLIDAY_DDL.split('-- dim_opr_date_f')[0])
    add_table('dim_opr_period_f', '统计周期时间表', '1行=1个截止日×1种统计周期', '脚本生成（dim_opr_date_f + dim_opr_holiday_period_f）',
              'anchor_date_no、period_type_code、holiday_period_code', ads_ts, PERIOD_DIM_DDL)
    trow['dim_opr_holiday_period_f'][ti['上游表']] = ''
    trow['dim_opr_period_f'][ti['上游表']] = 'dim_opr_date_f、dim_opr_holiday_period_f'
    if 'dim_opr_date_f' in by_t:
        extra = _ddl_cols(HOLIDAY_DDL.split('-- dim_opr_date_f')[1])
        have = {x[fi['字段名']] for x in by_t['dim_opr_date_f']}
        o = by_t['dim_opr_date_f'][0]
        rows = by_t['dim_opr_date_f']
        pos = next((i for i, x in enumerate(rows) if x[fi['字段名']] == 'etl_time'), len(rows))
        for c, ty, cm in extra:
            if c not in have:
                rows.insert(pos, frow('DIM', o[fi['表名（库.表）']], o[fi['表中文名']], 0, c, ty, '维度属性', cm, '脚本生成（含 dim_opr_holiday_period_f）', ''))
                pos += 1
        tr = trow['dim_opr_date_f']
        tr[ti['下游表']] = '、'.join([x for x in re.split(r'[、,，\s]+', str(tr[ti['下游表']])) if x] + ['dim_opr_period_f'])
        tr[ti['备注']] = (str(tr[ti['备注']]) + '；' if tr[ti['备注']] else '') + '【改造】补半年度、节假日区间、节假日第N天、农历、同比对齐日等 7 个字段'
        changed['dim_opr_date_f'] = '补 7 个统计周期字段（半年度、节假日区间、同比对齐日等）'

    # 字段清单按表顺序重排、重新编号
    F['rows'] = []
    for r in T['rows']:
        t = sn(r[ti['表名（库.表）']])
        for i, x in enumerate(by_t.get(t, []), 1):
            x[fi['序号']] = i
            F['rows'].append(x)
    for i, r in enumerate(T['rows'], 1):
        r[ti['序号']] = i

    # ---- 4. ADS业务指标：改造表按「查询指标」登记（统计周期在查询时选择），其余保留原样
    new = []
    cm = {c['mcode']: c for c in combos.values()}
    dn = {d[0]: d for d in DERIVS}
    for f in model['fields']:
        c = cm[f['m']]
        r0 = list(c['old'][0])
        tr = trow[f['t']]
        per = '全部 18 种' if len(f['pers']) == len(PERIODS) else ('仅当日' if f['pers'] == ['D1'] else f'{len(f["pers"])} 种（不含当日）')
        expr = ex_simple({'expr': c['expr'], 'stem': c['stem'], 'kw': c['kw']}).split(' AS ')[0]
        vals = {'指标编码': f"{f['m']}-{f['d']}", '业务指标名': f['nm'], '字段名': f['f'],
                '业务口径': c['kou'] if f['d'] == 'VAL' else dn[f['d']][4],
                '计算公式': f"{dn[f['d']][1]}：{dn[f['d']][4]}；区间汇总 = {expr}（ADS 日字段：{'、'.join(c['store'])}）",
                '单位': f['unit'], '统计周期': f'{per}（查询时关联 dim_opr_period_f）', '修饰词': c['mod'] or '—', '数据类型': f['type'],
                '精度/展示': '百分数数值（已乘 100），保留 6 位小数' if f['unit'] == '%' else ('百分点，保留 6 位小数' if f['unit'] == '百分点' else r0[ai['精度/展示']]),
                '更新频率': '每日 T+1（ADS 日数据）；周期查询时计算', '口径类型': r0[ai['口径类型']] if f['d'] == 'VAL' else '派生指标',
                '分析粒度': tr[ti['粒度']] + ' × 统计周期（查询时）'}
        for k, v in vals.items():
            if k in ai:
                r0[ai[k]] = v
        new.append(r0)
    keep = [r for r in A['rows'] if r[ai['离线/实时']] != '离线' or sn(r[ai['ADS表']]) not in tables]
    A['rows'] = new + keep

    # ---- 5. 分层汇总
    li = {c: i for i, c in enumerate(L['cols'])}
    for r in L['rows']:
        if r[0] == 'ADS':
            r[li['指标产出']] = f'日粒度基础指标 {model["summary"]["combos"]} 个；关联时间表 × 18 种统计周期 × 派生方式 = 业务指标 {model["summary"]["biz"]:,} 个（离线）'
            r[li['说明']] = str(r[li['说明']]) + '；日粒度存储，统计周期在查询时关联时间表'
        if r[0] == 'DIM':
            r[li['表数']] = sum(1 for x in T['rows'] if x[ti['分层']] == 'DIM')
            r[li['说明']] = str(r[li['说明']]) + '；新增统计周期时间表、节假日区间表'
    # 分层汇总里的「统计周期」说明换成新的周期编码
    rows = L['rows']
    k = next((i for i, r in enumerate(rows) if r[0] == '统计周期'), None)
    if k is not None:
        e = next((i for i in range(k + 1, len(rows)) if rows[i][0] in ('修饰词', '业务域前缀')), len(rows))
        rt = [r for r in rows[k + 1:e] if 'today' in str(r[0])]
        blank = lambda a, b: [a, b] + [''] * (len(L['cols']) - 2)
        new = [blank(p[0], f'{p[1]}：{p[3]}' + ('（前端传入起止日）' if not p[6] else '')) for p in PERIODS]
        rows[k + 1:e] = new + rt
        rows[k][1] = '含义（时间表 dim_opr_period_f 的 period_type_code，查询时关联）'
    return S, changed


def dict_xlsx(sheets, changed, path):
    """改造后的完整字典（与客户原 Excel 同样的工作表和表头），改动行标黄"""
    import openpyxl
    from openpyxl.styles import Font, PatternFill
    wb = openpyxl.Workbook()
    wb.remove(wb.active)
    hfill, hfont, mark = PatternFill('solid', fgColor='1F2937'), Font(color='FFFFFF', bold=True), PatternFill('solid', fgColor='FFF4CC')
    for name, d in sheets.items():
        ws = wb.create_sheet(name)
        ws.append(d['cols'])
        for c in ws[1]:
            c.fill, c.font = hfill, hfont
        tcol = next((i for i, c in enumerate(d['cols']) if c in ('表名（库.表）', 'ADS表', '表名')), None)
        for r in d['rows']:
            ws.append(['' if v is None else v for v in r])
            if tcol is not None and str(r[tcol]).split('.', 1)[-1] in changed:
                for c in ws[ws.max_row]:
                    c.fill = mark
        ws.freeze_panes = 'A2'
        for i, c in enumerate(d['cols'], 1):
            ws.column_dimensions[openpyxl.utils.get_column_letter(i)].width = 14 if len(str(c)) < 6 else 24
    ws = wb.create_sheet('改造说明', 0)
    ws.append(['表名', '改造内容'])
    for c in ws[1]:
        c.fill, c.font = hfill, hfont
    for k, v in changed.items():
        ws.append([k, v])
    ws.column_dimensions['A'].width, ws.column_dimensions['B'].width = 40, 100
    wb.save(path)
