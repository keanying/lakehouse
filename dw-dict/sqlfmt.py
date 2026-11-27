"""加工 SQL 排版：超长行拆成「一项一行」，保留行尾注释。

- SELECT / GROUP BY / PARTITION BY / ORDER BY / VALUES 等逗号列表：每个字段一行，续行与第一项对齐；
- 只有括号里是长列表的（如 STACK(...)、) AS (a, b, …)、IN (...)）：在括号内拆开；
- 长 WHERE / HAVING / ON 条件：在顶层 AND / OR 前换行；
- 行尾注释留在拆开后的第一行；字段行的中文注释由 etl_gen.annotate 随后逐行补上。
只改空白与换行，不改任何 SQL 文本（拆完会校验去空白后与原文一致）。
"""
import re

LIMIT = 110
HEAD = re.compile(r'^(SELECT DISTINCT |SELECT |GROUP BY |PARTITION BY |ORDER BY |DISTRIBUTE BY |CLUSTER BY |VALUES |PARTITION \(|COALESCE\()', re.I)


def _split_comment(line):
    """代码 / 行尾注释（引号外第一个 --）"""
    q = None
    for i, ch in enumerate(line):
        if q:
            if ch == q:
                q = None
        elif ch in "'\"`":
            q = ch
        elif line.startswith('--', i):
            return line[:i].rstrip(), line[i:]
    return line.rstrip(), ''


def _top(text, seps=(',',), depth0=0):
    """在括号深度 depth0、引号外按分隔符切分；返回 [(片段, 分隔符)]"""
    out, cur, d, q, i = [], '', 0, None, 0
    while i < len(text):
        ch = text[i]
        if q:
            cur += ch
            if ch == q:
                q = None
            i += 1
            continue
        if ch in "'\"`":
            q = ch
        elif ch == '(':
            d += 1
        elif ch == ')':
            d -= 1
        if d == depth0 and not q:
            hit = next((s for s in seps if text[i:i + len(s)].upper() == s), None)
            if hit:
                out.append((cur, hit))
                cur, i = '', i + len(hit)
                continue
        cur += ch
        i += 1
    out.append((cur, ''))
    return out


def _fmt_line(line, _d=0):
    if _d > 12:
        return [line]
    r = _fmt_once(line, _d)
    return [line] if r == [line] else [x for y in r for x in (_fmt_line(y, _d + 1) if y != line else [y])]


def _fmt_once(line, _d=0):
    code, cmt = _split_comment(line)
    if code.lstrip().startswith('--'):
        return [line]
    if len(code) <= LIMIT:
        # 不超长，但一行里放了多个「表达式 AS 列」：也拆成一列一行（便于逐列注释）
        ps = _top(code.strip()[len((HEAD.match(code.strip()) or [''])[0]):])
        if not (len([p for p, _ in ps if p.strip()]) >= 2 and sum(1 for p, _ in ps if re.search(r'\bAS \w+\s*$', p.strip())) >= 2):
            return [line]
    ind = code[:len(code) - len(code.lstrip())]
    body = code.strip()
    if re.match(r"^'[^']*',", body):          # STACK / VALUES 的一行 = 一组值，保持整行便于对照
        return [line]
    # 1) 条件：顶层 AND / OR 前换行
    m = re.match(r'^(WHERE |HAVING |AND |ON |OR )(.*)$', body, re.I)
    if m:
        parts = _top(m.group(2), (' AND ', ' OR '))
        if len(parts) > 1:
            lines, sep = [ind + m.group(1) + parts[0][0].strip()], parts[0][1]
            pad = ind + ' ' * max(len(m.group(1)) - 4, 2)
            for p, s in parts[1:]:
                lines.append(f'{pad}{sep.strip()} {p.strip()}')
                sep = s
            lines[0] += ('  ' + cmt if cmt else '')
            return lines
    # 2) 顶层逗号列表
    hm = HEAD.match(body)
    head = hm.group(1) if hm else ''
    rest = body[len(head):]
    parts = _top(rest)
    m = re.match(r'^((?:LEFT |RIGHT |FULL |INNER |CROSS )?(?:OUTER )?JOIN .*?)( ON .*)$', body, re.I)
    if m and len(_top(body, (' ON ',))) == 2:            # JOIN … ON …：ON 换行
        on = _top(body, (' ON ',))
        return [ind + on[0][0].strip() + ('  ' + cmt if cmt else ''), ind + '  ON ' + on[1][0].strip()]
    cw = _top(body, (' WHEN ', ' ELSE ', ' END'))
    if len(cw) >= 3 and 'CASE' in body.upper():          # CASE WHEN … 每个分支一行
        lines, sep = [ind + cw[0][0].rstrip()], cw[0][1]
        for p_, s_ in cw[1:]:
            tab = ind if sep.strip() == 'END' else ind + '    '
            lines.append(tab + sep.strip() + (' ' + p_.strip() if p_.strip() else ''))
            sep = s_
        lines[0] += ('  ' + cmt if cmt else '')
        return lines
    if len(parts) >= 2:
        pad = ind + ' ' * len(head)
        items = [p.strip() for p, _ in parts]
        trail = ''
        if items and items[-1] == '':
            items, trail = items[:-1], ','
    if len(parts) >= 2 and len(items) >= 2:
        lines = [ind + head + items[0] + ',']
        for k, it in enumerate(items[1:], 1):
            lines.append(pad + it + (',' if k < len(items) - 1 else trail))
        at = -1 if re.search(r'\bAS \w+$', items[-1]) and not head.startswith(('GROUP', 'PARTITION', 'ORDER')) else 0   # 行尾注释一般说的是最后一列
        lines[at] += ('  ' + cmt if cmt else '')
        return lines
    # 3) 括号里的长列表：在最外层括号内拆开
    q, stack = None, []
    for i, ch in enumerate(body):
        if q:
            if ch == q:
                q = None
            continue
        if ch in "'\"`":
            q = ch
        elif ch == '(':
            stack.append(i)
        elif ch == ')' and stack:
            start = stack.pop()
            inner = body[start + 1:i]
            ps = _top(inner)
            if len(ps) >= 3 and len(inner) > 40:
                pre, post = body[:start + 1], body[i:]
                pad = ind + ' ' * 4
                items = [p.strip() for p, _ in ps]
                lines = [ind + pre + ('  ' + cmt if cmt else '')]
                for k, it in enumerate(items):
                    lines.append(pad + it + (',' if k < len(items) - 1 else ''))
                lines.append(ind + post)
                return lines
    # 4) 兜底：仍超长的单个表达式，在子查询 / CASE / 条件关键字前换行
    if len(code) > 150:
        q, d = None, 0
        for i, ch in enumerate(body):
            if q:
                q = None if ch == q else q
                continue
            if ch in "'\"`":
                q = ch
                continue
            if i > 20 and body[i] == ' ':
                for kw in (' FROM ', ' WHERE ', ' GROUP BY ', ' WHEN ', ' ELSE ', ' OVER (', ' AND ', ' - ', ' + '):
                    if body[i:i + len(kw)].upper() == kw and len(body[:i]) > 40:
                        return [ind + body[:i].rstrip() + ('  ' + cmt if cmt else ''), ind + '    ' + body[i:].strip()]
    return [line]


def _stack_indent(lines):
    """STACK(n, …) 的每组值缩进到 STACK 之后，收尾括号与 STACK 对齐"""
    out, col = [], None
    for l in lines:
        code = _split_comment(l)[0]
        st = code.strip()
        if col is not None:
            if st.startswith(')'):
                out.append(' ' * col + l.strip())
                col = None
                continue
            out.append(' ' * (col + 4) + l.strip())
            continue
        out.append(l)
        m = re.search(r'\bSTACK\(\d+,\s*$', code)
        if m:
            col = len(code) - len(code.lstrip()) if st.startswith('STACK') else code.index('STACK')
    return out


def fmt(sql):
    out = []
    for l in sql.split('\n'):
        out += _fmt_line(l)
    out = _stack_indent(out)
    new = '\n'.join(out)
    strip = lambda s: re.sub(r'\s+', '', re.sub(r'--[^\n]*', '', s))
    if strip(new) != strip(sql):        # 只允许改空白，否则原样返回
        return sql
    return new
