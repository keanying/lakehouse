"""业务库原始表（MySQL，ODS 的上游）：从 docs/source/pft-arch-02-database.md 解析，整理成与「表清单 / 字段清单」同样的行结构。

分层记为 SRC；表名写成「库.表」（如 pft-order.t_order_group），与 ODS 表清单「来源」列的写法一致，便于互相链接。
"""
import collections, re

DOC = 'pft-arch-02-database.md'
AUDIT = {'create_time', 'update_time', 'create_by', 'update_by', 'deleted'}


def _split_cols(body):
    """CREATE TABLE 括号内按行拆：列定义 + 索引定义（DDL 每列一行）。"""
    cols, keys = [], []
    for line in body.split('\n'):
        l = line.strip().rstrip(',')
        if not l or l.startswith('--'):
            continue
        if re.match(r'(PRIMARY\s+KEY|UNIQUE\s+KEY|UNIQUE|KEY|INDEX|CONSTRAINT|FOREIGN|FULLTEXT)\b', l, re.I):
            keys.append(l)
            continue
        m = re.match(r'`?(\w+)`?\s+([A-Za-z]+(?:\([^)]*\))?(?:\s+UNSIGNED)?)(.*)$', l)
        if not m:
            continue
        rest = m.group(3)
        cm = re.search(r"COMMENT\s+'((?:[^']|'')*)'", rest, re.I)
        df = re.search(r"DEFAULT\s+('(?:[^']|'')*'|[\w.()]+(?:\s+ON\s+UPDATE\s+\w+)?)", rest, re.I)
        cols.append({'n': m.group(1), 'type': m.group(2).upper(), 'null': 'NOT NULL' not in rest.upper(),
                     'default': df.group(1) if df else '', 'auto': 'AUTO_INCREMENT' in rest.upper(),
                     'cmt': cm.group(1).replace("''", "'") if cm else ''})
    return cols, keys


def parse(docs_dir):
    txt = (docs_dir / DOC).read_text(encoding='utf-8')
    head, body = txt.split('## 二、完整DDL', 1)
    # 一、领域表清单：表 -> [(库, 领域中文, 说明)]
    listed, dom_db, cur = collections.OrderedDict(), {}, None
    for line in head.split('\n'):
        m = re.match(r'### \d+\.\s*(.*?)（(pft-[\w-]+) 库', line)
        if m:
            cur = (m.group(2), m.group(1))
            dom_db[m.group(1)] = m.group(2)
            continue
        m = re.match(r'\|\s*(t_\w+)\s*\|\s*([^|]*)\|', line)
        if m and cur:
            listed.setdefault(m.group(1), []).append((cur[0], cur[1], m.group(2).replace('**', '').strip()))
    # 二、完整DDL：每个 CREATE TABLE 及其所在的领域小节、表标题
    tables, sec, title = collections.OrderedDict(), '', {}
    pos = 0
    for m in re.finditer(r'^### [\d.]+\s*(\S+)|^#### (t_\w+)（([^）]*)）|^(CREATE TABLE\s+(?:IF NOT EXISTS\s+)?`?(\w+)`?\s*\((.*?)\n\)\s*(?:[^;\n]*?COMMENT\s*=?\s*\'((?:[^\']|\'\')*)\')?[^;\n]*;)',
                         body, re.S | re.M):
        if m.group(1):
            sec = m.group(1)
        elif m.group(2):
            title[m.group(2)] = m.group(3)
        else:
            name = m.group(5)
            cols, keys = _split_cols(m.group(6))
            tables[name] = {'ddl': m.group(4), 'cols': cols, 'keys': keys, 'tcmt': (m.group(7) or '').replace("''", "'"),
                            'sec': sec, 'title': title.get(name, '')}
    return listed, dom_db, tables


def build(docs_dir, data):
    """返回 {'tables': 表清单行, 'fields': 字段清单行, 'ddl': {表: DDL}, 'info': {表: 附加信息}}，列与 data 中两张表一致。"""
    listed, dom_db, tables = parse(docs_dir)
    T, F = data['表清单'], data['字段清单']
    tc, fc = T['cols'], F['cols']
    ti, fi = {c: i for i, c in enumerate(tc)}, {c: i for i, c in enumerate(fc)}
    # ODS 表：来源里写的「库.表」-> ODS 表；ODS 字段的上游字段「库.表.列」-> 字段类别
    down, dom_of, cat_of = collections.defaultdict(list), {}, {}
    for r in T['rows']:
        if not str(r[ti['分层']]).startswith('ODS'):
            continue
        for db, t in re.findall(r'(pft-[\w-]+)\.(t_\w+)', str(r[ti['来源']])):
            down[f'{db}.{t}'].append(str(r[ti['表名（库.表）']]).split('.', 1)[-1])
            dom_of.setdefault(db, collections.Counter())[r[ti['业务域']]] += 1
    for r in F['rows']:
        if str(r[fi['分层']]).startswith('ODS'):
            m = re.match(r'(pft-[\w-]+\.t_\w+\.\w+)$', str(r[fi['加工 / 来源']]).strip())
            if m:
                cat_of.setdefault(m.group(1), r[fi['字段类别']])
    trows, frows, ddl, info = [], [], {}, {}
    entries = []
    for t, x in tables.items():
        pairs = listed.get(t) or [(dom_db.get(x['sec'].replace('域', '') + '域', ''), x['sec'], '')]
        for db, dom_cn, desc in pairs:
            entries.append((db, t, dom_cn, desc, x))
    for no, (db, t, dom_cn, desc, x) in enumerate(entries, 1):
        name = f'{db}.{t}'
        pk = next((re.findall(r'\w+', k.split('(', 1)[1]) for k in x['keys'] if re.match(r'PRIMARY', k, re.I)), [])
        uks = [re.findall(r'\w+', k.split('(', 1)[1]) for k in x['keys'] if re.match(r'UNIQUE', k, re.I)]
        uk_cols = {c for u in uks for c in u}
        same = [d for d, _, _ in listed.get(t, []) if d != db]
        ods = down.get(name, [])
        dom = (dom_of.get(db) or collections.Counter()).most_common(1)
        note = [x['tcmt']]
        if same:
            note.append(f'{"、".join(same)} 库有同名表（{desc or "结构相同"}）')
        if not ods:
            note.append('未接入 ODS')
        row = [''] * len(tc)
        row[ti['序号']] = no
        row[ti['分层']] = 'SRC'
        row[ti['业务域']] = dom[0][0] if dom else ''
        row[ti['表名（库.表）']] = name
        row[ti['表中文名']] = x['title'] or re.split(r'[（(]', desc)[0].strip()
        row[ti['粒度']] = f'1行=1条{x["title"] or "记录"}（主键 {"、".join(pk) or "—"}）'
        row[ti['后缀含义']] = 'MySQL 业务表'
        row[ti['分区']] = '无（业务库，按 tenant_id 分库）' if any(c['n'] == 'tenant_id' for c in x['cols']) else '无（业务库）'
        row[ti['来源']] = f'业务系统 {db} 库（{dom_cn}），{DOC}'
        row[ti['度量 / 口径 / 关键字段']] = '；'.join(filter(None, [f'主键：{"、".join(pk)}' if pk else '',
                                                              '唯一键：' + '；'.join('、'.join(u) for u in uks) if uks else '']))
        row[ti['上游表']] = ''
        row[ti['下游表']] = '、'.join(ods)
        row[ti['备注']] = '；'.join(filter(None, note))
        trows.append(row)
        ddl[name] = x['ddl']
        info[name] = {'db': db, 'domain_cn': dom_cn, 'keys': x['keys'], 'ods': ods}
        for i, c in enumerate(x['cols'], 1):
            cat = cat_of.get(f'{name}.{c["n"]}') or ('主键' if c['n'] in pk else '业务主键' if c['n'] in uk_cols
                                                    else '时间' if c['n'] in AUDIT and c['n'].endswith('time')
                                                    else 'ETL' if c['n'] in AUDIT else '外键' if c['n'].endswith('_id') else '维度属性')
            fr = [''] * len(fc)
            fr[fi['分层']] = 'SRC'
            fr[fi['表名（库.表）']] = name
            fr[fi['表中文名']] = row[ti['表中文名']]
            fr[fi['序号']] = i
            fr[fi['字段名']] = c['n']
            fr[fi['类型']] = c['type']
            fr[fi['字段类别']] = cat
            fr[fi['字段注释']] = c['cmt']
            fr[fi['加工 / 来源']] = '；'.join(filter(None, ['可空' if c['null'] else 'NOT NULL',
                                                       'AUTO_INCREMENT' if c['auto'] else '',
                                                       f'默认 {c["default"]}' if c['default'] else '']))
            fr[fi['上游字段']] = ''
            frows.append(fr)
    return {'tables': trows, 'fields': frows, 'ddl': ddl, 'info': info}
