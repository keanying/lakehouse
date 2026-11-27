"""标准化数仓的加工逻辑：替代旧系统拼接在一起的脚本，按标准模型逐表给出可上线的实现。

- ODS：DataWorks 数据集成（离线同步）配置。按 update_time 增量、只同步字典里的列、敏感字段在读端脱敏、分表 / 历史库 / 数据源别名合并
- DIM / DWD：核心实体与订单域手写（etl_core.py）；其余按字段映射生成，多厂商同类表（停车 / 零售）UNION ALL 归一
- DWS：由指标口径生成。每个指标 = 来源明细 + 条件 + 聚合；同一来源的指标在一个子查询里预聚合，再 UNION ALL 合并后汇总
- ADS：日粒度，从 DWS 再汇总；去重类指标存位图，比率类存分子分母，周期 / 同比在查询时关联 dim_opr_period_f（与 PFT3.0 一致）

每段 SQL 用 sqlglot（spark 方言）解析，并校验输出列与字典字段清单一致。
"""
import collections, json, re

import model, rules, proc_model
import etl_core

P = "travel_date = '${bizdate}'"
NOW = "DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time"
BIZ_DAY = "TO_DATE('${bizdate}', 'yyyyMMdd')"


# ============================================================================ 公共
def fields_of(fields):
    F = collections.defaultdict(list)
    for f in fields:
        F[f[1].split('.', 1)[1]].append({'n': f[4], 'ty': f[5], 'cat': f[6], 'cm': str(f[7] or ''), 'proc': str(f[8] or '')})
    return F


def default_of(ty):
    ty = (ty or 'STRING').upper()
    if ty.startswith(('BIGINT', 'INT', 'TINYINT', 'SMALLINT')):
        return f'CAST(-1 AS {ty})'
    if ty.startswith('DECIMAL'):
        return f'CAST(0 AS {ty})'
    if ty == 'BITMAP':
        return 'CAST(NULL AS BINARY)'
    return 'CAST(NULL AS STRING)'


def null_of(ty):
    ty = (ty or 'STRING').upper()
    return 'CAST(NULL AS BINARY)' if ty == 'BITMAP' else f'CAST(NULL AS {ty})'


def col(expr, alias, note=''):
    """一行 SELECT 项：表达式对齐，行尾注释"""
    s = f'    {expr}'
    s = (s if expr.strip() == alias or expr.endswith('.' + alias) else f'{s:<64} AS {alias}')
    return s + (f'   -- {note}' if note else '')


def join_cols(lines):
    """逗号放在注释前"""
    out = []
    for i, l in enumerate(lines):
        last = i == len(lines) - 1
        if '   -- ' in l:
            a, b = l.split('   -- ', 1)
            out.append(a + ('' if last else ',') + '   -- ' + b)
        else:
            out.append(l + ('' if last else ','))
    return '\n'.join(out)


def header(tb, replaced, why, perf, sched, extra=(), perf_label='性能'):
    full = f"{tb['layer'].lower()}.{tb['name']}"
    L = ['-- ' + '=' * 96, f"-- {full}  {tb['cn']}", f"-- 粒度：{tb['grain']}", f"-- 分区：{tb['part']}", f"-- 调度：{sched}"]
    if tb.get('up'):
        L.append(f"-- 上游：{tb['up']}")
    if replaced:
        L.append(f'-- 替代旧任务 {len(replaced)} 个（上线对数一致后下线）：')
        for n in replaced[:12]:
            L.append(f"--   · {n['path']}（{n['type']}，cron {n['cron']}）")
        if len(replaced) > 12:
            L.append(f'--   · … 另 {len(replaced) - 12} 个')
    if why:
        L.append('-- 业务规则 / 修正：')
        L += [f'--   · {x}' for x in why]
    if perf:
        L.append(f'-- {perf_label}：')
        L += [f'--   · {x}' for x in perf]
    L += [f'-- {x}' for x in extra]
    L.append('-- ' + '=' * 96)
    return '\n'.join(L) + '\n'


SCHED = {'ODS': '每日 00:30 起（业务库低峰），T+1；bizdate = 业务日期 yyyyMMdd',
         'DIM': '每日，ODS 全部完成后；维表之间按上游顺序', 'DWD': '每日，依赖上游 ODS 当日分区与相关维表',
         'DWS': '每日，依赖上游 DWD 当日分区', 'ADS': '每日，依赖上游 DWS 当日分区；完成后回流 / 服务层读取'}


# ============================================================================ ODS：数据集成配置
UPD = ['update_time', 'updatetime', 'update_at', 'updated_at', 'modify_time', 'modifytime', 'gmt_modified', 'last_update_time', 'uptime', 'sync_update_time', 'modify_date']
CRT = ['create_time', 'createtime', 'created_at', 'create_at', 'addtime', 'add_time', 'insert_time', 'inserttime', 'ordertime', 'rectime', 'create_date', 'sync_create_time']
PHONE = re.compile(r'(phone|mobile|(?<!ho)tel)$', re.I)
IDCARD = re.compile(r'(id_card|idcard|personid|id_number|certificate_no)', re.I)


def mask_expr(c, ty, dom, dialect):
    """读端脱敏表达式（业务库方言）。格式保留前缀，后半段 SHA256，DWD 再拆出哈希 / 前缀"""
    q = f'`{c}`' if dialect != 'oracle' else c
    sha = (lambda x: f'SHA2({x}, 256)') if dialect != 'oracle' else (lambda x: f"LOWER(RAWTOHEX(STANDARD_HASH({x}, 'SHA256')))")
    cat = (lambda *a: f"CONCAT({', '.join(a)})") if dialect != 'oracle' else (lambda *a: ' || '.join(a))
    left = (lambda x, n: f'LEFT({x}, {n})') if dialect != 'oracle' else (lambda x, n: f'SUBSTR({x}, 1, {n})')
    if PHONE.search(c):
        return cat(left(q, 7), "'#'", sha(q)), '手机号：保留前 7 位号段（归属地），其余 SHA256'
    if IDCARD.search(c):
        ln = 'CHAR_LENGTH' if dialect != 'oracle' else 'LENGTH'
        return (f"CASE WHEN {ln}({q}) = 18 THEN {cat(left(q, 6), f'SUBSTR({q}, 7, 4)', f'SUBSTR({q}, 17, 1)', repr('#'), sha(f'UPPER({q})'))} "
                f"ELSE {cat(repr('#'), sha(f'UPPER({q})'))} END"), '证件号：保留地区 6 位 + 出生年 4 位 + 性别位，其余 SHA256'
    if re.search(r'address', c, re.I):
        if dom in ('ord', 'cus'):
            return cat(left(q, 6), "'****'"), '个人地址：只留前 6 个字'
        return None, ''
    if re.search(r'email', c, re.I):
        return cat(left(q, 2), "'***@'", f"SUBSTRING_INDEX({q}, '@', -1)"), '邮箱：保留首 2 位与域名'
    if rules.SENSITIVE.search(c):
        return cat("'#'", sha(q)), '卡号 / 证件类：SHA256（仍可作关联键）'
    return None, ''


def _time_where(colname, ty, legacy_where, dialect):
    unix = (ty or '').upper().startswith(('BIGINT', 'INT')) or 'UNIX_TIMESTAMP' in (legacy_where or '').upper()
    if dialect == 'oracle':
        a, b = "TO_DATE('${bizdate}', 'YYYYMMDD')", "TO_DATE('${bizdate}', 'YYYYMMDD') + 1"
        return f'{colname} >= {a} AND {colname} < {b}'
    a = "STR_TO_DATE('${bizdate}', '%Y%m%d')"
    b = "DATE_ADD(STR_TO_DATE('${bizdate}', '%Y%m%d'), INTERVAL 1 DAY)"
    if unix:
        return f'`{colname}` >= UNIX_TIMESTAMP({a}) AND `{colname}` < UNIX_TIMESTAMP({b})'
    return f'`{colname}` >= {a} AND `{colname}` < {b}'


def ods_di(tb, fl, group, writers):
    """一张 ODS 的 DataWorks 离线同步配置（脚本模式 JSON）+ 说明"""
    (lds, ltb) = tb['lsrc']
    dom = tb['dom']
    names = [f['n'] for f in fl if f['cat'] not in ('分区',)]
    types = {f['n']: f['ty'] for f in fl}
    srcs = [(ds, t, s) for (ds, t), s in group]
    typ = (srcs[0][2].get('type') or 'mysql').lower()
    dialect = 'oracle' if typ == 'oracle' else 'mysql'
    # 物理源分类：主表 / 历史库（只初始化）/ 同库分表 / 别名数据源
    hist = [x for x in srcs if re.search(r'history|_bak|backup|archive', x[0] + '.' + x[1], re.I) or re.search(r'_(19|20)\d{2,4}$', x[1])]
    live = [x for x in srcs if x not in hist]
    main_ds = max({x[0] for x in live} or {lds}, key=lambda d: (d == lds, sum(len(s['cols']) for ds, _, s in live if ds == d)))
    shards = sorted({x[1] for x in live if x[0] == main_ds})
    alias = sorted({x[0] for x in live if x[0] != main_ds})
    # 读端列：字典字段（原名） + 脱敏
    src_cols = {c.lower(): c for ds, t, s in srcs for c in s['cols'] if isinstance(c, str)}
    rcols, wcols, masks = [], [], []
    for n in names:
        c = src_cols.get(n, n)
        e, why = mask_expr(c, types.get(n), dom, dialect)
        rcols.append(e or c)
        wcols.append(n)
        if e:
            masks.append(f'{n}：{why}')
    # 增量条件
    inc = tb['name'].endswith('_di')
    legacy_where = next((w for _, _, s in srcs for w in sorted(s['where']) if w), '')
    tcol = next((c for c in UPD if c in names), None) if inc else None
    tnote = ''
    if inc and not tcol:
        tcol = next((c for c in CRT if c in names), None)
        tnote = '源表没有更新时间列，按创建时间增量（只追加的流水表）'
    where = _time_where(src_cols.get(tcol, tcol), types.get(tcol), legacy_where, dialect) if tcol else (legacy_where if inc else '')
    if inc and not tcol:
        tnote = '源表没有时间列：沿用旧增量条件'
    reader = {'stepType': {'polardb': 'polardb', 'oracle': 'oracle', 'selectdb': 'doris'}.get(typ, 'mysql'), 'category': 'reader', 'name': 'Reader',
              'parameter': {'datasource': main_ds, 'column': rcols, 'connection': [{'datasource': main_ds, 'table': shards or [ltb]}],
                            'where': where, 'splitPk': 'id' if 'id' in names else '', 'encoding': 'UTF-8'}}
    wds = next((str(w['di']['writer'].get('datasource')) for w in writers if w['type'] == 'DI' and w.get('di') and w['di'].get('writer')), 'BI_hive')
    writer = {'stepType': 'hive', 'category': 'writer', 'name': 'Writer',
              'parameter': {'datasource': wds, 'table': f"ods.{tb['name']}", 'partition': 'travel_date=${bizdate}', 'writeMode': 'truncate',
                            'column': wcols, 'fileType': 'orc', 'compress': 'SNAPPY'}}
    big = tb['name'] in ('ods_ord_order_di', 'ods_ord_order_track_di', 'ods_ord_order_traveler_di', 'ods_ord_order_traveler_track_di', 'ods_fin_trade_journal_di')
    job = {'type': 'job', 'version': '2.0', 'steps': [reader, writer], 'order': {'hops': [{'from': 'Reader', 'to': 'Writer'}]},
           'setting': {'errorLimit': {'record': '0'}, 'speed': {'throttle': False, 'concurrent': 8 if big else 2}}}
    notes = []
    old_w = sorted({w for w in (n['di']['reader'].get('where') if n['type'] == 'DI' and n.get('di') else '' for n in writers) if w})
    if inc:
        notes.append(f"增量：{'按 ' + tcol + ' 取 bizdate 当天新增 / 变更' if tcol else '沿用旧条件'}" + (f'（{tnote}）' if tnote else ''))
        if old_w and tcol and not any(tcol in w for w in old_w):
            notes.append(f'旧条件：{old_w[0][:120]} —— 只取当天新建记录，之后的状态变化漏采，已改为按 {tcol}')
    else:
        notes.append('全量：维度 / 配置类小表每日全量快照（truncate 当日分区，可重跑）')
    if len(shards) > 1:
        notes.append(f'同库分表 {len(shards)} 张：一个同步任务多表读取（connection.table），不再一张分表一个任务')
    if alias:
        notes.append(f"别名数据源 {'、'.join(alias)} 指向同一业务表：只保留 {main_ds}，其余同步任务下线")
    if hist:
        notes.append(f"历史库 / 归档 {len(hist)} 个（{'、'.join(f'{a}.{b}' for a, b, _ in hist[:4])}{' …' if len(hist) > 4 else ''}）：只在首次初始化时一次性补数，日任务不再读")
    if masks:
        notes.append('读端脱敏（明文不落数仓）：' + '；'.join(masks))
    drop = [c for ds, t, s in srcs for c in s['cols'] if isinstance(c, str) and rules.DROP.match(c)]
    if drop:
        notes.append('不同步：' + '、'.join(sorted(set(drop))) + '（密码类）')
    old_cols = max((len(n['di']['reader'].get('columns') or []) for n in writers if n['type'] == 'DI' and n.get('di')), default=0)
    if old_cols > len(names):
        notes.append(f'列裁剪：旧任务读 {old_cols} 列，标准只同步字典里的 {len(names)} 列')
    notes.append('写入：truncate 当日分区（幂等，可重跑）；ORC + SNAPPY；脏数据 0 容忍（errorLimit=0），有脏数据直接失败告警')
    body = json.dumps(job, ensure_ascii=False, indent=2)
    return body, notes


# ============================================================================ DIM / DWD：字段映射生成（非手写表）
VENDOR_PARK = {'daoer5': ('in_time', 'out_time', 'parking_no', 'pay_charge'), 'daoer': ('entry_time', 'exit_time', 'entry_name', 'pay_charge'),
               'ketuo': ('cap_time', 'cap_time', 'cap_place', None), 'shuaichen': ('enter_time', 'exit_time', 'park_code', 'paid_amount'),
               'zhihui': ('enter_time', 'out_time', 'park_key', 'total_amount')}


def _park_branches():
    out = []
    for v, (tin, tout, lot, fee) in VENDOR_PARK.items():
        for kind in ('entry', 'exit'):
            car = 'plate_no' if v == 'ketuo' else 'plate_num' if v == 'shuaichen' else 'car_no'
            m = {'parking_vendor': f"'{v}'", 'parking_lot_code': f'CAST({lot} AS STRING)', 'car_no': car,
                 'inout_type': "'IN'" if kind == 'entry' else "'OUT'", 'inout_time': tin if kind == 'entry' else tout,
                 'fee_amt': ('CAST(0 AS DECIMAL(18,2))' if kind == 'entry' or not fee else f'CAST({fee} AS DECIMAL(18,2)) / 100')}
            if kind == 'exit':
                m['in_time'] = tin
            out.append((f'ods_opr_parking_{v}_{kind}_record_di', m))
    return out


# 多来源 / 新增核心字段的映射：表 -> {'branches': [(ODS 表, {字段: 表达式})], 'note': 说明, 'where': 额外过滤}
CORE = {
    'dwd_opr_parking_record_di': {'branches': _park_branches(),
                                  'note': ['5 个停车厂商 × 入场 / 出场 10 张表 UNION ALL 归一：厂商、车场、进出类型、时间、金额统一口径（旧系统 10 个独立汇总任务）',
                                           '待确认：ketuo 出场表没有收费金额；金额单位按分（/100）与厂商接口核对']},
    'dwd_opr_retail_order_di': {'branches': [
        ('ods_opr_retail_sixun_order_di', {'retail_vendor': "'sixun'", 'shop_code': 'shop_code', 'order_no': 'order_no', 'sale_amt': 'CAST(payment_money AS DECIMAL(18,2))',
                                           'refund_flag': "IF(status = '2', 1, 0)", 'item_qty': 'CAST(NULL AS BIGINT)', 'pay_amt': 'payment_money', 'settlement_amt': 'settlement_money'}),
        ('ods_opr_retail_yinbao_ticket_di', {'retail_vendor': "'yinbao'", 'shop_code': 'CAST(app_id AS STRING)', 'order_no': 'sn', 'sale_amt': 'CAST(total_amount AS DECIMAL(18,2))',
                                             'refund_flag': "IF(ticket_type = 'SELL_RETURN', 1, 0)", 'create_time': 'date_time'}),
        ('ods_opr_retail_xisland_order_di', {'retail_vendor': "'xisland'", 'shop_code': 'store_name', 'order_no': 'order_code', 'sale_amt': 'CAST(pay_amount AS DECIMAL(18,2))',
                                             'refund_flag': 'IF(CAST(return_amount AS DECIMAL(18,2)) > 0, 1, 0)', 'pay_amt': 'pay_amount', 'create_time': 'order_create_time'})],
        'note': ['银豹 / 思迅 / 小岛 3 套零售系统 UNION ALL 归一（旧系统每套一条独立链路）', '待确认：退货标识各系统码值（思迅 status=2、银豹 SELL_RETURN）上线前与厂商确认；商品明细在 *_item 表，件数待接入']},
    'dwd_trf_scenic_inout_di': {'branches': [
        ('ods_trf_device_inout_journal_di', {'scenic_id': 'CAST(land_id AS BIGINT)', 'supplier_id': 'CAST(sid AS BIGINT)', 'terminal_no': 'CAST(device_key AS STRING)',
                                             'inout_type': "CASE roll_type WHEN '1' THEN 'IN' WHEN '2' THEN 'OUT' ELSE 'OTHER' END", 'inout_time': 'create_time',
                                             'person_qty': 'CAST(num AS BIGINT)', 'device_key': 'device_key', 'roll': 'roll_type', 'num': 'num'})],
        'note': ['闸机进出流水；待确认：roll_type 1=进 2=出（旧 dim_input_group_gate_d_f 未写码值）']},
    'dwd_fin_trade_journal_di': {'branches': [
        ('ods_fin_trade_journal_di', {'journal_id': 'CAST(id AS BIGINT)', 'account_id': 'CAST(account_id AS BIGINT)', 'subject_code': 'CAST(subject_code AS STRING)',
                                      'trade_amt': 'CAST(IF(daction = 0, dmoney, -dmoney) AS DECIMAL(18,2)) / 100', 'balance_amt': 'CAST(lmoney AS DECIMAL(18,2)) / 100',
                                      'trade_time': 'rectime', 'oper_month': 'recmonth'})],
        'note': ['收支方向带符号：daction=0 收入为正，1 支出为负（旧财务平衡脚本 IF(daction=0, dmoney, 0) 规则）；金额分 → 元']},
    'dwd_sup_member_login_di': {'branches': [
        ('ods_sup_member_login_log_di', {'member_id': 'CAST(mid AS BIGINT)', 'login_time': 'login_time', 'stat_date': "'${bizdate}'", 'user_id': 'CAST(mid AS BIGINT)', 'login_source': 'login_source'})],
        'note': ['只保留登录事实；IP / 浏览器 / 系统不进 DWD']},
    'dwd_ord_annual_card_trade_di': {'branches': [
        ('ods_ord_annual_card_trade_di', {'trade_no': 'CAST(id AS STRING)', 'card_no': "CONCAT('#', SUBSTRING_INDEX(card_no, '#', -1))", 'card_product_id': 'CAST(pid AS BIGINT)',
                                          'trade_type': "CASE CAST(type AS STRING) WHEN '0' THEN 'SELL' WHEN '1' THEN 'RENEW' WHEN '2' THEN 'ACTIVE' ELSE CAST(type AS STRING) END",
                                          'trade_amt': 'CAST(pay_money AS DECIMAL(18,2)) / 100', 'trade_time': 'add_time', 'ticket_id': 'CAST(ticket_id AS BIGINT)',
                                          'memberid': 'member_id', 'supplier_id': 'CAST(sid AS BIGINT)', 'order_no': 'ordernum', 'num': 'num', 'card_no_mask': 'card_no'})],
        'note': ['年卡交易为主表；待确认：type 码值（0 售卡 / 1 续费 / 2 激活）上线前与年卡业务库核对']},
    'dwd_sup_contract_event_di': {'branches': [
        ('ods_sup_contract_df', {'contract_no': 'contract_no', 'event_type': "'SIGN'", 'event_time': 'sign_date', 'event_amt': 'CAST(contrcat_amount AS DECIMAL(18,2))', 'amount_type': "'合同'"}),
        ('ods_opr_oa_form_111_df', {'contract_no': 'htbh', 'event_type': "'INVOICE'", 'event_time': 'kprq', 'event_amt': 'CAST(kpje AS DECIMAL(18,2))', 'amount_type': "'开票'",
                                    'bill_date': 'kprq', 'bill_amt': 'CAST(kpje AS DECIMAL(18,2))'}),
        ('ods_opr_oa_form_265_df', {'contract_no': 'htbh', 'event_type': "'PAYBACK'", 'event_time': 'hkrq', 'event_amt': 'CAST(hkje AS DECIMAL(18,2))', 'amount_type': 'hklx'})],
        'event_date': {'ods_sup_contract_df': 'sign_date', 'ods_opr_oa_form_111_df': 'kprq', 'ods_opr_oa_form_265_df': 'hkrq'},
        'note': ['合同签订 / 开票 / 回款三类事件 UNION ALL：合同台账 + OA 开票申请（表单 111）+ OA 回款登记（表单 265）', '源为全量快照，按事件日期 = bizdate 取当日事件']},
    'dwd_opr_module_open_di': {'branches': [
        ('ods_opr_module_used_df', {'module_id': 'CAST(module_id AS BIGINT)', 'member_id': 'CAST(member_id AS BIGINT)', 'open_time': 'begin_time', 'expire_time': 'expire_time',
                                    'stat_date': "'${bizdate}'", 'user_id': 'CAST(member_id AS BIGINT)', 'valid_start_time': 'begin_time', 'valid_end_time': 'expire_time',
                                    'module_status': 'status', 'add_time': 'create_time'})],
        'event_date': {'ods_opr_module_used_df': 'create_time'},
        'note': ['模块开通记录（module_used 全量快照，按开通创建日 = bizdate 取当日事件）；合同 / 销售信息在 module_used_ext，待按 member_id + module_id 补关联']},
    'dwd_trf_page_view_di': {'branches': [
        ('ods_prd_resource_search_history_df', {'user_id': 'CAST(member_id AS BIGINT)', 'page_code': "CONCAT('resource_search_', COALESCE(search_type, '0'))", 'visit_time': 'add_time',
                                                'distinct_id': 'CAST(member_id AS STRING)', 'user_account': 'CAST(NULL AS STRING)', 'click_date': 'SUBSTR(add_time, 1, 10)', 'pv_qty': 'CAST(1 AS BIGINT)'})],
        'event_date': {'ods_prd_resource_search_history_df': 'add_time'},
        'note': ['资源中心搜索行为作为页面访问；待确认：微商城埋点（旧 dwd_user_resource_center_pv_d_f 来自埋点日志）未在导出包，接入后作为第二个分支 UNION ALL']},
    'dwd_prd_resource_order_di': {'branches': [
        ('dwd_ord_order_di', {'order_no': 'order_no', 'resource_id': 'resource_id', 'supplier_id': 'rc_supplier_id', 'purchase_member_id': 'rc_purchase_id', 'stat_date': "'${bizdate}'",
                              'remote_order_no': 'remote_order_no', 'order_status': 'order_status', 'ticket_qty': 'ticket_qty', 'order_time': 'order_time',
                              'vertify_time': 'first_verify_time', 'resource_center_supplier_id': 'rc_supplier_id', 'resource_center_purchase_id': 'rc_purchase_id',
                              'scenic_id': 'scenic_id', 'ticket_id': 'ticket_id', 'booking_channel': 'CAST(order_mode AS STRING)', 'booking_price': 'ticket_price_amt',
                              'booking_qty': 'origin_ticket_qty', 'booking_pay_amt': 'CAST(origin_ticket_qty * sale_price_amt AS DECIMAL(18,2))', 'order_pay_amt': 'pay_amt',
                              'distributor_id': 'distributor_id', 'seller_id': 'seller_id', 'buyer_id': 'buyer_id', 'cost_price': 'cost_price_amt', 'sale_price': 'sale_price_amt',
                              'distribute_system_type': 'distribute_system_code', 'is_ota': "IF(distribute_system_code = 'OTA', 1, 0)"})],
        'from': {'dwd_ord_order_di': ("(\n        SELECT /*+ BROADCAST(p) */ o.*, p.sid AS rc_supplier_id, p.fid AS rc_purchase_id\n        FROM dwd.dwd_ord_order_di o\n"
                                      "        JOIN (SELECT DISTINCT CAST(sid AS BIGINT) AS sid, CAST(fid AS BIGINT) AS fid, CAST(ticket_id AS BIGINT) AS ticket_id\n"
                                      "              FROM ods.ods_prd_resource_purchase_df WHERE travel_date = '${bizdate}') p\n"
                                      "          ON p.ticket_id = o.ticket_id AND p.fid = o.buyer_id      -- 采购商用资源中心采购的票下单\n"
                                      "        WHERE o.travel_date = '${bizdate}' AND o.test_flag = 0\n    ) t")},
        'note': ['资源中心订单 = 标准订单明细 ∩ 资源中心采购关系（采购商 + 票），不再单独从业务库拉一遍订单（旧 dwd_resource_center_order_d_f 重算订单）',
                 '名称 / 账号 / 省市等冗余维度属性不在明细计算，查询时关联 dim_sup_member_df、dim_prd_scenic_df']},
    **proc_model.core(),
    'dim_opr_region_f': {'branches': [
        ('ods_opr_region_area_df', {'region_code': 'area_code', 'region_name': 'area_name', 'parent_code': 'parent_code', 'region_level': 'level', 'area_code': 'area_code',
                                    'zip_code': 'zip_code', 'lng': 'lng', 'lat': 'lat', 'city_code': 'city_code'})],
        'where': "COALESCE(status, '0') = '0'", 'note': ['行政区划一张表（省 / 市 / 区县同表，parent_code 串联）；旧系统 3 张城市表（dim_city_d_f / fixed / 省表）合一']},
    'dim_opr_phone_area_f': {'branches': [
        ('ods_opr_city_phone_df', {'phone_prefix': 'number', 'province_code': 'province_code', 'city_code': 'city_code', 'area_code': 'area_code', 'zip_code': 'zip_code',
                                   'province_name': 'province_name', 'city_name': 'city_name', 'country_name': 'country_name', 'lng': 'lng', 'lat': 'lat'})],
        'note': ['手机号段（前 7 位）→ 归属地；DWD 按 ODS 脱敏前缀等值关联']},
    'dim_opr_idcard_area_f': {'branches': [
        ('ods_opr_idcard_city_df', {'area_code': 'idcard', 'province_code': "CONCAT(SUBSTR(idcard, 1, 2), '0000')", 'city_code': "CONCAT(SUBSTR(idcard, 1, 4), '00')",
                                    'province_name': 'province', 'city_name': 'city', 'district_name': 'country'})],
        'note': ['证件前 6 位 → 省市区；省 / 市编码按行政区划码规则（前 2 / 4 位补 0）推出，不再关联两张城市表']},
    'dim_trf_channel_f': {'branches': [
        ('ods_opr_channel_df', {'channel_code': 'CAST(order_channel_id AS STRING)', 'channel_name': 'channel_name', 'order_channel_id': 'CAST(order_channel_id AS BIGINT)',
                                'track_source_id': 'CAST(track_source_id AS BIGINT)', 'is_line_off': 'is_line_off', 'is_group': 'CAST(is_group AS BIGINT)'})],
        'note': ['下单渠道码表；对接分销平台（OTA / API）见 dim_sup_member_df.distribute_system_code']},
    'dim_fin_pay_channel_f': {'branches': [
        ('ods_fin_merchant_payment_method_df', {'pay_channel_id': 'CAST(channel_id AS BIGINT)', 'pay_channel_name': 'channel_name', 'pay_mode': 'CAST(channel_id AS STRING)',
                                                'pay_mode_name': 'channel_name'})],
        'dedup': ['pay_channel_id'], 'note': ['支付渠道码表：商户支付方式去重得到渠道清单；待确认：订单 paymode 与 channel_id 的对应关系']},
}


def _find_source(f, ups, OF):
    m = re.search(r'沿用旧表 (\w+)\.(\w+)', f['proc'])
    return (m.group(1), m.group(2)) if m else (None, f['n'])


LEGACY_PART = {}   # 旧表 -> 分区列（由 generate 填充）


def gen_mapped(tb, fl, OF, ods_names):
    """非手写 DIM / DWD：按 CORE 映射或字段同名映射生成"""
    name = tb['name']
    ups = [u.strip() for u in re.split('、', tb['up'] or '') if u.strip()]
    ods_ups = [u for u in ups if u in ods_names]
    core = CORE.get(name)
    out_f = [f for f in fl if f['cat'] != '分区' and f['n'] != 'etl_time']
    is_di = name.endswith('_di')
    review = 0
    if core:
        branches = core['branches']
    else:
        # 主表：同名列命中最多的上游 ODS
        score = {u: sum(1 for f in out_f if _find_source(f, ups, OF)[1] in {x['n'] for x in OF.get(u, [])} or f['n'] in {x['n'] for x in OF.get(u, [])}) for u in ods_ups}
        main = max(score, key=lambda u: (score[u], -ods_ups.index(u))) if score else None
        branches = [(main, {})] if main else []
        # 旧宽表（字段多由多张中间表加工而来，ODS 同名命中不足三成）或来源不在导出包：过渡期从旧表平移
        refs = collections.Counter(re.search(r'沿用旧表 (\w+)\.', f['proc']).group(1) for f in out_f if re.search(r'沿用旧表 (\w+)\.', f['proc']))
        legacy_main = refs.most_common(1)[0][0] if refs else (tb.get('legacy') or [None])[0]
        if legacy_main and (not main or score.get(main, 0) < 0.3 * len(out_f)) and legacy_main not in ods_names:
            branches = [('@' + legacy_main, {})]
    if not branches:
        return None, 0, []
    # 通用映射：主表没有、其他上游 ODS 有的字段，按共同业务键 LEFT JOIN（先按键聚合去重，避免放大）
    joins = []
    if not core and branches and not branches[0][0].startswith('@'):
        main = branches[0][0]
        mc = {x['n'] for x in OF.get(main, [])}
        keyset = [_find_source(f, ups, OF)[1] for f in out_f if f['cat'] in ('主键', '业务主键', '外键')] + \
                 ['contract_no', 'member_id', 'customer_id', 'account_id', 'user_id', 'fid', 'ordernum', 'orderid', 'order_no', 'ticket_id', 'tid', 'lid', 'land_id', 'sid']
        need = collections.OrderedDict()
        for f in out_f:
            oc = _find_source(f, ups, OF)[1]
            if oc in mc or f['n'] in mc:
                continue
            for u in ods_ups:
                if u == main:
                    continue
                uc = {x['n'] for x in OF.get(u, [])}
                c = oc if oc in uc else f['n'] if f['n'] in uc else None
                if not c:
                    continue
                key = next((k for k in keyset if k and k != 'id' and k in mc and k in uc), None)
                if key:
                    need.setdefault((u, key), []).append((f['n'], c))
                    break
        for k, ((u, key), cols_) in enumerate(need.items(), 1):
            joins.append((f'j{k}', u, key, cols_))
    jmap = {fn: (a, c) for a, u, key, cols_ in joins for fn, c in cols_}
    blocks = []
    for i, (src, m) in enumerate(branches):
        legacy_src = src.startswith('@')
        src = src.lstrip('@')
        sc = {x['n'] for x in OF.get(src, [])}
        if legacy_src:
            sc = {_find_source(f, ups, OF)[1] for f in out_f if f'沿用旧表 {src}.' in f['proc']}
        lines = []
        for f in out_f:
            if f['n'] in m:
                lines.append(col(m[f['n']], f['n']))
                continue
            _, oc = _find_source(f, ups, OF)
            if f['n'] in jmap and i == 0:
                a, c = jmap[f['n']]
                lines.append(col(f"{a}.{c}" if f['ty'] == 'STRING' else f"CAST({a}.{c} AS {f['ty']})", f['n'], f'关联 ods.{next(u for x, u, _, _ in joins if x == a)}'))
                continue
            if oc in sc:
                e = oc if oc == f['n'] else oc
                if f['n'].endswith('_mask') and rules.SENSITIVE.search(oc):
                    e = f"SUBSTRING_INDEX({oc}, '#', 1)"
                lines.append(col(e if f['ty'] in ('STRING',) or e == f['n'] else f"CAST({e} AS {f['ty']})", f['n']))
            elif f['n'] in sc:
                lines.append(col(f['n'], f['n']))
            elif re.search(r'(_name|_account|_province|_city|_belong_area|_is_test|_auto_get|_topic|_type_name)$', f['n']) and core:
                lines.append(col(null_of(f['ty']), f['n'], '冗余维度属性：查询时关联维表，建议从明细移除' if i == 0 else ''))
            else:
                if i == 0:
                    review += 1
                lines.append(col(null_of(f['ty']), f['n'], '待确认：来源未同步' + (f"（旧字段 {f['proc'].replace('沿用旧表 ', '')}）" if '沿用旧表' in f['proc'] else '') if i == 0 else ''))
        lines.append(f'    {NOW}')
        src_di = src.endswith('_di')
        w = [P]
        if core and core.get('where'):
            w.append(core['where'])
        ev = (core or {}).get('event_date', {}).get(src)
        if is_di and not src_di and ev:
            w.append((f"{ev} = '${{bizdate}}'" if '(' in ev else f"DATE_FORMAT({ev}, 'yyyyMMdd') = '${{bizdate}}'") + '   -- 全量快照取当日事件')
        dedup = ''
        if src_di and 'id' in sc:
            upd = next((c for c in UPD if c in sc), None)
            if upd:
                dedup = upd
        frm = f'ods.{src}' if not legacy_src else src
        if legacy_src:
            pc = LEGACY_PART.get(src)
            w = [f"{pc[0]} = {'${bizdate}' if pc[1].upper().startswith('INT') else repr('${bizdate}')}   -- 过渡期：读旧表，按字段清单逐步改为从 ODS 计算"] if pc else []
        if (core or {}).get('from', {}).get(src):
            frm, w, dedup = core['from'][src], [], ''
        if dedup:
            frm = (f"(\n        SELECT *, ROW_NUMBER() OVER (PARTITION BY id ORDER BY {dedup} DESC) AS rn\n        FROM ods.{src}\n        WHERE {' AND '.join(w)}\n    ) t")
            w = ['rn = 1   -- 同一记录当日多次变更取最新']
        jtxt = ''
        if joins and i == 0:
            if not frm.startswith('('):
                frm = f"(SELECT * FROM {frm} WHERE {' AND '.join(w)}) m"
                w = []
            else:
                frm = frm[:-2] + ' m' if frm.endswith(' t') else frm
                w = [x.replace('rn = 1', 'm.rn = 1') for x in w]
            for a, u, key, cols_ in joins:
                agg = ', '.join(f'MAX({c}) AS {c}' for c in dict.fromkeys(c for _, c in cols_))
                jtxt += f"\nLEFT JOIN (SELECT {key}, {agg} FROM ods.{u} WHERE {P} GROUP BY {key}) {a} ON {a}.{key} = m.{key}"
            lines = [re.sub(r'^(    )(?!CAST\(NULL|j\d+\.|CAST\(j\d|DATE_FORMAT\(CURRENT|\')(CAST\()?(\w+)\b', lambda mm: mm.group(1) + (mm.group(2) or '') + 'm.' + mm.group(3), l) for l in lines]
        blk = f"SELECT\n{join_cols(lines)}\nFROM {frm}{jtxt}" + (f"\nWHERE {(chr(10) + '  AND ').join(w)}" if w else '')
        blocks.append((src, blk))
    target = f"{tb['layer'].lower()}.{name}"
    part = f" PARTITION (travel_date = '${{bizdate}}')" if 'travel_date' in [f['n'] for f in fl if f['cat'] == '分区'] else ''
    if len(blocks) == 1:
        body = blocks[0][1]
        dd = (core or {}).get('dedup')
        if dd:
            body = (f"SELECT *\nFROM (\n    SELECT u.*, ROW_NUMBER() OVER (PARTITION BY {', '.join(dd)} ORDER BY {dd[0]}) AS rn\n    FROM (\n"
                    + '\n'.join('        ' + l for l in body.split('\n')) + "\n    ) u\n) t\nWHERE rn = 1")
            body = body.replace('SELECT *\nFROM (', f"SELECT {', '.join(f['n'] for f in out_f)}, etl_time\nFROM (", 1)
        sql = f"INSERT OVERWRITE TABLE {target}{part}\n{body}\n"
    else:
        parts = []
        for k, (src, blk) in enumerate(blocks):
            parts.append(f'-- ({k + 1}) {src}\n{blk}')
        sql = f"INSERT OVERWRITE TABLE {target}{part}\n" + '\nUNION ALL\n'.join(parts) + '\n'
    notes = list((core or {}).get('note', []))
    if not core and branches[0][0].startswith('@'):
        lm = branches[0][0][1:]
        notes.append(f"过渡期从旧表 {lm} 平移：旧逻辑由多张中间表 / 外部采集加工，字段与 ODS 不能直接对应；字段口径按字典，"
                     f"上线顺序：先平移保证下游可切换，再按字段清单把「待确认」逐个改为从 ODS 计算后下线旧链路")
    elif not core:
        notes.append(f"主表 ods.{branches[0][0]}（同名字段命中最多）" + (f"；按共同业务键关联 {len(joins)} 张上游（{'、'.join(f'{u} ON {k}' for _, u, k, _ in joins)}），先按键聚合去重" if joins else '')
                     + "；仍无来源的字段标「待确认」")
    return sql, review, notes


# ============================================================================ DWS：由指标口径生成
ORD_DIMS = {'team_type': "IF(team_flag = 1, 'TEAM', 'INDIVIDUAL')", 'province_code': 'taker_province_code', 'city_code': 'taker_city_code',
            'district_code': 'taker_district_code', 'member_id': 'supplier_id'}
ADV = ("CASE WHEN advance_day_qty <= 0 THEN '当天' WHEN advance_day_qty = 1 THEN '1' WHEN advance_day_qty <= 3 THEN '2-3' WHEN advance_day_qty <= 7 THEN '4-7' "
       "WHEN advance_day_qty <= 15 THEN '8-15' WHEN advance_day_qty <= 30 THEN '16-30' ELSE '30+' END")
FELLOW = "CASE WHEN fellow_qty <= 1 THEN '1' WHEN fellow_qty <= 4 THEN '2-4' WHEN fellow_qty <= 9 THEN '5-9' ELSE '10+' END"

# 来源：键 -> (表, 过滤, 维度表达式覆盖, 说明)
SRC = {
    'ord': ('dwd.dwd_ord_order_di', [P, 'test_flag = 0', "pay_status <> '2'"], {**ORD_DIMS, 'stat_hour': 'HOUR(order_time)', 'advance_day_group': ADV},
            '预订：下单日分区 = bizdate，已支付（含现场支付、含之后取消）'),
    'ord_play': ('dwd.dwd_ord_order_di', ["travel_date BETWEEN DATE_FORMAT(DATE_SUB(" + BIZ_DAY + ", 90), 'yyyyMMdd') AND '${bizdate}'", 'test_flag = 0', "pay_status <> '2'",
                                          "play_date = DATE_FORMAT(" + BIZ_DAY + ", 'yyyy-MM-dd')"], {**ORD_DIMS, 'advance_day_group': ADV},
                 '按游玩日：近 90 天下单、游玩日 = bizdate（旧 ads_daily_scenic_pre_booking 取近 80 天，放宽到 90）'),
    'trk': ('dwd.dwd_ord_order_track_di', [P, 'test_flag = 0'], {**ORD_DIMS, 'stat_hour': 'HOUR(action_time)'}, '订单操作：操作日分区 = bizdate'),
    'vfy': ('dwd.dwd_ord_verify_di', [P, 'test_flag = 0'], {**ORD_DIMS, 'stat_hour': 'HOUR(verify_time)'}, '核销：验证日分区 = bizdate'),
    'trv_book': ('dwd.dwd_ord_traveler_di', [P, 'test_flag = 0', "SUBSTR(order_time, 1, 10) = DATE_FORMAT(" + BIZ_DAY + ", 'yyyy-MM-dd')"],
                 {'behavior_type': "'BOOK'", 'fellow_group': FELLOW, 'team_type': "IF(team_flag = 1, 'TEAM', 'INDIVIDUAL')"}, '预订游客：当日下单'),
    'trv_verify': ('dwd.dwd_ord_traveler_di', [P, 'test_flag = 0', "SUBSTR(verify_time, 1, 10) = DATE_FORMAT(" + BIZ_DAY + ", 'yyyy-MM-dd')"],
                   {'behavior_type': "'VERIFY'", 'fellow_group': FELLOW, 'team_type': "IF(team_flag = 1, 'TEAM', 'INDIVIDUAL')"}, '核销游客：当日验证'),
    'pkg': ('dwd.dwd_ord_order_di', [P, 'test_flag = 0', "pay_status <> '2'", "order_role = 'SUB'"], {'main_ticket_id': 'main_ticket_id', 'sub_ticket_id': 'ticket_id'},
            '套票子票：关联同日主票订单取主票票ID'),
    'pkg_vfy': ('dwd.dwd_ord_verify_di', [P, 'test_flag = 0', "order_role = 'SUB'"], {'main_ticket_id': 'main_ticket_id', 'sub_ticket_id': 'ticket_id'}, '子票核销'),
    'inout': ('dwd.dwd_trf_scenic_inout_di', [P], {'stat_hour': 'HOUR(inout_time)'}, '闸机进出流水，闸机组取自 dim_trf_gate_f'),
    'card': ('dwd.dwd_ord_annual_card_trade_di', [P], {}, '年卡交易'),
    'park': ('dwd.dwd_opr_parking_record_di', [P], {'stat_hour': 'HOUR(inout_time)'}, '停车进出（5 厂商已在 DWD 归一）'),
    'retail': ('dwd.dwd_opr_retail_order_di', [P], {}, '零售订单（3 系统已在 DWD 归一）'),
    'hotel': ('dwd.dwd_opr_hotel_order_df', [P, "arrive_date <= " + BIZ_DAY, "depart_date > " + BIZ_DAY],
              {}, '绿云在住订单：到店日 ≤ bizdate < 离店日（酒店订单明细，全量快照）'),
    'aio': ('dwd.dwd_ord_allinone_card_trade_di', [P, proc_model.AIO_WHERE], {'aio_pay_type': 'pay_type'}, '一卡通有效流水：卡操作 + 已支付消费 + 成功退款'),
    'journal': ('dwd.dwd_fin_trade_journal_di', [P], {}, '账户流水'),
    'login': ('dwd.dwd_sup_member_login_di', [P], {}, '商户登录'),
    'relation': ('dim.dim_sup_member_relation_zip', [], {'member_id': 'supplier_id'}, '分销关系拉链（当前快照）'),
    'ticketdim': ('dim.dim_prd_ticket_df', [], {'member_id': 'supplier_id'}, '票维度（当前快照）'),
    'module': ('dwd.dwd_opr_module_open_di', [P], {}, '模块开通'),
    'contract': ('dwd.dwd_sup_contract_event_di', [P], {}, '合同事件'),
    'resource': ('dwd.dwd_prd_resource_order_di', [P], {}, '资源中心订单'),
    'pv': ('dwd.dwd_trf_page_view_di', [P], {}, '页面访问'),
}


EXTRA = {'inout': {'gate_group_id'}}   # 来源子查询额外带出的列


def _trk(acts, what):
    a = ', '.join(f"'{x}'" for x in acts)
    if what == 'order_qty':
        return f'COUNT(DISTINCT IF(track_action IN ({a}), order_no, NULL))'
    c = {'ticket_qty': 'ticket_qty', 'sale_amt': 'sale_amt', 'cost_amt': 'cost_amt'}[what]
    return f'SUM(IF(track_action IN ({a}), {c}, 0))'


TRK = {'pay': ['PAY', 'ADD_TICKET'], 'cancel': ['CANCEL', 'MODIFY'], 'revoke': ['REVOKE', 'REVOKE_MODIFY'], 'finish': ['FINISH'], 'print': ['PRINT']}
# 指标 -> {来源: 聚合表达式}；第一项为默认来源
R = {
    'order_order_qty': {'ord': 'COUNT(1)', 'ord_play': 'COUNT(1)', 'trv_book': 'COUNT(DISTINCT order_no)'},
    'order_ticket_qty': {'ord': 'SUM(origin_ticket_qty)', 'ord_play': 'SUM(origin_ticket_qty)', 'pkg': 'SUM(origin_ticket_qty)', 'trv_book': 'COUNT(1)'},
    'order_sale_amt': {'ord': 'SUM(origin_ticket_qty * sale_price_amt)', 'ord_play': 'SUM(origin_ticket_qty * sale_price_amt)', 'resource': 'SUM(booking_pay_amt)'},
    'order_cost_amt': {'ord': 'SUM(origin_ticket_qty * cost_price_amt)'},
    'buyer_qty': {'ord': 'BITMAP_UNION(TO_BITMAP(XXHASH64(taker_id_card_hash)))'},
    'verify_order_qty': {'vfy': 'COUNT(DISTINCT order_no)'}, 'verify_ticket_qty': {'vfy': 'SUM(verify_ticket_qty)', 'pkg_vfy': 'SUM(verify_ticket_qty)', 'trv_verify': 'COUNT(1)'},
    'verify_sale_amt': {'vfy': 'SUM(verify_sale_amt)'}, 'verify_cost_amt': {'vfy': 'SUM(verify_cost_amt)'},
    'after_sale_ticket_qty': {'trk': _trk(['AFTER_SALE'], 'ticket_qty')}, 'after_sale_refund_amt': {'trk': "SUM(IF(track_action = 'AFTER_SALE', refund_amt, 0))"},
    'after_sale_income_amt': {'trk': "SUM(IF(track_action = 'AFTER_SALE', service_fee_amt, 0))"},
    'traveler_qty': {'trv_book': 'COUNT(1)', 'trv_verify': 'COUNT(1)'},
    'enter_qty': {'inout': "SUM(IF(inout_type = 'IN', person_qty, 0))"}, 'exit_qty': {'inout': "SUM(IF(inout_type = 'OUT', person_qty, 0))"},
    'in_park_qty': {'inout': "SUM(CASE inout_type WHEN 'IN' THEN person_qty WHEN 'OUT' THEN -person_qty ELSE 0 END)"},
    'card_sale_qty': {'card': "SUM(IF(trade_type = 'SELL', 1, 0))"}, 'card_sale_amt': {'card': "SUM(IF(trade_type = 'SELL', trade_amt, 0))"},
    'card_active_qty': {'card': "SUM(IF(trade_type = 'ACTIVE', 1, 0))"}, 'card_verify_qty': {'vfy': 'SUM(annual_card_flag)'},
    'park_entry_qty': {'park': "SUM(IF(inout_type = 'IN', 1, 0))"}, 'park_exit_qty': {'park': "SUM(IF(inout_type = 'OUT', 1, 0))"},
    'park_fee_amt': {'park': "SUM(IF(inout_type = 'OUT', fee_amt, 0))"},
    'park_minute_qty': {'park': "SUM(IF(inout_type = 'OUT', (UNIX_TIMESTAMP(inout_time) - UNIX_TIMESTAMP(in_time)) DIV 60, 0))"},
    'retail_order_qty': {'retail': 'COUNT(DISTINCT IF(refund_flag = 0, order_no, NULL))'}, 'retail_item_qty': {'retail': 'SUM(IF(refund_flag = 0, COALESCE(item_qty, 0), 0))'},
    'retail_sale_amt': {'retail': 'SUM(IF(refund_flag = 0, sale_amt, 0))'}, 'retail_refund_amt': {'retail': 'SUM(IF(refund_flag = 1, sale_amt, 0))'},
    'hotel_room_night_qty': {'hotel': 'SUM(room_qty)'}, 'hotel_revenue_amt': {'hotel': 'SUM(room_rate_amt * room_qty)'},
    'aio_trade_qty': {'aio': 'COUNT(1)'}, 'aio_trade_amt': {'aio': 'SUM(trade_amt)'}, 'aio_principal_amt': {'aio': 'SUM(principal_amt)'}, 'aio_bonus_amt': {'aio': 'SUM(bonus_amt)'},
    'account_income_amt': {'journal': 'SUM(IF(trade_amt > 0, trade_amt, 0))'}, 'account_expense_amt': {'journal': 'SUM(IF(trade_amt < 0, -trade_amt, 0))'},
    'account_balance_amt': {'journal': 'MAX_BY(balance_amt, trade_time)'},
    'login_member_qty': {'login': 'BITMAP_UNION(TO_BITMAP(member_id))'},
    'new_distributor_qty': {'relation': "COUNT(DISTINCT IF(DATE_FORMAT(add_time, 'yyyyMMdd') = '${bizdate}', distributor_id, NULL))"},
    'distributor_total_qty': {'relation': "COUNT(DISTINCT IF(end_date = '99991231', distributor_id, NULL))"},
    'onshelf_product_qty': {'ticketdim': "SUM(IF(ticket_status = '1', 1, 0))"}, 'module_open_qty': {'module': 'COUNT(1)'},
    'contract_amt': {'contract': "SUM(IF(event_type = 'SIGN', event_amt, 0))"}, 'invoice_amt': {'contract': "SUM(IF(event_type = 'INVOICE', event_amt, 0))"},
    'payback_amt': {'contract': "SUM(IF(event_type = 'PAYBACK', event_amt, 0))"},
    'resource_purchase_qty': {'resource': 'COUNT(DISTINCT purchase_member_id)'}, 'resource_order_qty': {'resource': 'COUNT(DISTINCT order_no)'},
    'page_pv': {'pv': 'SUM(COALESCE(pv_qty, 1))'}, 'page_uv_qty': {'pv': 'BITMAP_UNION(TO_BITMAP(XXHASH64(distinct_id)))'},
}
for a, acts in TRK.items():
    for m in ('order_qty', 'ticket_qty', 'sale_amt', 'cost_amt'):
        R.setdefault(f'{a}_{m}', {'trk': _trk(acts, m)})
SNAP = {'in_park_qty', 'account_balance_amt', 'distributor_total_qty', 'onshelf_product_qty'}
# 表内派生（不可再汇总，ADS 不存）
DERIVED = {'order_avg_ticket_price': 'CAST(SUM(order_sale_amt) / NULLIF(SUM(order_ticket_qty), 0) AS DECIMAL(18,2))'}
# 每张 DWS 允许的来源（表的上游决定；同一指标多来源时按表选）
DWS_SRC = {
    'dws_ord_scenic_ticket_trade_di': ['ord', 'trk', 'vfy', 'card', 'inout'], 'dws_ord_scenic_ticket_trade_hrs': ['ord', 'trk', 'vfy'],
    'dws_ord_scenic_traveler_profile_di': ['trv_book', 'trv_verify'], 'dws_ord_scenic_pre_booking_di': ['ord_play'],
    'dws_ord_package_sub_ticket_di': ['pkg', 'pkg_vfy'], 'dws_trf_scenic_inout_hrs': ['inout'], 'dws_ord_annual_card_di': ['card', 'vfy'],
    'dws_opr_parking_hrs': ['park'], 'dws_opr_retail_di': ['retail'], 'dws_opr_hotel_di': ['hotel'], 'dws_ord_allinone_card_di': ['aio'], 'dws_fin_account_trans_di': ['journal'],
    'dws_sup_member_di': ['login', 'relation', 'ticketdim', 'module'], 'dws_sup_contract_di': ['contract'], 'dws_prd_resource_center_di': ['resource'],
    'dws_trf_page_view_di': ['pv'],
}


def _agg_of(ty, n):
    if ty == 'BITMAP':
        return f'BITMAP_UNION({n})'
    if n in SNAP:
        return f'MAX({n})'
    return f'SUM({n})'


def gen_dws(tb, fl, OF):
    name = tb['name']
    grain = [f for f in fl if f['cat'] == '粒度键']
    mets = [f for f in fl if f['cat'] in ('指标', '度量') and f['n'] not in DERIVED]
    der = [f for f in fl if f['n'] in DERIVED]
    allowed = DWS_SRC.get(name, [])
    by_src = collections.OrderedDict((s, []) for s in allowed)
    review, notes = 0, []
    unresolved = []
    for f in mets:
        rec = R.get(f['n'], {})
        s = next((s for s in allowed if s in rec), None)
        if not s:
            unresolved.append(f['n'])
            continue
        by_src[s].append((f, rec[s]))
    by_src = collections.OrderedDict((s, v) for s, v in by_src.items() if v)
    branches = []
    for s, items in by_src.items():
        tbl, where, dmap, note = SRC[s]
        cols = {x['n'] for x in OF.get(tbl.split('.', 1)[1], [])}
        dl, gb = [], []
        for g in grain:
            e = dmap.get(g['n'], g['n'] if g['n'] in cols | EXTRA.get(s, set()) else None)
            if e is None:
                dl.append(col(default_of(g['ty']), g['n'], '该来源无此维度，取默认值'))
                continue
            e = f"COALESCE({e}, {default_of(g['ty'])})" if g['ty'].upper().startswith(('BIGINT', 'INT')) else e
            dl.append(col(e, g['n']))
            gb.append(e)
        have = {f['n'] for f, _ in items}
        ml = []
        for f in mets:
            if f['n'] in have:
                ml.append(col(dict((x['n'], e) for x, e in items)[f['n']], f['n']))
            else:
                ml.append(col(null_of(f['ty']) if f['ty'] == 'BITMAP' or f['n'] in SNAP else f"CAST(0 AS {f['ty']})", f['n']))
        frm = tbl
        if s == 'pkg':
            frm = (f"(\n        SELECT s.*, m.ticket_id AS main_ticket_id\n        FROM {tbl} s\n        JOIN (SELECT order_no, ticket_id FROM {tbl} WHERE {P}) m ON m.order_no = s.main_order_no\n"
                   f"        WHERE s.{P}\n    ) t")
            where = [w for w in where if w != P]
        if s == 'pkg_vfy':
            frm = (f"(\n        SELECT v.*, o.ticket_id AS main_ticket_id\n        FROM {tbl} v\n        JOIN (SELECT order_no, ticket_id FROM dwd.dwd_ord_order_di) o ON o.order_no = v.main_order_no\n"
                   f"        WHERE v.{P}\n    ) t")
            where = [w for w in where if w != P]
        if s == 'inout':
            frm = (f"(\n        SELECT /*+ BROADCAST(g) */ i.*, g.gate_group_id\n        FROM {tbl} i\n        LEFT JOIN (SELECT terminal_no, MAX(gate_group_id) AS gate_group_id FROM dim.dim_trf_gate_f GROUP BY terminal_no) g\n"
                   f"               ON g.terminal_no = i.terminal_no\n        WHERE i.{P}\n    ) t")
            where = [w for w in where if w != P]
        if s in ('relation',):
            where = where + ['supplier_id IS NOT NULL']
        if s in ('trv_book', 'trv_verify') and 'team_flag' not in cols:
            dl = [x.replace("IF(team_flag = 1, 'TEAM', 'INDIVIDUAL')", "'INDIVIDUAL'") for x in dl]
        blk = (f"    -- {s}：{note}\n    SELECT\n" + join_cols(['    ' + x for x in dl + ml]) + f"\n    FROM {frm}"
               + (f"\n    WHERE {(chr(10) + '      AND ').join(where)}" if where else '') + (f"\n    GROUP BY {', '.join(gb)}" if gb else ''))
        branches.append(blk)
    if not branches:
        return None, 0, []
    gnames = [g['n'] for g in grain if g['n'] != 'stat_hour' or True]
    outer = [col(g['n'], g['n']) for g in grain]
    for f in fl:
        if f['cat'] in ('粒度键', '分区') or f['n'] == 'etl_time':
            continue
        if f['n'] in DERIVED:
            outer.append(col(DERIVED[f['n']], f['n'], '表内派生：不可跨行再汇总'))
        elif f['n'] in unresolved:
            outer.append(col(null_of(f['ty']), f['n'], '待确认：没有可用来源'))
            review += 1
        elif f['n'] == 'in_park_qty' and 'stat_hour' in gnames:
            part = ', '.join(g for g in gnames if g != 'stat_hour')
            outer.append(col(f"SUM(SUM(in_park_qty)) OVER (PARTITION BY {part} ORDER BY stat_hour)", 'in_park_qty', '在园 = 当日累计入园 − 累计出园（截至该小时）'))
        else:
            outer.append(col(_agg_of(f['ty'], f['n']), f['n']))
    outer.append(f'    {NOW}')
    part = " PARTITION (travel_date = '${bizdate}')" if any(f['n'] == 'travel_date' and f['cat'] == '分区' for f in fl) else ''
    sql = (f"INSERT OVERWRITE TABLE dws.{name}{part}\nSELECT\n{join_cols(outer)}\nFROM (\n" + '\n    UNION ALL\n'.join(branches) + f"\n) u\nGROUP BY {', '.join(gnames)}\n")
    notes.append('同一来源的指标在一个子查询里预聚合（一次扫描），各来源 UNION ALL 后按粒度汇总，不做明细级 JOIN')
    if any('BITMAP' in f['ty'] for f in mets):
        notes.append('去重类指标存位图（TO_BITMAP / BITMAP_UNION，UDF 与 PFT3.0 同一套），任意周期 BITMAP_UNION_COUNT')
    if der:
        notes.append('、'.join(f['n'] for f in der) + ' 为表内派生，下游按分子分母重算，不直接 SUM')
    if unresolved:
        notes.append('待确认（无来源）：' + '、'.join(unresolved))
    srcs = '；'.join(f"{s} = {SRC[s][0]}（{SRC[s][3]}）" for s in by_src)
    notes.append('来源：' + srcs)
    return sql, review, notes


# ============================================================================ ADS：日粒度，从 DWS 再汇总
ADS_SRC_MAP = {'buyer_bitmap': 'buyer_qty', 'login_member_bitmap': 'login_member_qty', 'page_uv_bitmap': 'page_uv_qty'}


def gen_ads(tb, fl, OF):
    name = tb['name']
    ups = [u.strip() for u in re.split('、', tb['up'] or '') if u.strip().startswith(('dws_', 'dim_', 'ads_'))]
    grain = [f for f in fl if f['cat'] == '粒度键']
    mets = [f for f in fl if f['cat'] not in ('粒度键', '分区', 'ETL')]
    if not ups:
        return None, 0, []
    review, notes = 0, []
    owner = {}
    for f in mets:
        src = ADS_SRC_MAP.get(f['n'], f['n'])
        u = next((u for u in ups if src in {x['n'] for x in OF.get(u, [])}), None)
        if u:
            owner[f['n']] = (u, src)
    branches = []
    for u in ups:
        mine = [f for f in mets if owner.get(f['n'], (None,))[0] == u]
        if not mine:
            continue
        ucols = {x['n']: x for x in OF.get(u, [])}
        dl, gb = [], []
        for g in grain:
            if g['n'] in ucols:
                dl.append(col(g['n'], g['n']))
                gb.append(g['n'])
            else:
                dl.append(col(default_of(g['ty']), g['n'], '该上游无此维度'))
        ml = []
        for f in mets:
            if f in mine:
                src = owner[f['n']][1]
                ty = ucols[src]['ty']
                if ty == 'BITMAP' or f['ty'] == 'BITMAP' or f['n'].endswith('_bitmap'):
                    e = f'BITMAP_UNION({src})'
                elif src in SNAP:
                    e = f'MAX_BY({src}, stat_hour)' if 'stat_hour' in ucols else f'SUM({src})'
                else:
                    e = f'SUM({src})'
                ml.append(col(e, f['n']))
            else:
                ml.append(col(null_of(f['ty']) if f['ty'] == 'BITMAP' or f['n'].endswith('_bitmap') or ADS_SRC_MAP.get(f['n'], f['n']) in SNAP else f"CAST(0 AS {f['ty']})", f['n']))
        tbl = ('dim.' if u.startswith('dim_') else 'ads.' if u.startswith('ads_') else 'dws.') + u
        has_part = 'travel_date' in ucols
        blk = (f"    -- {u}\n    SELECT\n" + join_cols(['    ' + x for x in dl + ml]) + f"\n    FROM {tbl}"
               + (f"\n    WHERE {P}" if has_part else '') + (f"\n    GROUP BY {', '.join(gb)}" if gb else ''))
        branches.append(blk)
    if not branches:
        return None, 0, []
    outer = [col(g['n'], g['n']) for g in grain]
    for f in mets:
        if f['n'] not in owner:
            outer.append(col(null_of(f['ty']), f['n'], '待确认：上游 DWS 没有该字段'))
            review += 1
        elif f['ty'] == 'BITMAP' or f['n'].endswith('_bitmap'):
            outer.append(col(f"BITMAP_UNION({f['n']})", f['n']))
        elif ADS_SRC_MAP.get(f['n'], f['n']) in SNAP:
            outer.append(col(f"MAX({f['n']})", f['n']))
        else:
            outer.append(col(f"SUM({f['n']})", f['n']))
    outer.append(f'    {NOW}')
    part = " PARTITION (travel_date = '${bizdate}')" if any(f['n'] == 'travel_date' and f['cat'] == '分区' for f in fl) else ''
    if len(branches) == 1:
        inner = branches[0]
        sql = f"INSERT OVERWRITE TABLE ads.{name}{part}\nSELECT\n{join_cols(outer)}\nFROM (\n{inner}\n) u\nGROUP BY {', '.join(g['n'] for g in grain)}\n"
    else:
        sql = (f"INSERT OVERWRITE TABLE ads.{name}{part}\nSELECT\n{join_cols(outer)}\nFROM (\n" + '\n    UNION ALL\n'.join(branches)
               + f"\n) u\nGROUP BY {', '.join(g['n'] for g in grain)}\n")
    notes.append('ADS 只存日粒度：周 / 月 / 年 / 节假日 / 自定义区间与同比环比在查询时关联 dim_opr_period_f（见「指标口径 · ADS 业务指标」）')
    notes.append('比率类不落比率值，只存分子分母；去重类存位图；快照类取日终值')
    if len(branches) > 1:
        notes.append('多个上游各自预聚合后 UNION ALL，按 ADS 粒度合并（替代旧系统多表 FULL JOIN）')
    return sql, review, notes


# 特殊 ADS（非简单汇总）
def ads_special(name):
    if name == 'ads_mkt_sms_audience_di':
        return f"""
INSERT OVERWRITE TABLE ads.ads_mkt_sms_audience_di PARTITION (travel_date = '${{bizdate}}')
SELECT
    o.scenic_id,
    o.taker_phone_hash,
    -- 新客：此前没有在该景区下过单（按游客维度的首单日判定，避免回扫全部历史订单）
    MAX(IF(t.first_order_date IS NULL OR t.first_order_date >= DATE_FORMAT({BIZ_DAY}, 'yyyy-MM-dd'), 1, 0)) AS new_user_flag,
    COUNT(1)                                                         AS order_order_qty,
    {NOW}
FROM (SELECT scenic_id, taker_phone_hash, taker_id_card_hash FROM dwd.dwd_ord_order_di
      WHERE {P} AND test_flag = 0 AND pay_status <> '2' AND taker_phone_hash IS NOT NULL) o
LEFT JOIN (SELECT tourist_key, first_order_date FROM dim.dim_cus_tourist_df) t ON t.tourist_key = o.taker_id_card_hash
GROUP BY o.scenic_id, o.taker_phone_hash
""", ['短信营销人群：只出哈希，不出明文手机号；发送时由营销系统按哈希回查（旧 ads 直接导出明文手机号）']
    if name == 'ads_trf_digital_brain_di':
        return f"""
INSERT OVERWRITE TABLE ads.ads_trf_digital_brain_di PARTITION (travel_date = '${{bizdate}}')
SELECT scenic_id, data_domain, target_name, data_value AS data_value_qty, {NOW}
FROM (
    -- 交易：由标准 ADS 转成「指标域 × 指标」竖表，大屏按 target_name 取数
    SELECT scenic_id, 'trade' AS data_domain,
           STACK(4, 'order_ticket_qty', CAST(SUM(order_ticket_qty) AS DECIMAL(20,4)), 'order_sale_amt', CAST(SUM(order_sale_amt) AS DECIMAL(20,4)),
                    'verify_ticket_qty', CAST(SUM(verify_ticket_qty) AS DECIMAL(20,4)), 'cancel_ticket_qty', CAST(SUM(cancel_ticket_qty) AS DECIMAL(20,4))) AS (target_name, data_value)
    FROM ads.ads_ord_scenic_trade_overview_di WHERE {P}
    GROUP BY scenic_id
    UNION ALL
    -- 客流
    SELECT scenic_id, 'flow',
           STACK(3, 'enter_qty', CAST(SUM(enter_qty) AS DECIMAL(20,4)), 'exit_qty', CAST(SUM(exit_qty) AS DECIMAL(20,4)), 'in_park_qty', CAST(MAX(in_park_qty) AS DECIMAL(20,4))) AS (target_name, data_value)
    FROM ads.ads_trf_scenic_passenger_flow_di WHERE {P}
    GROUP BY scenic_id
) t
""", ['大屏竖表由标准 ADS 转置得到，口径与报表一致（旧大屏单独一套 SQL，且有写死的模拟数据，见问题清单 D6）']
    if name == 'ads_cus_scenic_customer_insight_mo':
        spec = [('basic_profile', 'tag_value', 'proportion'), ('travel_behavior', 'tag_value', 'proportion'), ('wealth_consume', 'tag_value', 'proportion'),
                ('visit_preference', 'preference_object', 'proportion'), ('source_distribution', 'name', 'proportion'), ('source_ranking', 'name', 'proportion'),
                ('work_live', 'name', 'proportion'), ('hot_poi', 'poi_name', 'popularity'), ('hot_visits', 'poi_name', 'popularity'), ('kpi', 'metric_name', 'metric_value')]
        parts = [f"    SELECT CAST(scenic_id AS BIGINT) AS scenic_id, '{k}' AS insight_type, CAST({n} AS STRING) AS item_name, CAST({v} AS DECIMAL(20,4)) AS item_value_qty\n"
                 f"    FROM ods.ods_cus_scenic_customer_insight_{k}_df\n    WHERE {P} AND period_granularity = 'month'" for k, n, v in spec]
        return (f"INSERT OVERWRITE TABLE ads.ads_cus_scenic_customer_insight_mo PARTITION (travel_month = SUBSTR('${{bizdate}}', 1, 6))\n"
                f"SELECT scenic_id, insight_type, item_name, item_value_qty, {NOW}\nFROM (\n" + '\n    UNION ALL\n'.join(parts) + "\n) t\n",
                ['客户洞察为外部（运营商 / 第三方）按月预计算的 10 类结果，统一成「洞察类型 × 指标项 × 值」竖表；旧系统 10 张 ADS 各一套导出',
                 '待确认：period_granularity 取值（month）与外部接口核对'])
    if name == 'ads_trf_ota_platform_di':
        return f"""
INSERT OVERWRITE TABLE ads.ads_trf_ota_platform_di PARTITION (travel_date = '${{bizdate}}')
SELECT scenic_id, platform_code, SUM(ota_order_qty) AS ota_order_qty, {NOW}
FROM (
    -- 携程交易（外部采集，日粒度）
    SELECT CAST(scenic_id AS BIGINT) AS scenic_id, 'ctrip' AS platform_code, CAST(order_count AS BIGINT) AS ota_order_qty
    FROM ods.ods_trf_ota_ctrip_trade_df
    WHERE {P} AND DATE_FORMAT(transaction_date, 'yyyyMMdd') = '${{bizdate}}' AND date_type = 'day'   -- 待确认：date_type / period_type 取值
) t
GROUP BY scenic_id, platform_code
""", ['OTA 外部数据只取日粒度原值，周 / 月由时间表汇总（旧系统同时存外部算好的环比，口径不可控）']
    if name == 'ads_sup_customer_company_df':
        return f"""
INSERT OVERWRITE TABLE ads.ads_sup_customer_company_df
SELECT
    c.company_id,
    BITMAP_UNION(l.login_member_qty)                                 AS login_member_bitmap,
    {NOW}
FROM (SELECT DISTINCT company_id, user_id FROM dim.dim_sup_company_df) c
LEFT JOIN (SELECT member_id, BITMAP_UNION(login_member_qty) AS login_member_qty FROM dws.dws_sup_member_di WHERE {P} GROUP BY member_id) l
       ON l.member_id = c.user_id
GROUP BY c.company_id
""", ['CRM 客户公司 → 平台账号（user_id）→ 商户日汇总；一个公司多个账号时位图合并去重', '合同 / 开票 / 回款：OA 合同链路客户确认下线（内部信息 ODS-OA 与合同 DIM / DWD / DWS），本表不再提供']
    return None


# ============================================================================ 校验
def check(sql, expect, dyn_part=None):
    """解析每条语句；任一写目标表 / 临时表的 SELECT 输出列与字典一致即通过"""
    import sqlglot
    from sqlglot import exp
    s = re.sub(r"\$\{[^}]+\}", '20250101', sql)
    try:
        stmts = [x for x in sqlglot.parse(s, read='spark') if x is not None]
    except Exception as e:  # noqa
        return False, f'解析失败：{str(e)[:160]}'
    got = []
    for st in stmts:
        q = st.expression if isinstance(st, (exp.Insert, exp.Create)) else None
        if q is None or not isinstance(q, (exp.Select, exp.Union, exp.Subquery)):
            continue
        sel = q
        while isinstance(sel, (exp.Union, exp.Subquery)):
            sel = sel.this if isinstance(sel, exp.Union) else sel.this
        names = [e.alias_or_name for e in sel.expressions]
        if names == ['*']:
            continue
        got.append(names)
        if names in (expect, expect + ([dyn_part] if dyn_part else [])):
            return True, ''
    return False, f'输出列与字典不一致：{got[:1]}'


# ============================================================================ 入口
def generate(tables, fields, C, ods_of_source, nodes, legacy_scripts):
    """→ {表名: {'sql', 'kind', 'path', 'stats', 'legacy'}}，以及校验结果"""
    OF = fields_of(fields)
    T = C['tables']
    for t, x in C['schemas'].items():
        if x.get('parts'):
            LEGACY_PART[t] = x['parts'][0][:2]
    ods_names = {t['name'] for t in tables if t['layer'] == 'ODS'}
    groups = collections.defaultdict(list)
    for k, v in ods_of_source.items():
        groups[v].append((k, C['sources'][k]))
    out, bad = {}, []
    for tb in tables:
        L, name = tb['layer'], tb['name']
        if L == 'SRC':
            continue
        fl = OF.get(name, [])
        replaced, seen = [], set()
        for l in tb.get('legacy', []):
            for n in T.get(l, {}).get('writers', []):
                if n['path'] not in seen:
                    seen.add(n['path'])
                    replaced.append(n)
        expect = [f['n'] for f in fl if not (f['cat'] == '分区' and f['n'] in ('travel_date', 'travel_month'))]
        dyn = None
        review = 0
        why, perf, extra = [], [], []
        kind = 'std'
        if L == 'ODS':
            body, notes = ods_di(tb, fl, sorted(groups.get(name, []), key=lambda x: x[0]), replaced)
            sql = header(tb, replaced, [], notes, SCHED['ODS'], ['DataWorks 数据集成 · 脚本模式（JSON）：'], perf_label='同步方式 / 优化')
            sql += body
            out[name] = {'sql': sql, 'kind': 'di', 'path': f"DI 同步 · 替代 {len(replaced)} 个旧任务", 'stats': {'nodes': len(replaced)}, 'legacy': legacy_scripts.get(name, '')}
            continue
        if name in etl_core.SQL:
            body, why, perf = etl_core.SQL[name]
            dyn = 'travel_date' if 'PARTITION (travel_date)' in body else None
            review = body.count('待确认')
            ok, err = check(body, expect if not dyn else [f['n'] for f in fl if f['n'] != 'travel_date'], dyn)
        elif name == 'dim_sup_member_relation_zip':
            body, why, perf = relation_zip()
            ok, err = check(body, expect)
        elif L in ('DIM', 'DWD'):
            if tb.get('note', '').endswith('（表结构从 PFT3.0 字典同步）') or '从 PFT3.0 字典同步' in tb.get('note', ''):
                body = pft3_shared(name)
                why = ['与 PFT3.0 共用：表结构与加工逻辑同 3.0（scripts/dim_date/gen_dim_opr_date_f.py 生成日期与节假日）']
                ok, err = True, ''
            else:
                r = gen_mapped(tb, fl, OF, ods_names)
                if r[0] is None:
                    continue
                body, review, why = r
                ok, err = check(body, expect)
        elif L == 'DWS':
            body, review, perf = gen_dws(tb, fl, OF)
            if body is None:
                continue
            ok, err = check(body, expect)
        else:
            sp = ads_special(name)
            if sp:
                body, why = sp[0].strip('\n') + '\n', sp[1]
                ok, err = check(body, expect)
            else:
                body, review, perf = gen_ads(tb, fl, OF)
                if body is None:
                    continue
                ok, err = check(body, expect)
        if not ok:
            bad.append((name, err))
        sql = header(tb, replaced, why, perf, SCHED[L], extra) + body.strip('\n') + '\n'
        out[name] = {'sql': sql, 'kind': kind, 'path': f"替代 {len(replaced)} 个旧任务" if replaced else '新建', 'stats': {'nodes': len(replaced), 'review': review},
                     'legacy': legacy_scripts.get(name, '')}
    return out, bad


def pft3_shared(name):
    return {'dim_opr_date_f': '-- 日期维度：由 scripts/dim_date/gen_dim_opr_date_f.py 生成近 3 年 + 未来 2 年（含法定节假日、调休、农历），与 PFT3.0 同一份\n'
                              '-- python3 scripts/dim_date/gen_dim_opr_date_f.py --sql > dim_opr_date_f.sql，在 DataWorks 执行一次；每年 12 月国务院公布次年安排后重跑\n',
            'dim_opr_holiday_period_f': '-- 节假日区间：与日期维度同脚本生成，与 PFT3.0 同一份\n',
            'dim_opr_period_f': '-- 统计周期时间表：由日期维度与节假日区间展开（日 / 周 / 月 / 季 / 半年 / 年 / 节假日 / 近 N 日），与 PFT3.0 同一份\n'
                                '-- 加工逻辑见 PFT3.0 字典页 dim.dim_opr_period_f「加工逻辑」\n'}.get(name, '-- 与 PFT3.0 共用\n')


def relation_zip():
    sql = f"""
-- 分销关系拉链：关系本身带建立 / 解除时间（rectime / cuttime），直接按业务时间生成区间，不需要每日比对快照
WITH r AS (
    SELECT CAST(parent_id AS BIGINT) AS parent_id, CAST(son_id AS BIGINT) AS son_id, son_id_type, CAST(ship_type AS BIGINT) AS ship_type, status, rectime, cuttime,
           ROW_NUMBER() OVER (PARTITION BY parent_id, son_id ORDER BY rectime DESC) AS rn
    FROM ods.ods_sup_member_relation_df
    WHERE {P}
),
grp AS (   -- 分销商分组：同一供应商下一个分销商可能在多个组，取最新加入的
    SELECT sid, fid, group_id
    FROM (SELECT CAST(sid AS BIGINT) AS sid, CAST(fid AS BIGINT) AS fid, CAST(group_id AS BIGINT) AS group_id,
                 ROW_NUMBER() OVER (PARTITION BY sid, fid ORDER BY rectime DESC) AS rn
          FROM ods.ods_trf_evolute_group_fid_df WHERE {P}) t
    WHERE rn = 1
)
INSERT OVERWRITE TABLE dim.dim_sup_member_relation_zip
SELECT /*+ BROADCAST(g) */
    r.parent_id                                                      AS supplier_id,
    r.son_id                                                         AS distributor_id,
    DATE_FORMAT(r.rectime, 'yyyyMMdd')                               AS start_date,
    IF(r.status = '0', '99991231', DATE_FORMAT(COALESCE(r.cuttime, r.rectime), 'yyyyMMdd')) AS end_date,   -- 有效关系 end_date = 99991231
    '${{bizdate}}'                                                   AS stat_date,
    r.parent_id,
    r.son_id,
    r.son_id_type                                                    AS son_type,
    r.ship_type                                                      AS relationship_type,
    g.group_id                                                       AS distributor_group,
    r.rectime                                                        AS add_time,
    r.cuttime                                                        AS cut_time,
    r.status                                                         AS order_status,
    {NOW}
FROM r
LEFT JOIN grp g ON g.sid = r.parent_id AND g.fid = r.son_id
WHERE r.rn = 1
"""
    return sql, ['替代 dim_user_relationship_d_f、dim_distributor_group_d_f、dim_prod_distribute_d_f：旧系统每天全量重建关系快照再 JOIN 分组'], \
        ['关系表自带业务时间，直接生成拉链区间；分组先按 供应商 × 分销商 去重再关联']
