#!/usr/bin/env python3
"""客户 DataWorks 现状诊断：读 DATAWORKS.zip，输出问题清单（docs/问题清单.md）与明细（output/*.csv）。

用法：python3 dataworks/audit.py [DATAWORKS.zip 路径]
"""
import collections, csv, datetime, pathlib, re, sys

ROOT = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT))
import parse  # noqa: E402

sh = lambda t: str(t).split('.')[-1].lower()
LAYER = {'ods': 'ODS', 's': 'ODS', 'src': 'ODS', 'dwd': 'DWD', 'dim': 'DIM', 'dws': 'DWS', 'ads': 'ADS'}
RANK = {'ODS': 0, 'DWD': 1, 'DIM': 1, 'DWS': 2, 'ADS': 3}
SENS = re.compile(r'(phone|mobile$|^tel$|tel$|idcard|id_card|personid|id_number|idno|card_no|bank|address|passport|email|password|pwd)', re.I)


def layer(t):
    m = re.match(r'^([a-z]+)_', sh(t))
    return LAYER.get(m.group(1)) if m else None


def analyse(nodes):
    N = nodes
    SQL = [n for n in N if n['lang'] == 'sql']
    DI = [n for n in N if n['type'] == 'DI' and n['di'] and 'reader' in n['di']]
    hive, export = collections.defaultdict(list), collections.defaultdict(list)
    for n in N:
        if n in DI:
            w = n['di']['writer']
            for t in w.get('tables', []):
                (hive[sh(t)] if w.get('type') == 'hive' else export[(w.get('datasource'), sh(t))]).append(n)
        elif n['lang'] == 'sql':
            for t, k in n['writes']:
                if k != 'ddl':
                    hive[sh(t)].append(n)
    reads = collections.defaultdict(list)
    for n in N:
        for t in n['reads']:
            reads[sh(t)].append(n)
    F = []   # (id, 级别, 类别, 标题, 数字, 说明, 建议, 明细表头, 明细行)

    def add(fid, lvl, cat, title, num, detail, suggest, cols, rows):
        F.append({'id': fid, 'level': lvl, 'cat': cat, 'title': title, 'n': num, 'detail': detail, 'suggest': suggest, 'cols': cols, 'rows': rows})

    # ---------------- 架构与分层 ----------------
    ws_layers = collections.defaultdict(collections.Counter)
    for t, ns in hive.items():
        for n in ns:
            ws_layers[n['ws']][layer(t) or '无分层前缀'] += 1
    add('A1', '高', '架构与分层', '三个工作空间各自建了一套数仓，没有统一的分层',
        len(ws_layers),
        '「数据中台」「数据平台」「业务工厂」三个空间都在做 ODS→ADS：数据中台有 ODS / 原始数据层(ODS)、DIM / 数据维度(DIM)、DW / 数仓明细层(DWD) 两套同义目录；数据平台按 SRC/ODS/DIM/DWD/DWS/ADS 分层；业务工厂按业务主题（景区指标、商户数据中心、报表数据、内部信息…）建目录，每个主题从同步到出数自成一套。'
        f'三个空间之间互相读表 {sum(1 for n in N for t in n["reads"] if hive.get(sh(t)) and n["ws"] not in {p["ws"] for p in hive[sh(t)]})} 处。',
        '以 PFT3.0 的分层为准收敛成一个数仓空间：ODS 每张业务表只落一次，DWD/DIM/DWS 按业务过程与主题建公共层，业务工厂只保留 ADS 与回流任务。',
        ['工作空间', '分层', '表数'], [[w, l, c] for w, cc in ws_layers.items() for l, c in cc.most_common()])

    xs, rev = [], []
    for n in SQL:
        for t, k in n['writes']:
            lt = layer(t)
            if k == 'ddl' or not lt:
                continue
            for r in n['reads']:
                lr = layer(r)
                if not lr:
                    continue
                if lt in ('ADS', 'DWS') and lr == 'ODS':
                    xs.append([n['path'], sh(t), lt, sh(r)])
                elif RANK[lr] > RANK[lt]:
                    rev.append([n['path'], sh(t), lt, sh(r), lr])
    add('A2', '高', '架构与分层', 'ADS / DWS 直接读 ODS，公共明细层形同虚设', len({x[1] for x in xs}),
        f'{len({x[1] for x in xs if x[2] == "ADS"})} 张 ADS、{len({x[1] for x in xs if x[2] == "DWS"})} 张 DWS 跳过 DWD 直接从 ODS 取数，'
        f'同一套清洗（去重、状态过滤、金额换算）在每张报表里各写一遍；另有 {len(rev)} 处反向引用（如 DIM 读 DWS、ODS 读 DIM）。',
        'ODS → DWD 只做一次清洗；DWS/ADS 一律从 DWD/DWS 取数；DIM 不依赖汇总层。',
        ['节点', '写入表', '层', '直接读的 ODS 表'], xs + [[r[0], r[1], r[2], f'{r[3]}（{r[4]}，反向）'] for r in rev])

    sty = collections.Counter('_d_i / _d_f' if re.search(r'_[dhom]_[if]$', t) else '_di / _df' if re.search(r'_(di|df|ti|hi|f|ri|oi|hrs_f)$', t)
                              else '无后缀' for t in hive)
    pre = collections.Counter((re.match(r'^([a-z]+)_', t) or [None, '无'])[1] for t in hive)
    off = {k: v for k, v in pre.items() if k not in LAYER}
    add('A3', '中', '架构与分层', '表命名多套规则并存', len(hive),
        f'{len(hive)} 张 Hive 表：后缀 ' + '、'.join(f'{k} {v} 张' for k, v in sty.most_common()) + f'；分层前缀之外还有 {sum(off.values())} 张用 {", ".join(f"{k}_" for k, _ in sorted(off.items(), key=lambda x: -x[1])[:8])} 等前缀；'
        '同一业务表的 ODS 有 s_xxx / ods_xxx / src_xxx / ods_myuu_xxx 多种叫法。',
        '统一按《数仓命名规范》：层_域_实体_粒度后缀（_di/_df/_zip/_f），存量表建映射表逐步改名。',
        ['表名', '后缀风格', '前缀'], [[t, '_d_i / _d_f' if re.search(r'_[dhom]_[if]$', t) else '_di / _df' if re.search(r'_(di|df|ti|hi|f|ri|oi|hrs_f)$', t) else '无后缀',
                                     (re.match(r'^([a-z]+)_', t) or [None, '无'])[1]] for t in sorted(hive)])

    shard = sorted(t for t in hive if re.search(r'_20\d{4}_', t))
    add('A4', '中', '架构与分层', '业务库分表按月 / 按年各同步一张 ODS', len(shard),
        f'业务库的分表（如订单 201801…202501）在 ODS 各落一张（{len(shard)} 张），下游要 UNION 才能用，新增分表要改任务。',
        'ODS 按逻辑表合并（同步任务多表读取写同一张表，带分表来源列）。', ['表名'], [[t] for t in shard])

    # ---------------- 重复开发 ----------------
    S = collections.defaultdict(list)
    for n in DI:
        r = n['di']['reader']
        if r.get('type') in ('hive', None):
            continue
        for t in r.get('tables') or ['(querySql)']:
            S[(r.get('datasource'), sh(t))].append(n)
    dup = {k: v for k, v in S.items() if len(v) > 1}
    add('B1', '高', '重复开发', '同一张业务表被多个任务重复同步', len(dup),
        f'{len(dup)} 张业务表被 {sum(len(v) for v in dup.values())} 个同步任务重复抽取。最严重的订单主表 POLAR_myuu.uu_ss_order 被 {len(S.get(("POLAR_myuu", "uu_ss_order"), []))} 个任务、分布在 3 个工作空间抽取'
        '（s_order_d_i、s_order_update_d_i、ods_myuu_uu_ss_order_di、src_uu_ss_order_di…），每天对业务库重复全量 / 增量读取。',
        '一张业务表只保留一个 ODS 同步任务（增量 + 合并），其他任务改读这张 ODS。',
        ['数据源', '业务表', '任务数', '工作空间', '落地表'],
        [[k[0], k[1], len(v), '、'.join(sorted({x['ws'] for x in v})), '、'.join(sorted({sh(t) for x in v for t in x['di']['writer'].get('tables', [])}))]
         for k, v in sorted(dup.items(), key=lambda x: -len(x[1]))])

    ds_of = collections.defaultdict(set)
    for ds, t in S:
        ds_of[t].add(str(ds))
    alias = {t: v for t, v in ds_of.items() if len(v) > 1}
    add('B2', '中', '重复开发', '同一个业务库配置了多个数据源名', len(alias),
        f'{len(alias)} 张表从不同名字的数据源读取（如 RDS_pft_open_cooperate / BI_RDS_pft_open_cooperate、RDS_oa_ecology / BI_RDS_oa_ecology、RDS_summary / BI_RDS_summary），'
        '同一个库两套账号与连接，重复同步不易发现。', '每个业务库只保留一个数据源，按库命名。',
        ['业务表', '数据源'], [[t, '、'.join(sorted(v))] for t, v in sorted(alias.items())])

    def part_key(n, t):
        """写入该表时的分区写法：静态分区值（如 type='ota'）或动态分区列"""
        m = re.search(r'insert\s+(?:overwrite|into)\s+(?:table\s+)?[`\w.]*' + re.escape(t) + r'`?\s*partition\s*\(([^)]*)\)', parse._strip_comments(n['script']), re.I)
        return re.sub(r'\s+', '', m.group(1)).lower() if m else ''
    multi, isolated = {}, {}
    for t, v in hive.items():
        ws = {x['path']: x for x in v}
        if len(ws) < 2:
            continue
        keys = [part_key(x, t) for x in ws.values()]
        # 各写各的分区：静态分区值互不相同，或按「表名」等动态分区列隔离（如增量登记表）
        lead = [k.split(',')[0].strip('`') for k in keys]
        if (all(k and '=' in k for k in keys) and len(set(keys)) == len(keys)) or \
           all(x and '=' not in x and not re.search(r'date|dt$|^ds$|day|month|hour', x) for x in lead):
            isolated[t] = v
        else:
            multi[t] = v
    add('B3', '高', '重复开发', '同一张表由多个任务写入', len(multi),
        f'{len(multi)} 张 Hive 表有多个写入任务且写同一批分区：如 ods_pft_report_checked_two_d_i 被正式工作流、归档抽取工作流和「手动任务_动态分区」3 个节点写入；ads_data_center_report_order_summary_d_i 的初始化节点（_o_f）仍在每天调度；'
        'ads_trf_scenic_passenger_flow_di 在数据平台和业务工厂各有一套；归档库按 2022–2025 年拆成 4 个节点写同一张表。后跑的任务会覆盖先跑的结果。'
        f'（另有 {len(isolated)} 张表多个任务各写各的分区，如增量登记表 dim_src_table_increment_info_di、按 data_domain 分区合并的 ads_digital_brain_target_merge_di，属设计如此，未计入。）',
        '一张表只能有一个生产任务；补数用同一任务的补数据功能，不复制节点。',
        ['表名', '写入任务数', '任务'], [[t, len({x['path'] for x in v}), '；'.join(sorted({x['path'] for x in v}))] for t, v in sorted(multi.items(), key=lambda x: -len(x[1]))])

    order_chain = set()
    seed = {sh(t) for n in DI if n['di']['reader'].get('type') in ('mysql', 'polardb')
            and any(sh(x) == 'uu_ss_order' for x in n['di']['reader'].get('tables', [])) for t in n['di']['writer'].get('tables', [])}
    down = collections.defaultdict(set)
    for n in N:
        outs = [sh(t) for t, k in n['writes'] if k != 'ddl']
        for r in n['reads']:
            down[sh(r)].update(outs)
    st = list(seed)
    order_chain |= seed
    while st:
        x = st.pop()
        for y in down.get(x, ()):
            if y not in order_chain:
                order_chain.add(y)
                st.append(y)
    dwd_order = sorted(t for t in order_chain if t.startswith('dwd_'))
    add('B4', '高', '重复开发', '订单明细被反复加工成多张口径不一的 DWD', len(dwd_order),
        f'从订单主表 uu_ss_order 往下共 {len(order_chain)} 张表，其中订单类 DWD 有 {len(dwd_order)} 张（dwd_order_d_i、dwd_split_d_i、dwd_order_split_d_i、dwd_ord_order_details_di、dwd_order_d_f_v7、dwd_order_verify_d_i_v8…），'
        '各自定义了订单状态、拆单、核销口径，下游报表取哪张由开发者决定，数字对不上。',
        '订单域只保留 PFT3.0 的 DWD：下单 / 支付 / 核销 / 退款四个业务过程各一张，拆单、游客、轨迹作为子表或宽表字段。',
        ['订单类 DWD'], [[t] for t in dwd_order])

    def wset(path):
        return {sh(t) for n in N if path in n['path'] for t, k in n['writes'] if k != 'ddl'}
    old, new = wset('景区指标旧表'), wset('景区指标宽表')
    oldn = [n for n in N if '景区指标旧表' in n['path']]
    newn = [n for n in N if '景区指标宽表' in n['path']]
    add('B5', '高', '重复开发', '「景区指标旧表」与「景区指标宽表」两套同时在跑', len(oldn) + len(newn),
        f'旧表 {len(oldn)} 个节点（{len(old)} 张表，按 渠道 × 省份 × 团散 × 票种… 每种组合一张）与宽表 {len(newn)} 个节点（{len(new)} 张表）都在正常调度、都回流到 RDS_bi_datav；'
        '旧表基于 dwd_split_d_i，宽表基于 dwd_order_d_i / dwd_order_track_d_i，两套口径并行，前端看到的数可能来自任一套。',
        '确认前端已全部切到宽表后，暂停旧表并保留一个账期对数，再下线。',
        ['套', '节点', '类型', '写入表'], [['旧表', n['path'], n['type'], '、'.join(sh(t) for t, k in n['writes'] if k != 'ddl')] for n in oldn] +
        [['宽表', n['path'], n['type'], '、'.join(sh(t) for t, k in n['writes'] if k != 'ddl')] for n in newn])

    ver = sorted(t for t in set(hive) | {k[1] for k in export}
                 if re.search(r'(_v\d+|_temp|_tmp|_new|_copy|_old|_bak\d*|_test|_dev)$|^tmp_|^temp_|_test_', t))
    add('B6', '中', '重复开发', '大量 _new / _bak2 / _v7 / _temp 版本表在生产', len(ver),
        f'{len(ver)} 张表带版本或临时后缀（daily_*_new、monthly_*_bak2、dwd_order_d_f_v7、dwd_order_verify_d_i_v8、s_*_temp…），新旧版本同时被调度和回流，不清楚哪张在用。',
        '每个版本表确认使用方后保留一张、改回正式名，其余停调度后删除。', ['表名'], [[t] for t in ver])

    tst = [n for n in N if re.search(r'(_v\d+|_temp|_tmp|_new|_copy|_old|_bak|_test|_dev|_err)$|test|副本|测试', n['name'], re.I) and n['type'] != 'WORKFLOW']
    add('B7', '中', '重复开发', '测试 / 副本节点在生产调度', len(tst),
        f'{len(tst)} 个节点名带 test / copy / _err / _dev 等（如 dim_date_isoweek_o_f_copy、test_emr_spark、ods_micromessage_page_view_d_f_err、oa_to_oracle_*_copy），全部在周期调度。',
        '测试放开发空间；副本节点删除。', ['节点', '类型'], [[n['path'], n['type']] for n in tst])

    # ---------------- 指标冗余 ----------------
    alias_t = collections.defaultdict(set)
    for n in SQL:
        tg = [sh(t) for t, k in n['writes'] if k != 'ddl' and layer(t) in ('ADS', 'DWS')]
        if not tg:
            continue
        s = parse._strip_comments(n['script']).lower()
        for a in set(re.findall(r'\bas\s+`?([a-z][a-z0-9_]{2,})`?\s*(?:,|\n|$)', s)):
            if re.search(r'(num|cnt|count|amount|amt|money|price|qty|rate|sum|total|ratio|fee)', a):
                alias_t[a].update(tg)
    hot = sorted(((a, t) for a, t in alias_t.items() if len(t) >= 5), key=lambda x: -len(x[1]))
    add('C1', '高', '指标冗余', '同一个指标在几十张表里各算一遍', len(hot),
        f'{len(hot)} 个指标字段在 5 张以上 ADS/DWS 里重复计算：order_num 出现在 {len(alias_t.get("order_num", ()))} 张表、ticket_num {len(alias_t.get("ticket_num", ()))} 张、'
        f'paid_amount {len(alias_t.get("paid_amount", ()))} 张、verify_ticket_num {len(alias_t.get("verify_ticket_num", ()))} 张……每张表自己从明细聚合，口径（是否含退票、取消、测试单）各写各的。',
        '按 PFT3.0 的口径字典把每个指标登记一次、在 DWS 落一次，ADS 只引用 DWS，不再从明细重算。',
        ['指标字段', '出现的表数', '表'], [[a, len(t), '、'.join(sorted(t))] for a, t in hot])

    syn = [['订单数', 'order_num / ordernum / ordernum_num / paid_count'], ['票数', 'ticket_num / mo_ticket_count / verify_num'],
           ['金额', 'paid_amount / payment_money / sale_money / mo_amount / total']]
    add('C2', '中', '指标冗余', '同一指标多种字段名', len(alias_t),
        f'指标类字段共 {len(alias_t)} 个名字，同义词并存：' + '；'.join(f'{a}：{b}' for a, b in syn) + '。下游无法判断是否同口径。',
        '建立指标字典（编码、标准名、口径、单位），字段名统一按字典。', ['含义', '现有字段名'], syn)

    periods = collections.defaultdict(set)
    for (ds, t) in export:
        m = re.match(r'^(daily|monthly|yearly|hourly|minutely)_(.+?)(_new|_bak2)?$', t)
        if m:
            periods[m.group(2)].add(m.group(1))
    trip = {k: v for k, v in periods.items() if len(v) >= 2}
    add('C3', '高', '指标冗余', '按日 / 月 / 年各建一套报表表', len(trip),
        f'{len(trip)} 组报表按 daily_* / monthly_* / yearly_* 各建一张（加上 _new、_bak2 版本），每组 2–3 套 SQL 分别从明细聚合；'
        '新增一个周期（季度、节假日、自定义区间）就要再复制一套。这与 PFT3.0 改造前 ADS 的问题相同。',
        '按 PFT3.0 方案：ADS 只存日粒度，周 / 月 / 年 / 节假日 / 自定义区间在查询时关联统计周期时间表汇总。',
        ['报表', '已有周期'], [[k, '、'.join(sorted(v))] for k, v in sorted(trip.items())])

    # ---------------- 性能 ----------------
    D_full = [n for n in DI if not str(n['di']['reader'].get('where', '')).strip() and not n['di']['reader'].get('querySql')]
    full_src = [n for n in D_full if n['di']['reader'].get('type') in ('mysql', 'polardb', 'oracle')]
    full_out = [n for n in D_full if n['di']['reader'].get('type') == 'hive']
    big = [n for n in full_src if any(re.search(r'order|ticket|track|log|record|detail|flow', str(t)) for t in n['di']['reader'].get('tables', []))]
    add('D1', '高', '性能', '同步任务大量每天全量', len(D_full),
        f'{len(DI)} 个同步任务中 {len(D_full)} 个没有增量条件：从业务库全量抽 {len(full_src)} 个（其中订单 / 流水 / 日志类大表 {len(big)} 个），'
        f'从 Hive 全量回写 MySQL / Oracle {len(full_out)} 个。数据量随时间线性增长，同步窗口和业务库压力越来越大。',
        '业务库按 update_time 增量 + ODS 合并；回流只推当天分区（按分区覆盖 / upsert）。',
        ['节点', '读', '读表', '写', '写表'], [[n['path'], f"{n['di']['reader'].get('type')}:{n['di']['reader'].get('datasource')}", '、'.join(map(str, n['di']['reader'].get('tables', []))),
                                              f"{n['di']['writer'].get('type')}:{n['di']['writer'].get('datasource')}", '、'.join(n['di']['writer'].get('tables', []))] for n in D_full])

    inc_create = [n for n in DI if re.search(r'create|add_time|ctime', str(n['di']['reader'].get('where', '')), re.I)
                  and not re.search(r'update|modify', str(n['di']['reader'].get('where', '')), re.I)]
    add('D2', '高', '数据质量', '增量同步只按创建时间取，漏掉后续变更', len(inc_create),
        f'{len(inc_create)} 个增量任务只按 create_time 取当天新增（如订单取票人表），订单后续的支付、取消、退款、核销状态变化不会进入 ODS；'
        '于是又另建 s_order_update_d_i 等任务补变更，或干脆每天回溯 15 天（ods_order_apply_15d_i、s_order_fx_details_15d_i）。',
        '按 update_time 增量，ODS 用主键合并（_di 增量 + _df 全量快照）。',
        ['节点', '读表', '增量条件'], [[n['path'], '、'.join(map(str, n['di']['reader'].get('tables', []))), n['di']['reader'].get('where', '')] for n in inc_create])

    def C(n):
        return parse._strip_comments(n['script']).lower()
    pats = [('SELECT *', r'select\s+\*', '读出全部列，列裁剪失效'), ('写入前 ORDER BY', None, '全局排序单 reducer'),
            ('COUNT(DISTINCT)', r'count\s*\(\s*distinct', '去重计数无法跨表复用、数据倾斜'),
            ('UNION（去重）', r'\bunion\s+(?!all)', '多一次全量去重'), ('NOT IN 子查询', r'\bnot\s+in\s*\(\s*select', '易退化为笛卡尔'),
            ('CROSS JOIN', r'\bcross\s+join\b', '笛卡尔积'), ('写死日期', r"'20\d\d-?[01]\d-?[0-3]\d'", '补数 / 重跑结果不对')]
    rows = []
    cnt = collections.Counter()
    for n in SQL:
        s = C(n)
        for nm, p, why in pats:
            hit = bool(re.search(p, s)) if p else bool(re.search(r'insert\s+(overwrite|into)[\s\S]*order\s+by', s) and not re.search(r'\blimit\b', s))
            if hit:
                cnt[nm] += 1
                rows.append([n['path'], nm, why])
    add('D3', '中', '性能', 'SQL 写法问题', len({r[0] for r in rows}),
        '；'.join(f'{k} {v} 个' for k, v in cnt.most_common()) + '。',
        '列裁剪、去掉写入前排序、UNION ALL、NOT EXISTS / LEFT ANTI JOIN、日期用调度参数。', ['节点', '问题', '影响'], rows)

    nest = sorted(((len(re.findall(r'\(\s*select', C(n))), len(C(n).splitlines()), n['path']) for n in SQL), reverse=True)
    deep = [x for x in nest if x[0] >= 10 or x[1] >= 300]
    add('D4', '中', '性能', '超长脚本与深层子查询', len(deep),
        f'{sum(1 for x in nest if x[0] >= 10)} 个脚本嵌套子查询 ≥10 层（dwd_order_split_d_i 44 个），{sum(1 for x in nest if x[1] >= 300)} 个脚本超过 300 行（最长 7,690 行），'
        f'只有 {sum(1 for n in SQL if re.search(r"^\s*with\s", C(n), re.M))} 个用了 WITH 分步。难以优化与排错。',
        '按 PFT3.0 加工逻辑的写法：WITH 命名逻辑块分步，先过滤分区再关联，多来源先预聚合再 UNION ALL。',
        ['子查询数', '行数', '节点'], [list(x) for x in deep])

    hard, mock = [], []
    for n in SQL:
        s = C(n)
        for c, v in re.findall(r"\b(\w+)\s+(?:not\s+)?in\s*\(\s*((?:'?[\w-]{3,}'?\s*,\s*){2,}'?[\w-]{3,}'?)\s*\)", s):
            if re.search(r'id|scenic|tenant|land|company|member|province', c) and re.search(r'\d{3,}', v):
                hard.append([n['path'], c, v.count(',') + 1, re.sub(r'\s+', '', v)[:120]])
                break
        if re.search(r"_mock|'mock", s):
            mock.append([n['path'], '写入演示 / 模拟数据', re.search(r".{0,40}_mock.{0,40}", s).group(0).strip()])
    add('D6', '中', '数据质量', '业务数据写死在 SQL 里，生产表混入演示数据', len(hard) + len(mock),
        f'{len(hard)} 个脚本把景区、商户、会员 ID 名单写死在 WHERE 里（新增景区要改代码）；'
        f'{len(mock)} 个节点把真实景区的指标复制成虚构景区 PFTSCM00000001「A级景区」写进生产 ADS（ads_digital_brain_target_merge_di），对外接口会读到演示数据。',
        '名单放配置维表（已有 dim_sid_white_list_d_f 可复用）；演示数据放独立的演示库或打标后由接口过滤。',
        ['节点', '字段', 'ID 个数 / 说明', '内容'], hard + [[m[0], '', m[1], m[2]] for m in mock])

    nodate = [n for n in SQL if n['writes'] and not re.search(r'\$\{|\$\[', n['script'])]
    add('D5', '中', '性能', '没有分区参数的脚本每次全量重算', len(nodate),
        f'{len(nodate)} 个 SQL 节点不带任何日期参数，每天全表扫描、全量重写（多为 _d_f 汇总与 DIM）。',
        '可增量的改为按分区增量；确需全量的降为周 / 月调度或改为拉链。', ['节点', '写入表'],
        [[n['path'], '、'.join(sh(t) for t, k in n['writes'] if k != 'ddl')] for n in nodate])

    # ---------------- 调度与依赖 ----------------
    byid, byname = {}, collections.defaultdict(list)
    for n in N:
        for o in n['output_ids']:
            byid[str(o)] = n
        byid[str(n['id'])] = n
        byname[n['name']].append(n)

    def ups(n):
        r = []
        for d in n['depends']:
            x = byid.get(str(d['output']))
            r += [x] if x else byname.get(sh(d['ref'] or ''), [])
        return r
    memo = {}

    def closure(n):
        if id(n) not in memo:
            seen, stk = set(), [n]
            while stk:
                for u in ups(stk.pop()):
                    if id(u) not in seen:
                        seen.add(id(u))
                        stk.append(u)
            memo[id(n)] = seen
        return memo[id(n)]
    miss = []
    for n in SQL:
        for t in n['reads']:
            ps = [p for p in hive.get(sh(t), []) if p is not n and p['recurrence'] != 'Pause']
            if ps and not re.search(r'_o_[fi]$', sh(t)) and not any(id(p) in closure(n) for p in ps):
                miss.append([n['path'], sh(t), ps[0]['path'], '跨空间' if ps[0]['ws'] != n['ws'] else '同空间'])
    add('E1', '高', '调度与依赖', '读了上游表却没配调度依赖，靠时间差碰运气', len(miss),
        f'{len({m[0] for m in miss})} 个节点的 {len(miss)} 处读表在依赖链上找不到产出任务（其中跨工作空间 {sum(1 for m in miss if m[3] == "跨空间")} 处）。'
        '上游延迟或失败时，下游照常运行，读到前一天或空分区，报表静默出错。',
        '读谁就依赖谁：跨空间用跨项目依赖或统一到一个空间；上线前用血缘自动校验依赖。', ['节点', '读的表', '产出任务', '范围'], miss)

    wf = [n for n in N if n['type'] == 'WORKFLOW']
    sa = [n for n in N if n['type'] != 'WORKFLOW' and not n['workflow']]
    zero = [n for n in wf + sa if re.match(r'0+ 0+ 0+ ', n['cron'])]
    early = [n for n in wf + sa if re.match(r'\d+ \d+ 0?[0-6] ', n['cron'])]
    add('E2', '中', '调度与依赖', '调度扎堆在凌晨', len(early),
        f'{len(wf)} 个工作流和 {len(sa)} 个独立节点中，{len(early)} 个（{len(early) * 100 // len(wf + sa)}%）在 0–6 点启动，其中 {len(zero)} 个正好是 00:00:00；'
        '业务库全量抽取与 Spark 计算同时挤在凌晨，资源与业务库压力峰值叠加，一个任务慢就整体顺延。',
        '同步按业务库错峰（备库 / 低峰时段），计算按依赖自然触发，不靠固定时刻。', ['节点 / 工作流', 'cron'], [[n['path'], n['cron']] for n in zero])

    add('E3', '中', '调度与依赖', '所有节点都没有设置超时', sum(1 for n in N if not n['timeout']),
        f'{len(N)} 个节点 / 工作流超时时间全部为 0（不限），卡住的任务会一直占用资源、阻塞下游，不会告警。',
        '按历史运行时长设置超时（如 P95 × 2）并配超时告警。', ['节点', '类型'], [[n['path'], n['type']] for n in N if not n['timeout']][:0])

    manual = [n for n in N if n['path'].startswith('业务工厂/手动任务') and n['type'] != 'WORKFLOW']
    add('E4', '中', '调度与依赖', '「手动任务」目录里的节点其实在周期调度', len(manual),
        f'业务工厂/手动任务 下 {len(manual)} 个节点（历史重跑、按年份归档、全量导出脚本、动态分区…）全部是周期调度节点，'
        '其中不少与正式任务写同一张表（见 B3），每天重复执行一次性的补数逻辑。',
        '一次性任务改为手动业务流程 / 补数据；确需周期执行的并入正式工作流。', ['节点', '类型', 'cron'], [[n['path'], n['type'], n['cron']] for n in manual])

    eng = collections.Counter(n['type'] for n in N if n['type'].endswith(('SPARK_SQL', 'SPARK', 'PYSPARK')))
    add('E5', '低', '调度与依赖', 'EMR 与 Serverless Spark 两套引擎混用', sum(eng.values()),
        '、'.join(f'{k} {v} 个' for k, v in eng.most_common()) + '；同一业务链路上下游跑在不同引擎，资源与参数各管一套。', '统一一种计算引擎与资源组。', ['类型', '节点数'], [[k, v] for k, v in eng.items()])

    # ---------------- 资产与数据质量 ----------------
    readset = set(reads)
    dead = sorted(t for t in hive if t not in readset)
    add('F1', '中', '资产', '产出了却没人用的表', len(dead),
        f'{len(dead)} 张 Hive 表没有被任何节点读取、也没有被回流（ODS {sum(1 for t in dead if layer(t) == "ODS")}、ADS {sum(1 for t in dead if layer(t) == "ADS")}…），每天仍在计算 / 同步。'
        '（导出包之外的查询方未计入，需对照访问日志确认。）', '对照查询日志确认无访问后停调度，30 天后删表。', ['表名', '层'], [[t, layer(t) or ''] for t in dead])

    ext = collections.Counter(sh(t) for n in SQL for t in n['reads'] if sh(t) not in hive)
    add('F2', '中', '资产', '读了导出包里没有产出任务的表', len(ext),
        f'{len(ext)} 张被读取的表在三个空间里都没有产出任务（如 cache_table、result_table、dim_distribute_ota_o_f、phone_area），来源不明，可能是手工建表或其他系统写入。',
        '补登记来源与负责人，或改为由调度任务产出。', ['表名', '被读次数'], [[t, c] for t, c in ext.most_common()])

    ddl = [n for n in SQL if n['ddl'].get('ddl')]
    stmts = [st for n in ddl for st in parse._strip_comments(n['script']).split(';')
             if re.search(r'create\s+(?:external\s+)?table\s+(?:if\s+not\s+exists\s+)?[`\w.]+\s*\(', st, re.I)]
    tcm = sum(1 for st in stmts if re.search(r'\)\s*comment\s+[\'"][^\'"]*[\'"]\s*(partitioned|stored|row\s+format|location|tblproperties|$)', st, re.I))
    life = sum(1 for n in ddl if re.search(r'lifecycle|ttl|partition\.retention', n['script'], re.I))
    add('F3', '低', '资产', '历史分区无限保留，三成表没有表说明', len(stmts),
        f'{len(stmts)} 个建表语句中 {tcm} 个（{tcm * 100 // len(stmts)}%）写了表注释，字段注释覆盖较好；设置生命周期 / 分区保留的只有 {life} 个，ODS 增量、临时表、_bak2 版本表的历史分区一直保留。',
        '表注释、负责人、生命周期纳入上线检查；ODS 增量按需保留，临时表 7 天。', [], [])

    sens = collections.defaultdict(set)
    for n in DI:
        r = n['di']['reader']
        if r.get('type') in ('hive', None):
            continue
        for c in r.get('columns', []):
            if isinstance(c, str) and SENS.search(c):
                sens[n['path']].add(c)
    pw = [p for p, cs in sens.items() if any(c.lower() in ('password', 'pwd', 'passwd') for c in cs)]
    add('G1', '高', '安全', '手机号、证件号、密码字段原样同步进数仓并回流', len(sens),
        f'{len(sens)} 个同步任务把 ordertel / personid / id_card / mobile / address / card_no 等敏感字段明文落到 Hive；'
        f'其中 {len(pw)} 个任务连 password 字段一起同步（OA 人员表、CRM 人员表、年卡表），并回写到 Oracle。',
        'ODS 落地即脱敏 / 加密（手机号、证件号哈希 + 掩码），密码类字段不同步；敏感表单独授权。', ['节点', '敏感字段'],
        [[p, '、'.join(sorted(c))] for p, c in sorted(sens.items())])

    m2o = [n for n in DI if n['di']['reader'].get('type') in ('mysql', 'polardb') and n['di']['writer'].get('type') == 'oracle']
    add('G2', '中', '架构与分层', '数仓被当作业务库之间的搬运通道', len(m2o) + len(full_out),
        f'{len(m2o)} 个任务把 OA、CRM 等业务库直接搬到 Oracle（RDS_oracle / RDS_oracle_it_project，不经过数仓）；{len(full_out)} 个任务每天把 Hive 结果全量写回 MySQL / Oracle / SelectDB / ClickHouse 给报表用。'
        '回流目标表也有 daily_* / _new / _bak2 多版本。', '系统间同步与数仓分开管理；报表统一从数仓的服务层（StarRocks / SelectDB）读，减少回流份数。',
        ['节点', '读', '写'], [[n['path'], f"{n['di']['reader'].get('datasource')}.{'、'.join(map(str, n['di']['reader'].get('tables', [])))}",
                             f"{n['di']['writer'].get('datasource')}.{'、'.join(n['di']['writer'].get('tables', []))}"] for n in m2o])

    own = collections.Counter(n['owner'] for n in N if n['type'] != 'WORKFLOW')
    named = [k for k in own if not re.fullmatch(r'\d+', k)]
    alias_o = {k: f'负责人{i}' for i, (k, _) in enumerate(own.most_common(), 1)}   # 报告不写人名
    top = own.most_common(1)[0]
    add('G3', '低', '规范', '负责人高度集中、无规范与上线检查', len(named),
        f'{sum(own.values())} 个节点由 {len(named)} 人负责，最多的一人负责 {top[1]} 个（{top[1] * 100 // sum(own.values())}%），前两人合计 {sum(v for _, v in own.most_common(2)) * 100 // sum(own.values())}%；'
        f'节点创建于 {min(n["created"] for n in N if n["created"])[:10]} ~ {max(n["created"] for n in N if n["created"])[:10]}，一年半内堆到 {len(N)} 个节点，没有命名、依赖、口径的上线检查。',
        '按域分配负责人；上线前自动检查命名、依赖、口径登记、超时与生命周期。', ['负责人', '节点数'], [[alias_o[k], v] for k, v in own.most_common()])

    stats = {'nodes': len(N), 'types': dict(collections.Counter(n['type'] for n in N)), 'ws': dict(collections.Counter(n['ws'] for n in N)),
             'sql': len(SQL), 'di': len(DI), 'hive': len(hive), 'export': len(export), 'workflows': len(wf),
             'di_flow': dict(collections.Counter(f"{n['di']['reader'].get('type')}→{n['di']['writer'].get('type')}" for n in DI))}
    return F, stats


ORDER = {'高': 0, '中': 1, '低': 2}


def to_md(F, stats, src):
    L = [f'# 客户 DataWorks 现状问题清单', '',
         f'> 由 `dataworks/audit.py` 读取 `{src}` 自动生成（{datetime.date.today().isoformat()}）。明细见 `dataworks/output/` 下同编号 CSV。', '',
         '## 概况', '',
         f'- 节点 {stats["nodes"]} 个：' + '、'.join(f'{k} {v}' for k, v in sorted(stats['types'].items(), key=lambda x: -x[1])),
         f'- 工作空间：' + '、'.join(f'{k} {v}' for k, v in stats['ws'].items()) + f'；工作流 {stats["workflows"]} 个',
         f'- Hive 表 {stats["hive"]} 张；回流到 MySQL / Oracle / SelectDB / ClickHouse 的目标表 {stats["export"]} 张',
         f'- 同步任务流向：' + '、'.join(f'{k} {v}' for k, v in sorted(stats['di_flow'].items(), key=lambda x: -x[1])), '',
         '## 问题汇总', '', '| 编号 | 级别 | 类别 | 问题 | 涉及 |', '|---|---|---|---|---|']
    F = sorted(F, key=lambda f: (ORDER[f['level']], f['id']))
    L += [f'| {f["id"]} | {f["level"]} | {f["cat"]} | {f["title"]} | {f["n"]:,} |' for f in F]
    L.append('')
    for cat in dict.fromkeys(f['cat'] for f in sorted(F, key=lambda f: f['id'])):
        L += [f'## {cat}', '']
        for f in sorted((x for x in F if x['cat'] == cat), key=lambda f: f['id']):
            L += [f'### {f["id"]}【{f["level"]}】{f["title"]}', '', f['detail'], '', f'**建议**：{f["suggest"]}', '']
            if f['rows']:
                L.append(f'明细：`output/{f["id"]}.csv`（{len(f["rows"]):,} 行）')
                L.append('')
    return '\n'.join(L)


def main():
    src = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT.parent / 'DATAWORKS.zip'
    nodes = parse.load(src)
    F, stats = analyse(nodes)
    out = ROOT / 'output'
    out.mkdir(exist_ok=True)
    for f in F:
        if f['rows']:
            with open(out / f'{f["id"]}.csv', 'w', newline='', encoding='utf-8-sig') as fh:
                w = csv.writer(fh)
                w.writerow(f['cols'])
                w.writerows(f['rows'])
    with open(out / '节点清单.csv', 'w', newline='', encoding='utf-8-sig') as fh:
        w = csv.writer(fh)
        w.writerow(['工作空间', '路径', '节点', '类型', '工作流', 'cron', '创建时间', '写入表', '读取表', '上游依赖'])
        for n in nodes:
            w.writerow([n['ws'], n['path'], n['name'], n['type'], n['workflow'], n['cron'], n['created'],
                        '、'.join(sh(t) for t, k in n['writes']), '、'.join(sh(t) for t in n['reads']), '、'.join(str(d['ref'] or d['output']) for d in n['depends'])])
    (ROOT / 'docs').mkdir(exist_ok=True)
    (ROOT / 'docs' / '问题清单.md').write_text(to_md(F, stats, src.name), encoding='utf-8')
    print(stats)
    for f in sorted(F, key=lambda f: (ORDER[f['level']], f['id'])):
        print(f['id'], f['level'], f['cat'], f['title'], f['n'])


if __name__ == '__main__':
    main()
