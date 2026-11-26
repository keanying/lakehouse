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
    import checks, ads_model, etl_gen, shutil
    xlsx = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else next((ROOT / 'data').glob('*.xlsx')))
    data = load_sheets(xlsx)
    res = checks.run(data, DOCS / 'source')
    model = ads_model.build(data, res)
    data2, changed = ads_model.apply_to_dictionary(data, model, res)
    res['mclass'].update(model.pop('mclass_extra', {}))   # 新登记的位图口径
    etl = etl_gen.generate(data2, model)
    model.pop('_int')
    sql_root = ROOT.parent / 'sql'
    if sql_root.exists():
        shutil.rmtree(sql_root)
    for t, e in etl.items():
        f = ROOT.parent / e['path']
        f.parent.mkdir(parents=True, exist_ok=True)
        f.write_text(e['sql'] + '\n', encoding='utf-8')
    # 改造前的原版（供页面对照）：被改动表的表清单行、字段，以及原 ADS业务指标
    ti = data['表清单']['cols'].index('表名（库.表）'); fi = data['字段清单']['cols'].index('表名（库.表）')
    short = lambda s: str(s).split('.', 1)[-1]
    orig = {'changed': changed,
            '表清单': {'cols': data['表清单']['cols'], 'rows': [r for r in data['表清单']['rows'] if short(r[ti]) in changed]},
            '字段清单': {'cols': data['字段清单']['cols'], 'rows': [r for r in data['字段清单']['rows'] if short(r[fi]) in changed]},
            'ADS业务指标': data['ADS业务指标']}
    meta = {'xlsx': xlsx.name, 'built': datetime.date.today().isoformat()}
    js = lambda o: json.dumps(o, ensure_ascii=False, separators=(',', ':')).replace('</', '<\\/')
    tpl = (ROOT / 'src' / 'template.html').read_text(encoding='utf-8')
    html = tpl.replace('__DATA__', js(data2)).replace('__ORIG__', js(orig)).replace('__CHECKS__', js(res)).replace('__META__', js(meta)).replace('__ADS__', js(model)).replace('__ETL__', js(etl))
    (ROOT / 'dist').mkdir(exist_ok=True)
    (ROOT / 'dist' / 'index.html').write_text(html, encoding='utf-8')
    DOCS.mkdir(exist_ok=True)
    (DOCS / '核对报告.md').write_text(checks.to_markdown(res, xlsx.name), encoding='utf-8')
    print('OK ->', ROOT / 'dist' / 'index.html', {k: len(v['rows']) for k, v in data.items()})
    n = ads_model.to_xlsx(model, ROOT / 'dist' / 'ADS指标体系.xlsx', xlsx.name)
    out = ROOT / 'dist' / (xlsx.stem + '_改造版.xlsx')
    ads_model.dict_xlsx(data2, changed, out)
    print('改造版字典 ->', out.name, '改动表', len(changed))
    import collections
    tot = collections.Counter()
    for e in etl.values():
        tot.update(e['stats'])
    print('加工逻辑：', len(etl), '张表 ->', sql_root, dict(tot))
    print('核对：', res['summary'])
    print('ADS 指标体系：', model['summary'], '业务指标行', n, '字段冲突', len(model['problems']))


if __name__ == '__main__':
    sys.path.insert(0, str(ROOT))
    main()
