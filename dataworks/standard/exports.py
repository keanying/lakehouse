"""旧系统导出（hive_to_db）应用层模型 → 标准 ADS 的覆盖核对，以及同一指标多口径的识别与统一。

- 覆盖：每个导出字段解码为「标准指标 + 维度」，在标准 ADS 中找能提供它的表（直接有 / 关联维表可得 / 时间表派生）；都没有的记为缺口并补进 ADS。
- 多口径：沿旧 SQL 血缘追到底层公式（lineage.py 缓存在 legacy_formulas.json），按 时间口径 / 计数方式 / 过滤条件 / 来源 归纳成口径标签，
  同一标准指标下出现多个标签即「同指标多口径」，统一为标准口径，并把每个旧口径与标准的差异写进字典。
"""
import collections, json, pathlib, re

import legacy_metrics as LM
import field_map

HERE = pathlib.Path(__file__).resolve().parent

# 由票 / 渠道 / 景区等维度关联即可得到的维度（不需要进 ADS 粒度）
DERIVABLE = {'product_id': 'ticket_id', 'product_type': 'ticket_id', 'supplier_id': 'ticket_id', 'scenic_id': 'ticket_id',
             '维度名称（关联维表）': None, '统计周期（时间表）': None}
MLOC = re.compile(r'company|s_company|merchant|member|user_|supplier_overview')
LOC = re.compile(r'park|inout|terminal|retail|hotel|aioc|allinone|passenger|tourist_in_out')
STD_DATE = {'order': '下单日', 'pay': '支付日', 'cancel': '取消日', 'verify': '验证日', 'finish': '完结日', 'revoke': '撤销日', 'print': '取票日', 'after_sale': '售后日'}


def load_formulas():
    p = HERE / 'legacy_formulas.json'
    return json.loads(p.read_text(encoding='utf-8')) if p.exists() else {}


def _norm(f):
    f = re.sub(r'\b[a-z_]\w*\.(?=[`\w])', '', f or '')
    f = re.sub(r"'?20250101'?", 'T', f)
    return re.sub(r'\s+', ' ', f).replace('`', '')


def label(trace):
    """底层公式 + 过滤 → 口径标签：时间口径 · 计数方式 · 过滤 · 来源"""
    if not trace:
        return '未追到公式（来源不在导出包内）', ''
    bt, bf, bw = trace[-1]
    f, w = _norm(bf), _norm(bw)
    parts = []
    m = re.search(r'\b(orderdate|order_date|booking_date|insertdate|insert_date|paydate|pay_date|verify_date|checkdate|travel_date|date|stat_date|playdate|play_date)\s*(=|>=|BETWEEN)', w, re.I)
    if m:
        k = m.group(1).lower()
        parts.append({'orderdate': '按下单日', 'order_date': '按下单日', 'booking_date': '按下单日', 'insertdate': '按操作（轨迹）日', 'insert_date': '按操作（轨迹）日',
                      'paydate': '按支付日', 'pay_date': '按支付日', 'verify_date': '按验证日', 'checkdate': '按验证日', 'playdate': '按游玩日', 'play_date': '按游玩日'}.get(k, f'按 {k}'))
    if re.search(r'COUNT\(DISTINCT', f, re.I):
        parts.append('订单号去重计数')
    elif re.search(r'SUM\(IF\([^,]+,\s*1,\s*0\)\)|COUNT\(1\)|COUNT\(\*\)|SUM\(CASE WHEN .* THEN 1 ELSE 0 END\)', f, re.I):
        parts.append('按行计数')
    else:
        cols = sorted(set(re.findall(r'\b(tnum|pay_num|ticket_num|booking_num|origin_num|verify_num|order_ticket|sale_price|tprice|totalmoney|order_pay_amount|'
                                     r'total_amount|settlement_money|payment_money|sell_price|quantity|cost_price|aprice|lprice)\b', f, re.I)))
        if cols:
            parts.append('取 ' + '×'.join(c.lower() for c in cols))
    flt = []
    for pat, txt in ((r'pay_num\s*>\s*0|pay_ticket_num\s*>\s*0|pay_status', '仅已支付'), (r'apply_did\s*=\s*sellerid', '仅一级分销（直销链首级）'),
                     (r'level\s+IN\s*\(0,\s*1\)', '分销层级 0/1'), (r'sid\s*<>\s*reseller_id', '排除自购'), (r'is_test|order_is_test', '排除测试'),
                     (r"tid\s*<>\s*-1", '排除无效票'), (r"order_type\s*(<>|!=)\s*'套票子票'|order_type\s+IN\s*\('套票主票', '单票'\)", '只算主单'),
                     (r"order_type\s*=\s*'套票子票'|order_type\s+IN\s*\('套票子票'\)", '只算子单'), (r'verify_ticket\s*\+\s*finish_ticket', '验证含完结'),
                     (r'cancel_ticket\s*\+\s*revoke_ticket', '取消含撤销'), (r'\*\s*100\b', '金额 ×100（元→分）'), (r'/\s*100\b', '金额 ÷100（分→元）'),
                     (r"ticket_type\s*=\s*'SELL'", '仅销售单'), (r'is_first_used', '仅首次使用')):
        if re.search(pat, f + ' ' + w, re.I):
            flt.append(txt)
    parts += flt
    src = '业务库报表库预计算' if re.search(r'report_|daycount|summary', bt) and not re.search(r'COUNT|IF\(', f) else f'明细重算（{bt}）'
    parts.append(src)
    return ' · '.join(dict.fromkeys(parts)), f'{bf}' + (f'  WHERE {bw}' if bw else '')


def analyse(nodes, C, mapping_rows, ads_specs, metrics, resolve=None, dims=(), blocked=()):
    """mapping_rows: 旧表映射；ads_specs: {ADS表: set(字段)}；metrics: 标准口径 M
    → (覆盖明细行, 口径统一行, {指标: 注释}, {ADS表: [补全指标]})"""
    F = load_formulas()
    exp_to_std = {r[0]: r[5] for r in mapping_rows if r[1] != 'Hive'}
    cover, var = [], collections.defaultdict(lambda: collections.defaultdict(list))
    gaps = collections.defaultdict(set)
    for n in nodes:
        if not (n['type'] == 'DI' and n['di'] and n['di'].get('reader', {}).get('type') == 'hive' and n['di'].get('writer', {}).get('type') not in ('hive', None)):
            continue
        r, w = n['di']['reader'], n['di']['writer']
        if not r.get('tables') or not w.get('tables'):
            continue
        ht = str(r['tables'][0]).lower().split('.')[-1]
        target = f"{w.get('datasource')}.{str(w['tables'][0]).lower().split('.')[-1]}"
        std = exp_to_std.get(target, '')
        rc = [c.lower().strip('`') for c in r.get('columns') or [] if isinstance(c, str)]
        wc = [c.lower().strip('`') for c in w.get('columns') or [] if isinstance(c, str)]
        dims = [LM.dim_of(c) for c in rc]
        grain = {d for d in dims if d and d not in DERIVABLE}
        if LOC.search(ht) or MLOC.search(ht + ' ' + target):   # 业态类旧表的省市 = 景区所在地；商户类 = 商户所在地：都由维表带出
            grain -= {'province_code', 'city_code', 'district_code'}
        for i, c in enumerate(rc):
            out = wc[i] if i < len(wc) else c
            d = LM.decode(c, ht + ' ' + target)
            x = field_map.decode(out, ht + ' ' + target) or field_map.decode(c, ht + ' ' + target)
            if x and (not d or d['metric'] not in metrics or x[0] in metrics):
                d = {'metric': x[0], 'role': 'ALL', 'cum': False, 'dims': {k: v for k, v in x[1].items() if k in dims},
                     'note': '、'.join(f'{k}={v}' for k, v in x[1].items() if k not in dims)}
            if not d:
                dm = LM.dim_of(c)
                rv = (resolve(c, std) or resolve(out, std)) if resolve and not dm else None
                if rv:
                    cover.append([target, out, ht, c, '', rv[0], std, rv[0], rv[1], '', ''])
                    continue
                kind = '维度' if dm else '其他'
                how = (f'维度 → {dm}' if dm else field_map.gap_reason(out, ht + ' ' + target) or '非指标字段（明细 / 配置 / 备注）')
                cover.append([target, out, ht, c, '', kind, std, '维度' if dm else '—', how, '', ''])
                continue
            m = d['metric']
            need = set(grain) | set(d['dims'])
            if d['role'] != 'ALL':
                need.add('order_role')
            have = None
            if m in metrics:
                for t, fs in ads_specs.items():
                    if m in fs and need <= fs:
                        have = t
                        if t == std:
                            break
            trace = F.get(f'{ht}.{c}', [])
            lab, formula = label(trace)
            blk = sorted(x for x in ({m} | {f'dim:{y}' for y in need}) if (std, x) in blocked)
            if have:
                status = '已覆盖' + ('（时间表派生）' if d['cum'] or '统计周期（时间表）' in dims else '')
            elif blk:
                status = '缺口（标准表来源不支持：' + '、'.join(x.replace('dim:', '维度 ') for x in blk) + '）'
            elif m in metrics and (std in ads_specs or m.split('_')[0] in STD_DATE):
                status = '补全'
                tgt = std if std in ads_specs else 'ads_ord_scenic_trade_overview_di'
                gaps[tgt].add(m)
                gaps[tgt] |= {f'dim:{x}' for x in need if x not in ads_specs.get(tgt, set())}
                have = tgt
            else:
                status = '缺口（无标准口径）'
            why = '、'.join(filter(None, [f'主子单={d["role"]}' if d['role'] != 'ALL' else '', '、'.join(f'{k}={v}' for k, v in d['dims'].items()), d.get('note', ''),
                                         '累计（_all）' if d['cum'] else '']))
            cover.append([target, out, ht, c, m, '指标', have or '', status, why, lab, formula[:400]])
            if m in metrics:
                var[m][lab].append(f'{target}.{out}')
    # 口径统一：每个标准指标的旧口径清单
    unify, notes = [], {}
    for m, labs in sorted(var.items(), key=lambda x: -sum(len(v) for v in x[1].values())):
        code, en, cn = metrics[m][0], m, metrics[m][2]
        std_txt = metrics[m][6]
        items = sorted(labs.items(), key=lambda x: -len(x[1]))
        for k, (lab, users) in enumerate(items, 1):
            unify.append([code, en, cn, len(items), f'V{k}', lab, len(users), '、'.join(users[:6]) + (' …' if len(users) > 6 else ''), std_txt, diff(lab, m)])
        notes[m] = f'旧系统 {len(items)} 种口径（{sum(len(v) for v in labs.values())} 个导出字段）：' + '；'.join(f'V{k} {lab}（{len(u)} 处）' for k, (lab, u) in enumerate(items[:5], 1)) + (' …' if len(items) > 5 else '')
    return cover, unify, notes, {k: sorted(v) for k, v in gaps.items()}


def diff(lab, m):
    """旧口径相对标准口径的差异说明"""
    act = m.split('_')[0]
    out = []
    std_day = STD_DATE.get(act)
    for k, txt in (('按下单日', '下单日'), ('按操作（轨迹）日', '操作日'), ('按支付日', '支付日'), ('按验证日', '验证日'), ('按游玩日', '游玩日')):
        if k in lab and std_day and txt != std_day:
            out.append(f'时间口径不同：旧按{txt}，标准按{std_day}')
    if '按行计数' in lab and m.endswith('order_qty'):
        out.append('计数方式不同：旧按行计数（拆单 / 多级分销会重复），标准按订单号去重')
    if '仅一级分销' in lab:
        out.append('范围更窄：旧只算直销链首级，标准含全部订单')
    if '验证含完结' in lab:
        out.append('旧验证数含过期完结，标准拆为验证 / 完结两个指标')
    if '取消含撤销' in lab:
        out.append('旧取消数含撤销，标准拆为取消 / 撤销两个指标')
    if '只算主单' in lab or '只算子单' in lab:
        out.append('标准不区分主子单，用维度 order_role 筛选')
    if '元→分' in lab:
        out.append('单位不同：旧金额 ×100 存分，标准统一为元')
    if '业务库报表库预计算' in lab:
        out.append('来源不同：旧取业务库 summary 预计算，标准由明细重算（上线前对数）')
    if '未追到公式' in lab:
        out.append('需人工确认')
    return '；'.join(out) or '与标准一致'
