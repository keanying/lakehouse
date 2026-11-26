"""旧系统导出模型的口径追溯：从导出读取的 Hive 列出发，沿旧 SQL 血缘向下追到最底层的计算公式与过滤条件。

结果缓存到 legacy_formulas.json（构建时直接读取）。刷新：python3 dataworks/standard/lineage.py
"""
import json, pathlib, re, signal, sys
HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))
import parse, sqlglot
from sqlglot import exp
from sqlglot.lineage import lineage
def stmt_for(C,t):
    for n in C['tables'][t]['writers']:
        if n['lang']!='sql': continue
        s=parse._strip_comments(n['script'])
        s=re.sub(r'\$\{[^}]*\}','20250101',s); s=re.sub(r'\$\[[^\]]*\]','20250101',s)
        for st in s.split(';'):
            if re.search(r'insert\s+(overwrite|into)\s+(table\s+)?`?'+t+r'`?\b',st,re.I): return st
SCH=None
def schema(C):
    global SCH
    if SCH is None:
        SCH={}
        for t,x in C['schemas'].items():
            SCH[t]={c:'STRING' for c,_,_ in x['cols']+x['parts']}
        for k,s in C['sources'].items():
            for l in s['landing']:
                SCH.setdefault(l,{}).update({c.lower():'STRING' for c in s['cols'] if c.replace('_','').isalnum()})
        for v in SCH.values():
            for p in ('pt','dt','ds','insert_date','orderdate','order_date'): v.setdefault(p,'STRING')
    return SCH
def _deep(q,name,C):
    node=lineage(name,q,schema=schema(C),dialect='spark')
    for nd in node.walk():
        e=nd.expression
        if isinstance(e,exp.Alias): e=e.this
        if e.find(exp.AggFunc) or e.find(exp.Case) or e.find(exp.If):
            return e
    e=node.expression
    return e.this if isinstance(e,exp.Alias) else e
def formulas(C,t,cols):
    st=stmt_for(C,t)
    if not st: return None,'no sql'
    try: tree=sqlglot.parse_one(st,read='spark')
    except Exception as e: return None,'parse err '+str(e)[:80]
    q=tree.expression
    sel=q
    while isinstance(sel,(exp.Union,)): sel=sel.left
    if isinstance(sel,exp.Subquery): sel=sel.this
    if not isinstance(sel,exp.Select): sel=q.find(exp.Select)
    projs=sel.expressions
    ddl=[c for c,_,_ in (C['schemas'].get(t) or {}).get('cols',[])]
    out={}
    for c in cols:
        try:
            if c in [p.alias_or_name for p in projs]:
                pr=next(p for p in projs if p.alias_or_name==c)
            elif c in ddl and ddl.index(c)<len(projs):
                pr=projs[ddl.index(c)]
            else:
                out[c]='ERR 找不到列';continue
            e=pr.this if isinstance(pr,exp.Alias) else pr
            if e.find(exp.AggFunc) or e.find(exp.Case) or e.find(exp.If):
                out[c]=e.sql(dialect='spark')
            else:
                out[c]=_deep(q,pr.alias_or_name,C).sql(dialect='spark')
        except Exception as ex:
            out[c]='ERR '+str(ex)[:60]
    return out,None

def _agg_node(q,name,C):
    """→ (聚合表达式, 所在查询的 WHERE)"""
    node=lineage(name,q,schema=schema(C),dialect='spark')
    for nd in node.walk():
        e=nd.expression
        if isinstance(e,exp.Alias): e=e.this
        if e.find(exp.AggFunc) or e.find(exp.Case) or e.find(exp.If):
            src=nd.source
            w=src.args.get('where') if isinstance(src,exp.Select) else None
            return e,(w.this.sql(dialect='spark') if w else '')
    e=node.expression
    return (e.this if isinstance(e,exp.Alias) else e),''

def base_formula(C,t,col,depth=0,seen=None):
    """沿旧表血缘向下追到最底层的计算：返回 [(表, 公式, 过滤条件)]"""
    seen=seen or set()
    if depth>4 or (t,col) in seen: return []
    seen.add((t,col))
    st=stmt_for(C,t)
    if not st: return []
    try: tree=sqlglot.parse_one(st,read='spark')
    except Exception: return []
    q=tree.expression
    sel=q
    while isinstance(sel,exp.Union): sel=sel.left
    if isinstance(sel,exp.Subquery): sel=sel.this
    if not isinstance(sel,exp.Select): sel=q.find(exp.Select)
    projs=sel.expressions
    ddl=[c for c,_,_ in (C['schemas'].get(t) or {}).get('cols',[])]
    try:
        if col in [p.alias_or_name for p in projs]: pr=next(p for p in projs if p.alias_or_name==col)
        elif col in ddl and ddl.index(col)<len(projs): pr=projs[ddl.index(col)]
        else: return []
        e=pr.this if isinstance(pr,exp.Alias) else pr
        w=''
        if not (e.find(exp.AggFunc) or e.find(exp.Case) or e.find(exp.If)):
            e,w=_agg_node(q,pr.alias_or_name,C)
    except Exception:
        return []
    out=[(t,e.sql(dialect='spark'),w)]
    # 如果只是对上游表某列再求和 / 透传，继续往下追
    cols=[c for c in e.find_all(exp.Column)]
    aggs=list(e.find_all(exp.AggFunc))
    simple=len(cols)==1 and (not aggs or all(isinstance(a,(exp.Sum,exp.Max,exp.Min)) for a in aggs)) and not e.find(exp.Case) and not e.find(exp.If)
    if simple:
        c=cols[0]
        ups=[r.lower().split('.')[-1] for n in C['tables'].get(t,{}).get('writers',[]) for r in n['reads']]
        tb=c.table.lower() if c.table else ''
        cand=[u for u in ups if u==tb] or [u for u in ups if c.name.lower() in {x for x,_,_ in (C['schemas'].get(u) or {}).get('cols',[])}]
        for u in cand[:1]:
            out+=base_formula(C,u,c.name.lower(),depth+1,seen)
    return out


def run():
    import catalog
    import legacy_metrics as LM
    nodes = parse.load(HERE.parent.parent / 'DATAWORKS.zip')
    C = catalog.build(nodes)

    class TO(Exception):
        pass

    def _h(*a):
        raise TO()
    signal.signal(signal.SIGALRM, _h)
    out, done = {}, set()
    for n in nodes:
        if not (n['type'] == 'DI' and n['di'] and n['di'].get('reader', {}).get('type') == 'hive' and n['di'].get('writer', {}).get('type') not in ('hive', None)):
            continue
        r = n['di']['reader']
        if not r.get('tables'):
            continue
        t = str(r['tables'][0]).lower().split('.')[-1]
        for c in r.get('columns') or []:
            if not isinstance(c, str):
                continue
            c = c.lower().strip('`')
            if (t, c) in done or not LM.decode(c, t):
                continue
            done.add((t, c))
            signal.alarm(20)
            try:
                out[f'{t}.{c}'] = base_formula(C, t, c)
            except Exception:
                out[f'{t}.{c}'] = []
            signal.alarm(0)
    (HERE / 'legacy_formulas.json').write_text(json.dumps(out, ensure_ascii=False, indent=0), encoding='utf-8')
    print('traced', len(out), 'with formula', sum(1 for v in out.values() if v))


if __name__ == '__main__':
    sys.path.insert(0, str(HERE))
    run()
