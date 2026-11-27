"""业务过程补齐：消费清单里在用、但旧系统只有报表库预计算 / 直接读 ODS、没有最细粒度事实表的业务过程。

每张表 = 一个业务过程（见 domains.PROC），粒度 = 业务库一行事件；字段显式定义，ETL 映射逐列给出（不靠同名猜测）。
列定义：(字段, 类型, 类别, 注释, 表达式) —— 多分支 UNION ALL 时表达式为与 branches 等长的元组。
"""
import re
ts = lambda c: f'FROM_UNIXTIME({c})'                 # 业务库秒级时间戳 → 'yyyy-MM-dd HH:mm:ss'
day = lambda c: f"FROM_UNIXTIME({c}, 'yyyyMMdd')"     # 全量快照按事件日取当日
yuan = lambda c: f'CAST({c} AS DECIMAL(18,2)) / 100'  # 分 → 元
B, I, S, DEC = 'BIGINT', 'INT', 'STRING', 'DECIMAL(18,2)'
NUL = {B: 'CAST(NULL AS BIGINT)', I: 'CAST(NULL AS INT)', S: 'CAST(NULL AS STRING)', DEC: 'CAST(NULL AS DECIMAL(18,2))'}

SPECS = []


def proc(name, cn, grain, up, note, branches, cols, legacy=(), event=None, frm=None, notes=(), where=None, part='travel_date'):
    SPECS.append(dict(name=name, cn=cn, grain=grain, up=up, note=note, branches=branches, cols=cols, legacy=list(legacy),
                      event=event or {}, frm=frm or {}, notes=list(notes), where=where, part=part))


# ---------------------------------------------------------------- B1 票务分销
proc('dwd_ord_team_order_df', '团队订单', '1行=1张团队单（当日最新状态）', 'ods_ord_team_order_df、ods_ord_team_order_link_df',
     '团队（旅行社 / 导游）报团下单：团单状态、人数、客源地、子订单数；团散拆分的「团」以此为准，子订单明细在 dwd_ord_order_di（team_flag=1）',
     ['ods_ord_team_order_df'], [
         ('team_order_no', S, '主键', '团队订单号', 'ordernum'),
         ('supplier_id', B, '外键', '供应商ID（租户ID），关联 dim_sup_member_df', 'aid'),
         ('distributor_id', B, '外键', '下单分销商（旅行社）ID，关联 dim_sup_member_df', 'fid'),
         ('distributor_group_id', B, '外键', '分销商分组ID', 'group_id'),
         ('guide_id', B, '外键', '导游ID', 'guide'),
         ('team_type_id', B, '外键', '团单类型ID（团队规则）', 'team_type_id'),
         ('order_type', I, '状态类型', '报团下单方式：1-云票务 2-微平台 …', 'ordertype'),
         ('team_status', I, '状态类型', '团单状态：0-未确认 1-已确认 2-已验证 …', 'status'),
         ('pay_status', I, '状态类型', '支付状态：0-未支付 1-已支付 2-部分支付', 'pay_status'),
         ('active_status', I, '状态类型', '激活状态：0-无需激活 1-未激活 2-已激活', 'active_status'),
         ('lodging_flag', I, '状态类型', '是否住宿：0-否 1-是', 'is_lodging'),
         ('team_person_qty', B, '度量', '团队人数', 'tnum'),
         ('sub_order_qty', B, '度量', '子订单数（团单关联的门票订单）', 'COALESCE(sub_order_qty, 0)'),
         ('scenic_qty', B, '度量', '涉及景区数', 'COALESCE(scenic_qty, 0)'),
         ('province_code', S, '外键', '客源省编码，关联 dim_opr_region_f', 'province_code'),
         ('city_code', S, '外键', '客源市编码', 'city_code'),
         ('district_code', S, '外键', '客源区县编码', 'county_code'),
         ('play_date', S, '时间', '游玩日期', 'playtime'),
         ('order_time', S, '时间', '下单时间', 'ordertime'),
         ('first_verify_time', S, '时间', '团单首次验证时间', 'first_check_time'),
         ('active_time', S, '时间', '激活时间', ts('active_time')),
         ('update_time', S, '时间', '最近更新时间', ts('updatetime')),
     ], legacy=['ods_team_order_d_f'],
     frm={'ods_ord_team_order_df': "(\n        SELECT o.*, l.sub_order_qty, l.scenic_qty\n        FROM ods.ods_ord_team_order_df o\n"
                                   "        LEFT JOIN (SELECT main_ordernum, COUNT(1) AS sub_order_qty, COUNT(DISTINCT lid) AS scenic_qty\n"
                                   "                   FROM ods.ods_ord_team_order_link_df WHERE travel_date = '${bizdate}' GROUP BY main_ordernum) l\n"
                                   "          ON l.main_ordernum = o.ordernum      -- 先聚合再关联，团单不放大\n"
                                   "        WHERE o.travel_date = '${bizdate}'\n    ) t"},
     notes=['团单是有状态的单据（确认 / 验证 / 激活会变）：存全量快照（_df），每日一份最新状态；按下单日 / 游玩日统计时过滤 order_time / play_date',
            '子订单数先在 team_order_link 按团单号聚合再关联（一个团单多张子订单，直接关联会放大团单）'])

# ---------------------------------------------------------------- B2 园区业态
_aio = ['ods_ord_allinone_card_trades_di', 'ods_fin_card_order_journal_di', 'ods_fin_card_order_refund_journal_di']
proc('dwd_ord_allinone_card_trade_di', '园区一卡通交易明细', '1行=1笔一卡通交易（购卡 / 充值 / 工本费 / 押金 / 消费 / 退款）', '、'.join(_aio + ['ods_ord_park_card_order_df']),
     '园区一卡通（实体卡 / 腕带 / IC 卡）：卡操作类交易 + 卡消费支付 + 卡消费退款 + IC 卡购卡订单四类流水 UNION ALL；本金、奖励金分开记，退款为负',
     _aio, [
         ('trade_source', S, '状态类型', '流水来源：CARD_OP-卡操作（充值 / 工本费 / 押金…）/ PAY-卡消费 / REFUND-卡消费退款', ("'CARD_OP'", "'PAY'", "'REFUND'")),
         ('trade_id', B, '主键', '流水ID（与 trade_source 联合唯一）', ('id', 'id', 'id')),
         ('trade_no', S, '业务主键', '交易流水订单号（退款为退款单号）', ('ordernum', 'ordernum', 'refund_order_num')),
         ('related_trade_no', S, '外键', '退款对应的原消费流水号', (NUL[S], NUL[S], 'ordernum')),
         ('trade_type', S, '状态类型', '交易类型：卡操作取 operation_type（1-充值 2-工本费 3-押金 …），消费为 CONSUME，退款为 REFUND',
          ('CAST(operation_type AS STRING)', "'CONSUME'", "'REFUND'")),
         ('supplier_id', B, '外键', '供应商ID（租户ID），关联 dim_sup_member_df', ('sid', 'sid', 'sid')),
         ('member_id', B, '外键', '持卡用户ID', ('member_id', 'member_id', 'member_id')),
         ('counterparty_member_id', B, '外键', '转账接收方用户ID（消费时的收款方）', (NUL[B], 'order_member_id', NUL[B])),
         ('card_id', B, '外键', '开卡记录ID', ('aio_card_id', NUL[B], NUL[B])),
         ('card_no_mask', S, '维度属性', '实体卡号（ODS 已脱敏）', ('card_no', NUL[S], NUL[S])),
         ('wrist_id', B, '外键', '腕带ID', ('wrist_id', NUL[B], NUL[B])),
         ('site_id', B, '外键', '站点ID', ('site_id', NUL[B], NUL[B])),
         ('sub_merchant_id', B, '外键', '子商户ID', ('sub_merchant_id', NUL[B], NUL[B])),
         ('pay_type', I, '状态类型', '支付方式：1-现金 2-支付宝 …（卡操作）', ('pay_type', NUL[I], NUL[I])),
         ('channel', I, '状态类型', '操作渠道：1-云票务 2-微商城 …', ('channel', NUL[I], NUL[I])),
         ('operator_id', B, '外键', '操作员ID，关联 dim_sup_staff_df', ('operate_id', 'operate_id', 'operate_id')),
         ('trade_amt', DEC, '度量', '交易金额（元），退款为负', (yuan('money'), yuan('money'), f"-{yuan('refund_money')}")),
         ('principal_amt', DEC, '度量', '卡本金发生额（元），退款为负', (yuan('physical_principal'), yuan('balance_pay_money'), f"-{yuan('balance_refund_money')}")),
         ('bonus_amt', DEC, '度量', '卡奖励金发生额（元），退款为负', (yuan('physical_bonus'), yuan('award_pay_money'), f"-{yuan('award_refund_money')}")),
         ('principal_balance_amt', DEC, '度量', '交易后卡本金余额（元）', (yuan('physical_principal_balance'), NUL[DEC], NUL[DEC])),
         ('bonus_balance_amt', DEC, '度量', '交易后卡奖励金余额（元）', (yuan('physical_bonus_balance'), NUL[DEC], NUL[DEC])),
         ('pay_status', I, '状态类型', '消费支付状态：1-未支付 2-已支付 3-…', (NUL[I], 'pay_status', NUL[I])),
         ('refund_status', I, '状态类型', '退款状态（消费：1-未退 2-部分退 …；退款：1-失败 2-成功）', (NUL[I], 'refund_status', 'refund_status')),
         ('trade_time', S, '时间', '交易时间', (ts('create_time'), ts('create_time'), ts('create_time'))),
     ], legacy=[r'^dwd_(pft_)?(allinone|aio)_?card'],
     notes=['四类流水 UNION ALL（IC 卡购卡订单为全量快照，按下单日取当日）；金额统一分 → 元、退款取负，SUM 即净额；消费笔数统计时过滤 pay_status = 2（已支付）、退款过滤 refund_status = 2（成功）',
            '旧系统 dws_tps_aioc_summary_* 把 operation1~10 做成透视列，这里保留 trade_type 一列，DWS 按行汇总'])
# 第 4 分支：IC 卡购卡订单（园区卡订单，全量快照按下单日取当日）
_ic = {'trade_source': "'IC_ORDER'", 'trade_id': 'id', 'trade_no': 'ordernum', 'trade_type': "'IC_CARD_BUY'", 'supplier_id': 'sid', 'member_id': 'member_id',
       'card_id': 'card_id', 'operator_id': 'op_id', 'trade_amt': yuan('money'), 'trade_time': ts('order_time')}
SPECS[-1]['branches'].append('ods_ord_park_card_order_df')
SPECS[-1]['cols'] = [(n, ty, cat, cm, e + (_ic.get(n, NUL[ty]),)) for n, ty, cat, cm, e in SPECS[-1]['cols']]
SPECS[-1]['event'] = {'ods_ord_park_card_order_df': day('order_time')}
proc('dwd_opr_hotel_order_df', '酒店订单', '1行=1张酒店订单（绿云账号，当日最新状态）', 'ods_opr_hotel_lvyun_hotel_master_df',
     '绿云 PMS 订单：预订 / 入住 / 离店状态、房型、房数、房价、消费与付款；间夜 = 房数 × 入住晚数',
     ['ods_opr_hotel_lvyun_hotel_master_df'], [
         ('hotel_order_id', B, '主键', '绿云订单记录ID', 'id'),
         ('supplier_id', B, '外键', '供应商ID（租户ID），关联 dim_sup_member_df', 'member_id'),
         ('con_sys_bind_id', B, '外键', '对接系统绑定ID（base_con_sys_bind）', 'con_sys_bind'),
         ('hotel_code', S, '外键', '酒店代码', 'hotel_code'), ('hotel_name', S, '维度属性', '酒店名称', 'hotel_name'),
         ('account_no', S, '业务主键', '绿云账号（一间房一个账号）', 'accnt'),
         ('order_status', S, '状态类型', '订单状态（绿云 sta：R-预订 I-在住 O-离店 X-取消 …）', 'sta'),
         ('reserve_no', S, '外键', '预订号', 'rsv_no'), ('ota_order_no', S, '外键', 'OTA 订单号', 'ota_rsv_no'),
         ('group_account_no', S, '外键', '团队账号', 'grp_accnt'),
         ('company_id', B, '外键', '协议单位ID', 'compan_id'), ('source_id', B, '外键', '订房中心ID', 'source_id'), ('agent_id', B, '外键', '旅行社ID', 'agent_id'),
         ('market_code', S, '状态类型', '市场码', 'market'), ('source_code', S, '状态类型', '来源码', 'src'),
         ('rate_code', S, '状态类型', '房价码', 'rate_code'), ('channel_code', S, '状态类型', '渠道代码', 'channel'),
         ('reserve_type', S, '状态类型', '预订类型', 'rsv_type'), ('room_type_code', S, '状态类型', '房型', 'rmtype'),
         ('room_no', S, '维度属性', '房号', 'rmno'),
         ('room_qty', B, '度量', '房数', 'CAST(rmnum AS BIGINT)'),
         ('night_qty', B, '度量', '入住晚数 = 离日 − 到日', 'CAST(DATEDIFF(TO_DATE(dep), TO_DATE(arr)) AS BIGINT)'),
         ('room_rate_amt', DEC, '度量', '房价（元 / 间夜）', 'CAST(real_rate AS DECIMAL(18,2))'),
         ('charge_amt', DEC, '度量', '消费合计（元）', 'CAST(charge AS DECIMAL(18,2))'),
         ('pay_amt', DEC, '度量', '付款合计（元）', 'CAST(pay AS DECIMAL(18,2))'),
         ('deposit_amt', DEC, '度量', '预付款（元）', 'CAST(deposit AS DECIMAL(18,2))'),
         ('adult_qty', B, '度量', '成人数', 'CAST(adult AS BIGINT)'), ('child_qty', B, '度量', '儿童数', 'CAST(children AS BIGINT)'),
         ('arrive_date', S, '时间', '到店日期', 'TO_DATE(arr)'), ('depart_date', S, '时间', '离店日期', 'TO_DATE(dep)'),
         ('reserve_time', S, '时间', '预订时间', 'rsv_date'), ('create_time', S, '时间', '创建时间', 'create_date'), ('modify_time', S, '时间', '修改时间', 'modify_date'),
     ],
     notes=['酒店订单状态会变（预订 → 在住 → 离店 / 取消），存全量快照；在住间夜按「到日 ≤ 统计日 < 离日」取当日在住订单',
            '预订人姓名 / 电话、会员卡、备注不进 DWD（ODS 已脱敏，事实表不需要）'])

# ---------------------------------------------------------------- B3 资源中心
proc('dwd_prd_resource_purchase_di', '资源采购明细', '1行=1次资源采购操作（自动 / 手动，含失败）', 'ods_prd_resource_purchase_recode_list_df',
     '分销商在资源中心采购供应商产品的每一次操作：成功 / 待采购 / 失败及原因、分销差价、自动分销分组',
     ['ods_prd_resource_purchase_recode_list_df'], [
         ('purchase_record_id', B, '主键', '采购记录ID', 'id'),
         ('supplier_id', B, '外键', '资源供应商ID，关联 dim_sup_member_df', 'sid'),
         ('purchaser_id', B, '外键', '采购分销商ID，关联 dim_sup_member_df', 'fid'),
         ('product_id', B, '外键', '产品ID，关联 dim_prd_product_df', 'pid'), ('ticket_id', B, '外键', '票ID，关联 dim_prd_ticket_df', 'ticket_id'),
         ('purchase_status', I, '状态类型', '采购结果：1-成功 2-待采购 …', 'status'),
         ('purchase_mode', I, '状态类型', '采购方式：0-按采购规则自动 1-按规则手动 …', 'operation_status'),
         ('fail_reason', S, '维度属性', '采购失败原因', 'reason'),
         ('price_spread_amt', DEC, '度量', '分销差价（元）', yuan('price_spread')),
         ('auto_group_ids', S, '维度属性', '自动分销的分组列表（逗号分隔）', 'group_ids'),
         ('all_distributor_flag', I, '状态类型', '是否默认分销给所有分销商：0-否 1-是', 'all_distributor'),
         ('operator_id', B, '外键', '操作员ID', 'opid'),
         ('purchase_time', S, '时间', '采购操作时间', ts('add_time')), ('update_time', S, '时间', '更新时间', ts('update_time')),
     ], event={'ods_prd_resource_purchase_recode_list_df': day('add_time')},
     notes=['采购记录表为全量快照，按操作日 = bizdate 取当日采购事件；当前采购关系（是否已采购）仍以 ods_prd_resource_purchase_df 为准（资源中心订单关联用）'])
_rop = ['ods_prd_resource_product_record_df', 'ods_prd_resource_salesman_log_df', 'ods_prd_resource_amount_operation_track_df']
proc('dwd_prd_resource_operation_di', '资源变更与操作明细', '1行=1条资源操作（产品上下架 / 修改、业务员变更、保证金 / 金额操作）', '、'.join(_rop),
     '资源中心运营动作统一为操作事件：产品上下架与修改、景区业务员变更、保证金等金额操作（operation_source 区分）',
     _rop, [
         ('operation_source', S, '状态类型', '操作来源：PRODUCT-产品上下架 / 修改 SALESMAN-业务员变更 AMOUNT-金额操作', ("'PRODUCT'", "'SALESMAN'", "'AMOUNT'")),
         ('record_id', B, '主键', '记录ID（与 operation_source 联合唯一）', ('id', 'id', 'id')),
         ('supplier_id', B, '外键', '供应商 / 用户ID，关联 dim_sup_member_df', ('sid', 'sid', 'member_id')),
         ('product_id', B, '外键', '产品ID', ('pid', NUL[B], NUL[B])),
         ('scenic_id', B, '外键', '景区ID', (NUL[B], 'lid', NUL[B])),
         ('salesman_id', B, '外键', '业务员ID，关联 dim_sup_staff_df', (NUL[B], 'salesman_id', NUL[B])),
         ('operation_type', S, '状态类型', '操作类型：产品 0-下架 1-上架 2-修改；业务员为资源选项；金额为「追踪类型-操作类型」',
          ('CAST(operate_type AS STRING)', 'CAST(resource_type AS STRING)', "CONCAT(CAST(track_type AS STRING), '-', CAST(op_type AS STRING))")),
         ('operation_content', S, '维度属性', '操作内容（产品修改 JSON / 金额备注）', ('daction', NUL[S], 'msg')),
         ('counterparty_member_id', B, '外键', '交易对方用户ID', (NUL[B], NUL[B], 'trad_member_id')),
         ('order_no', S, '外键', '订单号', (NUL[S], NUL[S], 'ordernum')), ('serial_no', S, '外键', '流水号', (NUL[S], NUL[S], 'serial_num')),
         ('operation_amt', DEC, '度量', '操作金额（元）', (NUL[DEC], NUL[DEC], yuan('money'))),
         ('balance_amt', DEC, '度量', '操作后余额（元）', (NUL[DEC], NUL[DEC], yuan('balance'))),
         ('operator_id', B, '外键', '操作人ID', ('operator_id', NUL[B], 'opid')),
         ('operation_time', S, '时间', '操作时间', ('record_time', ts('update_time'), ts('add_time'))),
     ], event={'ods_prd_resource_product_record_df': "DATE_FORMAT(record_time, 'yyyyMMdd')", 'ods_prd_resource_salesman_log_df': day('update_time'),
               'ods_prd_resource_amount_operation_track_df': day('add_time')},
     notes=['3 张操作记录表（均为全量快照）按各自操作时间取当日事件后 UNION ALL'])

# ---------------------------------------------------------------- B4 渠道对接
proc('dwd_trf_api_order_di', 'OTA / API 对接订单明细', '1行=1张对接订单（当日新增 / 变更）', 'ods_trf_all_api_order_di、ods_trf_api_order_track_di',
     'OTA / 第三方系统对接订单：平台订单号 ↔ 对接方订单号、对接系统、状态、凭证码查询、失败原因；报文交互次数取自 api_order_track',
     ['ods_trf_all_api_order_di'], [
         ('api_order_id', B, '主键', '对接订单记录ID', 'id'),
         ('order_no', S, '外键', '平台订单号，关联 dwd_ord_order_di', 'pftorder'),
         ('api_order_no', S, '业务主键', '对接方订单号', 'apiorder'), ('remote_order_no', S, '外键', '远端订单号', 'remoteorder'),
         ('temp_order_no', S, '外键', '临时订单号', 'temporder'),
         ('con_sys_id', B, '外键', '对接系统（合作商家）ID，关联 dim_trf_channel_f', 'coopb'),
         ('api_product_code', B, '外键', '对接方商品编码', 'bcode'),
         ('distributor_id', B, '外键', '分销商ID，关联 dim_sup_member_df', 'fid'),
         ('api_order_status', I, '状态类型', '对接订单状态：0-未使用 1-已使用 2-…', 'ostatus'),
         ('handle_status', I, '状态类型', '处理状态', 'handlestatus'),
         ('query_status', I, '状态类型', '查询状态：1-可核销 0-不可核销 2-…', 'select_status'),
         ('code_query_status', I, '状态类型', '向第三方请求消费码状态', 'code_query_status'),
         ('fail_flag', I, '状态类型', '是否对接失败：错误信息非空为 1', "IF(COALESCE(errormsg, '') <> '', 1, 0)"),
         ('error_msg', S, '维度属性', '错误信息', 'errormsg'),
         ('ticket_qty', B, '度量', '订单票数', 'ostnum'),
         ('interact_qty', B, '度量', '当日报文交互次数', 'COALESCE(interact_qty, 0)'),
         ('create_time', S, '时间', '记录时间', 'ctime'), ('update_time', S, '时间', '更新时间', 'utime'),
         ('query_time', S, '时间', '最近查询订单状态时间', ts('select_time')),
     ], legacy=['ods_third_purchase_order_d_f'][:0],
     frm={'ods_trf_all_api_order_di': "(\n        SELECT a.*, k.interact_qty\n        FROM (SELECT *, ROW_NUMBER() OVER (PARTITION BY id ORDER BY utime DESC) AS rn\n"
                                      "              FROM ods.ods_trf_all_api_order_di WHERE travel_date = '${bizdate}') a\n"
                                      "        LEFT JOIN (SELECT pftorder, COUNT(1) AS interact_qty FROM ods.ods_trf_api_order_track_di\n"
                                      "                   WHERE travel_date = '${bizdate}' GROUP BY pftorder) k\n"
                                      "          ON k.pftorder = a.pftorder\n        WHERE a.rn = 1      -- 同一记录当日多次变更取最新\n    ) t"},
     notes=['游客信息（tourist_info）与请求 / 响应报文不进 DWD：游客以 dwd_ord_traveler_di 为准，报文只保留交互次数',
            '待确认：对接失败口径（errormsg 非空 vs handlestatus 码值）上线前与渠道对接组确认'])
proc('dwd_trf_promoter_order_df', '全民分销推广订单', '1行=1张推广 / 分销订单（当日最新状态）', 'ods_trf_all_dis_orders_df、ods_trf_distribute_order_df',
     '全民营销（旧版三级分佣）与新版分销员推广两套订单 UNION ALL：推广员、下单人、票数、订单金额、佣金、发放状态',
     ['ods_trf_all_dis_orders_df', 'ods_trf_distribute_order_df'], [
         ('promote_source', S, '状态类型', '来源：ALL_DIS-全民营销 / DISTRIBUTE-分销员推广', ("'ALL_DIS'", "'DISTRIBUTE'")),
         ('promote_order_id', B, '主键', '推广订单记录ID（与来源联合唯一）', ('id', 'id')),
         ('order_no', S, '外键', '平台订单号，关联 dwd_ord_order_di', ('order_id', 'order_num')),
         ('supplier_id', B, '外键', '供应商ID（租户ID）', ('sid', 'sid')),
         ('scenic_id', B, '外键', '景区ID', (NUL[B], 'land_id')), ('ticket_id', B, '外键', '票ID', (NUL[B], 'ticket_id')),
         ('product_id', B, '外键', '产品ID', ('pid', NUL[B])),
         ('promoter_id', B, '外键', '推广员（一级 / 直推分销员）ID', ('dis_id', 'seller_id')),
         ('buyer_member_id', B, '外键', '下单用户ID', ('member_id', 'order_member_id')),
         ('promote_type', I, '状态类型', '全民营销类型：0-逆推三级 1-正算三级；分销员推广为空', ('all_dis_type', NUL[I])),
         ('self_buy_flag', I, '状态类型', '是否自购订单：0-否 1-是', ('is_self', NUL[I])),
         ('ticket_qty', B, '度量', '票数', ('tnum', 'ticket_num')),
         ('order_amt', DEC, '度量', '订单金额（元）', (yuan('total_money'), yuan('real_pay_money'))),
         ('commission_amt', DEC, '度量', '佣金（元）：全民营销 = 开发 + 推荐佣金；分销员 = 总佣金', (f"{yuan('develop_money')} + {yuan('recommend_money')}", yuan('total_reward'))),
         ('profit_amt', DEC, '度量', '订单利润（元）', (yuan('profit'), NUL[DEC])),
         ('order_status', S, '状态类型', '订单状态', ('CAST(order_status AS STRING)', 'order_status')),
         ('commission_status', S, '状态类型', '佣金发放状态', ('CAST(last_status AS STRING)', 'reward_status')),
         ('delete_flag', I, '状态类型', '是否删除：0-否 1-是', ('0', 'is_delete')),
         ('order_time', S, '时间', '下单时间', (ts('create_time'), 'order_time')),
         ('settle_time', S, '时间', '佣金发放 / 结算时间', (ts('complete_time'), 'settle_time')),
         ('verify_time', S, '时间', '核销时间', (NUL[S], 'write_off_time')),
     ], legacy=['dwd_all_dis_orders_d_f'],
     notes=['两套推广订单字段不同，按业务含义对齐后 UNION ALL；推广订单有佣金发放状态变化，存全量快照',
            '待确认：distribute_order.real_pay_money 为字符串，单位按分处理，上线前核对'])

# ---------------------------------------------------------------- B5 SaaS 服务
proc('dwd_opr_sms_send_di', '订单短信发送明细', '1行=1条订单短信', 'ods_opr_sms_journal_di',
     '平台订单短信：发送平台、条数（计费）、API 发送状态、用户接收状态、是否重发；短信正文不进数仓',
     ['ods_opr_sms_journal_di'], [
         ('sms_id', B, '主键', '短信记录ID', 'id'),
         ('supplier_id', B, '外键', '供应商ID（租户ID）', 'aid'),
         ('order_no', S, '外键', '订单号', 'ordernum'),
         ('phone_mask', S, '维度属性', '手机号（ODS 已脱敏）', 'mobile'),
         ('supplier_sms_flag', I, '状态类型', '是否供应商短信：1-供应商 0-分销商', "IF(tob = 'Y', 1, 0)"),
         ('platform_id', I, '状态类型', '短信发送平台ID', 'platformid'),
         ('send_channel', I, '状态类型', '发送渠道：1-平台 2-消息中心', 'channel'),
         ('api_code', I, '状态类型', 'API 调用发送状态', 'api_code'), ('report_code', I, '状态类型', '用户接收状态', 'report_code'),
         ('resend_flag', I, '状态类型', '是否重发：0-否 1-是', 'is_resend'),
         ('word_qty', B, '度量', '字数', 'CAST(wordscnt AS BIGINT)'), ('sms_qty', B, '度量', '计费条数', 'CAST(msgcnt AS BIGINT)'),
         ('send_time', S, '时间', '最后发送时间', ts('send_time')), ('report_time', S, '时间', '接收回执时间', ts('report_time')),
     ], notes=['短信正文（smstxt）含游客信息，不进 DWD；待确认：api_code / report_code 成功码值上线前与短信平台确认'])

# ---------------------------------------------------------------- B7 财务结算
proc('dwd_fin_invoice_di', '开票明细', '1行=1次开票（电子发票）', 'ods_fin_invoice_records_df',
     '游客 / 企业在订单上的开票记录：开票类型、发票状态、对接系统、开票渠道、红冲信息',
     ['ods_fin_invoice_records_df'], [
         ('invoice_record_id', B, '主键', '开票记录ID', 'id'),
         ('supplier_id', B, '外键', '供应商ID（租户ID）', 'sid'), ('member_id', B, '外键', '用户ID', 'member_id'),
         ('order_no', S, '外键', '订单号', 'ordernum'), ('out_trade_no', S, '外键', '订单流水号', 'out_trade_no'),
         ('invoice_serial_no', S, '业务主键', '开票平台流水号', 'serial_num'),
         ('invoice_code', S, '维度属性', '发票代码', 'invoice_code'), ('invoice_no', S, '维度属性', '发票号码', 'invoice_num'),
         ('enterprise_name', S, '维度属性', '开票企业名称', 'enterprise_name'), ('tax_no', S, '维度属性', '企业税号', 'tariff_number'),
         ('con_sys_id', I, '外键', '对接系统ID', 'sys_id'),
         ('invoice_type', I, '状态类型', '发票类型：0-增值税普通电子发票 1-…', 'invoice_type'),
         ('records_type', I, '状态类型', '开票方式：1-普通 2-合并 3-…', 'records_type'),
         ('invoice_status', I, '状态类型', '开票状态：0-未开票 1-进行中 2-…', 'invoice_status'),
         ('order_type', I, '状态类型', '订单类型：1-普通订单 2-旅游券订单', 'order_type'),
         ('red_flag', I, '状态类型', '是否有红冲：红票信息非空为 1', "IF(COALESCE(red_info, '') <> '', 1, 0)"),
         ('invoice_source', S, '维度属性', '开票渠道', 'source'), ('fail_reason', S, '维度属性', '开票失败原因', 'reason'),
         ('operator_id', B, '外键', '操作员ID', 'operator_id'),
         ('invoice_time', S, '时间', '开票时间', ts('add_time')),
     ], event={'ods_fin_invoice_records_df': day('add_time')},
     notes=['开票记录为全量快照，按开票日 = bizdate 取当日开票；取票人电话 / 身份证、原始订单报文不进 DWD',
            '待确认：开票金额不在列上（在 original_order_info 报文里），按订单号关联 dwd_ord_order_di 取订单金额，或上线前确认报文字段'])

# ---------------------------------------------------------------- B8 客户经营
proc('dwd_sup_crm_sales_order_df', 'CRM 销售订单', '1行=1张 CRM 销售订单（当日最新状态）', 'ods_sup_crm_sales_order_df',
     '纷享销客销售订单（平台向商户卖系统 / 服务）：客户、商机、销售金额、回款、开票、退款、生命状态；209 列只取业务必需的 25 列',
     ['ods_sup_crm_sales_order_df'], [
         ('crm_order_id', B, '主键', 'CRM 订单ID', 'id'), ('crm_order_name', S, '维度属性', '订单名称', 'name'),
         ('crm_account_id', S, '外键', 'CRM 客户ID，关联 dim_sup_company_df', 'account_id'), ('crm_account_name', S, '维度属性', 'CRM 客户名称', 'account_id__r'),
         ('opportunity_id', S, '外键', '商机ID', 'new_opportunity_id'),
         ('owner_department_id', S, '外键', '负责人主属部门ID', 'owner_department_id'), ('owner_department', S, '维度属性', '负责人主属部门', 'owner_department'),
         ('customer_type', S, '维度属性', '客户类型', 'field_2uy29__c'), ('scenic_type', S, '维度属性', '景区类型', 'field_8ys5r__c'),
         ('province_name', S, '维度属性', '省', 'field_xjw8n__c'), ('city_name', S, '维度属性', '城市', 'field_jfo4a__c'),
         ('standard_contract_flag', I, '状态类型', '是否标准合同', 'field_a4xac__c'), ('installment_flag', I, '状态类型', '是否分期付', 'field_aril1__c'),
         ('life_status', S, '状态类型', '生命状态', 'life_status'), ('receipt_status', S, '状态类型', '开票完成状态', 'receipt_status'),
         ('logistics_status', S, '状态类型', '发货状态', 'logistics_status'),
         ('order_amt', DEC, '度量', '销售金额（元）', 'CAST(order_amount AS DECIMAL(18,2))'),
         ('product_amt', DEC, '度量', '产品合计（元）', 'CAST(product_amount AS DECIMAL(18,2))'),
         ('payment_amt', DEC, '度量', '已回款金额（元）', 'CAST(payment_amount AS DECIMAL(18,2))'),
         ('receipt_amt', DEC, '度量', '已开票金额（元）', 'CAST(receipt_amount AS DECIMAL(18,2))'),
         ('no_receipt_amt', DEC, '度量', '待开票金额（元）', 'CAST(no_receipt_amount AS DECIMAL(18,2))'),
         ('refund_amt', DEC, '度量', '已退款金额（元）', 'CAST(refund_amount AS DECIMAL(18,2))'),
         ('order_time', S, '时间', '订单时间', 'order_time'), ('create_time', S, '时间', '创建时间', 'create_time'),
         ('last_modified_time', S, '时间', '最后修改时间', 'last_modified_time'),
     ], notes=['CRM 订单回款 / 开票金额随时间变化，存全量快照；金额在 CRM 中为字符串（元），CAST 为 DECIMAL',
               '与已下线的 OA 合同链路无关：这是 CRM（纷享）侧订单，业务仍在用（数据中心 / 客户属性）'])

# ---------------------------------------------------------------- B6 营销
proc('dwd_mkt_coupon_use_di', '优惠券使用明细', '1行=1次用券（一单可用多张券）', 'ods_mkt_coupon_use_log_df',
     '游客下单使用优惠券：订单、合并付款单、券码、抵扣金额、占用 / 使用 / 释放状态',
     ['ods_mkt_coupon_use_log_df'], [
         ('coupon_use_id', B, '主键', '用券记录ID', 'id'),
         ('supplier_id', B, '外键', '优惠券供应商ID', 'aid'), ('member_id', B, '外键', '用券用户ID', 'fid'),
         ('order_no', S, '外键', '使用订单号', 'use_order_num'), ('trade_no', S, '外键', '支付订单号（合并付款）', 'tradeid'),
         ('coupon_code', S, '维度属性', '券码（多张逗号分隔）', 'coupon_code'),
         ('use_status', I, '状态类型', '状态：1-占用中 2-已使用 3-已释放', 'status'),
         ('coupon_qty', B, '度量', '用券张数', "CAST(SIZE(SPLIT(coupon_code, ',')) AS BIGINT)"),
         ('deduct_amt', DEC, '度量', '抵扣金额（元）', yuan('all_use_coupon_money')),
         ('use_time', S, '时间', '使用时间', ts('use_time')),
     ], event={'ods_mkt_coupon_use_log_df': day('use_time')}, notes=['按用券日 = bizdate 取当日；统计实际抵扣时过滤 use_status = 2（已使用），占用后释放的不计'])
proc('dwd_mkt_seckill_di', '抢购参与明细', '1行=1次抢购下单任务（成功 / 失败）', 'ods_mkt_seckill_log_df、ods_mkt_seckill_v2_df',
     '抢购活动的每次下单任务：活动、票、用户、票数、订单金额、新老客、销售渠道；成功即有订单号',
     ['ods_mkt_seckill_log_df'], [
         ('seckill_log_id', B, '主键', '抢购记录ID', 'id'),
         ('seckill_id', B, '外键', '抢购活动ID，关联 dim_mkt_activity_df', 'seckill_id'), ('activity_id', B, '外键', '营销主活动ID', 'activity_id'),
         ('supplier_id', B, '外键', '供应商ID（活动发布方）', 'sid'),
         ('ticket_id', B, '外键', '票ID', 'tid'), ('member_id', B, '外键', '下单用户ID', 'member_id'),
         ('order_no', S, '外键', '成功订单号', 'ordernum'),
         ('success_flag', I, '状态类型', '是否抢购成功：有订单号为 1', "IF(COALESCE(ordernum, '') <> '', 1, 0)"),
         ('new_customer_flag', I, '状态类型', '是否新客：0-否 1-是', 'is_new'), ('sale_channel', I, '状态类型', '销售渠道：1-微商城 2-小程序', 'sale_channel'),
         ('cycle_key', S, '维度属性', '周期标识', 'cycle_key'),
         ('ticket_qty', B, '度量', '票数', 'tnum'), ('order_amt', DEC, '度量', '订单总价（元）', yuan('money')),
         ('play_date', S, '时间', '游玩日期', "FROM_UNIXTIME(play_time, 'yyyy-MM-dd')"), ('join_time', S, '时间', '抢购时间', ts('create_time')),
     ], frm={'ods_mkt_seckill_log_df': "(\n        SELECT l.*, s.sid\n        FROM ods.ods_mkt_seckill_log_df l\n"
                                        "        LEFT JOIN (SELECT id, MAX(sid) AS sid FROM ods.ods_mkt_seckill_v2_df WHERE travel_date = '${bizdate}' GROUP BY id) s\n"
                                        "          ON s.id = l.seckill_id\n"
                                        "        WHERE l.travel_date = '${bizdate}' AND FROM_UNIXTIME(l.create_time, 'yyyyMMdd') = '${bizdate}'   -- 全量快照取当日\n    ) t"},
     notes=['抢购日志为全量快照，按抢购时间 = bizdate 取当日；供应商取自抢购活动表（日志表没有）'])
proc('dwd_mkt_group_booking_di', '拼团订单明细', '1行=1张拼团订单', 'ods_mkt_group_booking_orders_df、ods_mkt_group_booking_df',
     '拼团活动产生的订单：活动、开团、票 / 景区、拼团价、销售渠道',
     ['ods_mkt_group_booking_orders_df'], [
         ('group_order_id', B, '主键', '拼团订单记录ID', 'id'), ('order_no', S, '外键', '订单号', 'ordernum'),
         ('supplier_id', B, '外键', '供应商ID（租户ID）', 'sid'), ('member_id', B, '外键', '用户ID', 'mid'),
         ('activity_id', B, '外键', '营销主活动ID', 'activity_id'), ('group_id', B, '外键', '拼团活动ID，关联 dim_mkt_activity_df', 'group_id'),
         ('scenic_id', B, '外键', '景区ID', 'lid'), ('ticket_id', B, '外键', '票ID', 'tid'),
         ('sale_channel', I, '状态类型', '销售渠道：1-微商城 2-小程序', 'sale_channel'),
         ('group_price_amt', DEC, '度量', '拼团价（元）', yuan('price')),
         ('valid_man_qty', B, '度量', '成团人数要求', 'CAST(valid_mans AS BIGINT)'),
         ('order_time', S, '时间', '拼团下单时间', ts('create_time')),
     ], frm={'ods_mkt_group_booking_orders_df': "(\n        SELECT o.*, g.lid, g.tid, g.price, g.valid_mans\n        FROM ods.ods_mkt_group_booking_orders_df o\n"
                                                 "        LEFT JOIN ods.ods_mkt_group_booking_df g ON g.id = o.group_id AND g.travel_date = '${bizdate}'   -- 活动主键唯一，不放大\n"
                                                 "        WHERE o.travel_date = '${bizdate}' AND FROM_UNIXTIME(o.create_time, 'yyyyMMdd') = '${bizdate}'\n    ) t"},
     notes=['拼团订单为全量快照，按下单时间 = bizdate 取当日；成团结果在 group_booking_open（开团表），需要时按 group_id 关联'])
proc('dwd_mkt_cut_price_di', '砍价参与明细', '1行=1次发起砍价（当日新增）', 'ods_mkt_cut_price_join_df、ods_mkt_cut_price_df',
     '用户发起砍价：活动、产品、已砍金额、砍价次数、状态（未完成 / 砍价完成 / 下单完成）',
     ['ods_mkt_cut_price_join_df'], [
         ('cut_join_id', B, '主键', '发起砍价记录ID', 'id'), ('cut_id', B, '外键', '砍价活动ID，关联 dim_mkt_activity_df', 'cut_id'),
         ('supplier_id', B, '外键', '供应商ID（租户ID）', 'sid'), ('member_id', B, '外键', '发起用户ID', 'mid'),
         ('product_id', B, '外键', '产品ID', 'pid'), ('order_no', S, '外键', '下单订单号', 'ordernum'),
         ('cut_status', I, '状态类型', '状态：0-未完成 1-砍价完成 2-下单完成', 'status'),
         ('cut_amt', DEC, '度量', '已砍金额（元）', yuan('cut_money')), ('cut_times_qty', B, '度量', '被砍次数', 'CAST(cut_times AS BIGINT)'),
         ('join_time', S, '时间', '发起时间', ts('create_time')), ('update_time', S, '时间', '更新时间', ts('update_time')),
     ], frm={'ods_mkt_cut_price_join_df': "(\n        SELECT j.*, c.pid\n        FROM ods.ods_mkt_cut_price_join_df j\n"
                                           "        LEFT JOIN ods.ods_mkt_cut_price_df c ON c.id = j.cut_id AND c.travel_date = '${bizdate}'\n"
                                           "        WHERE j.travel_date = '${bizdate}' AND FROM_UNIXTIME(j.create_time, 'yyyyMMdd') = '${bizdate}'\n    ) t"},
     notes=['按发起时间 = bizdate 取当日；发起后的状态变化（砍成 / 下单）看次日快照或按 update_time 补'])
proc('dwd_mkt_sms_task_di', '营销短信任务明细', '1行=1个营销短信任务', 'ods_mkt_marketing_sms_task_df',
     '商户创建的营销短信任务：推送人群类型、定时 / 即时、发送状态、发送与完成时间',
     ['ods_mkt_marketing_sms_task_df'], [
         ('task_id', B, '主键', '任务ID', 'id'), ('supplier_id', B, '外键', '创建商户ID', 'uid'),
         ('push_target_type', I, '状态类型', '推送人员类型：1-用户画像 2-…', 'p_type'), ('push_type_id', B, '外键', '推送类型业务ID', 'push_type_id'),
         ('send_state', I, '状态类型', '发送状态：1-待发送 2-发送中 3-…', 'state'), ('sendable_flag', I, '状态类型', '是否可发送：1-准备中 2-可发送', 'is_send'),
         ('timing_flag', I, '状态类型', '是否定时：1-定时 2-非定时', 'is_timing'), ('operator_id', B, '外键', '操作用户ID', 'operater_id'),
         ('send_time', S, '时间', '发送时间', ts('send_time')), ('finish_time', S, '时间', '发送完成时间', ts('finish_time')),
         ('create_time', S, '时间', '创建时间', ts('create_time')),
     ], event={'ods_mkt_marketing_sms_task_df': day('create_time')},
     notes=['按创建日 = bizdate 取当日任务；发送人数 / 成功数不在任务表，按条数需接入营销短信发送流水（待确认）'])

_act = ['ods_mkt_seckill_v2_df', 'ods_mkt_group_booking_df', 'ods_mkt_cut_price_df']
proc('dim_mkt_activity_df', '营销活动维度', '1行=1个营销活动（抢购 / 拼团 / 砍价）', '、'.join(_act),
     '抢购、拼团、砍价三类活动统一为一张活动维度（activity_type 区分）：发布商户、商品、活动价、库存、已售、有效期、是否有效；营销事实表按活动类型 + 活动ID 关联',
     _act, [
         ('activity_type', S, '主键', '活动类型：SECKILL-抢购 GROUP_BOOKING-拼团 CUT_PRICE-砍价', ("'SECKILL'", "'GROUP_BOOKING'", "'CUT_PRICE'")),
         ('activity_record_id', B, '主键', '活动ID（与 activity_type 联合唯一；对应事实表 seckill_id / group_id / cut_id）', ('id', 'id', 'id')),
         ('main_activity_id', B, '外键', '营销主活动ID', ('activity_id', 'activity_id', NUL[B])),
         ('activity_name', S, '维度属性', '活动名称', ('activity_name', NUL[S], NUL[S])),
         ('supplier_id', B, '外键', '发布商户ID（租户ID）', ('sid', 'sid', 'sid')),
         ('parent_supplier_id', B, '外键', '产品上级供应商ID', (NUL[B], 'aid', 'aid')),
         ('scenic_id', B, '外键', '景区ID', (NUL[B], 'lid', NUL[B])), ('ticket_id', B, '外键', '票ID', (NUL[B], 'tid', NUL[B])),
         ('product_id', B, '外键', '产品ID', (NUL[B], NUL[B], 'pid')),
         ('activity_price_amt', DEC, '维度属性', '活动价（元）', (yuan('price'), yuan('price'), yuan('price'))),
         ('storage_qty', B, '维度属性', '活动库存', ('storage', 'storage', 'storage')),
         ('sold_qty', B, '维度属性', '已售数量（快照）', ('quantity_sold', 'sold_num', 'quantity_sold')),
         ('begin_time', S, '时间', '活动开始时间', (ts('`begin`'), ts('`begin`'), ts('`begin`'))),
         ('end_time', S, '时间', '活动结束时间', (ts('`end`'), ts('`end`'), ts('`end`'))),
         ('valid_flag', I, '状态类型', '是否有效（未删除）：1-有效 0-删除', ('IF(status = 1, 1, 0)', 'IF(status = 1, 1, 0)', 'IF(status = 0, 1, 0)')),
         ('create_time', S, '时间', '创建时间', (ts('create_time'), ts('create_time'), ts('create_time'))),
     ], part='',
     notes=['三类活动表状态码相反（抢购 0 删 1 正常；拼团 1 正常 2 删；砍价 0 正常 1 删），统一为 valid_flag', '海报 / 物料中心为营销素材配置，未被在用报表使用，保留 ODS 不进维度'])

# ---------------------------------------------------------------- 新增汇总：一卡通（替代 dws_tps_aioc_summary_* 的透视列）
METRICS = [
    ('L301', 'aio_trade_qty', '一卡通交易笔数', 'ord', '原子指标', '统计日一卡通有效交易笔数（卡操作全计；消费取已支付；退款取成功）',
     '一卡通交易笔数 = COUNT(流水)', '笔', 'BIGINT', 'dwd_ord_allinone_card_trade_di', 'operation1~10_num'),
    ('L302', 'aio_trade_amt', '一卡通交易金额', 'ord', '原子指标', '统计日一卡通有效交易金额，退款为负', '一卡通交易金额 = SUM(交易金额)', '元', 'DECIMAL(18,2)',
     'dwd_ord_allinone_card_trade_di', 'operation1~10_money'),
    ('L303', 'aio_principal_amt', '一卡通本金发生额', 'ord', '原子指标', '统计日卡本金发生额，退款为负', '本金发生额 = SUM(本金)', '元', 'DECIMAL(18,2)', 'dwd_ord_allinone_card_trade_di', 'physical_principal'),
    ('L304', 'aio_bonus_amt', '一卡通奖励金发生额', 'ord', '原子指标', '统计日卡奖励金发生额，退款为负', '奖励金发生额 = SUM(奖励金)', '元', 'DECIMAL(18,2)', 'dwd_ord_allinone_card_trade_di', 'physical_bonus'),
]
DIMS = {'trade_source': ('STRING', '流水来源：CARD_OP / PAY / REFUND / IC_ORDER'), 'trade_type': ('STRING', '一卡通交易类型：1-充值 2-工本费 3-押金 … / CONSUME / REFUND / IC_CARD_BUY'),
        'aio_pay_type': ('INT', '一卡通支付方式：1-现金 2-支付宝 …')}
AIO_WHERE = "(trade_source IN ('CARD_OP', 'IC_ORDER') OR (trade_source = 'PAY' AND pay_status = 2) OR (trade_source = 'REFUND' AND refund_status = 2))"


def register(t, F, model):
    """在 model.T 的 DWD 段末尾登记业务过程表；另登记一卡通 DWS 的维度与指标"""
    for s in SPECS:
        t(s['name'], s['cn'], s['grain'], s['up'], s['note'], F(*[(n, ty, cat, cm, '') for n, ty, cat, cm, _ in s['cols']]), s['legacy'], part=s['part'])
    model.D.update(DIMS)
    for m in METRICS:
        model.METRICS.append(m)
        model.M[m[1]] = m


def register_dws(t, model):
    t('dws_ord_allinone_card_di', '园区一卡通日汇总', '1行=1天×供应商×流水来源×交易类型×支付方式', 'dwd_ord_allinone_card_trade_di',
      '一卡通充值 / 工本费 / 押金 / 消费 / 退款按行汇总；替代 dws_tps_aioc_summary_di / mo / yr 的 operation1~10 透视列与日 / 月 / 年三张表',
      model.dims('supplier_id', 'trade_source', 'trade_type', 'aio_pay_type') + model.mets('aio_trade_qty', 'aio_trade_amt', 'aio_principal_amt', 'aio_bonus_amt'),
      [r'^dws_tps_aioc_summary_'])


def core():
    """etl.CORE 格式的映射"""
    out = {}
    for s in SPECS:
        brs = []
        for i, src in enumerate(s['branches']):
            m = {}
            for n, ty, cat, cm, e in s['cols']:
                x = e[i] if isinstance(e, tuple) else e
                m[n] = f'CAST({x} AS {ty})' if ty != S and re.fullmatch(r'\w+', x) and x != '0' else x
            brs.append((src, m))
        c = {'branches': brs, 'note': s['notes']}
        if s['event']:
            c['event_date'] = s['event']
        if s['frm']:
            c['from'] = s['frm']
        if s['where']:
            c['where'] = s['where']
        out[s['name']] = c
    return out
