#!/usr/bin/env python3
"""从 Excel 生成单文件静态页面 dist/index.html，并输出核对报告 docs/核对报告.md
用法: pip install openpyxl && python3 build.py [Excel路径]
"""
import sys, json, datetime, pathlib

ROOT = pathlib.Path(__file__).parent
DOCS = ROOT.parent / 'docs'
SHEETS = ['分层汇总', '表清单', '字段清单', '调度工作流', '质量规则', 'DWS口径', 'ADS业务指标', '总线矩阵', '质量体检', '待确认事项']


def cell(c):
    if c is None: return ''
    if isinstance(c, (datetime.date, datetime.datetime)): return c.isoformat()
    return c


def load_sheets(xlsx):
    import openpyxl
    wb = openpyxl.load_workbook(xlsx, data_only=True, read_only=True)
    out = {}
    for name in SHEETS:
        if name not in wb.sheetnames:
            continue
        rows = [[cell(c) for c in r] for r in wb[name].iter_rows(values_only=True)]
        hdr = rows[0]; n = len(hdr)
        while n and hdr[n - 1] == '': n -= 1
        out[name] = {'cols': hdr[:n], 'rows': [r[:n] for r in rows[1:] if any(x != '' for x in r[:n])]}
    return out


def main():
    import checks
    xlsx = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else next((ROOT / 'data').glob('*.xlsx')))
    data = load_sheets(xlsx)
    res = checks.run(data, DOCS / 'source')
    meta = {'xlsx': xlsx.name, 'built': datetime.date.today().isoformat()}
    js = lambda o: json.dumps(o, ensure_ascii=False, separators=(',', ':')).replace('</', '<\\/')
    tpl = (ROOT / 'src' / 'template.html').read_text(encoding='utf-8')
    html = tpl.replace('__DATA__', js(data)).replace('__CHECKS__', js(res)).replace('__META__', js(meta))
    (ROOT / 'dist').mkdir(exist_ok=True)
    (ROOT / 'dist' / 'index.html').write_text(html, encoding='utf-8')
    DOCS.mkdir(exist_ok=True)
    (DOCS / '核对报告.md').write_text(checks.to_markdown(res, xlsx.name), encoding='utf-8')
    print('OK ->', ROOT / 'dist' / 'index.html', {k: len(v['rows']) for k, v in data.items()})
    print('核对：', res['summary'])


if __name__ == '__main__':
    sys.path.insert(0, str(ROOT))
    main()
