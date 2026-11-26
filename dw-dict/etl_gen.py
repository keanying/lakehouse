#!/usr/bin/env python3
"""按字典生成每张 DWD / DIM / DWS / ADS 表的加工逻辑（SQL）。

依据：字段清单的「加工 / 来源」「上游字段」「字段类别」，表清单的粒度、分区、后缀，ADS 改造模型。
离线表生成 Spark SQL / Hive（INSERT OVERWRITE … PARTITION (travel_date='${bizdate}')），
实时 DWD / DWS 生成 Flink SQL（写 StarRocks），实时 ADS 生成 StarRocks 异步物化视图。

每个字段给出状态：
  auto    —— 加工说明是「表.字段 / 改名 / ÷100 / 按键关联」，直接翻译；
  rule    —— 按规则翻译（前后差、JSON 展开、状态变更时间、聚合 where 条件、修饰词条件…）；
  review  —— 加工说明是业务描述（递归、映射、运营配置…），生成了可运行的近似写法并在 SQL 里标「待确认」。
"""
import re
import collections

BIZ = '${bizdate}'
BIZ_DASH = '${bizdate_dash}'          # yyyy-MM-dd
PREV_DASH = '${bizdate_prev_dash}'    # 前一天 yyyy-MM-dd

# 修饰词 → (字段, 编码)
MODS = {
    '渠道类型': ('channel_type', {'小程序': 'MP', 'H5': 'H5', 'PC后台代下': 'PC', '线下窗口': 'OFFLINE', 'OTA/API': 'API'}),
    '支付方式': ('pay_method_type', {'微信': 'WECHAT', '支付宝': 'ALIPAY', '余额': 'BALANCE', '授信': 'CREDIT', '线下收款': 'OFFLINE'}),
    '权益类型': ('entitlement_type', {'固定型': 'FIXED', '选择型': 'SELECTABLE', '计次型': 'COUNTED', '计时型': 'TIMED', '不限次型': 'UNLIMITED', '额度型': 'QUOTA'}),
    '退款发起方': ('initiator_type', {}),
    '分销层级': ('chain_level_no', {'一级': '1', '二级': '2', '三级': '3', '四级': '4'}),
    '冻结类型': ('freeze_type', {'利润冻结': 'PROFIT', '采购款冻结': 'SETTLEMENT', '全款冻结': 'FULL'}),
    '操作人类型': ('operator_type', {'B端员工': 'TENANT_STAFF', 'C端游客': 'CUSTOMER'}),
    '通知渠道': ('notify_channel_type', {'短信': 'SMS', '小程序消息': 'MINI_PROGRAM_MSG', '邮件': 'EMAIL', 'Webhook': 'WEBHOOK'}),
}
LAYER_DB = {'ods': 'ods', 'dwd': 'dwd', 'dim': 'dim', 'dws': 'dws', 'ads': 'ads'}


SQL_WORDS = {'and', 'or', 'not', 'in', 'is', 'null', 'like', 'between', 'case', 'when', 'then', 'else', 'end', 'true', 'false',
             'distinct', 'as', 'date_format', 'date_sub', 'datediff', 'to_date', 'unix_timestamp', 'coalesce', 'nullif', 'cast',
             'string', 'bigint', 'int', 'decimal', 'round', 'hour', 'get_json_object', 'if', 'abs', 'least', 'greatest', 'yyyymmdd',
             'travel_date', 'sum', 'count', 'max', 'min', 'avg', 'current_date', 'current_timestamp', 'substr', 'length', 'size', 'split', 'lower', 'upper'}


def valid_sql(frag, cols=None):
    """粗检：只含 ASCII、括号配平、没有悬空运算符；给了 cols 时标识符须是关键字/函数或已知字段"""
    if not frag or any(ord(ch) > 127 for ch in frag):
        return False
    depth = 0
    for ch in re.sub(r"'[^']*'", '', frag):
        depth += ch == '('
        depth -= ch == ')'
        if depth < 0:
            return False
    if depth:
        return False
    if re.search(r"(^|[(,])\s*[*/+]|[*/+\-<>=]\s*($|[),])|\b(group|order)\s+by\b|\bof\b", frag, re.I):
        return False
    if cols is not None:
        for w in re.findall(r"'[^']*'|\b[A-Za-z_][A-Za-z0-9_.]*\b", frag):
            if w.startswith("'"):
                continue
            w0 = w.split('.')[-1]
            if w0.lower() not in SQL_WORDS and w0 not in cols:
                return False
    return True


def jc(lines):
    """拼 SELECT 列表：逗号放在行尾注释之前"""
    out = []
    for i, l in enumerate(lines):
        if i < len(lines) - 1:
            k = l.find('  -- ')
            l = (l[:k] + ',' + l[k:]) if k >= 0 else l + ','
        out.append(l)
    return '\n'.join(out)


def col_name(line):
    m = re.search(r'\bAS (\w+)\s*(,|$|  --)', line) or re.search(r'(?:^|\s)(?:\w+\.)?(\w+)\s*(,|$|  --)', line.strip())
    return m.group(1) if m else ''


def reorder(lines, order):
    """按目标表字段顺序排列 SELECT 列（INSERT 按位置写入）"""
    pos = {n: i for i, n in enumerate(order)}
    return sorted(lines, key=lambda l: pos.get(col_name(l), len(pos)))


def sn(s):
    return re.sub(r'^\w+\.', '', str(s or '').strip())


class Dict:
    def __init__(self, sheets):
        T, F = sheets['表清单'], sheets['字段清单']
        ti = {c: i for i, c in enumerate(T['cols'])}
        fi = {c: i for i, c in enumerate(F['cols'])}
        self.t = {}
        for r in T['rows']:
            name = sn(r[ti['表名（库.表）']])
            self.t[name] = {'name': name, 'full': r[ti['表名（库.表）']], 'layer': str(r[ti['分层']]).replace('（实时）', ''),
                            'rt': '实时' in str(r[ti['分层']]), 'cn': r[ti['表中文名']], 'grain': str(r[ti['粒度']]),
                            'suffix': name.rsplit('_', 1)[-1] if not name.endswith(('_hrs_f',)) else 'hrs_f',
                            'part': str(r[ti['分区']]), 'src': str(r[ti['来源']]), 'up': str(r[ti['上游表']]), 'note': str(r[ti['备注']])}
        self.f = collections.defaultdict(list)
        for r in F['rows']:
            self.f[sn(r[fi['表名（库.表）']])].append({'n': r[fi['字段名']], 'type': r[fi['类型']], 'cat': r[fi['字段类别']],
                                                     'cmt': str(r[fi['字段注释']]), 'p': str(r[fi['加工 / 来源']]).strip(),
                                                     'up': str(r[fi['上游字段']])})
        self.cols = {t: dict.fromkeys(x["n"] for x in fs) for t, fs in self.f.items()}   # 按字段清单顺序（有序，保证生成结果稳定）

    def db(self, t):
        return t.split('_', 1)[0]

    def keys(self, t):
        return [x['n'] for x in self.f[t] if x['cat'] in ('主键', '业务主键', '粒度键')]

    def pk(self, t):
        ks = [x['n'] for x in self.f[t] if x['cat'] == '主键'] or self.keys(t)
        return ks[0] if ks else 'id'

    def zipcols(self, t):
        z = [x['n'] for x in self.f[t] if x['cat'] == '拉链']
        return (z + ['start_date', 'end_date'])[:2]

    def find_code_col(self, t, code):
        """在表 t 的字段注释里找包含编码 code 的状态字段"""
        for x in self.f.get(t, []):
            if re.search(rf'\b{re.escape(code)}\b', x['cmt']) and x['cat'] in ('状态类型', '退化维度', '维度属性', '粒度键'):
                return x['n']
        return None


# ---------------------------------------------------------------- 公共
def part_filter(D, t, alias, target_suffix=None, history=False):
    """上游表 t 的分区条件"""
    m = D.t.get(t)
    if not m or m['rt']:
        return ''
    suf = t.rsplit('_', 1)[-1]
    if suf == 'f' and not t.endswith('_hrs_f'):
        return ''
    if suf == 'zip':
        return f"{alias}.travel_date = '{BIZ}' AND {alias}.{D.zipcols(t)[1]} = '9999-12-31'"
    if history and suf in ('di', 'hrs'):
        return f"{alias}.travel_date <= '{BIZ}'"
    return f"{alias}.travel_date = '{BIZ}'"


def header(D, t, kind, stats, extra=''):
    m = D.t[t]
    lines = [f"-- {m['full']}  {m['cn']}",
             f"-- 粒度：{m['grain']}",
             f"-- 来源：{m['src']}",
             f"-- 生成方式：{kind}；字段 {sum(stats.values())} 个：直接翻译 {stats['auto']} · 规则翻译 {stats['rule']} · 待确认 {stats['review']}"]
    if extra:
        lines.append('-- ' + extra)
    if stats['review']:
        lines.append('-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对')
    return '\n'.join(lines) + '\n'


# ---------------------------------------------------------------- DWD / DIM：行级加工
REF = re.compile(r'\b((?:ods|dwd|dim|dws|ads)_\w+)\.(\w+)')


class RowGen:
    """DWD、DIM 以及实时 DWD 的行级加工：一张主表 + 若干关联表"""

    def __init__(self, D, t, flink=False):
        self.D, self.t, self.flink = D, t, flink
        fs = D.f[t]
        cnt = collections.Counter()
        for x in fs:
            for m in REF.finditer(x['p']):
                if m.group(1) in D.t and m.group(1) != t:
                    cnt[m.group(1)] += 1
        src_order = [s for s in re.findall(r'(?:ods|dwd|dim)_\w+', D.t[t]['src']) if s in D.t]
        cands = [s for s in src_order if s in cnt] or [s for s, _ in cnt.most_common()]
        prefer = [s for s in cands if s.startswith(('ods_', 'dwd_'))] or cands
        self.main = max(prefer, key=lambda s: (cnt[s], -src_order.index(s) if s in src_order else -99)) if prefer else None
        self.joins = collections.OrderedDict()   # key -> (alias, sql)
        self.aliases = {self.main: 'a'} if self.main else {}
        self.unresolved = []
        self.spec = {}
        self.is_log = bool(re.search(r'变更|流转|状态|log|change|1行=1次|1行=1条变', D.t[t]['grain'] + t))

    def main_cols(self):
        return self.D.cols.get(self.main, set())

    def entity(self, s):
        m = re.match(r'(?:ods|dwd|dim)_[a-z]+_(\w+?)_(?:di|df|f|zip|rt)$', s)
        return m.group(1) if m else ''

    def join_key(self, s, hint):
        D, mc = self.D, self.main_cols()
        scols = D.cols.get(s, set())
        skeys = D.keys(s) + [c for c in scols if c.endswith(('_id', '_no', '_code'))]
        conds = []
        if hint:
            for part in re.split(r'\+', hint):
                if '=' in part:
                    l, r_ = part.split('=', 1)
                    conds.append((r_ if r_ in scols else (skeys[0] if skeys else r_), l))
                    continue
                k = part
                sc = k if k in scols else next((x for x in skeys if k.endswith(x) or x.endswith(k)), None)
                mk = k if k in mc else next((x for x in mc if x.endswith('_' + k) or (k.endswith('_' + x) and x not in ('id', 'no', 'code'))), None)
                if sc and mk:
                    conds.append((sc, mk))
                elif sc and not mk and k.endswith('_id') and 'id' in mc and k.startswith(self.entity(self.main)):
                    conds.append((sc, 'id'))
            if conds:
                return conds
        ent = self.entity(self.main)
        for e in ([ent, ent.split('_')[-1]] if ent else []):   # 如主表 sys_role → 关联表的 role_id
            if f'{e}_id' in scols and 'id' in mc:
                return [(f'{e}_id', 'id')]
        for k in skeys:
            if k in mc and k not in ('id', 'tenant_id', 'create_by', 'update_by'):
                return [(k, k)]
        es = self.entity(s)
        for k in skeys:
            if k in ('id', 'no', 'code'):
                # 通用主键 id 只和主表的「<实体>_id」对应（如 package_id → 套餐包.id），不随便配任意 *_id
                ents = [es, es.split('_')[-1]] if es else []
                mk = next((x for e in ents for x in mc if x == f'{e}_{k}' or x.endswith(f'_{e}_{k}')), None)
            else:
                mk = next((x for x in mc if x != k and x.endswith('_' + k) and x not in ('tenant_id', 'create_by', 'update_by')), None)
            if mk:
                return [(k, mk)]
        if 'tenant_id' in scols and 'tenant_id' in mc and D.keys(s)[:1] == ['tenant_id']:   # 只有租户级的表才按 tenant_id 关联，否则会一对多
            return [('tenant_id', 'tenant_id')]
        return None

    def alias(self, s, hint=None, agg=None, asof=None):
        if s == self.main and not agg:
            return 'a'
        kk = self.join_key(s, hint)
        via = 'a'
        if not kk:
            # 关联键不在主表，在已关联的表里（如 channel_id 在聚合单上）
            cands = [hint.split('=')[0]] if hint else self.D.keys(s)
            for (s2, _, _v, ag2), (al2, _) in list(self.joins.items()):
                if ag2 is not None:
                    continue
                k = next((c for c in cands if c in self.D.cols.get(s2, set()) and c not in ('id', 'tenant_id')), None)
                if k:
                    sc = self.D.cols.get(s, set())
                    tk = k if k in sc else next((x for x in self.D.keys(s) if k.endswith(x)), None)
                    if tk:
                        kk, via = [(tk, k)], al2
                        break
        key = (s, tuple(kk) if kk else hint, via, agg or asof)
        if key in self.joins:
            return self.joins[key][0]
        if not hint and not agg and not asof:
            # 没写关联键的字段：同一张表已经按明确的键关联过，就复用那次关联
            for (s2, _k, _v, ag2), (al2, _) in self.joins.items():
                if s2 == s and ag2 is None:
                    return al2
        al = 'j' + str(len(self.joins) + 1)
        if not kk:
            pk = self.D.pk(s)
            kk = [(pk, pk if pk in self.main_cols() else 'id')]
            self.unresolved.append(s)
            note = '  -- 待确认：关联键'
        else:
            note = ''
        on = ' AND '.join(f'{al}.{x} = {via}.{y}' for x, y in kk)
        pf = part_filter(self.D, s, al)
        db = self.D.db(s)
        if agg:
            fn, col, extra = agg
            gk = ', '.join(x for x, _ in kk)
            where = f" WHERE {pf.replace(al + '.', '')}" if pf else ''
            if extra:
                where = (where + ' AND ' if where else ' WHERE ') + extra
            src = f'(SELECT {gk}, {fn} AS v FROM {db}.{s}{where} GROUP BY {gk})'
            sql = f'LEFT JOIN {src} {al}\n  ON {on}{note}'
        elif self.flink and s.startswith('dim_'):
            sql = f'LEFT JOIN {db}.{s} FOR SYSTEM_TIME AS OF a.proc_time AS {al}\n  ON {on}{note}'
        elif asof and s.endswith('_zip') and not self.flink:
            sd, ed = self.D.zipcols(s)
            sql = (f'LEFT JOIN {db}.{s} {al}\n  ON {on}\n AND {al}.travel_date = \'{BIZ}\'\n'
                   f' AND TO_DATE({asof}) BETWEEN {al}.{sd} AND {al}.{ed}   -- 按时间点取拉链历史版本') + note
        else:
            sql = f'LEFT JOIN {db}.{s} {al}\n  ON {on}' + (f'\n AND {pf}' if pf else '') + note
        self.joins[key] = (al, sql)
        self.spec[al] = {'s': s, 'kk': kk, 'via': via, 'agg': agg, 'asof': asof, 'note': note}
        return al

    def expr(self, x, done):
        """返回 (表达式, 状态, 说明)"""
        p, n, cat = x['p'], x['n'], x['cat']
        D = self.D
        if cat == 'ETL' or n == 'etl_time':
            return ('CURRENT_TIMESTAMP()' if not self.flink else 'CURRENT_TIMESTAMP'), 'auto', ''
        if cat == '拉链':
            return None, 'auto', ''
        m = re.match(r'常量\s*(-?\d+)', p)
        if m:
            return m.group(1), 'auto', ''
        refs = [(a, b) for a, b in REF.findall(p) if a in D.t]
        hint = None
        hm = re.search(r'按\s*([A-Za-z_][A-Za-z0-9_+=]*)', p)
        if hm:
            hint = hm.group(1)
        if not refs:
            # 同表字段运算 / 生成类
            names = re.findall(r'[a-z][a-z0-9_]+', p)
            if names and names[0] in done:
                b0 = done[names[0]]
                pk0 = f'a.{D.pk(self.main)}' if self.main else 'a.id'
                if '取小时' in p:
                    return f'HOUR({b0})', 'rule', ''
                if re.search(r'相邻相减|上一条', p):
                    return f'(UNIX_TIMESTAMP({b0}) - UNIX_TIMESTAMP(LAG({b0}) OVER (PARTITION BY {pk0} ORDER BY {b0}))) / 60', 'rule', ''
                mseg = re.search(r'第\s*(\d+)\s*段', p)
                if mseg:
                    return f"SPLIT({b0}, '/')[{int(mseg.group(1)) - 1}]", 'rule', ''
            if len(names) == 2 and all(nm in done for nm in names) and '相减' in p:
                a_, b_ = (done[nm] for nm in names)
                if all(nm.endswith('_date') for nm in names):
                    return f"DATEDIFF(TO_DATE({a_}, 'yyyyMMdd'), TO_DATE({b_}, 'yyyyMMdd'))", 'rule', ''
                return f'({a_}) - ({b_})', 'rule', ''
            if names and all(nm in done for nm in names) and not re.search(r'[\u4e00-\u9fa5]', p):
                e = p
                for nm in sorted(set(names), key=len, reverse=True):
                    e = re.sub(rf'\b{nm}\b', f'({done[nm]})', e)
                e = e.replace('÷', '/').replace('−', '-')
                return e, 'rule', ''
            return 'NULL', 'review', p
        (s, c) = refs[0]
        if s == self.t:
            if c in done:
                base = done[c]
            else:
                return 'NULL', 'review', p
        else:
            al = None
            if '计数' in p and hint:
                al = self.alias(s, hint, ('COUNT(%s)' % c, c, None))
                return f'COALESCE({al}.v, 0)', 'rule', ''
            cm = re.search(r'取\s*(\w+)=(\w+)', p)
            if cm:
                al = self.alias(s, None, (f'MAX({c})', c, f"{cm.group(1)} = '{cm.group(2)}'"))
                return f'{al}.v', 'rule', ''
            asof = None
            if '取拉链' in p and s.endswith('_zip'):
                asof = 'a.create_time' if 'create_time' in self.main_cols() else None
            al = self.alias(s, hint, asof=asof)
            base = f'{al}.{c}'
        rest = REF.sub('', p, count=1)
        rest = re.sub(r'按\s*[A-Za-z_][A-Za-z0-9_+=]*\s*(关联|冗余|匹配)?', '', rest)
        rest = rest.replace('按下单时间取拉链', '').replace('取拉链', '')
        rest = rest.replace('，改名', '').replace('JSON 原样保留', '').replace('冗余', '').replace('关联', '').strip(' ，,')
        pk = f'a.{D.pk(self.main)}' if self.main else 'a.id'
        order = 'a.binlog_time' if 'binlog_time' in self.main_cols() else 'a.update_time'
        if not rest:
            return base, 'auto', ''
        if re.fullmatch(r'[÷/]\s*100(\s*转元)?', rest):
            return f'ROUND({base} / 100, 2)', 'auto', ''
        # 时长：「A / B − C」里 / 表示「或」，如 revoked_at / expires_at - create_time
        tm = re.fullmatch(r'\s*/\s*(\w+)\s*[-−]\s*(\w+)\s*', rest)
        if tm and all(re.search(r'(_at|_time)$', x) for x in (c, tm.group(1), tm.group(2))):
            al0 = base.split('.')[0]
            unit = 3600 if 'hour' in n else (86400 if 'day' in n else 60)
            return (f'(UNIX_TIMESTAMP(COALESCE({base}, {al0}.{tm.group(1)})) - UNIX_TIMESTAMP({al0}.{tm.group(2)})) / {unit}'), 'rule', ''
        # 纯算术：把 表.字段 换成 别名.字段，×÷− 换成运算符
        arith = p
        for s2, c2 in refs:
            al2 = 'a' if s2 == self.main else (None if s2 == self.t else self.alias(s2, hint))
            arith = arith.replace(f'{s2}.{c2}', f'{al2}.{c2}' if al2 else f'({done.get(c2, c2)})', 1)
        arith = re.sub(r'，?(改名|转元|冗余)', '', arith).replace('÷', '/').replace('×', '*').replace('−', '-').strip(' ，')
        mc_ = self.main_cols()
        arith = re.sub(r'(?<![\w.])([a-z][a-z0-9_]*)\b(?!\s*\()', lambda mm: f'a.{mm.group(1)}' if mm.group(1) in mc_ and s == self.main else mm.group(1), arith)
        if re.fullmatch(r'[A-Za-z0-9_.\s*/+\-()]+', arith) and re.search(r'[*/+\-]', arith) and valid_sql(arith):
            if '/' in arith and '100' not in arith.split('/')[-1]:
                l_, r_ = arith.rsplit('/', 1)
                arith = f'{l_.strip()} / NULLIF({r_.strip()}, 0)'
            elif re.search(r'/\s*100\b', arith):
                arith = f'ROUND({arith}, 2)'
            return arith, 'rule', ''
        m = re.search(r'取\s*([A-Z][A-Z_]+)\s*$', rest)
        if m and s != self.t:
            cc = next((y for y in sorted(self.D.cols.get(s, set())) if y.endswith('_code') and y != c and 'value' not in y), None)
            if cc:
                al = self.alias(s, None, (f'MAX({c})', c, f"{cc} = '{m.group(1)}'"))
                return f'{al}.v', 'rule', ''
        if len(refs) >= 2 and ('÷' in p or '/' in p):
            s2, c2 = refs[1]
            al2 = self.alias(s2, hint) if s2 != self.t else None
            b2 = f'{al2}.{c2}' if al2 else done.get(c2, c2)
            return f'{base} / NULLIF({b2}, 0)', 'rule', ''
        if '非空' in rest:
            return f"CASE WHEN {base} IS NOT NULL AND {base} <> '' THEN 1 ELSE 0 END", 'rule', ''
        if re.match(r'^\s*=\s*\w+', rest):
            al0 = base.split('.')[0]
            cnd = base + re.sub(r'\s*且\s*', ' AND ', re.sub(r'\s*或\s*', ' OR ', rest))
            cnd = re.sub(r"(=\s*)([A-Za-z_]\w*)\b", lambda mm: f"{mm.group(1)}'{mm.group(2)}'", cnd)
            cnd = re.sub(r"(AND|OR)\s+([a-z_]\w*)\s*=", lambda mm: f"{mm.group(1)} {al0}.{mm.group(2)} =", cnd)
            if valid_sql(cnd):
                return f'CASE WHEN {cnd} THEN 1 ELSE 0 END', 'rule', ''
        mv = re.search(r'变为\s*([A-Z_]+(?:/[A-Z_]+)+)\s*的\s*(\w+)', rest)
        if mv:
            codes = ', '.join(f"'{c_}'" for c_ in mv.group(1).split('/'))
            return f"CASE WHEN {base} IN ({codes}) THEN {base.split('.')[0]}.{mv.group(2)} END", 'rule', ''
        if '前后差' in rest:
            return f'{base} - LAG({base}) OVER (PARTITION BY {pk} ORDER BY {order})', 'rule', ''
        if '前镜像' in rest:
            return f'LAG({base}) OVER (PARTITION BY {pk} ORDER BY {order})', 'rule', ''
        if '后镜像' in rest:
            return base, 'rule', ''
        if re.search(r'相减|相邻', rest):
            return f'(UNIX_TIMESTAMP({base}) - UNIX_TIMESTAMP(LAG({base}) OVER (PARTITION BY {pk} ORDER BY {base}))) / 60', 'rule', ''
        m = re.search(r'变为\s*(\w+)\s*的\s*(\w+)', rest)
        if m:
            tc = f'{base.split(".")[0]}.{m.group(2)}'
            return f"CASE WHEN {base} = '{m.group(1)}' THEN {tc} END", 'rule', ''
        m = re.search(r'展开\s*(\w+)\s*长度', rest)
        if m:
            return f"JSON_ARRAY_LENGTH(GET_JSON_OBJECT({base}, '$.{m.group(1)}'))", 'rule', ''
        m = re.search(r'展开\s*(\w+)', rest)
        if m:
            return f"GET_JSON_OBJECT({base}, '$.{m.group(1)}')", 'rule', ''
        if '取日期' in rest:
            return (f"DATE_FORMAT({base}, 'yyyyMMdd')" if not self.flink else f"DATE_FORMAT({base}, 'yyyyMMdd')"), 'rule', ''
        m = re.search(r'第\s*(\d+)\s*段', rest)
        if m:
            return f"SPLIT({base}, '/')[{int(m.group(1)) - 1}]", 'rule', ''
        if re.search(r'is_|是否|>|<|=', rest) and x['type'] in ('INT', 'TINYINT') and n.endswith('_type'):
            return f'CASE WHEN {base} IS NOT NULL THEN 1 ELSE 0 END', 'review', p
        return base, 'review', p

    def build_select(self):
        done, items = {}, []
        for x in self.D.f[self.t]:
            if x['cat'] == '分区' and not self.flink:
                continue
            e, st, note = self.expr(x, done)
            if e is None:
                continue
            done[x['n']] = e
            items.append((x, e, st, note))
        return items


CTE_SUFFIX = {'ods': 'src', 'dwd': 'dtl', 'dim': 'dim', 'dws': 'sum', 'ads': 'app'}
SMALL_DIM = re.compile(r'^dim_\w+_(f|df)$')


def core(s):
    """表名 → 逻辑块名主干：去掉层、业务域与后缀"""
    c = re.sub(r'^(ods|dwd|dim|dws|ads)_[a-z]+_', '', s)
    return re.sub(r'_(di|df|f|zip|rt|hrs|hrs_f|wk|mo)$', '', c)


class Names:
    def __init__(self):
        self.used = set()

    def get(self, base):
        n, i = base, 2
        while n in self.used:
            n, i = f'{base}_{i}', i + 1
        self.used.add(n)
        return n


def ind(text, k=2):
    return '\n'.join((' ' * k + l) if l.strip() else l for l in text.split('\n'))


def cols_line(cols, k=4, width=96):
    """把字段列表折行"""
    out, cur = [], ''
    for c in cols:
        piece = (', ' if cur else '') + c
        if len(cur) + len(piece) > width and cur:
            out.append(cur + ',')
            cur = c
        else:
            cur += piece
    out.append(cur)
    return ('\n' + ' ' * k).join(out)


def row_plan(D, g, items, names):
    """行级加工：主表与每个关联表各成一个 WITH 逻辑块（只取用到的列、先过滤分区、增量表先去重）
    返回 (ctes, select_items, from_join_text, hints)"""
    texts = [e for _, e, _, _ in items]
    for al, sp in g.spec.items():
        texts.append(' '.join(f'{al}.{x} = {sp["via"]}.{y}' for x, y in sp['kk']))
        if sp['asof']:
            texts.append(sp['asof'])
    used = collections.defaultdict(set)
    # 只保留被字段表达式引用、或被其他关联当作中转的关联
    live = set()
    for _, e, _, _ in items:
        live |= set(re.findall(r"(?<![\w'$.])(j\d+)\.", e))
    changed = True
    while changed:
        changed = False
        for al, sp in g.spec.items():
            if al in live and sp['via'] != 'a' and sp['via'] not in live:
                live.add(sp['via'])
                changed = True
    g.spec = {al: sp for al, sp in g.spec.items() if al in live}
    texts = [e for _, e, _, _ in items]
    for al, sp in g.spec.items():
        texts.append(' '.join(f'{al}.{x} = {sp["via"]}.{y}' for x, y in sp['kk']))
        if sp['asof']:
            texts.append(sp['asof'])
    for tx in texts:
        for al, c in re.findall(r"(?<![\w'$.])(a|j\d+)\.(\w+)", tx):
            used[al].add(c)
    ctes, rename, hints = [], {}, []
    m = g.main
    mcn = D.t[m]['cn']
    dedupe = g.main.startswith('ods_') and g.main.endswith('_di') and not g.is_log

    def latest(s, cols, cn, base):
        """ODS 增量：按主键取当日最新一条（两个逻辑块：编号 → 过滤）"""
        pk = D.pk(s)
        cl = sorted(set(cols) | {pk})
        rn, lt = names.get(base + '_rn'), names.get(base + '_latest')
        ctes.append((rn, f"「{cn}」当日增量，同一主键按 binlog 时间倒序编号",
                     f"SELECT {cols_line(cl + ['binlog_op_type'], 7)},\n       ROW_NUMBER() OVER (PARTITION BY {pk} ORDER BY binlog_time DESC) AS rn\n"
                     f"FROM {D.db(s)}.{s}\nWHERE travel_date = '{BIZ}'"))
        ctes.append((lt, f"「{cn}」每个主键只保留最新一条，剔除已删除记录",
                     f"SELECT {cols_line(cl, 7)}\nFROM {rn}\nWHERE rn = 1\n  AND binlog_op_type <> 'DELETE'"))
        return lt
    # 主表
    mcols = sorted(used['a'] | ({D.pk(m)} if dedupe else set()))
    if dedupe:
        mname = latest(m, mcols, mcn, core(m))
    else:
        mname = names.get(core(m) + ('_chg' if g.is_log else '_' + CTE_SUFFIX[D.db(m)]))
        pf = part_filter(D, m, 'x').replace('x.', '')
        ctes.append((mname, f"主表「{mcn}」" + ('：保留每条变更记录' if g.is_log else '') + '，只取用到的列',
                     f"SELECT {cols_line(mcols or ['*'], 7)}\nFROM {D.db(m)}.{m}" + (f"\nWHERE {pf}" if pf else '')))
    rename['a'] = mname
    # 关联表
    for al, sp in g.spec.items():
        s, cn = sp['s'], D.t[sp['s']]['cn']
        cols = sorted(used[al])
        keys = [x for x, _ in sp['kk']]
        if sp['agg']:
            fn, c, extra = sp['agg']
            nm = names.get(core(s) + '_' + re.match(r'\w+', fn).group(0).lower())
            pf = part_filter(D, s, 'x').replace('x.', '')
            wh = ' AND '.join(x for x in (pf, extra) if x)
            ctes.append((nm, f"「{cn}」按 {'、'.join(keys)} 预聚合",
                         f"SELECT {', '.join(keys)}, {fn} AS v\nFROM {D.db(s)}.{s}" + (f"\nWHERE {wh}" if wh else '') + f"\nGROUP BY {', '.join(keys)}"))
        elif s.startswith('ods_') and s.endswith('_di'):
            nm = latest(s, set(cols) | set(keys), cn, core(s))
        elif s.endswith('_zip') and sp['asof']:
            sd, ed = D.zipcols(s)
            nm = names.get(core(s) + '_hist')
            ctes.append((nm, f"「{cn}」拉链全部版本（按时间点取历史版本）",
                         f"SELECT {cols_line(sorted(set(cols) | set(keys) | {sd, ed}))}\nFROM {D.db(s)}.{s}\nWHERE travel_date = '{BIZ}'"))
        else:
            sfx = '_cur' if s.endswith('_zip') else '_' + CTE_SUFFIX[D.db(s)]
            nm = names.get(core(s) + sfx)
            pf = part_filter(D, s, 'x').replace('x.', '')
            ctes.append((nm, f"「{cn}」" + ('当前有效版本' if s.endswith('_zip') else '当日数据') + '，只取用到的列',
                         f"SELECT {cols_line(sorted(set(cols) | set(keys)))}\nFROM {D.db(s)}.{s}" + (f"\nWHERE {pf}" if pf else '')))
            if SMALL_DIM.match(s):
                hints.append(nm)
        rename[al] = nm

    def rn_(tx):
        for al, nm in sorted(rename.items(), key=lambda x: -len(x[0])):
            tx = re.sub(rf"(?<![\w'$.]){al}\.", nm + '.', tx)
        return tx
    sel = [(x, rn_(e), st, note) for x, e, st, note in items]
    jl = [f'FROM {mname}']
    for al, sp in g.spec.items():
        nm = rename[al]
        on = ' AND '.join(f'{nm}.{x} = {rename.get(sp["via"], sp["via"])}.{y}' for x, y in sp['kk'])
        cn = D.t[sp['s']]['cn']
        use = [short_cmt(x['cmt']) or x['n'] for x, e, _, _ in sel if f'{nm}.' in e]
        jl.append(f'LEFT JOIN {nm}' + f'  -- 关联「{cn}」' + (f"，取 {'、'.join(use[:5])}{f' 等 {len(use)} 个字段' if len(use) > 5 else ''}" if use else ''))
        jl.append(f'  ON {on}' + ('  -- 待确认：关联键' if sp['note'] else ''))
        if sp['asof']:
            sd, ed = D.zipcols(sp['s'])
            jl.append(f' AND TO_DATE({rn_(sp["asof"])}) BETWEEN {nm}.{sd} AND {nm}.{ed}  -- 按下单时间取当时有效的版本')
    return ctes, sel, '\n'.join(jl), hints, dedupe


def with_block(ctes):
    out = []
    for i, (n, c, body) in enumerate(ctes):
        out.append(f"{n} AS (  -- {c}\n{ind(body)}\n){',' if i < len(ctes) - 1 else ''}")
    return 'WITH\n' + '\n'.join(out)


def sel_lines(sel, k=2):
    lines = []
    w = min(max((len(e) for _, e, _, _ in sel), default=10), 60)
    for x, e, st, note in sel:
        lines.append(' ' * k + f"{e.ljust(w)} AS {x['n']}" + (f'  -- 待确认：{note}' if st == 'review' else ''))
    return jc(lines)


def gen_row(D, t):
    """DWD / DIM（非拉链）/ 实时 DWD"""
    m = D.t[t]
    flink = m['rt']
    g = RowGen(D, t, flink)
    if not g.main:
        return None
    items = g.build_select()
    stats = collections.Counter({'auto': 0, 'rule': 0, 'review': len(g.unresolved)})
    for _, _, st, _ in items:
        stats[st] += 1
    if flink:
        # Flink：CDC 源表直接 Lookup Join 维表（时态关联不能放进 WITH），保持单层
        sel = sel_lines(items)
        joins = '\n'.join(j for _, j in g.joins.values())
        body = f"INSERT INTO {D.db(t)}.{t}\nSELECT\n{sel}\nFROM {D.db(g.main)}.{g.main} a" + (f"\n{joins}" if joins else '') + ';'
        return header(D, t, 'Flink SQL（CDC 源表 → StarRocks 主键模型表；维表 Lookup Join）', stats,
                      '源表 ods.*_rt 为 Flink CDC 表（含 proc_time AS PROCTIME()），目标表在 StarRocks catalog 中') + '\n' + body, stats, items
    names = Names()
    ctes, sel, fj, hints, dedupe = row_plan(D, g, items, names)
    part = '' if (t.endswith('_f') and not t.endswith('_hrs_f')) else f" PARTITION (travel_date = '{BIZ}')"
    hint = f"  /*+ BROADCAST({', '.join(hints)}) */" if hints else ''
    body = end_stmt(with_block(ctes) + f"\nINSERT OVERWRITE TABLE {D.db(t)}.{t}{part}\nSELECT{hint}\n" + sel_lines(sel) + '\n' + fj)
    extra = ('主表增量先去重再关联' if dedupe else ('流水/状态变更类：保留每条变更记录' if g.is_log else '')) + \
        '；每个 WITH 逻辑块只取用到的列并先过滤分区' + ('；小维表广播关联' if hints else '')
    return header(D, t, 'Spark SQL / Hive', stats, extra.strip('；')) + '\n' + body, stats, items


def gen_zip(D, t):
    g = RowGen(D, t)
    items = g.build_select()
    stats = collections.Counter({'auto': 0, 'rule': 0, 'review': len(g.unresolved)})
    for _, _, st, _ in items:
        stats[st] += 1
    sd, ed = D.zipcols(t)
    pk = D.pk(t)
    names = Names()
    for n in ('src', 'src_hash', 'his'):
        names.used.add(n)
    items2 = [it for it in items if it[0]['n'] != 'etl_time']
    ctes, sel, fj, hints, dedupe = row_plan(D, g, items2, names)
    cols = [x['n'] for x, _, _, _ in items2]
    incr = g.main.endswith('_di')
    hashcols = ', '.join(f'CAST({c} AS STRING)' for c in cols if c != pk)
    hint = f"/*+ BROADCAST({', '.join(hints)}) */ " if hints else ''
    ctes += [('src', '今日最新状态（与拉链字段一一对应）', f"SELECT {hint}\n" + sel_lines(sel, 2).replace('\n', '\n') + '\n' + fj),
             ('src_hash', '今日状态的行哈希（比较是否变化）', f"SELECT s.*, MD5(CONCAT_WS('|', {hashcols})) AS row_hash\nFROM src s"),
             ('his', '昨日拉链及其行哈希', f"SELECT h.*, MD5(CONCAT_WS('|', {', '.join('CAST(h.' + c + ' AS STRING)' for c in cols if c != pk)})) AS row_hash\n"
                                       f"FROM {D.db(t)}.{t} h\nWHERE h.travel_date = '${{bizdate_prev}}'")]
    body = with_block(ctes) + f"""
INSERT OVERWRITE TABLE {D.db(t)}.{t} PARTITION (travel_date = '{BIZ}')
-- ① 历史记录：当前有效版本若{'有变化' if incr else '有变化或已删除'}则闭链（结束日 = 昨天）
SELECT {cols_line(['h.' + c for c in cols], 7)},
  h.{sd},
  CASE WHEN h.{ed} = '9999-12-31' AND {'s.row_hash IS NOT NULL AND ' if incr else ''}(s.row_hash IS NULL OR s.row_hash <> h.row_hash)
       THEN '{PREV_DASH}' ELSE h.{ed} END AS {ed},
  CURRENT_TIMESTAMP() AS etl_time
FROM his h
LEFT JOIN src_hash s ON s.{pk} = h.{pk}
UNION ALL
-- ② 新增或变化的记录开新链（开始日 = 今天，结束日 = 9999-12-31）
SELECT {cols_line(['s.' + c for c in cols], 7)},
  '{BIZ_DASH}' AS {sd},
  '9999-12-31' AS {ed},
  CURRENT_TIMESTAMP() AS etl_time
FROM src_hash s
LEFT JOIN his h ON h.{pk} = s.{pk} AND h.{ed} = '9999-12-31'
WHERE h.{pk} IS NULL OR h.row_hash <> s.row_hash;"""
    extra = '拉链：比对今日源数据与昨日拉链的行哈希，变化的旧版本闭链、新版本开链' + ('；源为增量表，未出现的主键保持不变' if incr else '；源为全量快照，消失的主键闭链')
    return header(D, t, 'Spark SQL / Hive（拉链表）', stats, extra) + '\n' + body, stats, items


def end_stmt(text):
    """在最后一行加分号（放在行尾注释之前）"""
    lines = text.rstrip().split('\n')
    k = lines[-1].find('  --')
    lines[-1] = (lines[-1][:k] + ';' + lines[-1][k:]) if k >= 0 else lines[-1] + ';'
    return '\n'.join(lines)


def assemble_agg(D, t, names, src_ctes, out_cols, kn, attrs, order, mode, pre_ctes=()):
    """汇总类加工的 WITH 组装：来源预聚合 → UNION ALL 合并 → 按粒度键汇总 → 关联维度名称"""
    ctes = list(pre_ctes) + list(src_ctes)
    if len(src_ctes) > 1:
        ctes.append((names.get('all_src'), '各来源字段已对齐，UNION ALL 合并（比多表 FULL JOIN 少 shuffle）',
                     '\nUNION ALL\n'.join(f'SELECT * FROM {n}' for n, _, _ in src_ctes)))
        base = ctes[-1][0]
    else:
        base = src_ctes[0][0]
    grp = f"\nGROUP BY {', '.join('u.' + k for k in kn)}" if kn else ''
    if len(src_ctes) == 1:
        # 单一来源：来源块已按同样的粒度键聚合，外层直接取列，省掉一次聚合
        out_cols = [re.sub(r'\b(SUM|MAX|MIN|BITMAP_UNION)\(u\.(\w+)\)', r'u.\2', l) for l in out_cols]
        out_cols = [re.sub(r'^(\s*)u\.(\w+) AS \2\b', r'\1u.\2', l) for l in out_cols]
        grp = ''
    hints = []
    if attrs:
        mg = names.get('merged')
        ctes.append((mg, '按粒度键汇总，计算派生指标', 'SELECT\n' + jc(out_cols) + f'\nFROM {base} u' + grp))
        dims = collections.OrderedDict()
        for fn_, s, c, k in attrs:
            dk = next((x for x in D.keys(s) if k.endswith(x) or x == k), D.pk(s))
            key = (s, dk, k)
            dims.setdefault(key, []).append((fn_, c))
        lines = [f'  {mg}.{col_name(l)}' for l in out_cols]
        joins = []
        for (s, dk, k), fl in dims.items():
            nm = names.get(core(s) + ('_cur' if s.endswith('_zip') else '_dim'))
            if mode == 'mv':
                pf = f"end_date = '9999-12-31'" if s.endswith('_zip') else ''
            else:
                pf = part_filter(D, s, 'x').replace('x.', '')
            ctes.append((nm, f"「{D.t[s]['cn']}」" + ('当前有效版本' if s.endswith('_zip') else '当日数据') + '，只取名称类字段',
                         f"SELECT {', '.join(dict.fromkeys([dk] + [c for _, c in fl]))}\nFROM dim.{s}" + (f"\nWHERE {pf}" if pf else '')))
            if SMALL_DIM.match(s):
                hints.append(nm)
            for fn_, c in fl:
                lines.append(f'  {nm}.{c} AS {fn_}')
            joins.append(f'LEFT JOIN {nm}  -- 关联「{D.t[s]["cn"]}」，补 {"、".join(fn_ for fn_, _ in fl)}\n  ON {nm}.{dk} = {mg}.{k}')
        final = f"SELECT{'  /*+ BROADCAST(' + ', '.join(hints) + ') */' if hints else ''}\n" + jc(reorder(lines, order)) + f'\nFROM {mg}\n' + '\n'.join(joins)
    else:
        final = 'SELECT\n' + jc(reorder(out_cols, order)) + f'\nFROM {base} u' + grp
    w = with_block(ctes)
    target = f'{D.db(t)}.{t}'
    if mode == 'flink':
        return end_stmt(f'INSERT INTO {target}\n{w}\n{final}')
    if mode == 'mv':
        return end_stmt(f'CREATE MATERIALIZED VIEW IF NOT EXISTS {target}\nREFRESH ASYNC EVERY (INTERVAL 1 MINUTE)\nAS\n{w}\n{final}')
    part = '' if t.endswith('_f') else f" PARTITION (travel_date = '{BIZ}')"
    return end_stmt(f'{w}\nINSERT OVERWRITE TABLE {target}{part}\n{final}')


# ---------------------------------------------------------------- DWS：多来源汇总
BMP = re.compile(r'^bitmap_union\s*\(\s*to_bitmap\s*\((.*?)\)\s*\)\s*(.*)$', re.I | re.S)
AGG = re.compile(r'^(count|sum|max|min|avg|bitmap_union)\s*\(\s*(distinct\s+)?(.*?)\)\s*(.*)$', re.I | re.S)


def translate_cond(D, s, cond):
    """把 where 条件里的裸编码（COMPLETED）补成 字段='编码'，中文条件标待确认"""
    st = 'rule'
    note = ''
    c = cond.strip()
    c = re.sub(r'\s*of paid orders?', ' AND pay_time IS NOT NULL', c)
    c = re.sub(r'（与离线同一口径 \w+）|\(与离线同一口径 \w+\)', '', c)
    c = re.sub(r'(\w+)\s+in\s+周期', rf"DATE_FORMAT(\1, 'yyyyMMdd') = '{BIZ}'", c)
    c = re.sub(r'(\w+)\s*<\s*周期起始', rf"DATE_FORMAT(\1, 'yyyyMMdd') < '{BIZ}'", c)
    m = re.search(r'近\s*(\d+)\s*[天日]', c)
    if m:
        n = int(m.group(1))
        c = re.sub(r'近\s*\d+\s*[天日]\s*(内)?', f"travel_date >= DATE_FORMAT(DATE_SUB('{BIZ_DASH}', {n - 1}), 'yyyyMMdd')", c)

    def bare(mm):
        code = mm.group(0)
        col = D.find_code_col(s, code)
        return f"{col} = '{code}'" if col else code
    parts = re.split(r"('[^']*')", c)
    for i in range(0, len(parts), 2):
        parts[i] = re.sub(r"(?<![=<>!'\w])\b[A-Z][A-Z_]{2,}\b(?!\s*[=(])", bare, parts[i])
    c = ''.join(parts)
    c = re.sub(r'^\s*AND\s+', '', c.strip()).strip(' ,，;；')
    if c in ('全历史', '截至统计日全部历史'):
        return '', 'rule', ''
    if not valid_sql(c, D.cols.get(s, set())):
        return '1 = 1', 'review', cond.strip()
    return c, st, note


def dws_metric(D, s, text, ftype):
    """'sum(x) where cond' → (聚合表达式, 状态, 说明)"""
    t = text.strip()
    t = re.sub(r'（与离线同一口径 \w+）', '', t).strip()
    b = BMP.match(t)
    if b:
        cond, st, note = ('', 'rule', '')
        tail = re.sub(r'(?i)^where\s+', '', b.group(2).strip())
        if tail:
            cond, st, note = translate_cond(D, s, tail)
        v = f'CASE WHEN {cond} THEN {b.group(1)} END' if cond else b.group(1)
        return f'BITMAP_UNION(TO_BITMAP({v}))', st, note
    m = AGG.match(t)
    if not m:
        m2 = re.match(r'^count\s+where\s+(.*)$', t, re.I)
        if m2:
            c, st, note = translate_cond(D, s, m2.group(1))
            return f'COUNT(CASE WHEN {c} THEN 1 END)', st, note
        if re.fullmatch(r'[A-Za-z0-9_\s*+\-/().]+', t) and valid_sql(t, D.cols.get(s, set())):
            return f'SUM({t})', 'rule', ''
        return 'NULL', 'review', t
    fn, dist, arg, tail = m.group(1).upper(), m.group(2), m.group(3).strip() or '*', m.group(4).strip()
    sc = D.cols.get(s, set())
    if re.fullmatch(r'[a-z_]+', arg) and arg not in sc:
        arg = next((c for c in sorted(sc) if arg in c and c.endswith(('_id', '_no'))), arg)
    if arg != '*' and not valid_sql(arg, sc):
        return 'NULL', 'review', text
    cond, st, note = '', 'rule', ''
    wm = re.match(r'(?i)(?:where\s+(.*)|(of paid orders?.*)|by\s+\w+.*)$', tail) if tail else None
    tail = tail.strip(' ,，;；')
    if tail and wm:
        raw = wm.group(1) or wm.group(2) or ''
        if raw:
            cond, st, note = translate_cond(D, s, raw)
    elif tail:
        cond, st, note = translate_cond(D, s, tail)
    if fn == 'BITMAP_UNION':
        inner = re.sub(r'(?i)to_bitmap\((.*)\)', r'\1', arg)
        return f"BITMAP_UNION(TO_BITMAP({f'CASE WHEN {cond} THEN {inner} END' if cond else inner}))", st, note
    if arg == '*':
        return (f'COUNT(CASE WHEN {cond} THEN 1 END)' if cond else 'COUNT(1)'), st, note
    a = f'CASE WHEN {cond} THEN {arg} END' if cond else arg
    return f"{fn}({'DISTINCT ' if dist else ''}{a})", st, note


def gen_agg(D, t, ads_store=None):
    """DWS / ADS（日粒度、实时 DWS）：按来源表分别汇总后 UNION ALL，再按粒度键合并"""
    m = D.t[t]
    flink = m['rt'] and m['layer'] == 'DWS'
    win = flink and any(x['n'] == 'window_start_time' for x in D.f[t])   # 有窗口字段才做滚动窗口
    fs = [x for x in D.f[t] if not (x['cat'] == '分区' and not m['rt'])]
    keys = [x for x in fs if x['cat'] == '粒度键' and x['n'] not in ('window_start_time', 'window_end_time')]
    wins = [x for x in fs if x['n'] in ('window_start_time', 'window_end_time')]
    attrs = [x for x in fs if x['cat'] == '维度属性']
    mets = [x for x in fs if x['cat'] in ('指标', '度量')]
    etl = [x for x in fs if x['cat'] == 'ETL']
    stats = collections.Counter({'auto': 0, 'rule': 0, 'review': 0})
    per_src = collections.OrderedDict()     # 来源表 -> [(目标字段, 表达式, 外层聚合, 状态, 说明, 额外关联)]
    outer = []                               # (字段, 外层表达式, 状态, 说明)
    is_df = t.endswith('_df')
    hidden = []
    for x in mets:
        p = re.sub(r'（原为[^）]*）', '', x['p'])
        mm = re.match(r'^((?:dwd|dws|dim)_\w+)[：:]\s*(.*)$', p)
        ref = REF.search(p)
        if mm and mm.group(1) in D.t:
            s = mm.group(1)
            e, st, note = dws_metric(D, s, mm.group(2), x['type'])
            if s == t:
                e, st, note = 'NULL', 'review', f'引用本表（{mm.group(2)}），需拆成两步计算'
            mc = re.match(r'COUNT\((DISTINCT )?(.*)\)$', e)
            if x['type'] == 'BITMAP' and mc:
                e = f'BITMAP_UNION(TO_BITMAP({mc.group(2)}))'
            if '当日值' in mm.group(2) or '日终快照' in mm.group(2):
                col = (REF.search(p) or [None, None, x['n']])
                e, st, note = _ads_val(D, t, x, s, REF.search(p).group(2) if REF.search(p) else x['n'])
            fm = re.match(r'\s*(min|max)\s*\(', mm.group(2), re.I)
            agg = 'BITMAP_UNION' if x['type'] == 'BITMAP' else (fm.group(1).upper() if fm else 'SUM')
            per_src.setdefault(s, []).append((x['n'], e, agg, st, note))
        elif '当日差值' in p:
            refs2 = [u.split('.')[-2:] for u in re.split(r'[、,]', x['up']) if u.strip()][:2]
            if len(refs2) == 2 and refs2[0][0] == refs2[1][0]:
                per_src.setdefault(refs2[0][0], []).append((x['n'], f'SUM({refs2[0][1]}) - SUM({refs2[1][1]})', 'SUM', 'rule', ''))
            elif len(refs2) == 2:
                for k_, (s_, c_) in enumerate(refs2, 1):
                    per_src.setdefault(s_, []).append((f'{x["n"]}_part{k_}', f'SUM({c_})', 'SUM', 'rule', ''))
                    hidden.append(f'{x["n"]}_part{k_}')
                outer.append((x['n'], f'{x["n"]}_part1 - {x["n"]}_part2', 'rule', ''))
            else:
                outer.append((x['n'], 'NULL', 'review', p))
        elif ref and ref.group(1) in D.t and ref.group(1) != t:
            s, c = ref.group(1), ref.group(2)
            if ads_store is not None or '：' in p:
                e, st, note = _ads_val(D, t, x, s, c)
            else:
                e, st, note = (f'SUM({c})', 'rule', '') if '汇总' in p else (f'SUM({c})' if x['type'] != 'BITMAP' else f'BITMAP_UNION({c})', 'auto', '')
            if x['type'] == 'BITMAP' and not e.startswith('BITMAP'):
                e = f'BITMAP_UNION({c})'
            agg = 'BITMAP_UNION' if x['type'] == 'BITMAP' else 'SUM'
            per_src.setdefault(s, []).append((x['n'], e, agg, st, note))
        else:
            # 同表派生：pay_amt - refund_amt、BITMAP_UNION_COUNT(xxx_bitmap)
            q = re.sub(r'（[^）]*）', '', p)
            bm = re.search(r'BITMAP_UNION_COUNT\((\w+)\)', q)
            if bm:
                outer.append((x['n'], f'BITMAP_COUNT({bm.group(1)})', 'rule', ''))
                continue
            names = re.findall(r'[a-z][a-z0-9_]+', q)
            mnames = {y['n'] for y in mets}
            if names and all(nm in mnames for nm in names):
                e = q.replace('÷', '/').replace('−', '-')
                if '/' in e:
                    a_, b_ = e.split('/', 1)
                    e = f"{a_.strip()}{' * 100' if x['n'].endswith('_rate') and '100' not in e else ''} / NULLIF({b_.strip()}, 0)"
                outer.append((x['n'], e, 'rule', ''))
            else:
                outer.append((x['n'], 'NULL', 'review', p))
    if not per_src:
        return None
    # 每个来源表的粒度键取值
    def key_expr(k, s):
        cands = [(a, b) for a, b in REF.findall(k['p'])]
        for a, b in cands:
            if a == s:
                return b, 'auto'
        sc = D.cols.get(s, set())
        if k['n'] in sc:
            return k['n'], 'auto'
        alt = next((c for c in sc if c.endswith(k['n']) or k['n'].endswith(c) and c.endswith(('_id', '_no', '_code', '_type'))), None)
        if alt:
            return alt, 'rule'
        if k['n'] == 'stat_hour_no':
            tc = next((c for c in sc if c.endswith('_time') and c != 'etl_time'), 'create_time')
            return f'HOUR({tc})', 'rule'
        return f"CAST(NULL AS {k['type']})", 'review'
    for k in keys:
        stats['auto'] += 1
    names = Names()
    ordered = [x['n'] for x in mets]
    exprs_by_src = {s: {n: (e, agg, st, note) for n, e, agg, st, note in v} for s, v in per_src.items()}
    agg_of = {}
    for s, v in per_src.items():
        for n, e, agg, st, note in v:
            stats[st] += 1
            agg_of[n] = agg
    for x in outer:
        stats[x[2]] += 1
    src_cols = [n for n in ordered + hidden if n in agg_of]
    src_ctes, pre = [], []
    for s, v in per_src.items():
        kx, gb, joins = [], [], []
        for k in keys:
            e, st = key_expr(k, s)
            if st == 'review':
                stats['review'] += 1
            kx.append(f"  {e} AS {k['n']}")
            if not e.startswith('CAST(NULL'):
                gb.append(e)
        if win:
            kx = ['  window_start AS window_start_time', '  window_end AS window_end_time'] + kx
            gb = ['window_start', 'window_end'] + gb
        ex = []
        for n in src_cols:
            if n in exprs_by_src[s]:
                e = exprs_by_src[s][n][0]
                if '{JOIN_CH}' in e:
                    e = e.replace('{JOIN_CH}', 'ch.')
                    if not pre:
                        pre.append((names.get('channel_dim'), '「渠道/接入端维度」渠道类型（修饰词条件用）',
                                    f"SELECT channel_id, channel_type\nFROM dim.dim_trf_channel_df\nWHERE travel_date = '{BIZ}'"))
                    joins.append(f"LEFT JOIN {pre[0][0]} ch ON ch.channel_id = s.channel_id")
                st_, note_ = exprs_by_src[s][n][2], exprs_by_src[s][n][3]
                ex.append(f'  {e} AS {n}' + (f'  -- 待确认：{note_}' if st_ == 'review' else ''))
            else:
                ex.append(f"  {'CAST(NULL AS BINARY)' if agg_of[n] == 'BITMAP_UNION' and not flink else 'NULL'} AS {n}")
        db = D.db(s)
        if win:
            frm = f"FROM TABLE(TUMBLE(TABLE {db}.{s}, DESCRIPTOR(event_time), INTERVAL '1' MINUTE)) s"
            wh = ''
        else:
            frm = f'FROM {db}.{s} s' + (('\n' + '\n'.join(sorted(set(joins)))) if joins else '')
            if m['rt']:
                wh = "WHERE s.travel_date = DATE_FORMAT(CURRENT_DATE(), '%Y%m%d')" if not s.endswith('_rt') else ''
            else:
                pf = part_filter(D, s, 's', history=is_df and s.endswith('_di'))
                wh = f'WHERE {pf}' if pf else ''
        nm = names.get('src_' + core(s))
        src_ctes.append((nm, f"来源「{D.t[s]['cn']}」按粒度键预聚合" + ('（1 分钟滚动窗口）' if win else ''),
                         'SELECT\n' + jc(kx + ex) + f"\n{frm}" + (f"\n{wh}" if wh else '') + (f"\nGROUP BY {', '.join(gb)}" if gb else '')))
    kn = [k['n'] for k in keys]
    if win:
        kn = ['window_start_time', 'window_end_time'] + kn
    out_cols = [f'  u.{k}' for k in kn]
    for n in ordered:
        if n in agg_of:
            out_cols.append(f"  {agg_of[n]}(u.{n}) AS {n}")
    agg_cols = {n for n in ordered + hidden if n in agg_of}
    done_outer = {}
    for n, e, st, note in outer:
        ee = e
        for nm_ in sorted(done_outer, key=len, reverse=True):      # 引用了前面的派生指标：代入其表达式
            ee = re.sub(rf'(?<![\w.]){nm_}\b', f'({done_outer[nm_]})', ee)
        for nm_ in sorted(agg_cols, key=len, reverse=True):
            ee = re.sub(rf'(?<![\w.]){nm_}\b', f'{agg_of[nm_]}(u.{nm_})', ee) if nm_ not in done_outer else ee
        done_outer[n] = ee
        out_cols.append(f'  {ee} AS {n}' + (f'  -- 待确认：{note}' if st == 'review' else ''))
    order = [x['n'] for x in fs if x['cat'] != '分区' or m['rt']]
    attr_list = []
    for a in attrs:
        r = REF.search(a['p'])
        if r and r.group(1).startswith('dim_'):
            hk = re.search(r'按\s*(\w+)', a['p'])
            attr_list.append((a['n'], r.group(1), r.group(2), hk.group(1) if hk else (kn[0] if kn else 'id')))
            stats['auto'] += 1
        else:
            out_cols.append(f"  CAST(NULL AS {a['type']}) AS {a['n']}  -- 待确认：{a['p']}")
            stats['review'] += 1
    for e in etl:
        out_cols.append(f"  CURRENT_TIMESTAMP{'' if flink else '()'} AS {e['n']}")
    mode = 'flink' if flink else 'hive'
    sql = assemble_agg(D, t, names, src_ctes, out_cols, kn, attr_list, order, mode, pre)
    if flink:
        kind = 'Flink SQL（' + ('1 分钟滚动窗口聚合' if win else '持续聚合（快照类，按主键更新）') + ' → StarRocks 主键模型表）'
    else:
        kind = 'Spark SQL / Hive'
    extra = '多来源：每个来源先按粒度键预聚合，UNION ALL 后再汇总' if len(per_src) > 1 else '来源先按粒度键预聚合'
    if is_df and not m['rt']:
        extra += '；快照/累计表：增量来源取截至统计日的全部分区'
    return header(D, t, kind, stats, extra) + '\n' + sql, stats, None


def _ads_val(D, t, x, s, c):
    """ADS 日字段：来源 DWS 的当日值，带修饰词条件"""
    p = x['p']
    st, note = 'auto', ''
    cond = ''
    if '待确认：上游字段与口径不一致' in p:
        return 'NULL', 'review', '上游字段与口径不一致，需按口径重写：' + p[:60]
    raw = re.search(r'条件：([a-z_]+\s*[<>=]+\s*[\d\']+\w*\'?)）', p)
    mm = None if raw else re.search(r'条件：([^=）]+)=([^）]+)', p)
    if raw:
        cond, st = raw.group(1), 'rule'
    if mm:
        dim, val = mm.group(1).strip(), mm.group(2).strip()
        col, codes = MODS.get(dim, (None, {}))
        sc = D.cols.get(s, set())
        code = codes.get(val)
        if col and not code:
            for y in D.f.get(s, []):
                if y['n'] == col:
                    for cd, lb in re.findall(r'([A-Z_]+)-([^，,；;]+)', y['cmt']):
                        if lb.strip() and (lb.strip() in val or val.replace('发起', '') in lb):
                            code = cd
        if col in sc and code:
            cond = f"{col} = '{code}'"
            st = 'rule'
        elif col == 'channel_type' and 'channel_id' in sc and code:
            cond = f"{{JOIN_CH}}channel_type = '{code}'"
            st = 'rule'
        else:
            cond = '1 = 1'
            st, note = 'review', f'修饰词 {dim}={val} 在 {s} 中找不到对应字段'
    sc = D.cols.get(s, set())
    if c not in sc:
        alt = x['n'] if x['n'] in sc else None
        if alt:
            c = alt
        else:
            st, note = 'review', f'{s} 中没有字段 {c}'
    v = f'CASE WHEN {cond} THEN {c} END' if cond else c
    if x['type'] == 'BITMAP':
        if not c.endswith('_bitmap'):
            return f'BITMAP_UNION(TO_BITMAP({v}))', st, note
        return f'BITMAP_UNION({v})', st, note
    return f'SUM({v})', st, note


# ---------------------------------------------------------------- ADS：未改造 / 实时
def gen_ads_legacy(D, t):
    """未改造的 ADS（分时、游玩日看板、周/月报、套餐月表）与实时 ADS：按来源表汇总后合并，再按公式计算"""
    m = D.t[t]
    rt = m['rt']
    fs = [x for x in D.f[t] if x['cat'] != '分区']
    keys = [x for x in fs if x['cat'] == '粒度键']
    stats = collections.Counter({'auto': 0, 'rule': 0, 'review': 0})
    need = collections.OrderedDict()      # (来源, 字段, 窗口) -> 内层列名
    outs, attrs = [], []

    def win_of(n):
        if not rt:
            return ''
        if '_1h_' in n:
            return 's.window_start_time >= NOW() - INTERVAL 1 HOUR'
        if '_5m_' in n:
            return 's.window_start_time >= NOW() - INTERVAL 5 MINUTE'
        return ''

    def col(src, c, w):
        k = (src, c, w)
        if k not in need:
            need[k] = f"{c}{'_' + str(len([1 for x in need if x[1] == c])) if any(x[1] == c for x in need) else ''}"
        return f'SUM(u.{need[k]})'
    for x in fs:
        if x['cat'] in ('ETL', '粒度键'):
            continue
        if x['cat'] == '维度属性':
            r = REF.search(x['p'])
            if r and r.group(1).startswith('dim_'):
                attrs.append((x, r))
                stats['auto'] += 1
            else:
                outs.append(f"  CAST(NULL AS {x['type']}) AS {x['n']}  -- 待确认：{x['p']}")
                stats['review'] += 1
            continue
        ups = [sn(u).split('.') for u in re.split(r'[、,]', x['up']) if u.strip()]
        ups = [u for u in ups if len(u) == 2]
        if not ups:
            outs.append(f"  NULL AS {x['n']}  -- 待确认：{x['p']}")
            stats['review'] += 1
            continue
        w = win_of(x['n'])
        if w and not all('window_start_time' in D.cols.get(a_, set()) for a_, _ in ups):
            outs.append(f"  NULL AS {x['n']}  -- 待确认：来源表没有分钟窗口字段，{x['n']} 需要的时间窗口算不出（{x['p'][:40]}）")
            stats['review'] += 1
            continue
        f = re.split(r'[，；;]', str(x['p']).split('=', 1)[-1])[0]
        if re.search(r'_(wow|mom|dod)_?rate$|_(wow|mom|dod)_', x['n']) and len(ups) < 2:
            outs.append(f"  NULL AS {x['n']}  -- 待确认：{x['p']}（需上一周期的值：关联时间表 prev_* 区间计算）")
            stats['review'] += 1
            continue
        c = [col(a, b, w) for a, b in ups]
        mul = ' * 100' if x['n'].endswith('_rate') else ''
        if '/' in f and len(c) >= 2:
            if re.search(r'\(\s*[^)]*-[^)]*\)', f):
                e = f'({c[1]} - {c[0]}){mul} / NULLIF({c[1]}, 0)'
            else:
                e = f'{c[0]}{mul} / NULLIF({c[1]}, 0)'
        elif re.search(r'[-−]', f) and len(c) >= 2:
            e = f'{c[0]} - {c[1]}'
        else:
            e = c[0]
        outs.append(f"  {e} AS {x['n']}")
        stats['rule'] += 1
    if not need:
        return None
    srcs = list(dict.fromkeys(k[0] for k in need))
    kn = [k['n'] for k in keys]
    names = Names()
    src_ctes = []
    for s_ in srcs:
        sc = D.cols.get(s_, set())
        kx = []
        for k in keys:
            ku = [sn(u).split('.') for u in re.split(r'[、,]', k['up']) if u.strip()]
            kc = next((b for a, b in ku if a == s_), k['n'] if k['n'] in sc else None)
            if not kc:
                kc = next((c for c in sc if c.endswith(k['n']) or k['n'].endswith(c) and c.endswith(('_id', '_no'))), None)
            PK = {'stat_week_code': "'${last_week_code}'", 'week_start_date': "'${last_week_start_dash}'",
                  'stat_month_code': "'${last_month_code}'", 'month_start_date': "'${last_month_start_dash}'"}
            kx.append(f"  s.{kc} AS {k['n']}" if kc else (f"  {PK[k['n']]} AS {k['n']}" if k['n'] in PK else f"  CAST(NULL AS {k['type']}) AS {k['n']}"))
        cols = []
        for (a, b, w), nm in need.items():
            v = (f'CASE WHEN {w} THEN s.{b} END' if w else f's.{b}') if a == s_ else 'NULL'
            cols.append(f'  {"SUM(" + v + ")" if a == s_ else "NULL"} AS {nm}')
        if rt:
            wh = f"s.travel_date = DATE_FORMAT(CURDATE(), '%Y%m%d')" if 'travel_date' in sc else ''
        elif t.endswith('_wk'):
            wh = "s.travel_date BETWEEN '${last_week_start}' AND '${last_week_end}'"
        elif t.endswith('_mo'):
            wh = "s.travel_date BETWEEN '${last_month_start}' AND '${last_month_end}'"
        else:
            wh = part_filter(D, s_, 's') or ''
        gb = [l.strip().split(' AS ')[0] for l in kx if not l.strip().startswith(('CAST(NULL', "'"))]
        src_ctes.append((names.get('src_' + core(s_)), f"来源「{D.t[s_]['cn']}」按粒度键预聚合",
                         'SELECT\n' + jc(kx + cols) + f"\nFROM dws.{s_} s" + (f"\nWHERE {wh}" if wh else '') + (f"\nGROUP BY {', '.join(gb)}" if gb else '')))
    sel = [f'  u.{k}' for k in kn] + outs + [f"  {'NOW()' if rt else 'CURRENT_TIMESTAMP()'} AS {e['n']}" for e in fs if e['cat'] == 'ETL']
    for e in fs:
        if e['cat'] == 'ETL':
            stats['auto'] += 1
    stats['auto'] += len(keys)
    attr_list = []
    for x, r in attrs:
        hk = re.search(r'按\s*(\w+)', x['p'])
        attr_list.append((x['n'], r.group(1), r.group(2), hk.group(1) if hk else (kn[0] if kn else 'id')))
    sql = assemble_agg(D, t, names, src_ctes, sel, kn, attr_list, [x['n'] for x in fs], 'mv' if rt else 'hive')
    kind = 'StarRocks 异步物化视图（每分钟刷新）' if rt else 'Spark SQL / Hive'
    extra = '多来源：各来源按粒度键预聚合后 UNION ALL 合并，再按公式计算' if len(srcs) > 1 else '来源按粒度键预聚合后按公式计算'
    if t.endswith(('_wk', '_mo')):
        extra += '；周/月区间可改为关联时间表 dim_opr_period_f（LW/LM）'
    return header(D, t, kind, stats, extra) + '\n' + sql, stats, None


# ---------------------------------------------------------------- 时间表（手写）
def gen_time_tables(D):
    out = {}
    pc = "'D1','WTD','LW','MTD','LM','QTD','LQ','HTD','LH','YTD','LY','N7','N30','N90','N180','N365'"
    out['dim_opr_period_f'] = """-- dim.dim_opr_period_f  统计周期时间表
-- 每个截止日 T × 每种统计周期一行：本期 / 环比基期 / 同比基期区间。截止日取日期维表的全部日期，日期维表扩范围后重跑即可。
-- 依赖 dim_opr_date_f（日期）与 dim_opr_holiday_period_f（节假日放假区间）；每类周期一个 WITH 逻辑块，最后合并
WITH
anchor_day AS (            -- 全部截止日 T，并预先算好周/月/季/半年/年的首日
  SELECT TO_DATE(date_code)                                                      AS t,
         DATE_SUB(TO_DATE(date_code), PMOD(DATEDIFF(TO_DATE(date_code), '1900-01-01'), 7)) AS week_start,   -- 本周一
         TRUNC(TO_DATE(date_code), 'MM')                                         AS month_start,
         TRUNC(TO_DATE(date_code), 'Q')                                          AS quarter_start,
         IF(MONTH(TO_DATE(date_code)) <= 6, TRUNC(TO_DATE(date_code), 'YYYY'),
            ADD_MONTHS(TRUNC(TO_DATE(date_code), 'YYYY'), 6))                    AS half_start,
         TRUNC(TO_DATE(date_code), 'YYYY')                                       AS year_start
  FROM dim.dim_opr_date_f
),
period_rolling AS (        -- 当日、近 N 日：环比 = 前 N 天，同比 = 去年同期
  SELECT d.t, p.code AS period_type_code, p.name AS period_name, CAST(NULL AS STRING) AS holiday_period_code,
         DATE_SUB(d.t, p.n - 1) AS s, d.t AS e,
         DATE_SUB(d.t, 2 * p.n - 1) AS ps, DATE_SUB(d.t, p.n) AS pe,
         ADD_MONTHS(DATE_SUB(d.t, p.n - 1), -12) AS ls, ADD_MONTHS(d.t, -12) AS le
  FROM anchor_day d
  CROSS JOIN (SELECT 'D1' AS code, '当日' AS name, 1 AS n UNION ALL SELECT 'N7', '近7日', 7 UNION ALL SELECT 'N30', '近30日', 30
              UNION ALL SELECT 'N90', '近90日', 90 UNION ALL SELECT 'N180', '近半年', 180 UNION ALL SELECT 'N365', '近1年', 365) p
),
period_start AS (          -- 自然周期的首日与月数步长（周按 7 天单独处理）
  SELECT t, 'MTD' AS td_code, '本月' AS td_name, 'LM' AS full_code, '上月' AS full_name, month_start AS s, 1 AS k FROM anchor_day
  UNION ALL SELECT t, 'QTD', '本季度', 'LQ', '上季度', quarter_start, 3 FROM anchor_day
  UNION ALL SELECT t, 'HTD', '本半年', 'LH', '上半年度', half_start, 6 FROM anchor_day
  UNION ALL SELECT t, 'YTD', '本年', 'LY', '上年度', year_start, 12 FROM anchor_day
),
period_to_date AS (        -- 本月/本季度/本半年/本年（至今）：环比取上一周期相同天数，同比取去年同期
  SELECT t, td_code AS period_type_code, td_name AS period_name, CAST(NULL AS STRING) AS holiday_period_code,
         s, t AS e,
         IF(td_code = 'YTD', ADD_MONTHS(s, -12), ADD_MONTHS(s, -k)) AS ps,
         IF(td_code = 'YTD', ADD_MONTHS(t, -12), LEAST(DATE_ADD(ADD_MONTHS(s, -k), DATEDIFF(t, s)), DATE_SUB(s, 1))) AS pe,
         ADD_MONTHS(s, -12) AS ls, ADD_MONTHS(t, -12) AS le
  FROM period_start
),
period_full AS (           -- 上月/上季度/上半年度/上年度（完整周期）
  SELECT t, full_code AS period_type_code, full_name AS period_name, CAST(NULL AS STRING) AS holiday_period_code,
         ADD_MONTHS(s, -k) AS s, DATE_SUB(s, 1) AS e,
         ADD_MONTHS(s, -2 * k) AS ps, DATE_SUB(ADD_MONTHS(s, -k), 1) AS pe,
         ADD_MONTHS(s, -k - 12) AS ls, DATE_SUB(ADD_MONTHS(s, -12), 1) AS le
  FROM period_start
),
period_week AS (           -- 本周（至今）与上周（完整）：同比按 52 周对齐（同星期）
  SELECT t, 'WTD' AS period_type_code, '本周' AS period_name, CAST(NULL AS STRING) AS holiday_period_code,
         week_start AS s, t AS e, DATE_SUB(week_start, 7) AS ps, DATE_SUB(t, 7) AS pe,
         DATE_SUB(week_start, 364) AS ls, DATE_SUB(t, 364) AS le
  FROM anchor_day
  UNION ALL
  SELECT t, 'LW', '上周', NULL,
         DATE_SUB(week_start, 7), DATE_SUB(week_start, 1), DATE_SUB(week_start, 14), DATE_SUB(week_start, 8),
         DATE_SUB(week_start, 371), DATE_SUB(week_start, 365)
  FROM anchor_day
),
period_holiday AS (        -- 节假日：截止日已开始的假期（本年及上年）；本期 = 首日 ~ min(末日, T)，环比 = 节前同等天数，同比 = 去年同一假期对应天数
  SELECT d.t, 'HOL' AS period_type_code, CONCAT(h.year_no, ' ', h.holiday_name) AS period_name, h.holiday_period_code,
         TO_DATE(h.start_date, 'yyyyMMdd') AS s,
         LEAST(TO_DATE(h.end_date, 'yyyyMMdd'), d.t) AS e,
         DATE_SUB(TO_DATE(h.start_date, 'yyyyMMdd'), DATEDIFF(LEAST(TO_DATE(h.end_date, 'yyyyMMdd'), d.t), TO_DATE(h.start_date, 'yyyyMMdd')) + 1) AS ps,
         DATE_SUB(TO_DATE(h.start_date, 'yyyyMMdd'), 1) AS pe,
         COALESCE(TO_DATE(ly.start_date, 'yyyyMMdd'), ADD_MONTHS(TO_DATE(h.start_date, 'yyyyMMdd'), -12)) AS ls,
         COALESCE(LEAST(TO_DATE(ly.end_date, 'yyyyMMdd'),
                        DATE_ADD(TO_DATE(ly.start_date, 'yyyyMMdd'), DATEDIFF(LEAST(TO_DATE(h.end_date, 'yyyyMMdd'), d.t), TO_DATE(h.start_date, 'yyyyMMdd')))),
                  ADD_MONTHS(LEAST(TO_DATE(h.end_date, 'yyyyMMdd'), d.t), -12)) AS le
  FROM anchor_day d
  JOIN dim.dim_opr_holiday_period_f h
    ON TO_DATE(h.start_date, 'yyyyMMdd') <= d.t AND h.year_no >= YEAR(d.t) - 1
  LEFT JOIN dim.dim_opr_holiday_period_f ly
    ON ly.holiday_period_code = h.last_year_period_code
),
all_period AS (            -- 合并全部周期
  SELECT * FROM period_rolling
  UNION ALL SELECT * FROM period_to_date
  UNION ALL SELECT * FROM period_full
  UNION ALL SELECT * FROM period_week
  UNION ALL SELECT * FROM period_holiday
)
INSERT OVERWRITE TABLE dim.dim_opr_period_f
SELECT
  DATE_FORMAT(t, 'yyyyMMdd')                     AS anchor_date_no,       -- 统计截止日 T
  period_type_code,                                                       -- 统计周期编码
  period_name,                                                            -- 统计周期名称
  holiday_period_code,                                                    -- 节假日区间编码
  DATE_FORMAT(s, 'yyyyMMdd')                     AS start_date_no,        -- 本期开始日
  DATE_FORMAT(e, 'yyyyMMdd')                     AS end_date_no,          -- 本期结束日
  DATEDIFF(e, s) + 1                             AS period_day_qty,       -- 本期天数
  DATE_FORMAT(ps, 'yyyyMMdd')                    AS prev_start_date_no,   -- 环比基期开始日
  DATE_FORMAT(pe, 'yyyyMMdd')                    AS prev_end_date_no,     -- 环比基期结束日
  DATE_FORMAT(ls, 'yyyyMMdd')                    AS ly_start_date_no,     -- 同比基期开始日
  DATE_FORMAT(le, 'yyyyMMdd')                    AS ly_end_date_no,       -- 同比基期结束日
  IF(period_type_code = 'D1', DATE_FORMAT(DATE_SUB(t, 7), 'yyyyMMdd'), NULL) AS wow_date_no,  -- 周同比基准日（仅当日）
  DATE_FORMAT(LEAST(s, ps, ls), 'yyyyMMdd')      AS scan_start_date_no,   -- 查询需扫描的最早分区
  DATE_FORMAT(s, 'yyyy-MM-dd')                   AS start_date,           -- 本期开始日（展示）
  DATE_FORMAT(e, 'yyyy-MM-dd')                   AS end_date,             -- 本期结束日（展示）
  CURRENT_TIMESTAMP()                            AS etl_time              -- ETL 加载时间
FROM all_period;"""
    cal = date_calendar()
    out['dim_opr_holiday_period_f'] = cal['holiday_sql'].rstrip('\n')
    out['dim_opr_date_f'] = cal['date_sql'].rstrip('\n')
    return out


# ---------------------------------------------------------------- 行内注释
def short_cmt(c):
    """字段注释取中文名：冒号或逗号前的部分"""
    c = str(c or '').strip()
    m = re.match(r'^([^：:，,；;]+)', c)
    v = (m.group(1) if m else c).strip()
    if len(v) > 20 and '（' in v:
        v = v[:v.index('（')]
    return v if len(v) <= 28 else v[:27] + '…'


def annotate(sql, t, D):
    """给加工 SQL 逐行加中文注释：字段中文名、关联表与取用字段、主表/去重/分区/分组说明"""
    fcm = {x['n']: short_cmt(x['cmt']) for x in D.f.get(t, [])}
    lines = sql.split('\n')
    # 别名 → 关联表；别名 → 用到的目标字段
    alias_t, alias_use = {}, collections.defaultdict(list)
    for l in lines:
        m = re.search(r'\bJOIN\s+(?:\w+)\.(\w+)\s+(?:FOR SYSTEM_TIME AS OF \S+ AS\s+)?(\w+)\s*$', l.split('  --')[0])
        if m:
            alias_t[m.group(2)] = m.group(1)
        m = re.search(r'\bJOIN\s+\(SELECT .*? FROM (\w+)\.(\w+).*\)\s+(\w+)\s*$', l.split('  --')[0])
        if m:
            alias_t[m.group(3)] = m.group(2) + '#agg'
        m = re.search(r'\bFROM\s+(?:\w+)\.(\w+)\s+(a|s)\s*$', l.split('  --')[0])
        if m:
            alias_t[m.group(2)] = m.group(1)
    for l in lines:
        code = l.split('  --')[0]
        am = re.search(r'\bAS (\w+),?\s*$', code)
        if am:
            for al in set(re.findall(r'\b(j\d+|d\d+)\.', code)):
                alias_use[al].append(am.group(1))
    tcn = lambda x: D.t.get(x.split('#')[0], {}).get('cn', '')
    out, width = [], 0
    cmts = []
    for l in lines:
        code, sep, old = l.partition('  -- ')
        st = code.strip()
        new = ''
        if st.startswith('--') or not st:
            cmts.append((l, None))
            continue
        name = None
        am = re.search(r'\bAS (\w+),?\s*$', code)
        if am:
            name = am.group(1)
        elif re.fullmatch(r'(?:\w+\.)?(\w+),?', st) and st.rstrip(',').split('.')[-1] in fcm:
            name = st.rstrip(',').split('.')[-1]
        if name and re.match(r"(CAST\(NULL AS \w+\)|NULL) AS ", st):
            new = ''   # UNION ALL 对齐用的占位列，不加注释
        elif name and name in fcm and not re.match(r'(SELECT|FROM|WITH|INSERT)\b', st):
            new = fcm[name]
        elif re.match(r'(INSERT OVERWRITE TABLE|INSERT INTO)\b', st):
            new = '写入当日分区' if 'PARTITION' in st else ('写入 StarRocks 目标表' if st.startswith('INSERT INTO') else '整表覆盖写入')
        elif st.startswith('CREATE MATERIALIZED VIEW'):
            new = '异步物化视图，StarRocks 定时刷新'
        elif re.match(r'(LEFT JOIN|JOIN)\b', st):
            m = re.search(r'(\w+)\s*$', st)
            al = m.group(1) if m else ''
            tt = alias_t.get(al, '')
            us = list(dict.fromkeys(fcm.get(n, n) for n in alias_use.get(al, [])))
            use = '、'.join(us[:5]) + (f' 等 {len(us)} 个字段' if len(us) > 5 else '')
            if tt.endswith('#agg'):
                new = f'关联「{tcn(tt)}」按键聚合' + (f'，得到 {use}' if use else '')
            elif tt:
                new = f'关联「{tcn(tt)}」' + (f'，取 {use}' if use else '')
            m2 = re.search(r'JOIN dim\.(\w+) (d\d+|ch) ON', st)
            if m2:
                new = f'关联「{tcn(m2.group(1))}」' + ('，取维度名称' if m2.group(2).startswith('d') else '，取渠道类型（修饰词条件用）')
        elif re.match(r'FROM\s+\w+\.\w+\s+(a|s)$', st):
            tt = re.search(r'FROM\s+\w+\.(\w+)', st).group(1)
            new = ('主表' if st.endswith(' a') else '来源表') + f'「{tcn(tt)}」'
        elif re.match(r'FROM TABLE\(TUMBLE', st):
            new = '按事件时间切 1 分钟滚动窗口'
        elif st == ') a':
            new = '主表当日增量，按主键取最新一条'
        elif re.search(r'ROW_NUMBER\(\) OVER', st):
            new = '同一主键多次变更，按 binlog 时间倒序编号'
        elif re.match(r'WHERE a\.rn = 1', st):
            new = '只保留每个主键的最新一条'
        elif "binlog_op_type <> 'DELETE'" in st:
            new = '剔除源库已删除的记录'
        elif re.search(r"travel_date <= '\$\{bizdate\}'", st):
            new = '累计口径：取截至统计日的全部分区'
        elif re.search(r"end_date = '9999-12-31'", st) and re.match(r'(WHERE|AND)\b', st):
            new = '取当日分区里的拉链当前有效版本' if 'travel_date' in st else '只取拉链当前有效版本'
        elif re.search(r"travel_date = '\$\{bizdate\}'", st) and re.match(r'(WHERE|AND)\b', st):
            new = '只取当日分区' + ('，并按条件过滤' if st.count(' AND ') >= 1 and 'end_date' not in st else '')
        elif re.match(r'ON\b', st):
            ks = re.findall(r'\w+\.(\w+)\s*=\s*\w+\.(\w+)', st)
            new = '按 ' + '、'.join(a_ if a_ == b_ else f'{b_}→{a_}' for a_, b_ in ks) + ' 关联' if ks else ''
        elif "CURDATE()" in st and re.match(r'WHERE\b', st):
            new = '只取今日数据'
        elif re.match(r'GROUP BY\b', st):
            new = '按粒度键汇总'
        elif st == 'UNION ALL':
            new = ''
        elif re.match(r'\) (u|x);?$', st):
            new = {'u': '各来源合并后的明细', 'x': '汇总结果，外层再补维度名称'}[st[2]]
        if old:
            new = (new + '｜' if new and new not in old else '') + old
        cmts.append((code.rstrip() if (new or old) else l, new or None))
    ls = sorted(len(c) for c, n in cmts if n)
    w = min(ls[int(len(ls) * 0.85)] if ls else 0, 80)   # 按大多数行对齐，超长行不拉宽
    for c, n in cmts:
        if n is None:
            out.append(c)
        else:
            out.append(f'{c.ljust(w)}  -- {n}')
    return '\n'.join(out)


# ---------------------------------------------------------------- 主入口
def generate(sheets, ads_model=None):
    D = Dict(sheets)
    out = {}
    hand = gen_time_tables(D)
    ads_tables = set((ads_model or {}).get('ddl', {}).keys())
    for t, m in D.t.items():
        L = m['layer']
        if L == 'ODS':
            continue
        try:
            if t in hand:
                n = len(D.f[t])
                r = (hand[t], collections.Counter({'auto': n, 'rule': 0, 'review': 0}), None)
                kind = 'hive'
            elif L in ('DWD', 'DIM'):
                r = gen_zip(D, t) if t.endswith('_zip') else gen_row(D, t)
                kind = 'flink' if m['rt'] else 'hive'
            elif L == 'DWS':
                r = gen_agg(D, t)
                kind = 'flink' if m['rt'] else 'hive'
            else:
                r = gen_agg(D, t, ads_store=True) if t in ads_tables else gen_ads_legacy(D, t)
                kind = 'starrocks' if m['rt'] else 'hive'
        except Exception as e:  # 单表失败不影响其他表
            r = (f'-- {t}：生成失败（{type(e).__name__}: {e}），需手写', collections.Counter({'auto': 0, 'rule': 0, 'review': len(D.f[t])}), None)
            kind = 'hive'
        if not r:
            continue
        sql, stats, _ = r
        if t not in hand:
            sql = annotate(sql, t, D)
        path = {'hive': f'sql/{L.lower()}/{t}.sql', 'flink': f'sql/flink/{t}.sql', 'starrocks': f'sql/starrocks/{t}.sql'}[kind]
        out[t] = {'sql': sql, 'kind': kind, 'path': path, 'stats': dict(stats)}
    return out


def date_calendar():
    """日期维表与节假日区间的数据由 scripts/dim_date/gen_dim_opr_date_f.py 生成（默认范围：往前 3 年 ~ 往后 2 年）。"""
    import importlib.util, pathlib
    p = pathlib.Path(__file__).resolve().parent.parent / 'scripts' / 'dim_date' / 'gen_dim_opr_date_f.py'
    spec = importlib.util.spec_from_file_location('gen_dim_opr_date_f', p)
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m.render(*m.default_range())
