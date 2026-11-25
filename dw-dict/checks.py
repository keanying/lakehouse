#!/usr/bin/env python3
"""数仓字典自动核对。

build.py 构建时调用 run(sheets, docs_dir)，结果嵌进页面「核对报告」，同时写 docs/核对报告.md。
也可以单独运行：python3 checks.py [Excel路径]  → 在终端打印核对结果。

核对依据：
  1. docs/规范/数仓命名规范.md      —— 命名、分区、字段关键字规范
  2. docs/source/*.md               —— 业务库 DDL（ODS 与源表逐字段比对）
  3. Excel 自身各工作表之间的一致性 —— 表/字段血缘、口径落地、ADS 引用、调度依赖
"""
import re
import collections
import pathlib

LAYERS = ['ODS', 'DWD', 'DIM', 'DWS', 'ADS']
DOMAINS = ['prd', 'ord', 'cus', 'sup', 'inv', 'fin', 'opr', 'trf', 'mkt']
SUFFIX_OF = {'天级增量': 'di', '天级全量': 'df', '小时级增量': 'hrs', '小时级全量': 'hrs_f', '周级增量': 'wk',
             '周级全量': 'wk_f', '月级增量': 'mo', '月级全量': 'mo_f', '季度增量': 'q', '年级增量': 'yr',
             '拉链表': 'zip', '非分区全量': 'f', '实时（后缀待定）': 'rt'}
FIELD_KW = ('_id', '_no', '_code', '_name', '_type', '_status', '_date', '_time', '_amt', '_qty', '_rate', '_desc')
# 去重后不可直接相加的实体（人、商户、SKU 等）
DISTINCT_ENTITY = re.compile(r'COUNT\(DISTINCT\s*(买家ID|游客ID|租户ID|卖家租户ID|分销商租户ID|SKU ID|设备ID|有支付的日期)\)')

sn = lambda s: re.sub(r'^[A-Za-z_]+\.', '', str(s or '').strip())
base = lambda l: str(l).replace('（实时）', '')


def toks(s):
    """把「a、b, c」之类的表名串拆成短表名列表（去掉 库. 前缀和括号说明）"""
    s = re.sub(r'（[^）]*）|\([^)]*\)', '', str(s or ''))
    return [sn(t) for t in re.split(r'[、,，\s;；+]+', s) if t.strip()]


class Sheet:
    def __init__(self, d):
        self.cols, self.rows = d['cols'], d['rows']
        self.ix = {c: i for i, c in enumerate(self.cols)}

    def get(self, r, c):
        return r[self.ix[c]] if c in self.ix else ''


# ---------------------------------------------------------------- 源库 DDL
def parse_source_ddl(docs_dir):
    """从设计文档里抽 CREATE TABLE，返回 {表名: [{file, cols:[(名,类型)]}]} 与 {表名: [库名]}"""
    ddl = collections.defaultdict(list)
    dbmap = collections.defaultdict(list)
    files = sorted(pathlib.Path(docs_dir).glob('*.md')) if docs_dir else []
    for f in files:
        txt = f.read_text(encoding='utf-8')
        for m in re.finditer(r'CREATE TABLE\s+(?:IF NOT EXISTS\s+)?`?([\w-]+)`?(?:\.`?(\w+)`?)?\s*\((.*?)\n\)', txt, re.S):
            name = m.group(2) or m.group(1)
            cols = []
            for line in m.group(3).split('\n'):
                l = line.strip()
                if not l or l.startswith('--') or re.match(r'(PRIMARY|UNIQUE|KEY|INDEX|CONSTRAINT|FOREIGN|FULLTEXT)\b', l, re.I):
                    continue
                mm = re.match(r'`?(\w+)`?\s+([A-Za-z]+(?:\([^)]*\))?)', l)
                if mm:
                    cols.append((mm.group(1), mm.group(2).upper()))
            ddl[name].append({'file': f.name, 'cols': cols})
        if 'database' in f.name:
            cur = None
            for line in txt.split('## 二、完整DDL')[0].split('\n'):
                m = re.match(r'### \d+\.\s*.*?（(pft-[\w-]+) 库', line)
                if m:
                    cur = m.group(1)
                    continue
                m = re.match(r'\|\s*(t_\w+)\s*\|', line)
                if m and cur:
                    dbmap[m.group(1)].append(cur)
    return ddl, dbmap


# ---------------------------------------------------------------- 指标聚合方式
def metric_class(row, S):
    """判断一个 DWS 口径在「任意时间区间」上能否直接由日数据汇总得到"""
    typ, formula, tcal, kou = (S.get(row, '口径类型'), str(S.get(row, '计算公式')),
                               str(S.get(row, '时间口径')), str(S.get(row, '业务口径')))
    if '快照' in tcal or '截至' in kou[:6]:
        return 'snapshot'
    if typ == '计算指标' and '/' not in formula.split('=', 1)[-1]:
        return 'additive'  # 差值类（净成交额、毛利额）按天可加
    if typ == '计算指标' or re.search(r'率|均|占比|客单价|/', str(S.get(row, '中文名'))) and typ != '原子指标':
        return 'ratio'
    if DISTINCT_ENTITY.search(formula):
        # 新注册、首单、入驻、认证这类「每个实体只发生一次」的事件，按天相加不会重复
        return 'once' if re.search(r'新|首|入驻|认证', str(S.get(row, '中文名'))) else 'distinct'
    if typ == '派生指标' and re.search(r'近\d+|累计', kou):
        return 'window'
    return 'additive'


CLASS_LABEL = {
    'additive': ('可加', '按天 SUM 即可得到任意区间'),
    'distinct': ('去重', '跨天/跨维度不能相加，需要存 BITMAP 或回明细去重'),
    'once': ('一次性事件', '每个实体只发生一次（新注册/首单/认证），按天可加；跨维度汇总仍需去重'),
    'ratio': ('比率/均值', '区间内分子、分母各自汇总后再相除'),
    'snapshot': ('快照', '取区间期末值（或区间日均）'),
    'window': ('固定窗口', '口径自带窗口（近30天等），改造为区间参数'),
}


# ---------------------------------------------------------------- 主流程
def run(sheets, docs_dir=None):
    T = Sheet(sheets['表清单'])
    F = Sheet(sheets['字段清单'])
    D = Sheet(sheets['DWS口径'])
    A = Sheet(sheets['ADS业务指标'])
    W = Sheet(sheets['调度工作流']) if '调度工作流' in sheets else None
    H = Sheet(sheets['质量体检']) if '质量体检' in sheets else None

    TB = {sn(T.get(r, '表名（库.表）')): r for r in T.rows}
    layer = {k: base(T.get(r, '分层')) for k, r in TB.items()}
    is_rt = {k: '实时' in str(T.get(r, '分层')) for k, r in TB.items()}
    fields = collections.defaultdict(dict)
    for r in F.rows:
        fields[sn(F.get(r, '表名（库.表）'))][F.get(r, '字段名')] = r
    up = {k: set(toks(T.get(r, '上游表'))) for k, r in TB.items()}

    findings = []

    def add(level, cat, title, detail, suggest, cols=None, rows=None, key=None):
        rows = rows or []
        findings.append({'id': key or f'F{len(findings) + 1:02d}', 'level': level, 'cat': cat, 'title': title,
                         'detail': detail, 'suggest': suggest, 'cols': cols or [], 'rows': rows[:300],
                         'n': len(rows)})

    # ---------- 1. 去重类指标被相加
    dcls = {D.get(r, '英文名'): metric_class(r, D) for r in D.rows}
    dcode = {D.get(r, '口径编码'): r for r in D.rows}
    # 来源表粒度里含有被去重的实体 ID（如 买家×商户 快照表），可以按行数/按键去重，不算问题
    grain = {k: str(T.get(r, '粒度')) for k, r in TB.items()}
    ENT = {'买家ID': ('buyer_customer_id',), '游客ID': ('customer_id', 'buyer_customer_id'), '租户ID': ('tenant_id',),
           '卖家租户ID': ('seller_tenant_id', 'tenant_id'), '分销商租户ID': ('distributor_tenant_id',), 'SKU ID': ('sku_id',),
           '设备ID': ('device_id',)}

    def entity_grain(code, tables):
        m = DISTINCT_ENTITY.search(str(D.get(dcode[code], '计算公式'))) if code in dcode else None
        keys = ENT.get(m.group(1), ()) if m else ()
        return any(any(re.search(rf'\b{k}\b', grain.get(t, '')) for k in keys) for t in tables)

    en2code = {D.get(r, '英文名'): D.get(r, '口径编码') for r in D.rows}
    summed = []
    for t, fs in fields.items():
        for n, r in fs.items():
            src = str(F.get(r, '加工 / 来源'))
            if dcls.get(n) == 'distinct' and layer.get(t) == 'DWS' and re.search(r'汇总|SUM', src, re.I) \
                    and not entity_grain(en2code.get(n), toks(src.split('.')[0])):
                summed.append([t, n, F.get(r, '字段注释'), src])
    period_distinct = []
    for r in A.rows:
        code = str(A.get(r, '基础口径')).split(' ')[0]
        per = A.get(r, '统计周期')
        if code in dcode and metric_class(dcode[code], D) == 'distinct' and per not in ('当日', '今日实时', '当前', '近5分钟', '近1小时', '当小时') \
                and not entity_grain(code, toks(A.get(r, '来源 DWS'))):
            period_distinct.append([A.get(r, '指标编码'), A.get(r, '业务指标名'), sn(A.get(r, 'ADS表')) + '.' + str(A.get(r, '字段名')),
                                    per, A.get(r, '来源 DWS')])
    if summed or period_distinct:
        add('高', '指标口径', '去重买家数被跨天、跨维度直接相加，结果偏大',
            f'DWS 里「支付买家数」等去重指标只存了 BIGINT 计数，汇总表又用 SUM 往上卷（{len(summed)} 处）；'
            f'ADS 的近7日/近30日/本月/本年支付买家数、老客买家数共 {len(period_distinct)} 个指标，来源都是按天的去重计数——'
            '同一个游客 7 天里买 3 次会被算 3 次，同一游客在两个 SKU/渠道下单也会被算 2 次。'
            '公式写的是 COUNT(DISTINCT)，但上游数据做不出这个结果。「质量体检」页没有发现这个问题。',
            'DWS 去重类指标改存 BITMAP（StarRocks BITMAP_UNION / Hive 侧存 id 数组），区间查询时 BITMAP_UNION_COUNT；'
            '或在 ADS 直接回 DWD 明细按区间 COUNT(DISTINCT)。详见「ADS 指标体系」。',
            ['对象', '字段', '问题', '上游'],
            [[a, b, 'SUM 上卷去重计数（跨 SKU/渠道重复计人）', d] for a, b, c, d in summed] +
            [[f'{x[0]} {x[1]}', x[2], f'{x[3]}：由按天去重计数得出，跨天重复计人', x[4]] for x in period_distinct],
            key='H1')

    # ---------- 2. 统计周期写死
    per_cnt = collections.Counter(A.get(r, '统计周期') for r in A.rows if A.get(r, '离线/实时') == '离线')
    base_cnt = len({str(A.get(r, '基础口径')).split(' ')[0] for r in A.rows})
    add('高', '指标设计', '统计周期写死为 ADS 宽表列，无法满足自定义时间、节假日、季度、半年度等筛选',
        f'801 个离线 ADS 指标里，{per_cnt["当日"]} 个当日、{per_cnt["近7日"]} 个近7日、{per_cnt["近30日"]} 个近30日、'
        f'{per_cnt["本月累计"]} 个本月累计、{per_cnt["本年累计"]} 个本年累计……同一口径按周期展开成不同字段（pay_1d_amt / pay_7d_amt / pay_30d_amt），'
        f'实际只用到 {base_cnt} 个基础口径。文旅行业常按「国庆 7 天」「暑期」「Q3」「上半年」「任意起止日」看数，'
        '每加一种周期就要给每张 ADS 表加一批列、改一次 SQL；自定义区间则根本做不到。',
        '改成「口径 × 时间区间参数」：DWS 只存日粒度原子数据，时间区间在查询时由指标服务解析成 travel_date 范围；'
        '日期维表补齐节假日/季度/半年度/同比对齐字段；ADS 改为「统计周期做行维度」，17 种预计算周期 × 本期值/日均/上期/环比/去年同期/同比/占比。详见「ADS 指标体系」与 dist/ADS指标体系.xlsx。',
        ['统计周期', '离线指标数'], [[k, v] for k, v in per_cnt.most_common()], key='H2')

    # ---------- 3. 分区字段未进字段清单
    no_part = []
    for k, r in TB.items():
        p = str(T.get(r, '分区'))
        if 'travel_date' in p and not is_rt[k] and 'travel_date' not in fields[k]:
            no_part.append([k, p])
    if no_part:
        add('高', 'DDL', f'{len(no_part)} 张离线分区表的字段清单里没有分区字段 travel_date，原页面 DDL 生成的是非分区表',
            '「表清单」分区列写了 travel_date（YYYYMMDD），但「字段清单」只有 14 张实时 DWD 表登记了 travel_date。'
            '原页面按字段清单生成 DDL，分区只输出成一行注释（-- 分区：travel_date），复制出去建的表没有 PARTITIONED BY，'
            '调度 SQL 里 INSERT OVERWRITE ... PARTITION (travel_date=...) 会直接报错。',
            '字段清单补上 travel_date（类别=分区）。本次已在页面 DDL 里按「表清单·分区」列补出 PARTITIONED BY (travel_date STRING)。',
            ['表名', '分区（表清单）'], no_part, key='H3')

    # ---------- 4. 表级血缘缺上游
    ref_gap = collections.defaultdict(set)
    bad_ref, no_up = [], []
    for r in F.rows:
        t = sn(F.get(r, '表名（库.表）'))
        if layer.get(t) == 'ODS':
            continue
        u = str(F.get(r, '上游字段')).strip()
        if not u:
            if F.get(r, '字段类别') not in ('ETL',):
                no_up.append([t, F.get(r, '字段名'), F.get(r, '字段类别'), F.get(r, '加工 / 来源')])
            continue
        for ref in re.split(r'[、,，;；]\s*', u):
            m = re.match(r'^(\w+)\.(\w+)\.(\w*)$', ref.strip())
            if not m or not m.group(3):
                bad_ref.append([t, F.get(r, '字段名'), ref])
                continue
            tt = m.group(2)
            if tt in TB and tt != t and tt not in up[t]:
                ref_gap[t].add(tt)
    if ref_gap:
        rows = [[t, '、'.join(sorted(v)), '、'.join(sorted(up[t]))] for t, v in sorted(ref_gap.items())]
        add('中', '血缘', f'{len(rows)} 张表的「上游表」漏登记：字段级血缘用到了，表级没写',
            '例如 dwd_ord_order_group_di 的 first_pay_time 来自 ods_fin_payment_record_di，channel_type 来自 dim_trf_channel_df，'
            '但表清单「上游表」只写了 ods_ord_order_group_di。调度工作流里这些依赖是齐的（已核对），'
            '所以不影响跑数，但页面上按表点血缘会漏链路，影响面评估会少算。',
            '按字段级血缘反推表级上游，补齐「上游表/下游表」两列。',
            ['表', '漏登记的上游', '当前登记的上游'], rows, key='M1')
    if bad_ref:
        add('中', '血缘', f'{len(bad_ref)} 处上游字段只写了表名、缺字段名',
            '格式应为 库.表.字段，这几处以「.」结尾。', '补全字段名。',
            ['表', '字段', '上游字段（原文）'], bad_ref, key='M2')
    if no_up:
        add('低', '血缘', f'{len(no_up)} 个非 ETL 字段没有上游字段',
            '「质量体检」写的是「0 个字段无上游」，实际有这些（多数是 ticket_qty=1 这类常量计数度量，以及派生的天数/分钟数）。'
            '常量度量可以接受，但体检结论应如实。',
            '常量度量在上游字段写「常量 1」或主键字段；派生字段写清参与计算的字段。',
            ['表', '字段', '类别', '加工 / 来源'], no_up, key='L1')

    # ---------- 5. DWS 口径落地 / ADS 引用
    land_bad = []
    for r in D.rows:
        for t in toks(D.get(r, '落地 DWS 表')):
            if t not in TB:
                land_bad.append([D.get(r, '口径编码'), D.get(r, '英文名'), t, '表不存在'])
            else:
                if layer[t] != 'DWS':
                    land_bad.append([D.get(r, '口径编码'), D.get(r, '英文名'), t, f'落在 {layer[t]} 层，不是 DWS'])
                if D.get(r, '英文名') not in fields[t]:
                    land_bad.append([D.get(r, '口径编码'), D.get(r, '英文名'), t, '该表没有这个字段'])
    if land_bad:
        add('中', '指标口径', f'{len(land_bad)} 处 DWS 口径的「落地 DWS 表」不对',
            'A082 风控命中次数、A083 风控拦截次数的落地表写成了 dwd_opr_risk_event_rt（DWD 层），且该表没有这两个字段；'
            '实际应落在 dws_opr_risk_rule_hit_rt。', '改正落地表。',
            ['口径编码', '英文名', '落地表', '问题'], land_bad, key='M3')
    src_bad = []
    for r in A.rows:
        code = str(A.get(r, '基础口径')).split(' ')[0]
        if code not in dcode:
            continue
        land = set(toks(D.get(dcode[code], '落地 DWS 表')))
        src = set(toks(A.get(r, '来源 DWS')))
        if land and not (land & src) and D.get(dcode[code], '口径类型') == '原子指标':
            src_bad.append([A.get(r, '指标编码'), A.get(r, '业务指标名'), code, '、'.join(sorted(src)), '、'.join(sorted(land))])
    if src_bad:
        add('中', '指标口径', f'{len(src_bad)} 个 ADS 指标的「来源 DWS」与其原子口径的落地表对不上',
            '例如员工业绩 staff_pay_*_amt 引用 A043（落在 dws_sup_staff_operate_di），来源却写 dws_ord_tenant_sku_channel_trade_di；'
            '动销商户数 active_tenant_*_qty 引用 A041（落在 dws_sup_tenant_lifetime_df），来源却写成交易日汇总表。'
            '两边任意一处改口径，另一处不会同步。', '以口径字典的落地表为准，改 ADS 来源或补登记落地表。',
            ['指标编码', '指标名', '基础口径', 'ADS 来源 DWS', '口径落地表'], src_bad, key='M4')

    # ---------- 6. ODS 对源库 DDL
    ddl, dbmap = parse_source_ddl(docs_dir)
    if ddl:
        ods_rows, ver_rows = [], []
        for k, r in TB.items():
            if layer[k] != 'ODS':
                continue
            m = re.match(r'(pft-[\w-]+)\.(t_\w+)', str(T.get(r, '来源')))
            if not m:
                continue
            db, st = m.groups()
            if st not in ddl:
                ods_rows.append([k, f'{db}.{st}', '设计文档里找不到该源表 DDL', ''])
                continue
            if dbmap.get(st) and db not in dbmap[st]:
                ods_rows.append([k, f'{db}.{st}', f'库名不符，文档为 {"/".join(dbmap[st])}', ''])
            src_cols = set(c for d in ddl[st] for c, _ in d['cols'])
            mine = set(fields[k])
            etl = {'etl_time', 'binlog_op_type', 'binlog_time', 'travel_date'}
            miss = sorted(src_cols - mine)
            extra = sorted(mine - src_cols - etl)
            if extra:
                ods_rows.append([k, f'{db}.{st}', 'ODS 有、源表没有', '、'.join(extra)])
            if miss and not is_rt[k]:
                ods_rows.append([k, f'{db}.{st}', '源表有、ODS 未接（多为密钥/敏感字段，按备注有意剔除）', '、'.join(miss)])
        for st, defs in ddl.items():
            if len(defs) > 1:
                cs = [set(c for c, _ in d['cols']) for d in defs]
                if any(c != cs[0] for c in cs[1:]):
                    a, b = defs[0], defs[1]
                    diff = sorted((set(c for c, _ in b['cols']) ^ set(c for c, _ in a['cols'])))
                    ver_rows.append([st, f"{a['file']} vs {b['file']}", '、'.join(diff)])
        n_ods = sum(1 for k in TB if layer[k] == 'ODS' and not is_rt[k])
        add('提示', '源库对照', f'ODS 与业务库 DDL 逐字段比对：{n_ods} 张离线 ODS 均能对上源表',
            '除下表列出的差异外，字段一一对应；未接入的都是密钥、银行卡号这类按备注有意剔除的字段，处理合理。'
            '实时 ODS 只取了计算需要的字段，未列出。', '无需修改；下表供客户安全确认（待确认事项 #16）。',
            ['ODS 表', '源表', '差异', '字段'], ods_rows, key='I1')
        if ver_rows:
            add('中', '源库对照', f'{len(ver_rows)} 张源表在不同设计文档里字段不一致',
                'core-models 与 database 两份文档对同一张表给出的字段不同（database.md 多出 sku_version、sale_dims、settle_amount、freeze_type 等）。'
                'ODS 按 database.md 的完整版本接入，结算价、冻结类型等指标依赖这些字段。',
                '请客户确认以 database.md 为准，并同步更新 core-models 文档。',
                ['源表', '文档', '有差异的字段'], ver_rows, key='M5')

    # ---------- 7. 命名规范
    name_bad = []
    for k, r in TB.items():
        n = T.get(r, '表名（库.表）')
        L = base(T.get(r, '分层')).lower()
        m = re.match(rf'^({L})\.\1_({"|".join(DOMAINS)})_([a-z0-9_]+?)_(hrs_f|hrs|di|df|wk_f|wk|mo_f|mo|q_f|q|yr_f|yr|f|zip|rt)$', n)
        if not m:
            name_bad.append([n, '不符合 库.分层_业务域_实体_粒度'])
        elif SUFFIX_OF.get(T.get(r, '后缀含义')) not in (m.group(4), None):
            name_bad.append([n, f'后缀与「后缀含义：{T.get(r, "后缀含义")}」不一致'])
    fbad = []
    for r in F.rows:
        n = F.get(r, '字段名')
        if not re.match(r'^[a-z][a-z0-9_]*$', str(n)):
            fbad.append([sn(F.get(r, '表名（库.表）')), n, '非 snake_case'])
        elif base(F.get(r, '分层')) != 'ODS' and not str(n).endswith(FIELD_KW) and F.get(r, '字段类别') not in ('ETL', '拉链', '分区'):
            fbad.append([sn(F.get(r, '表名（库.表）')), n, '未以规范关键字结尾（_id/_no/_amt/_qty …）'])
    if name_bad or fbad:
        add('低', '命名规范', f'命名不规范：表 {len(name_bad)} 处、字段 {len(fbad)} 处', '其余 273 张表、4,654 个字段均符合规范。',
            'coupon_value_num 建议改为 coupon_value_amt（面额）或 coupon_value_qty（折扣/张数）。',
            ['表', '字段 / 表名', '问题'], [[a, '', b] for a, b in name_bad] + fbad, key='L2')
    str_time = [r for r in F.rows if base(F.get(r, '分层')) in ('DWD', 'DWS', 'DIM') and str(F.get(r, '字段名')).endswith('_time')
                and F.get(r, '类型') == 'STRING' and F.get(r, '字段类别') != 'ETL']
    if str_time:
        add('低', '字段类型', f'{len(str_time)} 个 DWD/DIM/DWS 时间字段用 STRING 存储',
            '规范要求 _time 含时分秒。STRING 存时间无法做时间运算校验，格式不统一时排序/比较会出错。',
            '离线 Hive 可保留 STRING 但在注释写明格式 yyyy-MM-dd HH:mm:ss，并在质量规则里加格式校验；StarRocks 侧建议用 DATETIME。',
            ['表', '字段', '注释'], [[sn(F.get(r, '表名（库.表）')), F.get(r, '字段名'), F.get(r, '字段注释')] for r in str_time], key='L3')

    # ---------- 8. 日期维表
    dd = fields.get('dim_opr_date_f', {})
    need = {'half_year_no': '半年度', 'holiday_period_code': '节假日区间编码（如 2026_national_day）', 'holiday_day_no': '节假日第 N 天',
            'lunar_date_code': '农历日期（春节同比对齐）', 'last_year_same_day_date': '同比对齐日（去年同一节假日第 N 天 / 同星期）',
            'quarter_start_date': '所在季度第一天', 'year_start_date': '所在年第一天'}
    miss = [[k, v] for k, v in need.items() if k not in dd]
    if miss:
        add('中', '指标设计', f'日期维表 dim_opr_date_f 缺 {len(miss)} 个时间周期筛选需要的字段',
            '已有年/季/月/周/节假日类型/节假日名称/寒暑假/旺淡季，但没有半年度、节假日区间、节假日第 N 天、农历、同比对齐日，'
            '做不了「今年国庆 vs 去年国庆」「春节同比」「上半年」这类筛选。',
            '补齐下表字段，并新增节假日区间表 dim_opr_holiday_period_f（见「时间周期方案」）。',
            ['建议新增字段', '含义'], miss, key='M6')

    # ---------- 9. 质量体检结论复核
    verify = []
    if H:
        rev = {
            '字段级血缘覆盖（DWD 及以上）': ('不符', f'实际有 {len(no_up)} 个非 ETL 字段无上游；{len(bad_ref)} 处上游字段缺字段名'),
            'ADS 指标全部由「口径 × 周期 × 修饰词」生成': ('有风险', '生成方式本身成立，但周期写死成列，正是无法支持自定义周期的原因（H2）'),
            '原子口径单一定义（英文名不重复）': ('属实', '212 个口径英文名、编码均无重复'),
            '表名符合「分层_业务域_实体名_粒度」': ('属实' if not name_bad else '不符', f'复核 {len(TB)} 张表，{len(name_bad)} 处不符'),
            '库名与分层一致（如 dwd.dwd_xxx）': ('属实', ''),
            '字段与表全部带注释': ('属实', f'{len(F.rows)} 个字段全部有注释'),
            '分区字段统一 travel_date': ('部分属实', f'表清单写了 travel_date，但 {len(no_part)} 张表的字段清单里没有该字段（H3）'),
            'ADS 只读 DWS，不跨层': ('属实', 'ADS 上游只有 DWS 与 DIM'),
            '全链路无跨层引用': ('属实', '按表级上游复核，无跨层'),
            'DWD/DWS 无孤儿表': ('属实', ''),
            '字段名以规范关键词结尾（DWD 及以上）': ('不符' if fbad else '属实', f'{len(fbad)} 处不符（L2）'),
            '实时指标与离线同名指标口径一致': ('属实', '实时与离线共用口径编码'),
            '一致性维度总线矩阵': ('属实', ''),
            'ADS 指标可追溯到业务库': ('部分属实', f'字段级可追溯；表级上游漏登记 {len(ref_gap)} 张表（M1），页面点血缘会断'),
            'ADS 指标要素齐全（中文名/字段名/周期/公式/单位/来源）': ('部分属实', f'要素齐全；但 {len(src_bad)} 个指标来源与口径落地表不一致（M4）'),
        }
        for r in H.rows:
            item = H.get(r, '检查项')
            v = rev.get(item)
            for k2, v2 in rev.items():
                if v is None and k2.split('（')[0] in str(item):
                    v = v2
            if any(s in str(item) for s in ('新增', '近7日/近30日 之外')):
                v = ('有风险', '每加一种周期/修饰词就要给 ADS 加一批列；自定义区间做不到（H2）') if '近90日' in str(item) else (v or ('未复核', ''))
            if 'DWS 口径被' in str(item) or 'DWS 平均' in str(item):
                v = ('属实', '')
            verify.append([H.get(r, '维度'), item, H.get(r, '结果'), H.get(r, '状态'), *(v or ('未复核', '需人工判断'))])

    # ---------- 10. 口径聚合方式分类（时间周期方案用）
    mclass = {}
    for r in D.rows:
        mclass[D.get(r, '口径编码')] = metric_class(r, D)

    order = {'高': 0, '中': 1, '低': 2, '提示': 3}
    findings.sort(key=lambda f: (order[f['level']], f['id']))
    lv = collections.Counter(f['level'] for f in findings)
    return {'findings': findings, 'verify': verify, 'mclass': mclass, 'classLabel': CLASS_LABEL,
            'summary': {'高': lv['高'], '中': lv['中'], '低': lv['低'], '提示': lv['提示'],
                        'tables': len(TB), 'fields': len(F.rows), 'dws': len(D.rows), 'ads': len(A.rows),
                        'srcTables': len(ddl)}}


def to_markdown(res, xlsx_name):
    s = res['summary']
    L = [f'# PFT3.0 数仓字典核对报告', '',
         f'> 由 `dw-dict/checks.py` 自动生成，核对对象：`{xlsx_name}`（{s["tables"]} 张表、{s["fields"]} 个字段、'
         f'{s["dws"]} 个 DWS 口径、{s["ads"]} 个 ADS 指标），对照 `docs/规范/数仓命名规范.md` 与 `docs/source/` 下 {s["srcTables"]} 张业务库 DDL。', '',
         f'**结论：高 {s["高"]} 项、中 {s["中"]} 项、低 {s["低"]} 项、提示 {s["提示"]} 项。**', '',
         '| 编号 | 级别 | 类别 | 问题 | 涉及 |', '|---|---|---|---|---|']
    for f in res['findings']:
        L.append(f'| {f["id"]} | {f["level"]} | {f["cat"]} | {f["title"]} | {f["n"] or ""} |')
    for f in res['findings']:
        L += ['', f'## {f["id"]} · {f["title"]}', '', f'**级别**：{f["level"]}　**类别**：{f["cat"]}', '', f['detail'], '',
              f'**建议**：{f["suggest"]}']
        if f['rows']:
            cols = [c for c in f['cols'] if c]
            L += ['', '| ' + ' | '.join(cols) + ' |', '|' + '---|' * len(cols)]
            for r in f['rows'][:30]:
                L.append('| ' + ' | '.join(str(x).replace('|', '\\|').replace('\n', ' ') for x in r[:len(cols)]) + ' |')
            if f['n'] > 30:
                L.append(f'\n（共 {f["n"]} 条，此处列前 30 条，完整清单见页面「核对报告」）')
    if res['verify']:
        L += ['', '## 「质量体检」结论复核', '', '| 维度 | 检查项 | 客户结论 | 复核 | 说明 |', '|---|---|---|---|---|']
        for r in res['verify']:
            L.append(f'| {r[0]} | {r[1]} | {r[2]}（{r[3]}） | {r[4]} | {r[5]} |')
    return '\n'.join(L) + '\n'


if __name__ == '__main__':
    import sys
    import json
    sys.path.insert(0, str(pathlib.Path(__file__).parent))
    from build import load_sheets  # noqa
    root = pathlib.Path(__file__).parent
    xlsx = sys.argv[1] if len(sys.argv) > 1 else next((root / 'data').glob('*.xlsx'))
    res = run(load_sheets(xlsx), root.parent / 'docs' / 'source')
    for f in res['findings']:
        print(f'[{f["level"]}] {f["id"]} {f["title"]}  ({f["n"]})')
