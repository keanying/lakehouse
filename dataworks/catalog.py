"""旧系统资产目录：每张 Hive 表的字段（来自建表语句）、写入任务、读取任务；每张业务源表的同步任务与字段。"""
import collections, re

import parse

sh = lambda t: str(t).split('.')[-1].lower().strip('`')


def _cols(body):
    """CREATE TABLE 括号内的列：[(名, 类型, 注释)]"""
    out, depth, cur = [], 0, ''
    for ch in body:          # 按顶层逗号切分（DECIMAL(10,2) 里的逗号不切）
        if ch == '(':
            depth += 1
        elif ch == ')':
            depth -= 1
        if ch == ',' and depth == 0:
            out.append(cur)
            cur = ''
        else:
            cur += ch
    out.append(cur)
    cols = []
    for x in out:
        m = re.match(r"\s*`?(\w+)`?\s+([A-Za-z]+(?:\s*<[^>]*>|\s*\([^)]*\))?)(?:.*?\bcomment\s+'((?:[^']|\\')*)')?", x, re.I | re.S)
        if m and m.group(1).lower() not in ('primary', 'key', 'constraint', 'index', 'unique'):
            cols.append((m.group(1).lower(), re.sub(r'\s+', '', m.group(2)).upper(), (m.group(3) or '').strip()))
    return cols


def ddl_schemas(nodes):
    """所有建表语句：表 -> {cols, parts, comment, node}（同一张表多处建表取字段最多的一处）"""
    out = {}
    for n in nodes:
        if n['lang'] != 'sql':
            continue
        s = parse._strip_comments(n['script'])
        for st in s.split(';'):
            m = re.search(r'create\s+(?:external\s+)?table\s+(?:if\s+not\s+exists\s+)?([`\w.]+)\s*\(', st, re.I)
            if not m:
                continue
            i, depth = m.end(), 1
            j = i
            while j < len(st) and depth:
                depth += {'(': 1, ')': -1}.get(st[j], 0)
                j += 1
            cols = _cols(st[i:j - 1])
            rest = st[j:]
            tc = re.match(r"\s*comment\s+'((?:[^']|\\')*)'", rest, re.I)
            pm = re.search(r'partitioned\s+by\s*\((.*?)\)\s*(?:stored|row|location|tblproperties|clustered|$)', rest, re.I | re.S)
            t = sh(m.group(1))
            rec = {'cols': cols, 'parts': _cols(pm.group(1)) if pm else [], 'comment': tc.group(1) if tc else '', 'node': n['path']}
            if t not in out or len(cols) > len(out[t]['cols']):
                out[t] = rec
    return out


def build(nodes):
    """返回 {'tables': {表: 信息}, 'sources': {(数据源, 源表): 信息}}"""
    schemas = ddl_schemas(nodes)
    T = collections.defaultdict(lambda: {'writers': [], 'readers': [], 'kind': 'hive', 'schema': None, 'sources': set()})
    S = collections.defaultdict(lambda: {'nodes': [], 'cols': [], 'landing': set(), 'where': set(), 'targets': set()})
    for n in nodes:
        if n['type'] == 'DI' and n['di'] and 'reader' in n['di']:
            r, w = n['di']['reader'], n['di']['writer']
            for t in w.get('tables', []):
                k = sh(t) if w.get('type') == 'hive' else f"{w.get('datasource')}.{sh(t)}"
                T[k]['writers'].append(n)
                T[k]['kind'] = 'hive' if w.get('type') == 'hive' else 'export'
            for t in r.get('tables', []) or []:
                if r.get('type') == 'hive':
                    T[sh(t)]['readers'].append(n)
                elif r.get('type'):
                    key = (str(r.get('datasource')), sh(t))
                    s = S[key]
                    s['nodes'].append(n)
                    if len(r.get('columns') or []) > len(s['cols']):
                        s['cols'] = [c for c in r['columns'] if isinstance(c, str)]
                    s['where'].add(str(r.get('where', '')).strip())
                    s['type'] = r.get('type')
                    if r.get('tableComment'):
                        s['comment'] = r['tableComment']
                    for wt in w.get('tables', []):
                        (s['landing'] if w.get('type') == 'hive' else s['targets']).add(sh(wt) if w.get('type') == 'hive' else f"{w.get('datasource')}.{sh(wt)}")
                        if w.get('type') == 'hive':
                            T[sh(wt)]['sources'].add(key)
        elif n['lang'] == 'sql':
            for t, k in n['writes']:
                if k != 'ddl':
                    T[sh(t)]['writers'].append(n)
            for t in n['reads']:
                T[sh(t)]['readers'].append(n)
    for t, x in T.items():
        x['schema'] = schemas.get(t)
    return {'tables': dict(T), 'sources': dict(S), 'schemas': schemas}
