#!/usr/bin/env python3
"""生成旧系统的标准化数仓字典（与 PFT3.0 Excel 相同的工作表与表头）+ 旧表映射。

用法：python3 dataworks/standard/build.py
输出：dataworks/dist/旧版数仓_标准化字典.xlsx 与 dataworks/standard/dict.json（页面用）
"""
import collections, json, pathlib, re, sys

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parent
sys.path[:0] = [str(ROOT), str(HERE)]
import parse, catalog, audit  # noqa: E402
import rules, model, names, exports  # noqa: E402
import etl as etl_mod  # noqa: E402
import src_ddl  # noqa: E402
import domains  # noqa: E402

sh = catalog.sh
LAYER_CN = {'ODS': '原始数据层', 'DIM': '维度层', 'DWD': '明细层', 'DWS': '汇总层', 'ADS': '应用层'}
SUFFIX = {'di': '天级增量', 'df': '天级全量', 'f': '非分区全量', 'zip': '拉链', 'hrs': '小时级增量', 'mo': '月级增量'}
PIVOT = re.compile(r'^(main|sub)_(male|female|unknown|total|group_\d)|_age_\d+(to\d+|plus)|_all$|^(male|female)_age|_\d+$')
TECH = {'sync_status', 'idx', 'record_id', 'mainid', 'requestid', 'oa_request_id', 'sqr', 'sqbm', 'sqrq', 'lcbh', 'bz', 'htbh', 'lock_status', 'site_id', 'ext_content'}
ETL_COLS = {'etl_time', 'dw_ins_time', 'inserttime', 'insert_time', 'sync_create_time', 'sync_update_time', 'modedatacreatedate', 'modedatacreatetime',
            'modeuuid', 'modedatacreater', 'modedatacreatertype', 'modedatamodifier', 'modedatamodifydatetime', 'formmodeid'}


def suffix_of(name):
    m = re.search(r'_(di|df|f|zip|hrs|mo)$', name)
    return SUFFIX.get(m.group(1), '') if m else ''


def category(n, keys, layer):
    if n in keys[:1] and layer in ('DIM', 'DWD', 'ODS'):
        return '主键'
    if n in keys and layer in ('DWS', 'ADS'):
        return '粒度键'
    if n in keys and n.endswith(('_no', '_code')):
        return '业务主键'
    if n == 'etl_time':
        return 'ETL'
    if re.search(r'_(qty|amt|rate|bitmap|pv|value)$', n):
        return '度量'
    if re.search(r'(_time|_date|_date_no)$', n):
        return '时间'
    if re.search(r'(_status|_type|_flag|^is_|_mode|_level|_role)$', n) or n.startswith('is_'):
        return '状态类型'
    if re.search(r'_(id|no|code)$', n):
        return '外键'
    return '维度属性'


SRCDDL, SRCDEP = {}, {}
DEAD = {}   # 随上游下线的标准表


def dep_text(d):
    return '客户标记弃用' + (f"（{d['reason']}" + (f"，{d['note']}" if d.get('note') else '') + '）' if d.get('reason') else '')


def ddl_col(lds, ltb, c):
    """客户提供的业务库 DDL 中的列（无则 None）"""
    d = SRCDDL.get(f'{lds}:{ltb}')
    if not d:
        return None
    return next((x for x in d['cols'] if x['n'].lower() == c.lower()), None)


def guess_type(n):
    """标准化后新增字段的类型：按命名规范的后缀推断"""
    for pat, ty in ((r'_amt$', 'DECIMAL(18,2)'), (r'_(qty|pv)$', 'BIGINT'), (r'_rate$', 'DECIMAL(20,6)'), (r'_(flag|level|hour)$|^stat_hour$', 'INT'), (r'_id$', 'BIGINT')):
        if re.search(pat, n):
            return ty
    return 'STRING'


def fix_mojibake(s):
    """旧 DDL 里有 UTF-8 被按 cp1252 解读的注释（如 å–ç¥¨äºº），还原"""
    if not s or not re.search(r'[\u00c0-\u00ff][\u0080-\u00ff\u0152-\u2122]', s):
        return s
    try:
        b = b''.join(bytes([ord(ch)]) if ord(ch) < 256 else ch.encode('cp1252') for ch in s)
        return b.decode('utf-8')
    except (UnicodeEncodeError, UnicodeDecodeError):
        return ''          # 转码时已丢字节，无法还原：置空，交给字段中文名补齐


PFT3 = None


def build():
    global PFT3
    import openpyxl
    wb = openpyxl.load_workbook(next((ROOT.parent / 'dw-dict' / 'dist').glob('*_改造版.xlsx')), read_only=True, data_only=True)
    PFT3 = {n: {'cols': None, 'rows': [list(r) for r in wb[n].iter_rows(values_only=True)][1:]} for n in ('表清单', '字段清单')}
    nodes = parse.load(ROOT.parent / 'DATAWORKS.zip')
    C = catalog.build(nodes)
    T, S, SC = C['tables'], C['sources'], C['schemas']
    tables, fields, mapping = [], [], {}
    global SRCDDL, SRCDEP
    got, notes_ = src_ddl.load(sorted({':'.join(rules.logical_source(ds, tb)) for ds, tb in S}))
    SRCDDL = {k: v for k, v in got.items() if v.get('ddl')}
    SRCDEP = {k: v for k, v in got.items() if v.get('status') == '弃用'}
    for x in notes_:
        print('业务库 DDL：', x)

    # ------------------------------------------------ ODS：每个逻辑业务表一张
    logical = collections.OrderedDict()
    for (ds, tb), s in sorted(S.items()):
        if not s['landing']:
            continue
        logical.setdefault(rules.logical_source(ds, tb), []).append(((ds, tb), s))
    ods_of_source, ods_names = {}, {}
    for (lds, ltb), group in logical.items():
        dom = rules.domain_of(lds, ltb)
        ent = rules.entity_of(ltb)
        inc = any(w for _, s in group for w in s['where'] if w)
        name = f'ods_{dom}_{ent}_{"di" if inc else "df"}'
        if name in ods_names:                      # 同一实体来自两个库：合并为一张
            ods_names[name]['group'] += group
            for k, _ in group:
                ods_of_source[k] = name
            continue
        ods_names[name] = {'dom': dom, 'lds': lds, 'ltb': ltb, 'group': group, 'inc': inc}
        for k, _ in group:
            ods_of_source[k] = name
    for name, o in ods_names.items():
        group = o['group']
        cols = max((s['cols'] for _, s in group), key=len)
        landing = sorted({l for _, s in group for l in s['landing']})
        schema = next((SC[l] for l in landing if l in SC), None)
        tmap = {c: (ty, cm) for c, ty, cm in (schema['cols'] if schema else [])}
        cn = SRCDDL.get(f"{o['lds']}:{o['ltb']}", {}).get('tcmt') or next((s.get('comment') for _, s in group if s.get('comment')), '') or (schema or {}).get('comment', '') or rules.PINYIN.get(o['ltb'], ('', ''))[1] or table_cn(o['ltb'])
        srcs = sorted({f'{ds}.{tb}' for (ds, tb), _ in group})
        sens = [c for c in cols if rules.SENSITIVE.search(c)]
        drop = [c for c in cols if rules.DROP.match(c)]
        note = []
        if len(srcs) > 1:
            note.append(f'合并 {len(srcs)} 个物理源（分表 / 历史库 / 数据源别名）')
        if sens:
            note.append('敏感字段落地脱敏：' + '、'.join(c for c in sens if c not in drop))
        if drop:
            note.append('不同步：' + '、'.join(drop))
        if o['ltb'] in rules.PINYIN or re.match(r'formtable_main_\d+', o['ltb']):
            note.append('源表名为拼音 / 编号，中文名待业务确认')
        dep = SRCDEP.get(f"{o['lds']}:{o['ltb']}")
        if dep:
            note.insert(0, f'源表已弃用：{dep_text(dep)}；建议停掉同步、ODS 下线（下游如仍引用需先改造）')
        tables.append({'layer': 'ODS', 'dom': o['dom'], 'name': name, 'cn': cn, 'grain': '同源表，1行=1条源记录', 'suffix': suffix_of(name),
                       'part': 'travel_date（YYYYMMDD）', 'src': '、'.join(srcs), 'keys': '源表全字段（敏感字段按备注处理）', 'up': f'{o["lds"]}:{o["ltb"]}', 'note': '；'.join(note),
                       'legacy': landing, 'lsrc': (o['lds'], o['ltb'])})
        seq = 0
        for c in cols:
            if not re.fullmatch(r'\w+', c) or rules.DROP.match(c):
                continue
            seq += 1
            ty, cm = tmap.get(c.lower(), ('STRING', ''))
            dd = ddl_col(o['lds'], o['ltb'], c)
            if dd and (c.lower() not in tmap):
                ty = dd['t']
            cm = rules.FIELD_FIX.get((o['ltb'], c.lower())) or fix_mojibake(cm)
            if dd and dd['c'] and not rules.FIELD_FIX.get((o['ltb'], c.lower())):
                cm = dd['c']          # 业务库 DDL 注释是源头，优先于旧 Hive 表注释
            cat = '主键' if c.lower() == 'id' else 'ETL' if c.lower() in ETL_COLS else category(c.lower(), [], 'ODS')
            fields.append(['ODS', f'ods.{name}', cn, seq, c.lower(), rules.std_type(ty), cat, (cm or c) + ('（脱敏）' if rules.SENSITIVE.search(c) else ''),
                           f'{srcs[0]}.{c}' + ('，落地脱敏' if rules.SENSITIVE.search(c) else ''), ''])
        fields.append(['ODS', f'ods.{name}', cn, seq + 1, 'travel_date', 'STRING', '分区', '数据日期，格式 YYYYMMDD', '调度参数 ${bizdate}', ''])
        for l in landing:
            mapping[l] = (name, '合并' if len(landing) > 1 or l != name else '保留')

    # ------------------------------------------------ DIM / DWD / DWS / ADS
    hive = {t for t, x in T.items() if x['kind'] == 'hive' and x['writers']}
    claimed = {}

    def match(pat, t):
        return re.search(pat, t) if pat.startswith('^') else t == pat

    # 客户确认下线 / 取消的节点（exclude.txt）排除后：没有任何存活上游（ODS / 其他标准表）、也没有仍在产出的旧表的标准表整体下线；
    # 迭代到稳定（DWD 下线后，只靠它的 DWS / ADS 跟着下线）；口径来源表下线的指标一并去掉
    std_names = {s_['name'] for s_ in model.T}

    def up_tokens(spec):
        pref = re.findall(r'(ods_\w+?)_\*', spec['up'])
        xs = [x.strip() for x in re.split(r'[、]', spec['up']) if x.strip() and '*' not in x]
        xs += [o for o in ods_names if any(o.startswith(p_) for p_ in pref)]
        return [x for x in xs if re.match(r'(ods|dim|dwd|dws|ads)_', x)]

    def alive(x):
        if x.startswith('ods_'):
            return x in ods_names or x[:-3] + '_df' in ods_names or x[:-3] + '_di' in ods_names
        return x in std_names and x not in DEAD
    DEAD.clear()
    while True:
        new = {}
        for s_ in model.T:
            ts = up_tokens(s_)
            if s_['name'] in DEAD or not ts or any(alive(x) for x in ts) or any(match(p_, t) for p_ in s_['legacy'] for t in hive):
                continue
            new[s_['name']] = '上游全部下线：' + '、'.join(ts)
        if not new:
            break
        DEAD.update(new)
    model.T[:] = [s_ for s_ in model.T if s_['name'] not in DEAD]
    dead_m = {m[1] for m in model.METRICS if m[9] in DEAD}
    model.METRICS[:] = [m for m in model.METRICS if m[1] not in dead_m]
    for n_ in dead_m:
        model.M.pop(n_, None)
    for s_ in model.T:
        if isinstance(s_['fields'], list):
            s_['fields'] = [f for f in s_['fields'] if f[0] not in dead_m]
        s_['up'] = '、'.join(x for x in re.split(r'[、]', s_['up'])
                             if x.strip() and (not re.match(r'(ods|dim|dwd|dws|ads)_\w+$', x.strip()) or alive(x.strip())))
    if DEAD:
        print('标准表随上游下线：', DEAD)
        print('指标随来源下线：', sorted(dead_m))
    for spec in model.T:
        layer = spec['name'].split('_')[0].upper()
        legacy = []
        for p in spec['legacy']:
            for t in sorted(hive | set(SC)):
                if t not in claimed and match(p, t):
                    claimed[t] = spec['name']
                    legacy.append(t)
        spec['legacy_hit'] = legacy
        for l in legacy:
            mapping[l] = (spec['name'], '合并' if len(legacy) > 1 else '改名')
    # 维度 / 明细里引用了 ODS 通配的，把对应 ODS 补进上游
    ods_set = set(ods_names)
    for spec in model.T:
        layer = spec['name'].split('_')[0].upper()
        dom = spec['name'].split('_')[1]
        part = spec['part']
        up = spec['up']
        if '*' in up:
            pref = re.findall(r'(ods_\w+?)_\*', up)
            up = '、'.join(sorted(o for o in ods_set if any(o.startswith(p) for p in pref)) + [x for x in re.split(r'[、]', spec['up']) if x and '*' not in x])
        # 上游写的 ODS 名与实际增量 / 全量后缀不一致（_di / _df）时，对到实际存在的 ODS
        fix = lambda x: x if not x.startswith('ods_') or x in ods_set else next((y for y in (x[:-3] + '_df', x[:-3] + '_di') if y in ods_set), x)
        up = '、'.join(fix(x.strip()) for x in re.split(r'[、]', up) if x.strip())
        keys = []
        flist = []
        if spec['fields'] == 'pft3':          # 与 PFT3.0 共用的表：字段直接取 3.0 改造版字典，两边保持一致
            rows3 = [r for r in PFT3['字段清单']['rows'] if str(r[1]).split('.', 1)[-1] == spec['name']]
            for r in rows3:
                fields.append([layer, f'{layer.lower()}.{spec["name"]}', spec['cn'], r[3], r[4], r[5], r[6], r[7], r[8], r[9]])
            t3 = next((r for r in PFT3['表清单']['rows'] if str(r[3]).split('.', 1)[-1] == spec['name']), None)
            tables.append({'layer': layer, 'dom': dom, 'name': spec['name'], 'cn': spec['cn'], 'grain': t3[5] if t3 else spec['grain'], 'suffix': suffix_of(spec['name']),
                           'part': t3[7] if t3 else '无分区', 'src': t3[8] if t3 else up, 'up': up, 'keys': t3[9] if t3 else '',
                           'note': spec['note'] + '（表结构从 PFT3.0 字典同步）' + (f'；归并旧表 {len(spec["legacy_hit"])} 张' if spec['legacy_hit'] else ''), 'legacy': spec['legacy_hit']})
            continue
        if isinstance(spec['fields'], tuple):
            core = spec['fields'][1]
            keys = core
            seen = collections.OrderedDict()
            srcs = spec['legacy_hit'] or sorted(o for o in ods_set if o in up)   # 排序：保证每次生成一致
            freq = collections.Counter()
            for l in srcs:
                for c, _, _ in (SC[l]['cols'] if l in SC else []):
                    freq[rules.std_col(c)[0]] += 1
            for l in srcs:
                sch = SC.get(l)
                cols = sch['cols'] if sch else [(c.lower(), 'STRING', '') for _, s in [(k, v) for k, v in S.items() if l in v['landing']] for c in s['cols'] if re.fullmatch(r'\w+', c)]
                if not sch and l in ods_set:
                    cols = [(f[4], f[5], f[7]) for f in fields if f[1] == f'ods.{l}' and f[4] != 'travel_date']
                for c, ty, cm in cols:
                    if c in ETL_COLS or rules.DROP.match(c) or c in ('travel_date', 'dt', 'ds', 'pt'):
                        continue
                    n, _ = rules.std_col(c)
                    if PIVOT.search(n) or n in TECH:
                        continue
                    # 只收主表（第一张）字段 + 至少两张旧表都有的字段，避免把宽表 / 透视列全并进来
                    if l != srcs[0] and freq[n] < 2 and n not in core and len(srcs) > 2:
                        continue
                    if rules.SENSITIVE.search(n) and not n.endswith(('_hash', '_mask')):
                        n = n + '_mask'
                    if n not in seen:
                        seen[n] = (rules.std_type(ty), cm or '', f'沿用旧表 {l}.{c}', l)
            ordered = [k for k in core if k in seen] + [k for k in core if k not in seen] + [k for k in seen if k not in core]
            for n in ordered:
                ty, cm, proc, l = seen.get(n, (guess_type(n), '', '新增（标准化后补齐）', ''))
                flist.append((n, ty, category(n, keys, layer), cm or n, proc, ''))
        else:
            keys = [f[0] for f in spec['fields'] if f[2] == '粒度键']
            for row in spec['fields']:
                n, ty, cat, cm = row[:4]
                alias = row[4] if len(row) > 4 else ''
                proc = model.M[n][6] if n in model.M else (f'旧字段：{alias}' if alias else '')
                flist.append((n, ty, cat, cm, proc, ''))
        if part:
            for p in part.split('、'):
                flist.append((p, 'STRING' if p != 'stat_hour' else 'INT', '分区', {'travel_date': '数据日期，格式 YYYYMMDD', 'travel_month': '数据月份，格式 YYYYMM', 'stat_hour': '小时分区'}.get(p, p), '调度参数', ''))
        flist.append(('etl_time', 'STRING', 'ETL', 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss', '调度写入', ''))
        full = f'{layer.lower()}.{spec["name"]}'
        for i, (n, ty, cat, cm, proc, upf) in enumerate(flist, 1):
            fields.append([layer, full, spec['cn'], i, n, ty, cat, cm, proc, upf])
        tables.append({'layer': layer, 'dom': dom, 'name': spec['name'], 'cn': spec['cn'], 'grain': spec['grain'], 'suffix': suffix_of(spec['name']),
                       'part': f'{part}（YYYYMMDD）' if part == 'travel_date' else part or '无分区', 'src': up, 'up': up,
                       'keys': '粒度键：' + '、'.join(keys) if layer in ('DWS', 'ADS') else '、'.join(keys[:6]),
                       'note': spec['note'] + (f'；归并旧表 {len(spec["legacy_hit"])} 张' if spec['legacy_hit'] else ''), 'legacy': spec['legacy_hit']})

    # 旧 ODS 由 SQL 从其他 ODS 再加工（如 ods_order_d_i ← s_order_d_i）：沿血缘归到对应的标准 ODS
    for _ in range(3):
        for t in sorted(hive):
            if t in mapping or not re.match(r'(ods|s|src)_', t):
                continue
            ups = [sh(r) for n in T[t]['writers'] for r in n['reads']]
            ups += [ods_of_source[k] for n in T[t]['writers'] if n['type'] == 'DI' and n['di'] for k in
                    [(str(n['di']['reader'].get('datasource')), sh(x)) for x in n['di']['reader'].get('tables', [])] if k in ods_of_source]
            hit = next((mapping[u][0] if u in mapping else u for u in ups if u in mapping or u in ods_names), None)
            if hit and not re.search(r'_temp$|_tmp$', t):
                mapping[t] = (hit, '合并')

    def model_target(t):
        for spec in model.T:
            if any(match(p, t) for p in spec['legacy']):
                return spec['name']
        return ''

    # ------------------------------------------------ 旧表映射（全部 Hive 表 + 回流表）
    rows = []
    for t in sorted(hive):
        x = T[t]
        ws = '、'.join(sorted({n['ws'] for n in x['writers']}))
        tgt, act = mapping.get(t, ('', ''))
        note = ''
        if not tgt:
            for p, (a, why) in model.OTHER:
                if re.search(p, t):
                    act, note = a, why
                    break
        if not tgt and not act:
            for p, (a, why) in model.OTHER:
                if re.search(p, t):
                    act, note = a, why
        if not tgt and not act:
            readers = [n for n in x['readers'] if n not in x['writers']]
            if re.search(r'_temp$|_tmp$|^tmp_|^temp_', t):
                act, note = '下线', '临时表'
            else:
                act, note = ('下线', '无下游读取，也未回流') if not readers else ('待确认', '未归入标准模型，需业务确认用途')
        rows.append([t, 'Hive', ws, audit.layer(t) or '无分层前缀', len({n['path'] for n in x['writers']}), tgt, act, note])
    for t, x in sorted(T.items()):
        if x['kind'] != 'export' or not x['writers']:
            continue
        srcs = sorted({sh(r) for n in x['writers'] for r in n['reads']})
        tgt = next((mapping[s][0] for s in srcs if s in mapping), '') or next((model_target(s) for s in srcs + [sh(t)] if model_target(s)), '')
        direct = all(n['type'] == 'DI' and n['di'] and n['di']['reader'].get('type') not in ('hive', None) for n in x['writers'])
        if direct:
            act, note = '移出数仓', f'业务库直传（{"、".join(sorted({str(n["di"]["reader"].get("datasource")) for n in x["writers"]}))}.{"、".join(srcs)}），不经过数仓，建议迁到数据集成平台单独管理'
        elif tgt:
            act, note = '回流改造', f'来源 {"、".join(srcs)}；改为由标准表回流或服务层直读'
        elif any(re.search(p, x) for p, _ in model.OTHER for x in srcs + [sh(t)]):
            act, note = next(v for p, v in model.OTHER for x in srcs + [sh(t)] if re.search(p, x))
        else:
            act, note = '待确认', f'来源 {"、".join(srcs)}，未归入标准模型'
        rows.append([t, '回流（' + t.split('.')[0] + '）', '、'.join(sorted({n['ws'] for n in x['writers']})), '回流目标', len({n['path'] for n in x['writers']}), tgt if not direct else '', act, note])
    # 下游表
    down = collections.defaultdict(set)
    for tb in tables:
        for u in re.split(r'[、]', tb['up']):
            if u:
                down[u.strip()].add(tb['name'])
    for tb in tables:
        tb['down'] = '、'.join(sorted(down.get(tb['name'], ())))
    # 字段中文名：缺失或与字段名相同的，用旧系统真实注释补，没有再按字段名翻译
    global NAMER
    NAMER = names.Namer(SC, nodes)
    legacy_of = {f'{x["layer"].lower()}.{x["name"]}': x['legacy'] for x in tables}
    for f in fields:
        if not names.needs_name(f[7], f[4]):
            continue
        lc = re.findall(r'(?:沿用旧表 |^)(?:[\w-]+\.)?(\w+)\.(\w+)', str(f[8] or ''))
        tabs = [a for a, _ in lc] + list(legacy_of.get(f[1], []))
        cols = [b for _, b in lc] + [x.strip() for x in re.findall(r'旧字段：(.*)', str(f[8] or ''))[0].split('/')] if '旧字段：' in str(f[8] or '') else [b for _, b in lc]
        sens = '（脱敏）' if rules.SENSITIVE.search(f[4]) and f[0] == 'ODS' else ''
        f[7] = NAMER.name(f[4], tabs, [c for c in cols if c]) + sens
    # 客户标注的核心 ID：原始字段（sid / lid / pid / tid）与下游标准字段统一中文名
    for f in fields:
        if f[0] == 'ODS' and f[4] in rules.ID_ANN:
            f[7] = rules.ID_ANN[f[4]][1]
        elif f[0] != 'ODS':
            c = rules.id_comment(f[4], str(f[7] or ''))
            if c:
                f[7] = c
    return nodes, C, tables, fields, rows, logical, ods_of_source


NAMER = None


def table_cn(t):
    """源表没有中文表名时按表名翻译（去掉 uu_ / pft_ 前缀）"""
    base = re.sub(r'^(uu_|pft_|t_)', '', t)
    m = re.match(r'formtable_main_(\d+)(_dt(\d+))?$', t)
    if m:
        return f'OA 表单 {m.group(1)}' + (f' 明细表 {m.group(3)}' if m.group(2) else '') + '（中文名待确认）'
    s, sure = names.translate(base)
    return s if sure else f'{s}（待确认）'


def sheets(tables, fields, mrows, findings):
    order = {'ODS': 0, 'DIM': 1, 'DWD': 2, 'DWS': 3, 'ADS': 4}
    tables.sort(key=lambda x: (order[x['layer']], x['dom'], x['name']))
    tcols = ['序号', '分层', '业务域', '表名（库.表）', '表中文名', '粒度', '后缀含义', '分区', '来源', '度量 / 口径 / 关键字段', '上游表', '下游表', '备注']
    trows = [[i, x['layer'], x['dom'], f'{x["layer"].lower()}.{x["name"]}', x['cn'], x['grain'], x['suffix'], x['part'], x['src'], x['keys'], x['up'], x['down'], x['note']]
             for i, x in enumerate(tables, 1)]
    fo = {f'{x["layer"].lower()}.{x["name"]}': i for i, x in enumerate(tables)}
    fields.sort(key=lambda f: (fo.get(f[1], 9e9), f[3]))
    cnt = collections.Counter(x['layer'] for x in tables)
    mcnt = collections.Counter(r[6] for r in mrows)
    lsum = [[l, LAYER_CN[l], cnt[l], d, p] for l, d, p in (
        ('ODS', '业务库 1:1；367 个物理同步合并为逻辑表（分表、历史库、数据源别名合并），敏感字段落地脱敏', '不出指标'),
        ('DIM', '公共维度：景区 / 门票 / 商户 / 渠道 / 地区 / 日期（与 PFT3.0 共用日期与统计周期表）', '不出指标'),
        ('DWD', '按业务过程：下单 / 分销 / 操作 / 核销 / 游客 / 年卡 / 出入园 / 停车 / 零售 / 流水 …', '度量'),
        ('DWS', '主题 × 粒度日汇总，指标只在这里算一次', f'口径 {len(model.METRICS)} 个'),
        ('ADS', '日粒度；周 / 月 / 年 / 节假日 / 自定义在查询时关联时间表', '业务指标'))]
    lsum += [['合计', '', sum(cnt.values()), f'旧系统 {sum(1 for r in mrows if r[1] == "Hive")} 张 Hive 表 + {sum(1 for r in mrows if r[1] != "Hive")} 张回流表 → 标准 {sum(cnt.values())} 张', ''],
             [None] * 5, ['统计周期', '含义', None, None, None], ['D1', '当日', None, None, None], ['WTD / MTD / QTD / HTD / YTD', '本周 / 本月 / 本季 / 本半年 / 本年至今', None, None, None],
             ['N7 / N30 / N90 / N180 / N365', '近 7 / 30 / 90 / 180 / 365 日', None, None, None], ['HOL', '节假日（按 dim_opr_holiday_period_f）', None, None, None],
             ['CUS', '自定义起止日', None, None, None], [None] * 5, ['修饰词', '取值', None, None, None],
             ['主子单', '主票（含单票）/ 套票子票', None, None, None], ['团散', '团队 / 散客', None, None, None], ['行为', '预订 / 核销', None, None, None],
             ['零售系统', '银豹 / 思迅 / 小岛', None, None, None], ['停车厂商', '道尔 / 道尔5 / 科拓 / 帅臣 / 智慧', None, None, None], [None] * 5,
             ['业务域前缀', '含义', None, None, None]] + [[f'{k}_', v, None, None, None] for k, v in rules.DOMAINS.items()]
    # 调度
    wf = [['日调度', 1, 'start.daily', '开始', '源库就绪检查', None, None, 0, None, None, None, '检查各业务库 T-1 数据完结（增量位点越过 ${bizdate_end}）']]
    step = {'ODS': 2, 'DIM': 4, 'DWD': 6, 'DWS': 8, 'ADS': 10}
    for x in tables:
        waits = [u for u in re.split('、', x['up']) if u and not u.startswith('scripts/')]
        wf.append(['日调度', step[x['layer']], x['name'], '任务', x['cn'], x['layer'], None, 0, '、'.join(f'dq.{u}' for u in waits) or 'start.daily', None, None,
                   f'sql/{x["layer"].lower()}/{x["name"]}.sql' if x['layer'] != 'ODS' else f'数据集成：{x["src"]} → ods.{x["name"]}'])
        wf.append(['日调度', step[x['layer']] + 1, f'dq.{x["name"]}', '质检', f'{x["cn"]} 质检', x['layer'], '阻断', 2, x['name'], None, None, None])
    wf.append(['日调度', 12, 'end.daily', '结束', '数据就绪 · 发布', None, None, 0, '全部 ADS 质检', None, None, '写就绪标记，触发回流与报表缓存刷新'])
    # 质量规则
    dq, k = [], 0
    for x in tables:
        full = f'{x["layer"].lower()}.{x["name"]}'
        part = "travel_date = '${bizdate}'" if 'travel_date' in x['part'] else '1=1'
        k += 1
        dq.append([f'R{k:04d}', '日调度', f'dq.{x["name"]}', x['name'], '完整性', '当日分区有数据', '强' if x['layer'] in ('ODS', 'DWD') else '弱', '阻断下游', 'cnt > 0', '',
                   f'SELECT COUNT(*) AS cnt FROM {full} WHERE {part};'])
        ks = [f[4] for f in fields if f[1] == full and f[6] in ('主键', '粒度键')]
        if ks:
            k += 1
            dq.append([f'R{k:04d}', '日调度', f'dq.{x["name"]}', x['name'], '唯一性', f'{"、".join(ks[:10])} 唯一', '强', '阻断下游', 'dup_cnt = 0', '',
                       f'SELECT COUNT(*) AS dup_cnt FROM (SELECT {", ".join(ks[:10])} FROM {full} WHERE {part} GROUP BY {", ".join(ks[:10])} HAVING COUNT(*) > 1) t;'])
    # DWS 口径
    used = collections.defaultdict(set)
    for f in fields:
        if f[0] == 'ADS' and f[4] in model.M:
            used[f[4]].add(f[1].split('.', 1)[1])
    land = collections.defaultdict(set)
    for f in fields:
        if f[0] == 'DWS' and f[4] in model.M:
            land[f[4]].add(f[1].split('.', 1)[1])
    dcols = ['口径编码', '英文名', '中文名', '口径类型', '业务域', '业务口径', '计算公式', '单位', '时间口径', '数据类型', '精度/展示', '来源明细表', '落地 DWS 表', '被哪些 ADS 表使用', '旧系统对应字段']
    drows = [[c, en, cn, typ, dom, kou, f, unit, '统计日日终快照' if '快照' in kou else '按业务时间归属统计日', dt, {'元': '元，保留 2 位小数', '%': '百分数，保留 6 位小数'}.get(unit, f'整数，单位：{unit}'), src,
              '、'.join(sorted(land[en])), '、'.join(sorted(used[en])), old] for c, en, cn, dom, typ, kou, f, unit, dt, src, old in model.METRICS]
    # ADS 业务指标
    acols = ['指标编码', '业务指标名', '字段名', '业务口径', '计算公式', '单位', '统计周期', '修饰词', '时间口径', '数据类型', '精度/展示', '更新频率', '离线/实时', '基础口径', '口径类型', 'ADS表',
             'ADS表中文名', '分析粒度', '来源 DWS', '使用端']
    arows, k = [], 0
    for x in tables:
        if x['layer'] != 'ADS':
            continue
        for f in fields:
            if f[1] != f'ads.{x["name"]}' or f[6] not in ('指标', '度量'):
                continue
            m = model.M.get(f[4])
            k += 1
            arows.append([f'S{k:04d}', m[2] if m else f[7].split('：')[0], f[4], m[5] if m else f[7], m[6] if m else '', m[7] if m else '', '查询时关联时间表（当日 / 周 / 月 / 年 / 节假日 / 自定义）',
                          '—', '按业务时间归属统计日', f[5], '', '每日 T+1', '离线', f'{m[0]} {m[2]}' if m else '', m[4] if m else '外部结果', x['name'], x['cn'], x['grain'], x['up'], ''])
    # 总线矩阵
    bus_dims = [('日期', 'travel_date'), ('景区', 'scenic_id'), ('门票', 'ticket_id'), ('供应商', 'supplier_id'), ('分销商', 'distributor_id'), ('商户', 'member_id'),
                ('渠道', 'order_mode'), ('支付方式', 'pay_mode'), ('客源地', 'province_code'), ('性别年龄', 'gender'), ('终端 / 闸机', 'terminal_no'), ('停车场', 'parking_lot_code'),
                ('门店', 'shop_code'), ('年卡产品', 'card_product_id'), ('账户', 'account_id'), ('合同', 'contract_no'), ('资源', 'resource_id')]
    bcols = ['分层', '表名', '中文名'] + [d for d, _ in bus_dims]
    brows = []
    for x in tables:
        if x['layer'] not in ('DWD', 'DWS', 'ADS'):
            continue
        fs = {f[4] for f in fields if f[1] == f'{x["layer"].lower()}.{x["name"]}'}
        brows.append([x['layer'], f'{x["layer"].lower()}.{x["name"]}', x['cn']] + ['●' if (c in fs or (c == 'travel_date' and 'travel_date' in x['part'])) else None for _, c in bus_dims])
    # 质量体检（对标准化结果自检）
    ok_name = sum(1 for x in tables if re.fullmatch(r'(ods|dim|dwd|dws|ads)_(ord|fin|prd|inv|cus|sup|trf|opr|mkt)_[a-z0-9_]+_(di|df|f|zip|hrs|mo)', x['name']))
    pinyin = sum(1 for x in tables if '拼音' in x['note'])
    hc = [['规范度', '表名符合「分层_业务域_实体名_粒度」', f'{ok_name}/{len(tables)}', '通过' if ok_name == len(tables) else '待改', ''],
          ['规范度', '分区字段统一 travel_date（YYYYMMDD）', f'{sum(1 for x in tables if "travel_date" in x["part"])}/{len(tables)}', '通过', '码表 / 维度 / 全量快照不分区'],
          ['规范度', '源表名为拼音 / 编号（中文名待确认）', str(pinyin), '待确认' if pinyin else '通过', 'OA 表单 formtable_main_N、uf_*'],
          ['复用度', '每张业务表只同步一次', f'{sum(1 for r in mrows if r[3] == "ODS" and r[1] == "Hive")} 张旧 ODS → {cnt["ODS"]} 张', '通过', ''],
          ['复用度', '指标只在 DWS 计算一次', f'{len(model.METRICS)} 个口径', '通过', '旧系统同一指标在 45 张表各算一遍'],
          ['完整性', '旧 Hive 表已归入标准模型或给出处理', f'{sum(1 for r in mrows if r[1] == "Hive" and r[6] != "待确认")}/{sum(1 for r in mrows if r[1] == "Hive")}', '待确认' if any(r[6] == '待确认' for r in mrows) else '通过', '见「旧表映射」'],
          ['安全', '敏感字段落地脱敏 / 不同步密码', f'{sum(1 for x in tables if "脱敏" in x["note"])} 张 ODS', '通过', '手机号、证件号哈希 + 掩码']]
    todo = [[1, '命名规范', '内部管理数据（OA / HR / 考勤 / CRM / 合同）在 9 个业务域里没有对应域', 'OA / HR / 考勤 → opr，CRM / 合同 → sup；建议规范补「adm_ 内部管理」域', '影响约 80 张 ODS'],
            [2, '数据源', '同一业务库配置了 BI_ 与非 BI_ 两个数据源', 'ODS 按逻辑库合并，保留一个数据源', 'RDS_pft_open_cooperate / RDS_oa_ecology / RDS_summary'],
            [3, '口径', '旧系统「预定验证报表」来自业务库 summary 汇总表，与明细重算结果可能不一致', '上线前用 1 个月数据对数，差异逐项确认', '预订 / 验证类全部指标'],
            [4, '口径', '景区指标旧表与宽表口径不同（dwd_split_d_i vs dwd_order_d_i）', '以新模型 dwd_ord_order_di 为准，对数后下线两套旧表', '景区画像 / 渠道 60+ 张表'],
            [5, '外部结果', 'AI 洞察、携程为外部系统结果', '只做 ODS 落地 + ADS 直通，不在数仓重算', '客群洞察 10 张、OTA 2 张'],
            [6, '安全', 'OA 人员表、CRM 人员表、年卡表同步了 password 字段', '源头不再同步密码类字段；存量分区清理', '4 个同步任务'],
            [7, '拼音表名', 'OA 表单 formtable_main_N、uf_* 无业务含义', '与 OA 管理员确认每张表单含义后改名', f'{pinyin} 张 ODS'],
            [8, '节假日', '2028 年放假安排未公布', '日期表脚本已按法定假日估算，公布后重跑', 'dim_opr_date_f']]
    mcols = ['旧表名', '类型', '所在工作空间', '旧分层', '写入任务数', '标准表', '处理', '说明']
    pcols = ['编号', '级别', '类别', '问题', '涉及', '说明', '建议']
    prow = [[f['id'], f['level'], f['cat'], f['title'], f['n'], f['detail'], f['suggest']] for f in sorted(findings, key=lambda f: ({'高': 0, '中': 1, '低': 2}[f['level']], f['id']))]
    fcols = ['分层', '表名（库.表）', '表中文名', '序号', '字段名', '类型', '字段类别', '字段注释', '加工 / 来源', '上游字段']
    return collections.OrderedDict([
        ('分层汇总', {'cols': ['分层', '层级含义', '表数', '说明', '指标产出'], 'rows': lsum}),
        ('表清单', {'cols': tcols, 'rows': trows}), ('字段清单', {'cols': fcols, 'rows': fields}),
        ('调度工作流', {'cols': ['工作流', '步骤', '节点', '类型', '说明', '分层', '失败处理', '规则数', '等待（上游）', '依赖上一周期（T-1）', '跨流程依赖', '执行 / 说明'], 'rows': wf}),
        ('质量规则', {'cols': ['规则编号', '工作流', '质检节点', '表', '质量维度', '规则', '级别', '失败处理', '期望', '说明', '检测 SQL'], 'rows': dq}),
        ('DWS口径', {'cols': dcols, 'rows': drows}), ('ADS业务指标', {'cols': acols, 'rows': arows}),
        ('总线矩阵', {'cols': bcols, 'rows': brows}), ('质量体检', {'cols': ['维度', '检查项', '结果', '状态', '说明 / 明细'], 'rows': hc}),
        ('待确认事项', {'cols': ['序号', '类别', '问题', '当前处理 / 建议', '影响'], 'rows': todo}),
        ('旧表映射', {'cols': mcols, 'rows': mrows}), ('现状问题', {'cols': pcols, 'rows': prow})])


def ads_fix(model_, sh_):
    """比率的分子、分母若已是同表的日字段（如 退票率 = 取消票数 / 预订票数），不再单独存分子分母列，查询时直接用这两列"""
    sys.path.insert(0, str(ROOT.parent / 'dw-dict'))
    import ads_model
    D = sh_['DWS口径']
    di = {c: i for i, c in enumerate(D['cols'])}
    cn2en = sorted(((str(r[di['中文名']]), r[di['英文名']]) for r in D['rows']), key=lambda x: -len(x[0]))
    plain = {(x['t'], x['f']) for x in model_['store'] if not re.search(r'_(numerator|denominator)_', x['f'])}
    drop = set()
    for c in model_['combos']:
        if c['kind'] not in ('pct', 'avg') or len(c['store']) != 2:
            continue
        _, nen, _, den = ads_model.split_ratio(c['calc'], cn2en)
        if (c['t'], nen) in plain and (c['t'], den) in plain:
            drop |= {(c['t'], f) for f in c['store']}
            c['store'] = [nen, den]
            c['expr'] = {'v': f'SUM({{C}}{nen}){" * 100" if c["kind"] == "pct" else ""} / NULLIF(SUM({{C}}{den}), 0)'}
    model_['store'] = [x for x in model_['store'] if (x['t'], x['f']) not in drop]
    model_['summary']['store'] = len(model_['store'])
    for c in model_['_int']['combos'].values() if '_int' in model_ else []:
        m = next((x for x in model_['combos'] if x['mcode'] == c['mcode']), None)
        if m:
            c['store'], c['expr'] = m['store'], m['expr']
    return model_


def ads_storage(sh_):
    """ADS 字段按 PFT3.0 的日粒度存储设计重排：粒度键 + 日存储字段（比率存分子分母、去重存位图、快照存期末值）"""
    sys.path.insert(0, str(ROOT.parent / 'dw-dict'))
    import checks, ads_model
    res = checks.run(sh_, None)
    model_ = ads_model.build(sh_, res)
    ads_fix(model_, sh_)
    F = sh_['字段清单']['rows']
    keep = [r for r in F if r[0] != 'ADS']
    ads = collections.OrderedDict()
    for r in F:
        if r[0] == 'ADS':
            ads.setdefault(r[1], []).append(r)
    out = []
    for full, rs in ads.items():
        t = full.split('.', 1)[1]
        st = [x for x in model_['store'] if x['t'] == t]
        if not st:
            out += rs
            continue
        head = [r for r in rs if r[6] in ('粒度键', '维度属性')]
        tail = [r for r in rs if r[6] in ('分区', 'ETL')]
        cn = rs[0][2]
        rows = head + [['ADS', full, cn, 0, x['f'], x['type'], '指标', x['cmt'], x['proc'], x['up']] for x in st] + tail
        for i, r in enumerate(rows, 1):
            r[3] = i
        out += rows
    sh_['字段清单']['rows'] = keep + out
    return res, model_


def ads_query_rows(sh_, model_):
    """ADS业务指标：与 PFT3.0 改造版一致，按「查询指标」登记（统计周期在查询时选择），日存储字段（位图等）另登记"""
    sys.path.insert(0, str(ROOT.parent / 'dw-dict'))
    import ads_model
    A = sh_['ADS业务指标']
    ai = {c: i for i, c in enumerate(A['cols'])}
    base = {}
    for r in A['rows']:
        base.setdefault((r[ai['ADS表']], str(r[ai['基础口径']]).split(' ')[0]), r)
    dn = {d[0]: d for d in ads_model.DERIVS}
    cm = {c['mcode']: c for c in model_['combos']}
    n18 = len(ads_model.PERIODS)
    rows = []
    for f in model_['fields']:
        c = cm[f['m']]
        r0 = list(base[(c['t'], c['code'])])
        per = f'全部 {n18} 种' if len(f['pers']) == n18 else ('仅当日' if f['pers'] == ['D1'] else f'{len(f["pers"])} 种')
        expr = ads_model.ex_simple({'expr': c['expr'], 'stem': c['stem'], 'kw': c['kw']}).split(' AS ')[0]
        vals = {'指标编码': f"{f['m']}-{f['d']}", '业务指标名': f['nm'], '字段名': f['f'], '业务口径': c['kou'] if f['d'] == 'VAL' else dn[f['d']][4],
                '计算公式': f"{dn[f['d']][1]}：{dn[f['d']][4]}；区间汇总 = {expr}（ADS 日字段：{'、'.join(c['store'])}）", '单位': f['unit'],
                '统计周期': f'{per}（查询时关联 dim_opr_period_f）', '数据类型': f['type'], '口径类型': r0[ai['口径类型']] if f['d'] == 'VAL' else '派生指标',
                '更新频率': '每日 T+1（ADS 日数据）；周期查询时计算'}
        for k, v in vals.items():
            r0[ai[k]] = v
        rows.append(r0)
    q = {(f['t'], f['f']) for f in model_['fields']}
    for x in model_['store']:
        if (x['t'], x['f']) in q:
            continue
        c = cm[x['m']]
        r0 = list(base[(c['t'], c['code'])])
        for k, v in {'指标编码': f"{x['m']}-STORE", '业务指标名': f"{c['base_cn']}（日存储字段）", '字段名': x['f'], '业务口径': x['cmt'], '计算公式': x['proc'],
                     '统计周期': '—（日存储字段，查询时按区间汇总）', '数据类型': x['type'], '口径类型': '存储字段'}.items():
            r0[ai[k]] = v
        rows.append(r0)
    sh_['ADS业务指标']['rows'] = rows


def legacy_etl(tables, T, nodes):
    """每张标准表的「加工逻辑」：列出它要替代的旧任务及其脚本，作为按标准模型重写的参考"""
    out = {}
    for tb in tables:
        if tb['layer'] == 'SRC':
            continue
        parts, seen = [], set()
        for l in tb['legacy']:
            for n in T.get(l, {}).get('writers', []):
                if n['path'] in seen:
                    continue
                seen.add(n['path'])
                if n['type'] == 'DI' and n['di'] and 'reader' in n['di']:
                    r, w = n['di']['reader'], n['di']['writer']
                    body = (f"-- 数据集成：{r.get('type')} {r.get('datasource')}.{'、'.join(map(str, r.get('tables', [])))}（{len(r.get('columns') or [])} 列）"
                            f"\n--   增量条件：{str(r.get('where') or '无（全量）').strip()}\n--   写入：{w.get('type')} {w.get('datasource')}.{'、'.join(w.get('tables', []))}"
                            f"{'  分区 ' + w['partition'] if w.get('partition') else ''}{'  写入方式 ' + w['writeMode'] if w.get('writeMode') else ''}")
                else:
                    body = n['script'].strip()
                parts.append(f"-- ======== 旧任务 {len(parts) + 1}：{n['path']}（{n['type']}，调度 {n['cron']}）写入 {l}\n{body}")
        if not parts:
            continue
        head = (f"-- 标准表 {tb['layer'].lower()}.{tb['name']}（{tb['cn']}）\n-- 归并 {len(tb['legacy'])} 张旧表、{len(parts)} 个旧任务；以下为旧实现，按标准模型（粒度、字段、口径见字典）重写后下线旧任务\n\n")
        out[tb['name']] = {'sql': head + '\n\n'.join(parts), 'kind': 'legacy', 'path': f'{len(parts)} 个旧任务', 'stats': {'nodes': len(parts)}}
    return out


def write_sql(etl, tables):
    """加工逻辑落盘：dataworks/sql/<层>/<表>.sql（ODS 为数据集成脚本模式 .json），可直接导入 DataWorks"""
    import shutil
    base = ROOT / 'sql'
    for sub in ('ods', 'dim', 'dwd', 'dws', 'ads'):      # 只清生成的分层目录；report/ 等手写目录保留
        if (base / sub).exists():
            shutil.rmtree(base / sub)
    layer = {t['name']: t['layer'].lower() for t in tables}
    cnt, todo = collections.Counter(), collections.Counter()
    for name, e in sorted(etl.items()):
        d = base / layer[name]
        d.mkdir(parents=True, exist_ok=True)
        if e['kind'] == 'di':
            body = e['sql'][e['sql'].index('{'):]
            (d / f'{name}.json').write_text(body, encoding='utf-8')
            e['path'] = f'sql/{layer[name]}/{name}.json'
        else:
            (d / f'{name}.sql').write_text(e['sql'], encoding='utf-8')
            e['path'] = f'sql/{layer[name]}/{name}.sql'
        cnt[layer[name]] += 1
        todo[layer[name]] += e['stats'].get('review', 0)
    rows = '\n'.join(f'| {k.upper()} | {cnt[k]} | {todo[k]} |' for k in ('ods', 'dim', 'dwd', 'dws', 'ads'))
    (base / 'README.md').write_text(f"""# 标准化数仓加工逻辑

由 `python3 dataworks/standard/build.py` 生成，与字典页「表清单 → 加工逻辑」一致；每段都经 sqlglot（spark）解析，输出列与字典字段清单逐一核对。

| 层 | 脚本数 | 待确认字段 |
|---|---|---|
{rows}

## 约定

- 调度参数：`bizdate` = 业务日期（yyyyMMdd，DataWorks `$[yyyymmdd-1]`）；分区统一 `travel_date`。
- ODS：`ods/*.json` 为数据集成脚本模式配置。增量表按 `update_time`（无则创建时间）取当天变更；只同步字典里的列；分表多表读取；历史库只在初始化时补一次。
- 脱敏在读端完成，明文不落数仓：
  - 手机号 = 前 7 位号段 + `#` + SHA256；
  - 证件号（18 位）= 地区 6 位 + 出生年 4 位 + 性别位 + `#` + SHA256；
  - DWD 用 `SUBSTRING_INDEX(x, '#', -1)` 取哈希、`SUBSTRING_INDEX(x, '#', 1)` 取前缀（归属地 / 性别 / 年龄）。
- Spark 参数：订单明细按下单日动态分区覆盖，需 `spark.sql.sources.partitionOverwriteMode=dynamic`；明细关联订单时带下单日分区条件，依赖动态分区裁剪（Spark 3 默认开启）。
- 去重类指标存位图：`TO_BITMAP / BITMAP_UNION / BITMAP_COUNT` 与 PFT3.0 同一套 UDF。
- 累计维表、订单明细先写 `tmp` 临时表再覆盖（Spark 不允许同表边读边覆盖），需要 `tmp` 库。
- 「待确认」：源字段未同步或码值需业务确认；「过渡期从旧表平移」：旧宽表逻辑分散在多张中间表，先平移保证下游切换，再逐字段改为从 ODS 计算。

## 上线顺序

ODS（同步）→ `dim_opr_dict_f`、地区 / 号段 / 证件地区码表 → `dim_sup_member_df` → `dim_prd_scenic_df` → `dim_prd_ticket_df` → `dim_prd_product_df`
→ `dwd_ord_order_di` → 轨迹 / 核销 / 游客 / 分销 → `dim_sup_member_relation_zip` → `dim_sup_supplier_df`、`dim_cus_tourist_df` → `dim_cus_user_df` → DWS → ADS。

每张表上线后与它替代的旧任务并行跑 7 天、按日对数（脚本头部列出了替代的旧任务），一致后下线旧任务。

## 其他

- `report/industry_report.sql`：行业报告取数（手写，不由 build 生成），方案见 `dataworks/docs/行业报告取数方案.md`。
""", encoding='utf-8')


def legacy_src(C, logical, ods_of_source, fcols, tcols):
    """业务库原始表（SRC）：DataWorks 同步任务读取的全部业务表；落地数仓的与 ODS 一一对应"""
    S, SC = C['sources'], C['schemas']
    ti, fi = {c: i for i, c in enumerate(tcols)}, {c: i for i, c in enumerate(fcols)}
    trows, frows, ddl, ddl_done, tool = [], [], {}, {}, []
    groups = collections.OrderedDict()
    for (ds, tb), s in sorted(S.items()):
        groups.setdefault(rules.logical_source(ds, tb), []).append(((ds, tb), s))
    for no, ((lds, ltb), g) in enumerate(groups.items(), 1):
        name = f'{lds}:{ltb}'
        cols = max((s['cols'] for _, s in g), key=len)
        D = SRCDDL.get(name)
        tool.append({'name': name, 'ds': lds, 'table': ltb, 'fields': [{'n': c} for c in cols if re.fullmatch(r'\w+', c)]})
        synced = {c.lower() for c in cols}
        if D:   # 客户 DDL：字段以 DDL 为准（顺序、类型、注释、主键），同步配置有而 DDL 没有的排在后面
            dn = {x['n'].lower() for x in D['cols']}
            cols = [x['n'] for x in D['cols']] + [c for c in cols if c.lower() not in dn]
        landing = sorted({l for _, s in g for l in s['landing']})
        types = {}
        for l in landing:
            for c, ty, cm in (SC.get(l) or {}).get('cols', []):
                types.setdefault(c, (ty, cm))
        ods = sorted({ods_of_source[k] for k, _ in g if k in ods_of_source})
        targets = sorted({x for _, s in g for x in s['targets']})
        cn = (D or {}).get('tcmt') or next((s.get('comment') for _, s in g if s.get('comment')), '') or (D or {}).get('comment') or rules.PINYIN.get(ltb, ('', ''))[1] or table_cn(ltb)
        note = []
        if len(g) > 1:
            note.append('物理源：' + '、'.join(f'{a}.{b}' for (a, b), _ in g))
        if not ods:
            note.append('未落数仓：同步任务直接写到 ' + ('、'.join(targets[:3]) + (' 等' if len(targets) > 3 else '') if targets else '其他系统'))
        if any(rules.DROP.match(c) for c in cols):
            note.append('含密码类字段，标准化后不同步')
        if name in SRCDEP:
            note.insert(0, dep_text(SRCDEP[name]))
        if D:
            ddl_done[name] = D.get('at') or D['file']
            miss = [x['n'] for x in D['cols'] if x['n'].lower() not in synced]
            note.append(f"表结构：客户 DDL（{D['file']}）" + (f"；未同步字段 {len(miss)} 个" if miss else ''))
        r = [''] * len(tcols)
        r[ti['序号']], r[ti['分层']], r[ti['业务域']], r[ti['表名（库.表）']], r[ti['表中文名']] = no, 'SRC', rules.domain_of(lds, ltb), name, cn
        r[ti['粒度']], r[ti['后缀含义']], r[ti['分区']] = '业务表，1行=1条源记录', f'{g[0][1].get("type", "")} 业务表', '无（业务库）'
        r[ti['来源']] = f'{rules.SOURCE_DB.get(lds, (lds, ""))[0]}（数据源 {lds}）'
        r[ti['度量 / 口径 / 关键字段']] = f'字段 {len(cols)} 个，同步 {len(synced)} 个' + (f"；主键 {'、'.join(D['pk'])}" if D and D['pk'] else '') if D else f'同步字段 {len(cols)} 个'
        r[ti['下游表']] = '、'.join(ods)
        r[ti['备注']] = '；'.join(note)
        trows.append(r)
        lines = []
        for i, c in enumerate(cols, 1):
            ty, cm = types.get(c.lower(), ('', ''))
            dd = ddl_col(lds, ltb, c)
            if dd:
                ty, cm = dd['t'], dd['c'] or cm
            fr = [''] * len(fcols)
            fr[fi['分层']], fr[fi['表名（库.表）']], fr[fi['表中文名']], fr[fi['序号']], fr[fi['字段名']] = 'SRC', name, cn, i, c
            fr[fi['类型']] = ty or '—'
            is_pk = c in (D or {}).get('pk', []) if D else c.lower() == 'id'
            fr[fi['字段类别']] = '主键' if is_pk else ('维度属性' if not rules.SENSITIVE.search(c) else '敏感字段')
            cm = rules.FIELD_FIX.get((ltb, c.lower())) or fix_mojibake(cm)
            fr[fi['字段注释']] = rules.ID_ANN[c.lower()][1] if c.lower() in rules.ID_ANN else (cm if not names.needs_name(cm, c) else NAMER.name(c, landing))
            fr[fi['加工 / 来源']] = '密码类字段：标准化后不再同步' if rules.DROP.match(c) else ('敏感字段：ODS 落地脱敏' if rules.SENSITIVE.search(c) else '')
            if D and c.lower() not in synced:
                fr[fi['加工 / 来源']] = '未同步（DDL 有、同步任务未读）'
            elif D and not dd:
                fr[fi['加工 / 来源']] = '同步配置有、DDL 没有：字段可能已删除或改名'
            frows.append(fr)
            lines.append(f'  {c:<32} {ty or "（类型以业务库为准）"}' + (f'  -- {cm}' if cm else ''))
        ddl[name] = (f"-- 客户提供 DDL（{D['file']}{'，' + D['at'] + ' 录入' if D.get('at') else ''}）\n"
                     + (f"-- 人工修改描述：{'、'.join(D['edited'])}（字段清单已按修改后的描述）\n" if D.get('edited') else '') + D['ddl'] if D else
                     '-- 字段来自 DataWorks 同步任务配置（读端列）；类型取数仓落地表\n' + f'{ltb} (\n' + '\n'.join(lines) + '\n)')
    # 业务库 DDL 补齐工具的表清单：字段为同步配置读取的列（用于和客户 DDL 比对）
    fx = {(r[fi['表名（库.表）']], r[fi['字段名']]): r for r in frows}
    for t, r in zip(tool, trows):
        t['cn'], t['note'] = r[ti['表中文名']], r[ti['备注']]
        for f in t['fields']:
            x = fx.get((t['name'], f['n']))
            if x:
                f.update({'t': '' if x[fi['类型']] == '—' else x[fi['类型']], 'c': x[fi['字段注释']] or '', 'k': x[fi['字段类别']], 's': x[fi['加工 / 来源']] or ''})
    (ROOT / 'ddl_tool' / 'src_tables.json').write_text(json.dumps({'tables': tool}, ensure_ascii=False, separators=(',', ':')), encoding='utf-8')
    return {'tables': trows, 'fields': frows, 'ddl': ddl, 'info': {}, 'ddlNote': '业务库表结构，取自同步任务配置', 'ddlDone': ddl_done}


def ads_specs():
    """模型里 ADS 表 → 字段名集合（粒度键 + 指标）"""
    return {sp['name']: {f[0] for f in sp['fields']} for sp in model.T if sp['name'].startswith('ads_') and isinstance(sp['fields'], list)}


def fill_gaps(gaps):
    """把导出模型需要、而标准 ADS 缺的指标 / 维度补进模型（DWS 交易表同步补指标）"""
    added = collections.defaultdict(list)
    by = {sp['name']: sp for sp in model.T}
    for t, items in gaps.items():
        sp = by.get(t)
        if not sp or not isinstance(sp['fields'], list):
            continue
        have = {f[0] for f in sp['fields']}
        nd = [x[4:] for x in items if x.startswith('dim:') and x[4:] in model.D and x[4:] not in have]
        nm = [x for x in items if not x.startswith('dim:') and x in model.M and x not in have]
        k = max([i for i, f in enumerate(sp['fields']) if f[2] == '粒度键'] or [-1]) + 1
        sp['fields'][k:k] = model.dims(*nd)
        sp['fields'] += model.mets(*nm)
        added[t] += nd + nm
        for up in re.split('、', sp['up']):
            u = by.get(up.strip())
            if u and isinstance(u['fields'], list) and up.startswith('dws_'):
                uh = {f[0] for f in u['fields']}
                kk = max([i for i, f in enumerate(u['fields']) if f[2] == '粒度键'] or [-1]) + 1
                u['fields'][kk:kk] = model.dims(*[x for x in nd if x not in uh and x not in DERIVED_DIMS])
                u['fields'] += model.mets(*[x for x in nm if x not in uh])
    return added


DERIVED_DIMS = {'product_type'}


def main():
    nodes, C, tables, fields, mrows, logical, ods_of_source = build()
    # 导出（hive_to_db）应用层模型：先核对覆盖，缺的指标 / 维度补进标准 ADS，再重新生成
    _, _, _, gaps = exports.analyse(nodes, C, mrows, ads_specs(), model.M)
    added = fill_gaps(gaps)
    nodes, C, tables, fields, mrows, logical, ods_of_source = build()
    cover, unify, mnotes, gaps2 = exports.analyse(nodes, C, mrows, ads_specs(), model.M)
    print('导出模型补全：', {k: len(v) for k, v in added.items()}, '仍缺：', {k: len(v) for k, v in gaps2.items()})
    findings, stats = audit.analyse(nodes)
    sh_ = sheets(tables, fields, mrows, findings)
    # 业务域 × 数据域 × 业务过程：消费清单倒推最细模型
    cons, used_ods = domains.consumption(nodes, C, mrows, ods_of_source, tables, cover)
    pc, bm = domains.process_rows(tables, used_ods, cons['rows'])
    sh_['消费清单'], sh_['业务过程'], sh_['业务过程总线矩阵'], sh_['ODS去向'] = cons, pc, bm, domains.ods_rows(tables, used_ods)
    print('消费清单', len(cons['rows']), collections.Counter(r[0] for r in cons['rows']), '结论', collections.Counter(r[16].split('；')[0] for r in cons['rows']), '待补口径字段', sum(r[14] or 0 for r in cons['rows']))
    print('ODS 去向', collections.Counter(r[3] for r in sh_['ODS去向']['rows']), '未被在用', sum(1 for r in sh_['ODS去向']['rows'] if not r[5]))
    miss = sorted({s_ for p_ in domains.PROC for s_ in p_[6] if '*' not in s_} - {t['name'] for t in tables}
                  | {s_ for v in domains.DIM_SRC.values() for s_ in v} - {t['name'] for t in tables})
    if miss:
        print('业务过程 / 维度来源里不存在的 ODS：', miss)
    D_ = sh_['DWS口径']
    D_['cols'] = D_['cols'] + ['旧系统口径差异']
    for r in D_['rows']:
        r.append(mnotes.get(r[1], ''))
    sh_['导出模型覆盖'] = {'cols': ['导出目标表', '导出字段', '来源 Hive 表', '来源字段', '标准指标', '字段类型', '标准 ADS', '覆盖情况', '维度取值', '旧口径', '旧公式（底层）'], 'rows': cover}
    sh_['口径统一'] = {'cols': ['口径编码', '英文名', '中文名', '旧口径数', '旧口径', '旧口径说明', '使用处数', '使用的导出字段', '标准口径', '与标准的差异'], 'rows': unify}
    res0, model_ = ads_storage(sh_)
    ads_query_rows(sh_, model_)
    out = ROOT / 'dist'
    out.mkdir(exist_ok=True)
    import openpyxl
    from openpyxl.styles import Font, PatternFill
    wb = openpyxl.Workbook()
    wb.remove(wb.active)
    for name, d in sh_.items():
        ws = wb.create_sheet(name)
        ws.append(d['cols'])
        for c in ws[1]:
            c.fill, c.font = PatternFill('solid', fgColor='1F2937'), Font(color='FFFFFF', bold=True)
        for r in d['rows']:
            ws.append(['' if v is None else v for v in r])
        ws.freeze_panes = 'A2'
        for i, c in enumerate(d['cols'], 1):
            ws.column_dimensions[openpyxl.utils.get_column_letter(i)].width = 14 if len(str(c)) < 6 else 26
    xlsx = out / '旧版数仓_标准化字典.xlsx'
    wb.save(xlsx)
    cnt = collections.Counter(x['layer'] for x in tables)
    act = collections.Counter((r[1] == 'Hive', r[6]) for r in mrows)
    print('标准表', dict(cnt), '字段', len(fields), '口径', len(model.METRICS))
    print('旧表映射', {('Hive' if k[0] else '回流') + '/' + k[1]: v for k, v in sorted(act.items())})
    print('->', xlsx)
    print('字段中文名补齐：', dict(NAMER.stats))

    # ------------------------------------------------ 页面（与 PFT3.0 字典页同一模板，legacy 模式）
    sys.path.insert(0, str(ROOT.parent / 'dw-dict'))
    import checks, ads_model, etl_gen
    import datetime
    disp = {k: v for k, v in sh_.items() if k not in ('旧表映射', '现状问题', '导出模型覆盖', '口径统一', '消费清单', '业务过程', '业务过程总线矩阵', 'ODS去向')}
    res = checks.run(disp, None)
    res['mclass'].update(res0['mclass'])
    res['verify'], res['after'] = [], None
    model_.pop('_int', None)
    old = legacy_etl(tables, C['tables'], nodes)
    etl, bad = etl_mod.generate(tables, sh_['字段清单']['rows'], C, ods_of_source, nodes, {k: v['sql'] for k, v in old.items()})
    write_sql(etl, tables)
    kinds = collections.Counter(v['kind'] for v in etl.values())
    print('加工逻辑：', dict(kinds), '校验未通过', len(bad))
    for b in bad[:20]:
        print('   ', b)
    src = legacy_src(C, logical, ods_of_source, sh_['字段清单']['cols'], sh_['表清单']['cols'])
    order = {'高': 0, '中': 1, '低': 2}
    F = sorted(findings, key=lambda f: (order[f['level']], f['id']))
    L = {'zip': 'DATAWORKS.zip', 'stats': f"{stats['nodes']:,} 个节点 · {stats['hive']} 张 Hive 表 · {stats['export']} 张回流表 · 3 个工作空间",
         'summary': {**{k: sum(1 for f in F if f['level'] == k) for k in order}, 'text': '；'.join(f['title'] for f in F if f['level'] == '高')[:160]},
         'findings': [{k: f[k] for k in ('id', 'level', 'cat', 'title', 'detail', 'suggest', 'cols')} | {'rows': [list(map(str, r)) for r in f['rows'][:400]], 'total': len(f['rows'])} for f in F],
         'mapping': {'cols': sh_['旧表映射']['cols'], 'rows': sh_['旧表映射']['rows'], 'filters': [1, 2, 3, 6],
                     'note': f"旧系统 {sum(1 for r in mrows if r[1] == 'Hive')} 张 Hive 表 + {sum(1 for r in mrows if r[1] != 'Hive')} 张回流表，每张都给出归属的标准表与处理方式；点行跳到标准表"},
         'nodes': {'cols': ['工作空间', '路径', '节点', '类型', 'cron', '写入表', '读取表', '处理'],
                   'rows': [[n['ws'], n['path'], n['name'], n['type'], n['cron'], '、'.join(sh(t) for t, k in n['writes'] if k != 'ddl'), '、'.join(sh(t) for t in n['reads'])[:300],
                             next((x[6] for x in mrows if n['writes'] and x[0] == sh(n['writes'][0][0])), '')] for n in nodes if n['type'] != 'WORKFLOW']
                          + [[n['ws'], n['path'], n['name'], n['type'], n['cron'], '、'.join(sh(t) for t, k in n['writes'] if k != 'ddl'), '、'.join(sh(t) for t in n['reads'])[:300],
                              '纯同步（库到库，原样迁移，不入数仓）'] for n in parse.SYNC_ONLY if n['type'] != 'WORKFLOW'],
                   'filters': [0, 3, 7], 'note': f'全部旧节点（不含工作流容器）；「处理」取其写入表在旧表映射中的处理方式；另有 {sum(1 for n in parse.SYNC_ONLY if n["type"] != "WORKFLOW")} 个纯同步任务（客户确认不参与数仓计算）单独标出；下线 / 取消的节点（dataworks/exclude.txt）不列出'},
         'cover': {'cols': sh_['导出模型覆盖']['cols'], 'rows': [[str(x) for x in r] for r in sh_['导出模型覆盖']['rows']], 'filters': [5, 7, 6],
                   'note': f"旧系统 {len({r[0] for r in sh_['导出模型覆盖']['rows']})} 个导出（hive_to_db）应用层模型、{len(sh_['导出模型覆盖']['rows'])} 个字段逐个对到标准 ADS；缺的指标 / 维度已补进标准 ADS"},
         'unify': {'cols': sh_['口径统一']['cols'], 'rows': [[str(x) for x in r] for r in sh_['口径统一']['rows']], 'filters': [1, 3],
                   'note': '同一指标在旧系统的不同算法（按 时间口径 / 计数方式 / 过滤条件 / 来源 归纳），统一为标准口径，差异逐条说明'},
         'tips': {'issues': '<div style="font-weight:600;color:var(--text)">现状问题</div><div>客户现有 DataWorks 全部任务的自动诊断：架构分层、重复开发、指标冗余、性能、调度依赖、数据质量、安全。每条可展开明细。</div>',
                  'map': '<div style="font-weight:600;color:var(--text)">旧表 → 标准表</div><div>每张旧 Hive 表与回流表归到哪张标准表：合并 / 改名 / 回流改造 / 移出数仓 / 下线。迁移时按此逐张切换并对数。</div>',
                  'cover': '<div style="font-weight:600;color:var(--text)">导出模型覆盖</div><div>客户导出到 MySQL / Oracle / SelectDB 等的应用层模型，每个字段对到标准指标与标准 ADS：已覆盖 / 时间表派生（年 / 月 / 周、累计列）/ 已补全。</div>',
                  'unify': '<div style="font-weight:600;color:var(--text)">口径统一</div><div>同一个指标在旧系统有多种算法时逐个列出（Vn），说明与标准口径的差异；标准口径见「指标口径 · 口径字典」。</div>',
                  'nodes': '<div style="font-weight:600;color:var(--text)">旧节点清单</div><div>导出包里的全部节点（同步、SQL、Python），可按工作空间、类型、处理方式筛选。</div>'},
         'reportHref': '../docs/问题清单.md',
         'extra': [
             {'k': 'consume', 'label': '消费清单', 'cols': sh_['消费清单']['cols'], 'rows': [[str(x) for x in r] for r in sh_['消费清单']['rows']], 'filters': [0, 7, 8, 16],
              'links': ['标准表'], 'ph': '搜索旧节点 / 旧表 / 目标库表 / 标准表…',
              'pills': {'覆盖结论': {'已承接（': 'g', '已承接到标准表；': 'o', '已承接到标准表（': 'b', '已承接；源表': 'o', '未映射': 'r'}},
              'note': f"排除下线 / 纯同步后仍给业务用的数据：导出回流 {sum(1 for r in sh_['消费清单']['rows'] if r[0] == '导出回流')} 个 + 末端 ADS（BI 直读）"
                      f"{sum(1 for r in sh_['消费清单']['rows'] if r[0] != '导出回流')} 个；沿血缘追到业务库源表 → ODS → 业务过程，标注业务域 / 数据域与字段口径覆盖",
              'tip': '<div style="font-weight:600;color:var(--text)">消费清单</div><div>业务在用的旧表（导出到 MySQL / Oracle / SelectDB 等，或 BI 直读的末端 ADS），每个都追到业务过程与标准表；「待补口径字段」是导出字段里还没逐一对到标准指标的数量。</div>'},
             {'k': 'proc', 'label': '业务过程', 'cols': sh_['业务过程']['cols'], 'rows': [[str(x) for x in r] for r in sh_['业务过程']['rows']], 'filters': [1, 2, 6],
              'links': ['标准 DWD（原子事实表）'], 'ph': '搜索业务过程 / DWD / ODS…', 'pills': {'状态': {'新增': 'o', '已有': 'g'}},
              'note': f"业务域（给哪块业务用）× 数据域（是什么数据）× 业务过程（不可再拆的业务动作）：{len(domains.PROC)} 个业务过程，每个一张最细粒度 DWD（粒度 = 业务库一行事件），"
                      f"其中 {sum(1 for p_ in domains.PROC if p_[9])} 个为本次按消费清单补齐",
              'tip': '<div style="font-weight:600;color:var(--text)">业务过程</div><div>按业务实际在用的数据倒推：每个业务过程一张原子事实表，DWS / ADS 都从这里汇总，不再直接读 ODS 或报表库预计算表。</div>'},
             {'k': 'bus2', 'label': '业务过程总线矩阵', 'cols': sh_['业务过程总线矩阵']['cols'], 'rows': [[str(x) for x in r] for r in sh_['业务过程总线矩阵']['rows']], 'filters': [1],
              'links': ['事实表'], 'ph': '搜索业务过程…', 'note': '行 = 业务过程（事实表），列 = 一致性维度；✓ 表示该事实表带有此维度外键，可与其他业务过程按此维度对齐分析',
              'tip': '<div style="font-weight:600;color:var(--text)">业务过程总线矩阵</div><div>Kimball 总线矩阵：同一维度在所有事实表里含义一致，跨业务过程分析（如 下单 × 核销 × 出入园）按共有维度关联。</div>'},
             {'k': 'odsrole', 'label': 'ODS 去向', 'cols': sh_['ODS去向']['cols'], 'rows': [[str(x) for x in r] for r in sh_['ODS去向']['rows']], 'filters': [2, 3, 6],
              'links': ['ODS 表'], 'ph': '搜索 ODS / 去向…',
              'pills': {'角色': {'业务过程': 'g', '维度': 'b', '属性关联': 'b', '未在用': '', '报表库预计算': 'o', '外部数据': '', '项目专用': '', '运营日志': ''}, '是否在用': {'在用': 'g', '未被': ''}},
              'note': f"{sum(1 for r in sh_['ODS去向']['rows'])} 张 ODS 每张的角色：业务过程来源 / 维度来源 / 属性关联 / 报表库预计算（只供对数）/ 外部 / 项目专用 / 未在用（保留同步暂不建模）",
              'tip': '<div style="font-weight:600;color:var(--text)">ODS 去向</div><div>每张业务库同步表进了哪个业务过程或维度；未被在用链路使用的标出原因，需求来了再按业务过程补 DWD。</div>'}]}
    meta = {'mode': 'legacy', 'xlsx': xlsx.name, 'built': datetime.date.today().isoformat(), 'dict2': xlsx.name,
            'desc': '客户现有 DataWorks 按 PFT3.0 标准重构后的统一数仓：分层、业务域、口径与旧表映射',
            'downloads': [[xlsx.name, '标准化字典（Excel，含旧表映射）'], ['ADS指标体系.xlsx', 'ADS 指标体系（Excel）']],
            'dlNote': '分层、命名、口径、日粒度 ADS 与时间表与 PFT3.0 同一套标准；日期表与时间表直接共用'}
    cal = etl_gen.date_calendar()
    d10 = lambda x: f'{x[:4]}-{x[4:6]}-{x[6:]}'
    hol = {}
    for r in cal['holiday_rows']:
        hol.setdefault(r[1], []).append([r[3], r[2], d10(r[4]), d10(r[5])])
    js = lambda o: json.dumps(o, ensure_ascii=False, separators=(',', ':'), default=str).replace('</', '<\\/')
    orig = {'changed': {}, '表清单': {'cols': disp['表清单']['cols'], 'rows': []}, '字段清单': {'cols': disp['字段清单']['cols'], 'rows': []}, 'ADS业务指标': disp['ADS业务指标']}
    tpl = (ROOT.parent / 'dw-dict' / 'src' / 'template.html').read_text(encoding='utf-8').replace('<title>PFT3.0 数仓字典</title>', '<title>旧版数仓标准化</title>')
    html = (tpl.replace('__LEGACY__', js(L)).replace('__SRC__', js(src)).replace('__HOL__', js(hol)).replace('__DATA__', js(disp)).replace('__ORIG__', js(orig))
            .replace('__CHECKS__', js(res)).replace('__META__', js(meta)).replace('__ADS__', js(model_)).replace('__ETL__', js(etl)))
    (out / 'index.html').write_text(html, encoding='utf-8')
    ads_model.to_xlsx(model_, out / 'ADS指标体系.xlsx', xlsx.name)
    print('页面 ->', out / 'index.html', f'{len(html) / 1e6:.1f} MB', '自检', res['summary'])
    return sh_, stats


if __name__ == '__main__':
    main()
