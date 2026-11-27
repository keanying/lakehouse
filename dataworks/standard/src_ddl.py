"""读取客户提供的业务库表 DDL（业务库 DDL 补齐工具 dataworks/ddl_tool 写入的 src_ddl.sql）。

文件放在 dataworks/input/src_ddl*.sql（多个文件按文件名排序，后面的覆盖前面的同名表）。格式：
    -- @table 数据源:表名        （未对上页面业务库表的，数据源为 ?）
    -- @at 录入时间
    -- @status 弃用 / @reason 原因 / @note 备注（标记弃用时才有）
    CREATE TABLE ... ;          （弃用表可以没有）
没有 @table 标记的普通 DDL 文件也能读：按表名对到业务库表（同名多数据源时跳过并提示）。
"""
import pathlib, re

INPUT = pathlib.Path(__file__).resolve().parent.parent / 'input'


def _split_top(s):
    out, d, q, b, i = [], 0, None, 0, 0
    while i < len(s):
        ch = s[i]
        if q:
            if ch == '\\':
                i += 2
                continue
            if ch == q:
                q = None
        elif ch in '\'"`':
            q = ch
        elif ch == '(':
            d += 1
        elif ch == ')':
            d -= 1
        elif ch == ',' and d == 0:
            out.append(s[b:i])
            b = i + 1
        i += 1
    out.append(s[b:])
    return out


CREATE = re.compile(r'CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?((?:`[^`]+`|[\w$]+)(?:\s*\.\s*(?:`[^`]+`|[\w$]+))?)\s*\(', re.I)
COMMENT = r"COMMENT\s+'((?:[^'\\]|\\.|'')*)'"


def parse(text):
    """→ [{db, table, cols: [{n, t, nn, d, c}], pk, comment, ddl}]（与页面 parseDDL 同一规则）"""
    starts = [(m.start(), m.group(1), m.end()) for m in CREATE.finditer(text)]
    out = []
    for k, (i0, name, body) in enumerate(starts):
        d, j, q = 1, body, None
        while j < len(text) and d > 0:
            ch = text[j]
            if q:
                if ch == '\\':
                    j += 2
                    continue
                if ch == q:
                    q = None
            elif ch in '\'"`':
                q = ch
            elif ch == '(':
                d += 1
            elif ch == ')':
                d -= 1
            j += 1
        inner = text[body:j - 1]
        nxt = starts[k + 1][0] if k + 1 < len(starts) else len(text)
        end = text.find(';', j)
        if end < 0 or end > nxt:
            end = nxt
        tail = text[j:end]
        nm = re.sub(r'[`\s]', '', name).split('.')
        cols, pk = [], []
        for line in _split_top(inner):
            L = line.strip()
            if not L:
                continue
            p = re.match(r'PRIMARY\s+KEY\s*\(([^)]*)\)', L, re.I)
            if p:
                pk += [re.sub(r'\(\d+\)$', '', re.sub(r'[`\s]', '', x)) for x in p.group(1).split(',')]
                continue
            if re.match(r'(UNIQUE|KEY|INDEX|CONSTRAINT|FULLTEXT|SPATIAL|FOREIGN|CHECK)\b', L, re.I):
                continue
            c = re.match(r'`?([^`\s]+)`?\s+(\w+(?:\s*\([^)]*\))?(?:\s+unsigned)?(?:\s+zerofill)?)(.*)$', L, re.I | re.S)
            if not c:
                continue
            rest = c.group(3)
            cm = re.search(COMMENT, rest, re.I)
            df = re.search(r"DEFAULT\s+('(?:[^'\\]|\\.)*'|\S+)", rest, re.I)
            cols.append({'n': c.group(1), 't': re.sub(r'\s+', ' ', c.group(2)), 'nn': bool(re.search(r'NOT\s+NULL', rest, re.I)),
                         'd': df.group(1).rstrip(',') if df else '', 'c': cm.group(1).replace("''", "'").replace("\\'", "'") if cm else ''})
            if re.search(r'PRIMARY\s+KEY', rest, re.I):
                pk.append(c.group(1))
        tc = re.search(r"COMMENT\s*=?\s*'((?:[^'\\]|\\.|'')*)'", tail, re.I)
        out.append({'db': nm[0] if len(nm) > 1 else '', 'table': nm[-1], 'cols': cols, 'pk': pk, 'comment': tc.group(1) if tc else '',
                    'ddl': text[i0:end].strip().rstrip(';') + ';'})
    return out


def load(src_names=()):
    """→ ({'数据源:表名': 解析结果 + at}, [提示])；src_names 为页面上的业务库表名，用于无标记文件按表名匹配"""
    files = sorted(INPUT.glob('src_ddl*.sql')) if INPUT.exists() else []
    by_tb = {}
    for n in src_names:
        by_tb.setdefault(n.split(':', 1)[1].lower(), []).append(n)
    res, notes = {}, []
    for f in files:
        text = f.read_text(encoding='utf-8-sig')
        if re.search(r'^--\s*@table\s+', text, re.M):
            parts = re.split(r'^--\s*@table\s+(\S+)\s*$', text, flags=re.M)
            for k in range(1, len(parts), 2):
                body = parts[k + 1]
                meta = {m: (re.search(rf'^--\s*@{m}\s+(.+)$', body, re.M) or [None, ''])[1].strip() for m in ('at', 'status', 'reason', 'note')}
                p = parse(body)
                if p or meta['status']:
                    res[parts[k]] = {**(p[0] if p else {'cols': [], 'pk': [], 'comment': '', 'ddl': ''}), **meta, 'file': f.name}
        else:
            for p in parse(text):
                c = by_tb.get(p['table'].lower(), [])
                if len(c) == 1:
                    res[c[0]] = {**p, 'at': '', 'file': f.name}
                elif len(c) > 1:
                    notes.append(f"{f.name}：{p['table']} 在多个数据源同名（{'、'.join(c)}），没有 @table 标记无法确定，已跳过")
                else:
                    res['?:' + p['table']] = {**p, 'at': '', 'file': f.name}
    return res, notes
