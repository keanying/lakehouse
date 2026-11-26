#!/usr/bin/env python3
"""生成日期维表 dim.dim_opr_date_f 与节假日放假区间表 dim.dim_opr_holiday_period_f 的数据。

只用 Python 标准库，无需联网：
  - 节假日：按国务院办公厅每年的《部分节假日安排的通知》录入（HOLIDAYS），未公布的年份按《全国年节及纪念日放假办法》
    估算法定假日（不含调休），输出时给出提示，公布后补进 HOLIDAYS 重跑即可；
  - 农历：内置香港天文台《公历与农历日期对照表》2019–2036 年每个农历月的初一（LUNAR_MONTHS）；
  - 寒暑假、旺淡季属于运营配置，默认规则见 vacation_type() / season_type()，按实际业务改。

用法：
  python3 gen_dim_opr_date_f.py                          # 默认：今年往前 3 年 1 月 1 日 ~ 往后 2 年 12 月 31 日
  python3 gen_dim_opr_date_f.py --start 2023-01-01 --end 2028-12-31 --out output

输出（--out 目录）：
  dim_opr_date_f.csv / dim_opr_date_f.sql                     日期维表（SQL 为 Spark SQL：INSERT OVERWRITE … FROM VALUES，etl_time 取执行时间）
  dim_opr_holiday_period_f.csv / dim_opr_holiday_period_f.sql 节假日放假区间（覆盖日期范围及其前一年，供同比对齐）
"""
import argparse, csv, datetime as dt, pathlib, sys

D = dt.date
ONE = dt.timedelta(days=1)

# ---------------------------------------------------------------------------
# 节假日放假区间（含与假期相连的周末）+ 调休上班日。来源：国务院办公厅历年通知
#   2022 国办发明电〔2021〕11号  2023 国办发明电〔2022〕16号  2024 国办发明电〔2023〕7号
#   2025 国办发明电〔2024〕12号  2026 国办发明电〔2025〕7号   2027 国办发明电〔2026〕10号
# 每年 11 月前后国务院公布次年安排后，在这里追加一年。
# (编码, 名称, 首日, 末日, 调休上班日)
# ---------------------------------------------------------------------------
HOLIDAYS = {
    2022: [('new_year', '元旦', '20220101', '20220103', ''),
           ('spring_festival', '春节', '20220131', '20220206', '20220129,20220130'),
           ('qingming', '清明节', '20220403', '20220405', '20220402'),
           ('labour_day', '劳动节', '20220430', '20220504', '20220424,20220507'),
           ('dragon_boat', '端午节', '20220603', '20220605', ''),
           ('mid_autumn', '中秋节', '20220910', '20220912', ''),
           ('national_day', '国庆节', '20221001', '20221007', '20221008,20221009')],
    2023: [('new_year', '元旦', '20221231', '20230102', ''),
           ('spring_festival', '春节', '20230121', '20230127', '20230128,20230129'),
           ('qingming', '清明节', '20230405', '20230405', ''),
           ('labour_day', '劳动节', '20230429', '20230503', '20230423,20230506'),
           ('dragon_boat', '端午节', '20230622', '20230624', '20230625'),
           ('national_day', '中秋节·国庆节', '20230929', '20231006', '20231007,20231008')],
    2024: [('new_year', '元旦', '20231230', '20240101', ''),
           ('spring_festival', '春节', '20240210', '20240217', '20240204,20240218'),
           ('qingming', '清明节', '20240404', '20240406', '20240407'),
           ('labour_day', '劳动节', '20240501', '20240505', '20240428,20240511'),
           ('dragon_boat', '端午节', '20240608', '20240610', ''),
           ('mid_autumn', '中秋节', '20240915', '20240917', '20240914'),
           ('national_day', '国庆节', '20241001', '20241007', '20240929,20241012')],
    2025: [('new_year', '元旦', '20250101', '20250101', ''),
           ('spring_festival', '春节', '20250128', '20250204', '20250126,20250208'),
           ('qingming', '清明节', '20250404', '20250406', ''),
           ('labour_day', '劳动节', '20250501', '20250505', '20250427'),
           ('dragon_boat', '端午节', '20250531', '20250602', ''),
           ('national_day', '国庆节·中秋节', '20251001', '20251008', '20250928,20251011')],
    2026: [('new_year', '元旦', '20260101', '20260103', '20260104'),
           ('spring_festival', '春节', '20260215', '20260223', '20260214,20260228'),
           ('qingming', '清明节', '20260404', '20260406', ''),
           ('labour_day', '劳动节', '20260501', '20260505', '20260509'),
           ('dragon_boat', '端午节', '20260619', '20260621', ''),
           ('mid_autumn', '中秋节', '20260925', '20260927', ''),
           ('national_day', '国庆节', '20261001', '20261007', '20260920,20261010')],
    2027: [('new_year', '元旦', '20270101', '20270103', ''),
           ('spring_festival', '春节', '20270205', '20270213', '20270131,20270214'),
           ('qingming', '清明节', '20270403', '20270405', ''),
           ('labour_day', '劳动节', '20270501', '20270505', '20270508'),
           ('dragon_boat', '端午节', '20270609', '20270609', ''),
           ('mid_autumn', '中秋节', '20270915', '20270915', ''),
           ('national_day', '国庆节', '20271001', '20271007', '20270926,20271009')],
}

# ---------------------------------------------------------------------------
# 农历：香港天文台《公历与农历日期对照表》中每个农历月初一的公历日期（YYYYMMDD:月份，L = 闰月）
# ---------------------------------------------------------------------------
LUNAR_MONTHS = """
20190106:12 20190205:1 20190307:2 20190405:3 20190505:4 20190603:5 20190703:6 20190801:7 20190830:8
20190929:9 20191028:10 20191126:11 20191226:12 20200125:1 20200223:2 20200324:3 20200423:4 20200523:4L
20200621:5 20200721:6 20200819:7 20200917:8 20201017:9 20201115:10 20201215:11 20210113:12 20210212:1
20210313:2 20210412:3 20210512:4 20210610:5 20210710:6 20210808:7 20210907:8 20211006:9 20211105:10
20211204:11 20220103:12 20220201:1 20220303:2 20220401:3 20220501:4 20220530:5 20220629:6 20220729:7
20220827:8 20220926:9 20221025:10 20221124:11 20221223:12 20230122:1 20230220:2 20230322:2L 20230420:3
20230519:4 20230618:5 20230718:6 20230816:7 20230915:8 20231015:9 20231113:10 20231213:11 20240111:12
20240210:1 20240310:2 20240409:3 20240508:4 20240606:5 20240706:6 20240804:7 20240903:8 20241003:9
20241101:10 20241201:11 20241231:12 20250129:1 20250228:2 20250329:3 20250428:4 20250527:5 20250625:6
20250725:6L 20250823:7 20250922:8 20251021:9 20251120:10 20251220:11 20260119:12 20260217:1 20260319:2
20260417:3 20260517:4 20260615:5 20260714:6 20260813:7 20260911:8 20261010:9 20261109:10 20261209:11
20270108:12 20270206:1 20270308:2 20270407:3 20270506:4 20270605:5 20270704:6 20270802:7 20270901:8
20270930:9 20271029:10 20271128:11 20271228:12 20280126:1 20280225:2 20280326:3 20280425:4 20280524:5
20280623:5L 20280722:6 20280820:7 20280919:8 20281018:9 20281116:10 20281216:11 20290115:12 20290213:1
20290315:2 20290414:3 20290513:4 20290612:5 20290711:6 20290810:7 20290908:8 20291008:9 20291106:10
20291205:11 20300104:12 20300203:1 20300304:2 20300403:3 20300502:4 20300601:5 20300701:6 20300730:7
20300829:8 20300927:9 20301027:10 20301125:11 20301225:12 20310123:1 20310221:2 20310323:3 20310422:3L
20310521:4 20310620:5 20310719:6 20310818:7 20310917:8 20311016:9 20311115:10 20311214:11 20320113:12
20320211:1 20320312:2 20320410:3 20320509:4 20320608:5 20320707:6 20320806:7 20320905:8 20321004:9
20321103:10 20321203:11 20330101:12 20330131:1 20330301:2 20330331:3 20330429:4 20330528:5 20330627:6
20330726:7 20330825:8 20330923:9 20331023:10 20331122:11 20331222:11L 20340120:12 20340219:1 20340320:2
20340419:3 20340518:4 20340616:5 20340716:6 20340814:7 20340913:8 20341012:9 20341111:10 20341211:11
20350109:12 20350208:1 20350310:2 20350408:3 20350508:4 20350606:5 20350705:6 20350804:7 20350902:8
20351001:9 20351031:10 20351130:11 20351229:12 20360128:1 20360227:2 20360328:3 20360426:4 20360526:5
20360624:6 20360723:6L 20360822:7 20360920:8 20361019:9 20361118:10 20361217:11
"""
# 清明（节气日），同出自香港天文台对照表；仅用于估算未公布年份的清明假期
QINGMING = {2019: '0405', 2020: '0404', 2021: '0404', 2022: '0405', 2023: '0405', 2024: '0404', 2025: '0404', 2026: '0405',
            2027: '0405', 2028: '0404', 2029: '0404', 2030: '0405', 2031: '0405', 2032: '0404', 2033: '0404', 2034: '0405',
            2035: '0405', 2036: '0404'}

MONTH_CN = ['正月', '二月', '三月', '四月', '五月', '六月', '七月', '八月', '九月', '十月', '冬月', '腊月']
DAY_CN = ['初一', '初二', '初三', '初四', '初五', '初六', '初七', '初八', '初九', '初十',
          '十一', '十二', '十三', '十四', '十五', '十六', '十七', '十八', '十九', '二十',
          '廿一', '廿二', '廿三', '廿四', '廿五', '廿六', '廿七', '廿八', '廿九', '三十']

COLUMNS = [  # 与字典「字段清单」dim_opr_date_f 的字段顺序一致
    ('date_code', 'STRING'), ('date_no', 'STRING'), ('year_no', 'INT'), ('quarter_no', 'INT'), ('month_no', 'INT'),
    ('week_of_year_no', 'INT'), ('weekday_no', 'INT'), ('weekday_mask_code', 'STRING'), ('weekend_type', 'INT'),
    ('holiday_type', 'INT'), ('holiday_name', 'STRING'), ('vacation_type', 'INT'), ('season_type', 'INT'),
    ('week_start_date', 'STRING'), ('month_start_date', 'STRING'), ('half_year_no', 'INT'), ('quarter_start_date', 'STRING'),
    ('year_start_date', 'STRING'), ('holiday_period_code', 'STRING'), ('holiday_day_no', 'INT'), ('lunar_date_code', 'STRING'),
    ('last_year_same_day_date', 'STRING'), ('etl_time', 'STRING')]
HOLIDAY_COLUMNS = [
    ('holiday_period_code', 'STRING'), ('year_no', 'INT'), ('holiday_code', 'STRING'), ('holiday_name', 'STRING'),
    ('start_date', 'STRING'), ('end_date', 'STRING'), ('holiday_day_qty', 'INT'), ('adjust_workday_desc', 'STRING'),
    ('last_year_period_code', 'STRING'), ('etl_time', 'STRING')]


def p8(s):
    return D(int(s[:4]), int(s[4:6]), int(s[6:8]))


def f8(d):
    return d.strftime('%Y%m%d')


def f10(d):
    return d.isoformat()


# ----------------------------- 农历 -----------------------------
_LM = [(p8(x.split(':')[0]), int(x.split(':')[1].rstrip('L')), x.endswith('L')) for x in LUNAR_MONTHS.split()]


def lunar(d):
    """返回 (农历月, 是否闰月, 农历日)。"""
    if not (_LM[0][0] <= d < _LM[-1][0] + dt.timedelta(days=30)):
        raise ValueError(f'{d} 超出内置农历范围（{_LM[0][0]} ~ {_LM[-1][0]}），请补充 LUNAR_MONTHS')
    lo, hi = 0, len(_LM) - 1
    while lo < hi:  # 最后一个 <= d 的月初
        mid = (lo + hi + 1) // 2
        if _LM[mid][0] <= d:
            lo = mid
        else:
            hi = mid - 1
    start, m, leap = _LM[lo]
    return m, leap, (d - start).days + 1


def lunar_text(d):
    m, leap, day = lunar(d)
    return ('闰' if leap else '') + MONTH_CN[m - 1] + DAY_CN[day - 1]


def spring_festival(year):
    return next(s for s, m, lp in _LM if m == 1 and not lp and s.year == year)


def lunar_date(year, month, day):
    ny = spring_festival(year)
    k = next(i for i, x in enumerate(_LM) if x[0] == ny)
    start = next(s for s, m, lp in _LM[k:] if m == month and not lp)
    return start + dt.timedelta(days=day - 1)


# ----------------------------- 节假日 -----------------------------
def estimate_year(year):
    """未公布年份：按《全国年节及纪念日放假办法》（2024 年修订）的法定假日估算：逢周末顺延补休，向两侧并入相连周末，不含调休上班。"""
    days = {
        'new_year': [D(year, 1, 1)],
        'spring_festival': [spring_festival(year) - ONE + dt.timedelta(days=i) for i in range(4)],  # 除夕 ~ 初三
        'qingming': [p8(f'{year}{QINGMING[year]}')],
        'labour_day': [D(year, 5, 1), D(year, 5, 2)],
        'dragon_boat': [lunar_date(year, 5, 5)],
        'mid_autumn': [lunar_date(year, 8, 15)],
        'national_day': [D(year, 10, 1), D(year, 10, 2), D(year, 10, 3)],
    }
    names = {'new_year': '元旦', 'spring_festival': '春节', 'qingming': '清明节', 'labour_day': '劳动节',
             'dragon_boat': '端午节', 'mid_autumn': '中秋节', 'national_day': '国庆节'}
    ma = days['mid_autumn'][0]
    if D(year, 9, 28) <= ma <= D(year, 10, 8):  # 中秋在国庆前后一周内：合并为一个假期（如 2025）
        nd = set(days.pop('national_day'))
        if ma in nd:  # 中秋落在 10/1~10/3 内，顺延一天
            nd.add(max(nd) + ONE)
        nd.add(ma)
        days['national_day'] = sorted(nd)
        days.pop('mid_autumn')
        names['national_day'] = '中秋节·国庆节' if ma < D(year, 10, 1) else '国庆节·中秋节'
    out = []
    for code, ds in days.items():
        s, e = min(ds), max(ds)
        extra = sum(1 for x in ds if x.weekday() >= 5)  # 法定假日逢周末，顺延补休到之后的工作日
        while extra:
            e += ONE
            if e.weekday() < 5:
                extra -= 1
        while (s - ONE).weekday() >= 5:
            s -= ONE
        while (e + ONE).weekday() >= 5:
            e += ONE
        out.append((code, names[code], f8(s), f8(e), ''))
    return sorted(out, key=lambda x: x[2])


def holiday_periods(years):
    """返回 [(holiday_period_code, year, code, name, start, end, qty, adjust, ly_code, estimated)]，按年份、首日排序。"""
    rows, estimated = [], []
    for y in years:
        src = HOLIDAYS.get(y)
        if src is None:
            src = estimate_year(y)
            estimated.append(y)
        for code, name, s, e, adj in src:
            rows.append([f'{y}_{code}', y, code, name, s, e, (p8(e) - p8(s)).days + 1, adj, '', y in estimated])
    have = {r[0] for r in rows}
    for r in rows:
        ly = f'{r[1] - 1}_{r[2]}'
        r[8] = ly if ly in have else ''
    rows.sort(key=lambda r: (r[1], r[4]))
    return rows, estimated


# ----------------------------- 运营配置（按客户实际改） -----------------------------
def vacation_type(d):
    """寒暑假：0-否，1-寒假，2-暑假。默认：暑假 7/1~8/31；寒假 = 春节（正月初一）前 21 天 ~ 正月十五。"""
    if D(d.year, 7, 1) <= d <= D(d.year, 8, 31):
        return 2
    for y in (d.year, d.year + 1):
        s = spring_festival(y)
        if s - dt.timedelta(days=21) <= d <= s + dt.timedelta(days=14):
            return 1
    return 0


def season_type(d, holiday_type, vac):
    """旺淡季：1-旺季，2-平季，3-淡季。默认：法定节假日、暑假为旺季；11 月 ~ 次年 3 月其余日期为淡季；其余平季。"""
    if holiday_type == 2 or vac == 2:
        return 1
    if d.month in (11, 12, 1, 2, 3):
        return 3
    return 2


# ----------------------------- 生成 -----------------------------
def build(start, end, etl_time=None):
    etl_time = etl_time or dt.datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    hp, estimated = holiday_periods(range(start.year - 1, end.year + 1))
    by_code = {r[0]: r for r in hp}
    day_hol, workday = {}, {}
    for r in hp:
        s, e = p8(r[4]), p8(r[5])
        x = s
        while x <= e:
            if x in day_hol:
                raise ValueError(f'{x} 同时属于 {day_hol[x][0]} 和 {r[0]}')
            day_hol[x] = r
            x += ONE
        for w in filter(None, r[7].split(',')):
            wd = p8(w)
            if wd.weekday() < 5:
                raise ValueError(f'{r[0]} 的调休上班日 {w} 不是周末，请核对')
            workday[wd] = r
    rows = []
    d = start
    while d <= end:
        wk = d.isoweekday()
        weekend = 1 if wk >= 6 else 0
        h = day_hol.get(d)
        htype = 2 if h else 3 if d in workday else 1 if weekend else 0
        vac = vacation_type(d)
        q = (d.month - 1) // 3 + 1
        if h:
            n = (d - p8(h[4])).days + 1
            ly = by_code.get(h[8])
            ly_day = p8(ly[4]) + dt.timedelta(days=n - 1) if ly else d - dt.timedelta(days=364)
        else:
            n, ly_day = None, d - dt.timedelta(days=364)
        rows.append([
            f10(d), f8(d), d.year, q, d.month, d.isocalendar()[1], wk, str(1 << (wk - 1)), weekend,
            htype, h[3] if h else None, vac, season_type(d, htype, vac),
            f10(d - dt.timedelta(days=wk - 1)), f10(d.replace(day=1)), 1 if d.month <= 6 else 2,
            f10(D(d.year, 3 * q - 2, 1)), f10(D(d.year, 1, 1)),
            h[0] if h else None, n, lunar_text(d), f10(ly_day), etl_time])
        d += ONE
    hol_rows = [r[:9] + [etl_time] for r in hp]
    return rows, hol_rows, [r[0] for r in hp if r[9]], estimated


def sql_lit(v, typ):
    if v is None or (v == '' and typ != 'STRING'):
        return 'NULL'
    if typ == 'INT':
        return str(int(v))
    return "'" + str(v).replace("'", "''") + "'"


def to_sql(table, cols, rows, header):
    """Spark SQL：INSERT OVERWRITE … SELECT … FROM VALUES；etl_time 取执行时间（最后一列，不进 VALUES）。"""
    vcols = cols[:-1]
    names = [c for c, _ in vcols]
    vals = ',\n'.join('  (' + ', '.join(sql_lit(v, t) for v, (_, t) in zip(r, vcols)) + ')' for r in rows)
    sel = ',\n  '.join(f'CAST({c} AS {t}) AS {c}' if t == 'INT' else c for c, t in vcols)
    return (f'{header}INSERT OVERWRITE TABLE {table}\nSELECT\n  {sel},\n'
            f"  DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time\n"
            f'FROM VALUES\n{vals}\nAS v({", ".join(names)});\n')


def default_range(today=None):
    """默认范围：今年往前 3 年的 1 月 1 日 ~ 往后 2 年的 12 月 31 日。"""
    today = today or D.today()
    return D(today.year - 3, 1, 1), D(today.year + 2, 12, 31)


def render(start, end):
    """返回 {'date_sql', 'holiday_sql', 'date_rows', 'holiday_rows', 'estimated_years', 'estimated_codes'}。"""
    rows, hol_rows, est_codes, est_years = build(start, end)
    note = (f'-- 估算：{"、".join(map(str, est_years))} 年国务院放假安排未公布，按法定假日估算（逢周末顺延补休、不含调休上班），'
            f'公布后补进脚本 HOLIDAYS 重跑\n') if est_years else ''
    head = (f'-- dim.dim_opr_date_f 日期维度（1 行 = 1 天），{start} ~ {end} 共 {len(rows)} 天\n'
            f'-- 由 scripts/dim_date/gen_dim_opr_date_f.py 生成（改范围：--start / --end），非分区全量覆盖；字段顺序与字典一致\n'
            f'-- 节假日来自国务院历年放假安排，农历来自香港天文台对照表；寒暑假、旺淡季为默认运营规则，见脚本 vacation_type / season_type\n{note}')
    hhead = (f'-- dim.dim_opr_holiday_period_f 节假日放假区间（{hol_rows[0][1]}–{hol_rows[-1][1]} 年，含前一年供同比对齐）\n'
             f'-- 由 scripts/dim_date/gen_dim_opr_date_f.py 生成；放假区间含相连周末；每年国务院公布次年安排后补进脚本 HOLIDAYS 重跑\n{note}')
    return {'date_sql': to_sql('dim.dim_opr_date_f', COLUMNS, rows, head),
            'holiday_sql': to_sql('dim.dim_opr_holiday_period_f', HOLIDAY_COLUMNS, hol_rows, hhead),
            'date_rows': rows, 'holiday_rows': hol_rows, 'estimated_years': est_years, 'estimated_codes': est_codes}


def write_csv(path, cols, rows):
    with open(path, 'w', newline='', encoding='utf-8') as f:
        w = csv.writer(f)
        w.writerow([c for c, _ in cols])
        for r in rows:
            w.writerow(['' if v is None else v for v in r])


def main(argv=None):
    s0, e0 = default_range()
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--start', default=s0.isoformat(), help='起始日期 yyyy-MM-dd（默认：今年往前 3 年的 1 月 1 日）')
    ap.add_argument('--end', default=e0.isoformat(), help='结束日期 yyyy-MM-dd（默认：往后 2 年的 12 月 31 日）')
    ap.add_argument('--out', default=str(pathlib.Path(__file__).parent / 'output'), help='输出目录')
    a = ap.parse_args(argv)
    start, end = D.fromisoformat(a.start), D.fromisoformat(a.end)
    out = pathlib.Path(a.out)
    out.mkdir(parents=True, exist_ok=True)
    r = render(start, end)
    rows, hol_rows, est_codes, est_years = r['date_rows'], r['holiday_rows'], r['estimated_codes'], r['estimated_years']
    (out / 'dim_opr_date_f.sql').write_text(r['date_sql'], encoding='utf-8')
    (out / 'dim_opr_holiday_period_f.sql').write_text(r['holiday_sql'], encoding='utf-8')
    write_csv(out / 'dim_opr_date_f.csv', COLUMNS, rows)
    write_csv(out / 'dim_opr_holiday_period_f.csv', HOLIDAY_COLUMNS, hol_rows)
    print(f'dim_opr_date_f：{start} ~ {end}，{len(rows)} 行 -> {out}')
    print(f'dim_opr_holiday_period_f：{len(hol_rows)} 行（{hol_rows[0][1]}–{hol_rows[-1][1]} 年）')
    if est_years:
        print(f'提示：{"、".join(map(str, est_years))} 年放假安排未公布，已按法定假日估算（不含调休）：{"、".join(est_codes)}', file=sys.stderr)


if __name__ == '__main__':
    main()
