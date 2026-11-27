"""解析 DataWorks 导出包（DATAWORKS.zip）：节点、调度、依赖、SQL 读写表、数据集成同步任务。

导出包结构：<工作空间>/<目录…>/<节点>/
  .dataworks/<类型>.type        节点类型（DI / EMR_SPARK_SQL / SERVERLESS_SPARK_SQL / WORKFLOW / VIRTUAL …）
  .dataworks/metadata.json      节点 uuid、脚本 / 调度文件路径
  <节点>.schedule.json          调度：cron、实例方式、重跑、资源组、负责人、依赖（dependencies）、产出（outputs）
  <节点>.spec.json              工作流的调度配置
  <节点>.sql / .py / .sh        脚本；数据集成（DI）为 <节点>.json
"""
import pathlib
import collections, json, posixpath, re, zipfile

KW = set('''select from where join left right inner outer full cross on and or not in is null as with group by order
having limit union all distinct case when then else end lateral view explode values table insert overwrite into
partition exists between like rlike cast if over desc asc using semi anti'''.split())


def _strip_comments(sql):
    out, i, n, q = [], 0, len(sql), None
    while i < n:
        c = sql[i]
        if q:
            out.append(c)
            if c == '\\' and i + 1 < n:
                out.append(sql[i + 1]); i += 2; continue
            if c == q:
                q = None
            i += 1
        elif c in ("'", '"', '`'):
            q = c; out.append(c); i += 1
        elif sql.startswith('--', i):
            j = sql.find('\n', i); i = n if j < 0 else j
        elif sql.startswith('/*', i):
            j = sql.find('*/', i + 2); i = n if j < 0 else j + 2
        else:
            out.append(c); i += 1
    return ''.join(out)


def _tbl(x):
    return x.replace('`', '').strip().lower()


def sql_io(sql):
    """返回 (写入表, 读取表, 语句统计)。不依赖完整语法解析，容忍 ${变量}。"""
    s = _strip_comments(sql)
    s = re.sub(r'\$\{[^}]*\}|\$\[[^\]]*\]', '__v__', s)
    writes, reads, ddl = [], [], collections.Counter()
    for m in re.finditer(r'\binsert\s+(overwrite|into)\s+(?:table\s+)?([`\w.]+)', s, re.I):
        writes.append((_tbl(m.group(2)), m.group(1).lower()))
    for m in re.finditer(r'\bcreate\s+(?:or\s+replace\s+)?(temporary\s+|external\s+)?(table|view)\s+(?:if\s+not\s+exists\s+)?([`\w.]+)(.{0,4000}?)(?:;|$)', s, re.I | re.S):
        kind = 'ctas' if re.search(r'\bas\s+(select|with)\b', m.group(4), re.I) else 'ddl'
        if m.group(1) and m.group(1).strip().lower() == 'temporary':
            kind = 'temp'
        if m.group(2).lower() == 'view':
            kind = 'view'
        ddl[kind] += 1
        if kind in ('ctas', 'view'):
            writes.append((_tbl(m.group(3)), kind))
        elif kind == 'ddl':
            writes.append((_tbl(m.group(3)), 'ddl'))
    for k in ('drop table', 'truncate table', 'alter table', 'msck repair', 'drop view'):
        ddl[k] += len(re.findall(r'\b' + k.replace(' ', r'\s+') + r'\b', s, re.I))
    ctes = {x.lower() for x in re.findall(r'(?:\bwith|,)\s*([`\w]+)\s+as\s*\(', s, re.I)}
    for m in re.finditer(r'\b(from|join)\s+([`\w.]+)', s, re.I):
        t = _tbl(m.group(2))
        prev = s[max(0, m.start() - 40):m.start()]
        if m.group(1).lower() == 'from' and re.search(r'\b(extract|trim|substring|position)\s*\([^()]*$', prev, re.I):
            continue
        if t in KW or t in ctes or t.startswith('__v__') or re.fullmatch(r'[\d.]+', t):
            continue
        reads.append(t)
    w = {t for t, _ in writes}
    return writes, sorted(set(reads) - w) + sorted(set(reads) & w), ddl


def _di(js):
    """数据集成任务：读端 / 写端"""
    out = {'reader': {}, 'writer': {}}
    steps = js.get('steps') or (js.get('externalCode') or {}).get('steps') or []   # 新版导出（filespec）放在 externalCode 里
    for st in steps:
        p = st.get('parameter', {})
        tables = []
        for c in p.get('connection', []) or []:
            tables += c.get('table', []) if isinstance(c.get('table'), list) else [c.get('table')] if c.get('table') else []
            if c.get('querySql'):
                out[st.get('category', '')]['querySql'] = c['querySql']
        if p.get('table'):
            tables.append(p['table'])
        side = st.get('category')
        if side not in out:
            continue
        out[side].update({'type': st.get('stepType'), 'datasource': p.get('datasource') or (p.get('connection') or [{}])[0].get('datasource'),
                          'tables': [str(t) for t in tables if t], 'columns': p.get('column') or [], 'where': p.get('where', ''),
                          'partition': p.get('partition', ''), 'writeMode': p.get('writeMode', ''), 'splitPk': p.get('splitPk', ''),
                          'preSql': p.get('preSql', []), 'postSql': p.get('postSql', []), 'tableComment': p.get('tableComment', '')})
    out['cu'] = (js.get('extend') or {}).get('cu')
    out['setting'] = js.get('setting', {})
    return out


def load(zip_path):
    z = zipfile.ZipFile(zip_path)
    names = [n for n in z.namelist() if not n.endswith('/')]
    by_dir = collections.defaultdict(list)
    for n in names:
        parts = n.split('/')
        if '.dataworks' in parts:
            d = '/'.join(parts[:parts.index('.dataworks')])
            by_dir[d].append(n)
        else:
            by_dir[posixpath.dirname(n)].append(n)
    node_dirs = sorted(d for d, fs in by_dir.items() if any(f.endswith('.dataworks/metadata.json') for f in fs))
    wf_dirs = {d for d in node_dirs if any(f.endswith('WORKFLOW.type') for f in by_dir[d])}
    read = lambda n: z.read(n).decode('utf-8', 'replace')
    nodes = []
    for d in node_dirs:
        fs = by_dir[d]
        typ = next((posixpath.basename(f)[:-5] for f in fs if f.endswith('.type')), '')
        meta = json.loads(read(next(f for f in fs if f.endswith('.dataworks/metadata.json'))))
        base = posixpath.basename(d)
        sched_f = next((f for f in fs if f.endswith('.schedule.json') or f.endswith('.spec.json')), None)
        spec = json.loads(read(sched_f)) if sched_f else {}
        sp = spec.get('spec', {})
        obj = (sp.get('nodes') or sp.get('workflows') or [{}])[0]
        trig, strat = obj.get('trigger', {}), obj.get('strategy', {})
        script = obj.get('script', {}) or {}
        md = obj.get('metadata', {}) or {}
        rel = d.split('/', 1)[1] if d.startswith('DATAWORKS/') else d
        ws = rel.split('/')[0]
        wf = next((w for w in sorted(wf_dirs, key=len, reverse=True) if d != w and d.startswith(w + '/')), None)
        n = {'id': obj.get('id') or meta.get('uuid'), 'name': obj.get('name') or base, 'type': typ, 'path': rel, 'ws': ws,
             'dir': '/'.join(rel.split('/')[1:-1]), 'workflow': posixpath.basename(wf) if wf else '',
             'workflow_id': (md.get('container') or {}).get('uuid', ''),
             'cron': trig.get('cron', ''), 'trigger': trig.get('type', ''), 'delay': trig.get('delaySeconds', 0),
             'recurrence': obj.get('recurrence') or strat.get('recurrenceType', ''), 'instance': obj.get('instanceMode') or strat.get('instanceMode', ''),
             'rerun': obj.get('rerunMode') or strat.get('rerunMode', ''), 'rerun_times': obj.get('rerunTimes', strat.get('rerunTimes')),
             'timeout': obj.get('timeout', strat.get('timeout')), 'owner': md.get('ownerName', ''), 'created': md.get('createTime', ''),
             'resource_group': (obj.get('runtimeResource') or {}).get('resourceGroup', ''), 'cu': (script.get('runtime') or {}).get('cu'),
             'engine': (obj.get('datasource') or {}).get('name', ''),
             'params': {p.get('name'): p.get('value') for p in script.get('parameters', []) or []},
             'outputs': [o.get('refTableName') or o.get('data') for o in (obj.get('outputs') or {}).get('nodeOutputs', [])],
             'output_ids': [o.get('data') for o in (obj.get('outputs') or {}).get('nodeOutputs', [])],
             'depends': [{'output': x.get('output'), 'ref': x.get('refTableName'), 'type': x.get('type')}
                         for dep in sp.get('dependencies', []) or [] for x in dep.get('depends', [])],
             'script': '', 'lang': '', 'writes': [], 'reads': [], 'ddl': {}, 'di': None}
        code = next((f for f in fs if posixpath.basename(f) in (f'{base}.sql', f'{base}.py', f'{base}.sh')), None)
        if code:
            n['script'], n['lang'] = read(code), code.rsplit('.', 1)[1]
            if n['lang'] == 'sql':
                w, r, dd = sql_io(n['script'])
                n['writes'], n['reads'], n['ddl'] = w, r, dict(dd)
        dij = next((f for f in fs if posixpath.basename(f) == f'{base}.json'), None)
        if typ == 'DI' and dij:
            try:
                n['di'] = _di(json.loads(read(dij)))
                n['script'] = read(dij)
                n['lang'] = 'json'
                w = n['di']['writer']
                n['writes'] = [(_tbl(t), 'di') for t in w.get('tables', [])]
                n['reads'] = [_tbl(t) for t in n['di']['reader'].get('tables', [])]
            except Exception as e:  # 少数导出不完整
                n['di'] = {'error': str(e)}
        nodes.append(n)
    ex = excluded()
    return [n for n in nodes if not any(n['path'] == x or n['path'].startswith(x + '/') for x in ex)]


def excluded():
    """exclude.txt 里的路径前缀：不纳入梳理的旧节点"""
    f = pathlib.Path(__file__).resolve().parent / 'exclude.txt'
    if not f.exists():
        return []
    return [l.strip().replace('\\', '/').strip('/') for l in f.read_text(encoding='utf-8').splitlines() if l.strip() and not l.strip().startswith('#')]
