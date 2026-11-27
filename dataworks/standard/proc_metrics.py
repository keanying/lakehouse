"""下游指标补齐：消费清单里在用、但标准 DWS / ADS 还没有的指标，按业务过程 DWD 重算（口径对齐旧 SQL，差异写进说明）。

- 酒店：预订 / 预订取消 / 入住 / 入住取消 × 单数 / 房间数 / 成人 / 儿童 / 人数 / 消费 / 实付（旧 dws_sup_hotel_summary_di）
- 账户：冻结收入 / 冻结支出（解冻）/ 可用收入 / 可用支出（旧 ads_daily_account_trans_*）；增加 交易账户 / 账本 / 费用项 维度
- 零售：实付、优惠、退货件数、客流人数（旧 xisland / sixun 汇总）
- 一卡通：操作渠道、景区 / 票、订单支付方式维度（旧 dws_tps_aioc_summary_*）
- 交易：取消 / 撤销手续费（旧 dws_mps_*_report_summary_di）
"""
B, DEC = 'BIGINT', 'DECIMAL(18,2)'
BIZ_DAY = "TO_DATE('${bizdate}', 'yyyyMMdd')"
P = "travel_date = '${bizdate}'"

# ---------------------------------------------------------------- 酒店
H_ACT = [('booking', '预订', f'TO_DATE(reserve_time) = {BIZ_DAY}', '预订时间在统计日（含之后取消的）'),
         ('booking_cancel', '预订取消', f"TO_DATE(reserve_time) = {BIZ_DAY} AND order_status = 'X'", '统计日预订、当前状态为取消'),
         ('checkin', '入住', f'arrive_date = {BIZ_DAY}', '到店日在统计日'),
         ('checkin_cancel', '入住取消', f"arrive_date = {BIZ_DAY} AND order_status = 'X'", '统计日到店、当前状态为取消')]
H_MEAS = [('order_qty', '单数', '单', B, '1'), ('room_qty', '房间数', '间', B, 'room_qty'), ('adult_qty', '成人数', '人', B, 'adult_qty'),
          ('child_qty', '儿童数', '人', B, 'child_qty'), ('guest_qty', '人数', '人', B, 'adult_qty + child_qty'),
          ('sales_amt', '消费合计', '元', DEC, 'charge_amt'), ('pay_amt', '实付合计', '元', DEC, 'pay_amt')]
METRICS, R = [], {}
for i, (a, an, cond, kou) in enumerate(H_ACT):
    for j, (m, mn, unit, ty, e) in enumerate(H_MEAS):
        name = f'hotel_{a}_{m}'
        METRICS.append((f'L4{i + 1}{j + 1}', name, f'酒店{an}{mn}', 'opr', '原子指标', f'{kou}；酒店订单明细（绿云）',
                        f'{an}{mn} = SUM({e}) 条件：{kou}', unit, ty, 'dwd_opr_hotel_order_df',
                        {'booking': 'booking_', 'booking_cancel': 'booking_cancel_', 'checkin': 'checkin_', 'checkin_cancel': 'checkin_cancel_'}[a] + m))
        R[name] = {'hotel_evt': f'SUM(IF({cond}, {e}, 0))'}
HOTEL = [m[1] for m in METRICS]

# ---------------------------------------------------------------- 账户
ACC = [('account_frozen_income_amt', '冻结收入', 'frozen_trade_type = 0', 'frozen_income'), ('account_frozen_expense_amt', '冻结支出（解冻）', 'frozen_trade_type = 1', 'frozen_expense'),
       ('account_available_income_amt', '可用收入', 'available_trade_type = 0', 'available_income'), ('account_available_expense_amt', '可用支出', 'available_trade_type = 1', 'available_expense')]
for k, (n, cn, cond, old) in enumerate(ACC, 1):
    amt = 'frozen_amt' if 'frozen' in n else 'available_amt'
    METRICS.append((f'L45{k}', n, f'账户{cn}', 'fin', '原子指标', f'统计日账户流水中{cn}金额（{cond}）', f'{cn} = SUM({amt}) / 100 条件：{cond}', '元', DEC, 'dwd_fin_trade_journal_di', old))
    R[n] = {'journal': f'SUM(IF({cond}, CAST({amt} AS DECIMAL(18,2)) / 100, 0))'}

# ---------------------------------------------------------------- 零售
RET = [('retail_pay_amt', '零售实付金额', '元', DEC, 'SUM(IF(refund_flag = 0, COALESCE(pay_amt, sale_amt), 0))', '实付 = SUM(实付) 条件：非退货', 'payment_money'),
       ('retail_discount_amt', '零售优惠金额', '元', DEC, 'SUM(IF(refund_flag = 0, sale_amt - COALESCE(pay_amt, sale_amt), 0))', '优惠 = SUM(应收 − 实付) 条件：非退货', 'discount_amount'),
       ('retail_refund_item_qty', '零售退货件数', '件', B, 'SUM(IF(refund_flag = 1, COALESCE(item_qty, 0), 0))', '退货件数 = SUM(件数) 条件：退货', 'cancel_num'),
       ('retail_customer_qty', '零售客流人数', '人', B, 'SUM(IF(refund_flag = 0, COALESCE(number_of_people, 0), 0))', '客流 = SUM(就餐 / 消费人数) 条件：非退货', 'number_of_people')]
RET += [('retail_profit_amt', '零售利润金额', '元', DEC, 'SUM(IF(refund_flag = 0, COALESCE(profit_amt, 0), 0))', '利润 = SUM(单据利润) 条件：销售单（仅银豹提供利润）', 'profit_money'),
        ('retail_refund_profit_amt', '零售退货利润金额', '元', DEC, 'SUM(IF(refund_flag = 1, COALESCE(profit_amt, 0), 0))', '退货利润 = SUM(单据利润) 条件：退货单（旧口径另含作废销售单）', 'cancel_profit_money')]
for k, (n, cn, unit, ty, e, f, old) in enumerate(RET, 1):
    METRICS.append((f'L46{k}', n, cn, 'opr', '原子指标', f'统计日{cn}（3 个零售系统已在 DWD 归一）', f, unit, ty, 'dwd_opr_retail_order_di', old))
    R[n] = {'retail': e}

# ---------------------------------------------------------------- 交易手续费（取消 / 撤销）
for k, (a, an, acts) in enumerate([('cancel', '取消', "'CANCEL', 'MODIFY'"), ('revoke', '撤销', "'REVOKE', 'REVOKE_MODIFY'")], 1):
    n = f'{a}_fee_amt'
    METRICS.append((f'L47{k}', n, f'{an}手续费', 'ord', '原子指标', f'统计日{an}（退票）收取的手续费', f'{an}手续费 = SUM(手续费) 条件：{an}轨迹', '元', DEC,
                    'dwd_ord_order_track_di', f'{a}_income_fee_amt'))
    R[n] = {'trk': f'SUM(IF(track_action IN ({acts}), service_fee_amt, 0))'}

METRICS.append(('L473', 'pay_cost_amt', '支付成本金额', 'ord', '原子指标', '统计日支付成功订单的成本（结算价 × 票数，含加票支付）',
                '支付成本金额 = SUM(结算单价 × 票数) 条件：支付轨迹', '元', DEC, 'dwd_ord_order_track_di', 'sales_expense_amt / pay_cost'))
R['pay_cost_amt'] = {'trk': "SUM(IF(track_action IN ('PAY', 'ADD_TICKET'), cost_amt, 0))"}

METRICS.append(('L481', 'verify_person_qty', '核销人数', 'ord', '原子指标', '统计日核销的游客人次（实名游客数，非实名按票数）', '核销人数 = SUM(游客人数) 条件：核销', '人', B,
                'dwd_ord_verify_di', 'check_people'))
R['verify_person_qty'] = {'vfy': 'SUM(COALESCE(traveler_qty, verify_ticket_qty))'}
METRICS.append(('L482', 'park_in_lot_qty', '场内车辆净增', 'opr', '原子指标', '统计时段内入场车次 − 出场车次（在场车辆变化）', '场内车辆净增 = 入场车次 − 出场车次', '辆', B,
                'dwd_opr_parking_record_di', 'being'))
R['park_in_lot_qty'] = {'park': "SUM(CASE inout_type WHEN 'IN' THEN 1 WHEN 'OUT' THEN -1 ELSE 0 END)"}
for _m, _e in (('order_order_qty', 'COUNT(DISTINCT order_no)'), ('order_ticket_qty', 'SUM(ticket_qty)'), ('order_sale_amt', 'SUM(sale_amt)')):
    R.setdefault(_m, {})['mkt_tag'] = _e

DIMS = {'trade_account_id': ('BIGINT', '交易账户ID'), 'account_book_id': ('BIGINT', '账本ID'), 'template_item_code': ('STRING', '账本专项费用项编码'),
        'marketing_type': ('STRING', '营销方式：SECKILL-抢购 CUT_PRICE-砍价 GROUP_BOOKING-拼团 COUPON-优惠券 ALL_DIS-全民营销 DISTRIBUTOR-分销专员 RESOURCE_CENTER-资源中心 PARK_CARD-园区一卡通 ANNUAL_CARD-年卡 EXTERNAL_CODE-外部发码'),
        'aio_channel': ('INT', '一卡通操作渠道：0-未知 1-云票务 2-微商城 3-闸机 4-手持机 5-小程序 6-平台')}

# 表 -> (新增维度, 新增指标)
ADD = {
    'dws_opr_hotel_di': ([], HOTEL), 'ads_opr_hotel_di': ([], HOTEL),
    'dws_fin_account_trans_di': (['trade_account_id', 'account_book_id', 'template_item_code'], [a[0] for a in ACC]),
    'ads_fin_account_balance_di': (['trade_account_id', 'account_book_id', 'template_item_code'], [a[0] for a in ACC]),
    'dws_opr_retail_di': ([], [r[0] for r in RET]), 'ads_opr_retail_di': ([], [r[0] for r in RET]),
    'dws_ord_allinone_card_di': (['aio_channel', 'scenic_id', 'ticket_id', 'pay_mode'], []),
    'dws_trf_scenic_inout_hrs': (['ticket_id'], ['verify_order_qty', 'verify_ticket_qty', 'verify_person_qty']),
    'dws_opr_parking_hrs': ([], ['park_in_lot_qty']),
    'dws_ord_scenic_ticket_trade_di': ([], ['pay_cost_amt', 'cancel_fee_amt', 'revoke_fee_amt']),
    'ads_ord_scenic_trade_overview_di': ([], ['pay_cost_amt', 'cancel_fee_amt', 'revoke_fee_amt']),
}
NOTE = {'dws_opr_hotel_di': '；预订 / 入住 × 单数、房间、人数、消费、实付（旧系统「取消」类恒为 0，标准按订单当前状态=取消计）',
        'dws_fin_account_trans_di': '；冻结 / 可用收支与交易账户、账本、费用项维度（替代旧 账户 / 交易账户 / 费用项 3 张汇总）'}


def register(model):
    model.D.update(DIMS)
    for m in METRICS:
        model.METRICS.append(m)
        model.M[m[1]] = m
    by = {s['name']: s for s in model.T}
    for t, (ds, ms) in ADD.items():
        sp = by.get(t)
        if not sp or not isinstance(sp['fields'], list):
            continue
        have = {f[0] for f in sp['fields']}
        k = max([i for i, f in enumerate(sp['fields']) if f[2] == '粒度键'] or [-1]) + 1
        sp['fields'][k:k] = model.dims(*[d for d in ds if d not in have])
        sp['fields'] += model.mets(*[m for m in ms if m not in have])
        sp['note'] += NOTE.get(t, '')
    if 'dwd_mkt_order_tag_di' in by and 'dws_mkt_order_tag_di' not in by:
        model.t('dws_mkt_order_tag_di', '订单营销方式日汇总', '1行=1天×供应商×景区×营销方式', 'dwd_mkt_order_tag_di',
                '按营销方式（抢购 / 砍价 / 拼团 / 优惠券 / 全民营销 / 资源中心 / 一卡通 / 年卡 / 外部发码）汇总下单单数、票数、金额；替代旧 channel_aids 的营销标签列',
                model.dims('supplier_id', 'scenic_id', 'marketing_type') + model.mets('order_order_qty', 'order_ticket_qty', 'order_sale_amt'), [])
    if 'dws_opr_hotel_di' in by:
        by['dws_opr_hotel_di']['grain'] = '1行=1天×酒店（在住间夜 + 当日预订 / 入住事件）'


def etl(SRC, R_, DWS_SRC):
    SRC['hotel_evt'] = ('dwd.dwd_opr_hotel_order_df', [P], {}, '酒店订单：按预订日 / 到店日取当日事件（全量快照）')
    SRC['aio'] = (SRC['aio'][0], SRC['aio'][1], {**SRC['aio'][2], 'aio_channel': 'channel', 'pay_mode': 'order_pay_mode'}, SRC['aio'][3])
    for k, v in R.items():
        R_.setdefault(k, {}).update(v)
    DWS_SRC['dws_opr_hotel_di'] = ['hotel', 'hotel_evt']
    SRC['mkt_tag'] = ('dwd.dwd_mkt_order_tag_di', [P], {}, '订单营销标签：当日下单订单 × 营销方式')
    DWS_SRC['dws_mkt_order_tag_di'] = ['mkt_tag']
    DWS_SRC['dws_trf_scenic_inout_hrs'] = ['inout', 'vfy']      # 分终端核销（旧 branch_terminal_summary）与出入园同表
