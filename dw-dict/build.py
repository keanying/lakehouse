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
    import checks, ads_model, etl_gen, shutil, source_tables
    xlsx = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else next((ROOT / 'data').glob('*.xlsx')))
    data = load_sheets(xlsx)
    import copy
    raw = copy.deepcopy(data)            # 客户原版（页面「改造前」对照用）
    from supplement import fin_report   # 3.0 财务报表补齐（客户 Excel 不改，生成时追加）
    fin_etl, fin_new = fin_report.apply(data)
    from supplement import etl_fix
    dict_fixed = etl_fix.fix_dict(data)   # 客户字典里的字段定义错误（编码被标成金额）
    res = checks.run(data, DOCS / 'source')
    model = ads_model.build(data, res)
    data2, changed = ads_model.apply_to_dictionary(data, model, res)
    res['mclass'].update(model.pop('mclass_extra', {}))   # 新登记的位图口径
    res['after'] = [{k: f[k] for k in ('id', 'level', 'cat', 'title', 'n')} for f in checks.run(data2, DOCS / 'source')['findings']]   # 改造版复核
    etl = etl_gen.generate(data2, model)
    D2 = etl_gen.Dict(data2)
    for t, e in fin_etl.items():   # 财务报表新增表用手写加工逻辑，逐行补字段中文注释（与自动生成的表同一套注释规则）
        etl[t] = {**e, 'sql': etl_gen.annotate(e['sql'], t, D2)}
    # 自动生成里的「待确认」占位字段：按表补齐口径（行级替换 / 补关联 / 整表手写）
    for msg in etl_fix.apply(etl, D2, etl_gen.annotate):
        print('  etl_fix:', msg)
    tdi = {c: i for i, c in enumerate(data2['待确认事项']['cols'])}
    n0 = max(int(r[tdi['序号']]) for r in data2['待确认事项']['rows'] if str(r[tdi['序号']]).isdigit())
    for k, (cat, q, how, imp) in enumerate(etl_fix.TODO, 1):
        r = [''] * len(tdi)
        for kk, v in (('序号', n0 + k), ('类别', cat), ('问题', q), ('当前处理 / 建议', how), ('影响', imp)):
            r[tdi[kk]] = v
        data2['待确认事项']['rows'].append(r)
    for t, note in dict_fixed.items():
        changed[t] = (changed[t] + '；' if t in changed else '') + note
    for t in fin_new:
        changed.setdefault(t, '新增表（3.0 财务报表）')
    model.pop('_int')
    sql_root = ROOT.parent / 'sql'
    if sql_root.exists():
        shutil.rmtree(sql_root)
    for t, e in etl.items():
        f = ROOT.parent / e['path']
        f.parent.mkdir(parents=True, exist_ok=True)
        f.write_text(e['sql'] + '\n', encoding='utf-8')
    # 改造前的原版（供页面对照）：被改动表的表清单行，以及原 ADS业务指标
    ti = raw['表清单']['cols'].index('表名（库.表）')
    short = lambda s: str(s).split('.', 1)[-1]
    orig = {'changed': changed,
            '表清单': {'cols': raw['表清单']['cols'], 'rows': [r for r in raw['表清单']['rows'] if short(r[ti]) in changed]},
            'ADS业务指标': raw['ADS业务指标']}
    meta = {'xlsx': xlsx.name, 'built': datetime.date.today().isoformat(), 'dict2': xlsx.stem + '_改造版.xlsx'}
    js = lambda o: json.dumps(o, ensure_ascii=False, separators=(',', ':')).replace('</', '<\\/')
    tpl = (ROOT / 'src' / 'template.html').read_text(encoding='utf-8')
    cal = etl_gen.date_calendar()   # 区间解析演示的节假日与 dim_opr_holiday_period_f 同源
    d10 = lambda x: f'{x[:4]}-{x[4:6]}-{x[6:]}'
    hol = {}
    for r in cal['holiday_rows']:
        hol.setdefault(r[1], []).append([r[3], r[2], d10(r[4]), d10(r[5])])
    src = source_tables.build(DOCS / 'source', data2)   # 业务库原始表（ODS 上游）
    html = tpl.replace('__LEGACY__', 'null').replace('__SRC__', js(src)).replace('__HOL__', js(hol)).replace('__DATA__', js(data2)).replace('__ORIG__', js(orig)).replace('__CHECKS__', js(res)).replace('__META__', js(meta)).replace('__ADS__', js(model)).replace('__ETL__', js(etl))
    (ROOT / 'dist').mkdir(exist_ok=True)
    (ROOT / 'dist' / 'index.html').write_text(html, encoding='utf-8')
    DOCS.mkdir(exist_ok=True)
    (DOCS / '核对报告.md').write_text(checks.to_markdown(res, xlsx.name), encoding='utf-8')
    print('OK ->', ROOT / 'dist' / 'index.html', {k: len(v['rows']) for k, v in raw.items()})
    n = ads_model.to_xlsx(model, ROOT / 'dist' / 'ADS指标体系.xlsx', xlsx.name)
    out = ROOT / 'dist' / (xlsx.stem + '_改造版.xlsx')
    fcols = ['约束 / 默认值' if c == '加工 / 来源' else c for c in data2['字段清单']['cols']]
    ads_model.dict_xlsx({**data2, '业务库表': {'cols': data2['表清单']['cols'], 'rows': src['tables']},
                         '业务库字段': {'cols': fcols, 'rows': src['fields']}}, changed, out)
    print('业务库表：', len(src['tables']), '张，', len(src['fields']), '个字段')
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
