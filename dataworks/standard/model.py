"""标准化数仓（旧系统重构）：DIM / DWD / DWS / ADS 设计，以及每张旧表归并到哪张标准表。

字段：DIM / DWD 由归并的旧表字段并集按命名规范标准化（core 列在前）；DWS / ADS 按「维度 + 指标」显式定义，
ADS 统一日粒度，统计周期（周 / 月 / 年 / 节假日 / 自定义）在查询时关联 dim_opr_period_f，与 PFT3.0 一致。
legacy：旧表名或正则（以 ^ 开头），按顺序匹配，先到先得。
"""

# ---------------------------------------------------------------- 公共维度（DWS / ADS 的粒度键）
D = {
    'scenic_id': ('BIGINT', '景区ID，关联 dim_prd_scenic_df'), 'ticket_id': ('BIGINT', '门票ID，关联 dim_prd_ticket_df'),
    'supplier_id': ('BIGINT', '供应商（景区发布商户）ID，关联 dim_sup_member_df'), 'distributor_id': ('BIGINT', '一级分销商ID，关联 dim_sup_member_df'),
    'buyer_id': ('BIGINT', '购买者ID（直接下单的商户 / 会员），关联 dim_sup_member_df'), 'member_id': ('BIGINT', '商户ID，关联 dim_sup_member_df'),
    'order_mode': ('INT', '下单渠道编码，关联 dim_trf_channel_f'), 'pay_mode': ('INT', '支付方式编码，关联 dim_fin_pay_channel_f'),
    'distribute_system_code': ('STRING', '对接分销平台编码（OTA / API），关联 dim_trf_channel_f'),
    'order_role': ('STRING', '主子单：MAIN-主票（含单票）/ SUB-套票子票'), 'team_type': ('STRING', '团散：TEAM-团队 / INDIVIDUAL-散客'),
    'behavior_type': ('STRING', '行为：BOOK-预订 / VERIFY-核销'), 'province_code': ('STRING', '客源省编码（取票人证件 / 手机号归属），关联 dim_opr_region_f'),
    'city_code': ('STRING', '客源市编码，关联 dim_opr_region_f'), 'gender': ('STRING', '性别：M-男 / F-女 / U-未知'),
    'age_group': ('STRING', '年龄段：0-7 / 8-17 / 18-27 / 28-40 / 41-60 / 61+ / 未知'), 'fellow_group': ('STRING', '同行人数段：1 / 2-4 / 5-9 / 10+'),
    'advance_day_group': ('STRING', '提前预订天数段：当天 / 1 / 2-3 / 4-7 / 8-15 / 16-30 / 30+'),
    'terminal_no': ('STRING', '终端号（闸机 / 手持机）'), 'gate_group_id': ('BIGINT', '闸机组ID，关联 dim_trf_gate_f'), 'stat_hour': ('INT', '小时：0~23'),
    'parking_lot_code': ('STRING', '停车场编码'), 'parking_vendor': ('STRING', '停车系统厂商：daoer / daoer5 / ketuo / shuaichen / zhihui'),
    'shop_code': ('STRING', '门店编码'), 'retail_vendor': ('STRING', '零售系统：yinbao-银豹 / sixun-思迅 / xisland-小岛'), 'goods_code': ('STRING', '商品编码'),
    'card_product_id': ('BIGINT', '年卡产品ID'), 'account_id': ('BIGINT', '账户ID'), 'subject_code': ('STRING', '账本科目编码'),
    'contract_no': ('STRING', '合同编号'), 'module_id': ('BIGINT', '应用模块ID，关联 dim_opr_module_package_df'),
    'resource_id': ('BIGINT', '资源中心资源ID，关联 dim_prd_resource_df'), 'page_code': ('STRING', '页面编码'),
    'hotel_code': ('STRING', '酒店编码'), 'main_ticket_id': ('BIGINT', '套票主票门票ID'), 'sub_ticket_id': ('BIGINT', '套票子票门票ID'),
}


def F(*rows):
    """显式字段：(名, 类型, 类别, 注释, 旧字段别名)"""
    return [r if len(r) == 5 else r + ('',) for r in rows]


def dims(*ks):
    return [(k, D[k][0], '粒度键', D[k][1]) for k in ks]


# ---------------------------------------------------------------- 指标（口径）：编码 -> (英文名, 中文名, 业务域, 类型, 业务口径, 计算公式, 单位, 来源明细表, 旧系统字段)
ACTIONS = [('order', '预订', '下单时间', 'dwd_ord_order_di', '统计日内创建的订单（不含测试单）'),
           ('pay', '支付', '支付时间', 'dwd_ord_order_di', '统计日内支付成功的订单'),
           ('cancel', '取消', '取消时间', 'dwd_ord_order_track_di', '统计日内取消（退票）的订单，按取消票数计'),
           ('verify', '验证', '验证时间', 'dwd_ord_verify_di', '统计日内验证（核销）的订单'),
           ('finish', '完结', '完结时间', 'dwd_ord_order_track_di', '统计日内过期自动完结的订单'),
           ('revoke', '撤销', '撤销时间', 'dwd_ord_order_track_di', '统计日内撤销（验证后撤改）的订单'),
           ('print', '取票', '取票时间', 'dwd_ord_order_track_di', '统计日内取票（打印）的订单')]
MEASURES = [('order_qty', '订单数', '单', 'BIGINT', 'COUNT(DISTINCT 订单号)'), ('ticket_qty', '票数', '张', 'BIGINT', 'SUM(票数)'),
            ('sale_amt', '金额', '元', 'DECIMAL(18,2)', 'SUM(销售单价 × 票数) / 100'), ('cost_amt', '成本金额', '元', 'DECIMAL(18,2)', 'SUM(结算单价 × 票数) / 100')]
LEGACY_ALIAS = {'order': 'order_num / ordernum / order_ticket / sale_money / order_cost_money / mo_order_* / no_mo_order_*',
                'pay': 'paid_count / paid_amount / mo_ticket_count / mo_amount / payment_money', 'cancel': 'cancel_num / cancel_ticket / cancel_sale_money / mo_cancel_*',
                'verify': 'verify_num / verify_ticket / verify_sale_money / verify_cost_money / mo_verify_*', 'finish': 'finish_num / finish_ticket / mo_finish_*',
                'revoke': 'revoke_num / revoke_ticket / revoke_sale_money / mo_revoke_*', 'print': 'print_num / mo_print_num'}
METRICS = []
for i, (a, an, tcol, src, kou) in enumerate(ACTIONS):
    for j, (m, mn, unit, typ, f) in enumerate(MEASURES):
        if a == 'print' and m != 'ticket_qty':
            continue
        if a == 'pay' and m == 'cost_amt':
            continue
        METRICS.append((f'L{i + 1:02d}{j + 1}', f'{a}_{m}', f'{an}{mn}', 'ord', '原子指标', f'{kou}；{mn}按{tcol}归日', f'{an}{mn} = {f}；条件：{an}时间在统计日内，排除测试订单（is_test=1）', unit, typ, src, LEGACY_ALIAS[a]))
METRICS += [
    ('L081', 'after_sale_ticket_qty', '售后票数', 'ord', '原子指标', '统计日内发生售后（部分退 / 改签）的票数', '售后票数 = SUM(售后票数)', '张', 'BIGINT', 'dwd_ord_order_track_di', 'after_sale_ticket_num / mo_after_sale_ticket_num'),
    ('L082', 'after_sale_refund_amt', '售后退回金额', 'ord', '原子指标', '售后退回给购买方的金额', '售后退回金额 = SUM(售后退款) / 100', '元', 'DECIMAL(18,2)', 'dwd_ord_order_track_di', 'after_sale_refund_money'),
    ('L083', 'after_sale_income_amt', '售后收入金额', 'ord', '原子指标', '售后产生的手续费等收入', '售后收入金额 = SUM(售后手续费) / 100', '元', 'DECIMAL(18,2)', 'dwd_ord_order_track_di', 'after_sale_income_money / service_money'),
    ('L091', 'traveler_qty', '游客人数', 'cus', '原子指标', '订单上登记的游客人数（主子单分别计）', '游客人数 = COUNT(游客记录)；按行为（预订 / 核销）分别统计', '人', 'BIGINT', 'dwd_ord_traveler_di', 'mo_total / no_mo_total / total / mo_male_age_* …（28 个透视列）'),
    ('L092', 'buyer_qty', '购买人数', 'cus', '原子指标', '统计期内下单的取票人去重人数（证件号哈希），日存位图，任意周期 BITMAP_UNION_COUNT', '购买人数 = COUNT(DISTINCT 买家ID)；买家ID = 取票人证件号哈希，日存位图，任意周期 BITMAP_UNION_COUNT', '人', 'BITMAP', 'dwd_ord_order_di', 'COUNT(DISTINCT personid)（各表各算）'),
    ('L101', 'enter_qty', '入园人次', 'trf', '原子指标', '统计期内闸机 / 手持机入园验证人次', '入园人次 = COUNT(入园记录)', '人次', 'BIGINT', 'dwd_trf_scenic_inout_di', 'in_num / enter_num / terminal_pass'),
    ('L102', 'exit_qty', '出园人次', 'trf', '原子指标', '统计期内出园人次', '出园人次 = COUNT(出园记录)', '人次', 'BIGINT', 'dwd_trf_scenic_inout_di', 'out_num'),
    ('L103', 'in_park_qty', '在园人数', 'trf', '原子指标', '截至统计时点在园人数（快照）', '在园人数 = 累计入园人次 − 累计出园人次（当日）', '人', 'BIGINT', 'dwd_trf_scenic_inout_di', 'in_park / remain'),
    ('L111', 'card_sale_qty', '年卡售卡数', 'ord', '原子指标', '统计日内售出（支付成功）的年卡张数', '年卡售卡数 = COUNT(年卡交易) 条件：交易类型=售卡', '张', 'BIGINT', 'dwd_ord_annual_card_trade_di', 'annual_card_order'),
    ('L112', 'card_sale_amt', '年卡售卡金额', 'ord', '原子指标', '售卡支付金额', '年卡售卡金额 = SUM(支付金额) / 100', '元', 'DECIMAL(18,2)', 'dwd_ord_annual_card_trade_di', ''),
    ('L113', 'card_verify_qty', '年卡核销次数', 'ord', '原子指标', '年卡入园核销次数', '年卡核销次数 = COUNT(年卡核销记录)', '次', 'BIGINT', 'dwd_ord_verify_di', 'annual_card_checked'),
    ('L114', 'card_active_qty', '年卡激活数', 'ord', '原子指标', '统计日内激活的年卡数', '年卡激活数 = COUNT(激活申请) 条件：审核通过', '张', 'BIGINT', 'dwd_ord_annual_card_trade_di', ''),
    ('L121', 'park_entry_qty', '入场车次', 'opr', '原子指标', '停车场入场车次（5 个厂商统一口径）', '入场车次 = COUNT(入场记录)', '车次', 'BIGINT', 'dwd_opr_parking_record_di', 'entry_num'),
    ('L122', 'park_exit_qty', '出场车次', 'opr', '原子指标', '停车场出场车次', '出场车次 = COUNT(出场记录)', '车次', 'BIGINT', 'dwd_opr_parking_record_di', 'exit_num'),
    ('L123', 'park_fee_amt', '停车收费金额', 'opr', '原子指标', '出场时实收停车费', '停车收费金额 = SUM(实收金额) / 100', '元', 'DECIMAL(18,2)', 'dwd_opr_parking_record_di', 'pay_money'),
    ('L124', 'park_minute_qty', '停车总时长', 'opr', '原子指标', '出场车辆停车时长合计（分钟），平均停车时长 = 总时长 / 出场车次', '停车总时长 = SUM(出场时间 − 入场时间)', '分钟', 'BIGINT', 'dwd_opr_parking_record_di', 'park_time'),
    ('L131', 'retail_order_qty', '零售单数', 'opr', '原子指标', '二消门店销售单数（银豹 / 思迅 / 小岛统一口径）', '零售单数 = COUNT(DISTINCT 销售单号) 条件：非退货单', '单', 'BIGINT', 'dwd_opr_retail_order_di', 'order_count'),
    ('L132', 'retail_item_qty', '零售件数', 'opr', '原子指标', '销售商品件数', '零售件数 = SUM(商品数量)', '件', 'BIGINT', 'dwd_opr_retail_order_di', 'sale_num'),
    ('L133', 'retail_sale_amt', '零售销售额', 'opr', '原子指标', '销售实收金额', '零售销售额 = SUM(实收金额)', '元', 'DECIMAL(18,2)', 'dwd_opr_retail_order_di', 'sale_money / total_amount'),
    ('L134', 'retail_refund_amt', '零售退款额', 'opr', '原子指标', '退货退款金额', '零售退款额 = SUM(退款金额)', '元', 'DECIMAL(18,2)', 'dwd_opr_retail_order_di', 'refund_money'),
    ('L141', 'account_income_amt', '账户收入金额', 'fin', '原子指标', '账户流水中的收入（入账）', '账户收入金额 = SUM(金额) 条件：收支方向=收入', '元', 'DECIMAL(18,2)', 'dwd_fin_trade_journal_di', 'income_money'),
    ('L142', 'account_expense_amt', '账户支出金额', 'fin', '原子指标', '账户流水中的支出（出账）', '账户支出金额 = SUM(金额) 条件：收支方向=支出', '元', 'DECIMAL(18,2)', 'dwd_fin_trade_journal_di', 'expense_money'),
    ('L143', 'account_balance_amt', '账户日终余额', 'fin', '原子指标', '截至统计日日终的账户余额（快照）', '账户日终余额 = 取统计日最后一笔流水后的余额', '元', 'DECIMAL(18,2)', 'dwd_fin_trade_journal_di', 'balance'),
    ('L151', 'login_member_qty', '登录商户数', 'sup', '原子指标', '统计日内登录过平台的商户数（去重位图）', '登录商户数 = COUNT(DISTINCT 租户ID)；日存位图，任意周期 BITMAP_UNION_COUNT', '家', 'BITMAP', 'dwd_sup_member_login_di', 'login_num'),
    ('L152', 'new_distributor_qty', '新增分销商数', 'sup', '原子指标', '统计日内新建立分销关系的分销商数', '新增分销商数 = COUNT(DISTINCT 分销商) 条件：关系建立日=统计日', '家', 'BIGINT', 'dim_sup_member_relation_zip', 'distributor_add_count'),
    ('L153', 'distributor_total_qty', '分销商总数', 'sup', '原子指标', '截至统计日有效分销关系数（快照）', '分销商总数 = COUNT(有效分销关系)', '家', 'BIGINT', 'dim_sup_member_relation_zip', 'distributor_total_count'),
    ('L154', 'onshelf_product_qty', '在售产品数', 'sup', '原子指标', '截至统计日上架状态的门票数（快照）', '在售产品数 = COUNT(门票) 条件：状态=上架', '个', 'BIGINT', 'dim_prd_ticket_df', 'product_onshelf'),
    ('L155', 'module_open_qty', '模块开通数', 'opr', '原子指标', '统计日内商户开通应用模块 / 套餐的次数', '模块开通数 = COUNT(开通记录)', '次', 'BIGINT', 'dwd_opr_module_open_di', 'module_open'),
    ('L161', 'contract_amt', '合同金额', 'sup', '原子指标', '统计日签订的合同金额', '合同金额 = SUM(合同金额)', '元', 'DECIMAL(18,2)', 'dwd_sup_contract_event_di', 'htje'),
    ('L162', 'invoice_amt', '开票金额', 'sup', '原子指标', '统计日开票金额', '开票金额 = SUM(开票金额) 条件：事件=开票', '元', 'DECIMAL(18,2)', 'dwd_sup_contract_event_di', 'kpje'),
    ('L163', 'payback_amt', '回款金额', 'sup', '原子指标', '统计日回款金额', '回款金额 = SUM(回款金额) 条件：事件=回款', '元', 'DECIMAL(18,2)', 'dwd_sup_contract_event_di', 'hkje / paid_amount'),
    ('L171', 'resource_purchase_qty', '资源采购数', 'prd', '原子指标', '资源中心统计日采购（上架到分销商）次数', '资源采购数 = COUNT(采购记录)', '次', 'BIGINT', 'dwd_prd_resource_order_di', 'purchase_num'),
    ('L172', 'resource_order_qty', '资源中心订单数', 'prd', '原子指标', '经资源中心产品产生的订单数', '资源中心订单数 = COUNT(DISTINCT 订单号) 条件：资源中心采购商品', '单', 'BIGINT', 'dwd_prd_resource_order_di', 'order_num'),
    ('L181', 'page_pv', '页面浏览量', 'trf', '原子指标', '微商城 / 资源中心页面访问次数', '页面浏览量 = COUNT(访问记录)', '次', 'BIGINT', 'dwd_trf_page_view_di', 'pv'),
    ('L182', 'page_uv_qty', '页面访客数', 'trf', '原子指标', '访问用户去重人数，日存位图，任意周期 BITMAP_UNION_COUNT', '页面访客数 = COUNT(DISTINCT 游客ID)；日存位图，任意周期 BITMAP_UNION_COUNT', '人', 'BITMAP', 'dwd_trf_page_view_di', 'uv'),
    ('L191', 'hotel_room_night_qty', '酒店间夜数', 'opr', '原子指标', '绿云酒店系统统计日入住间夜', '间夜数 = SUM(入住间夜)', '间夜', 'BIGINT', 'ods_opr_hotel_lvyun_hotel_master_df', 'room_nights'),
    ('L192', 'hotel_revenue_amt', '酒店营收', 'opr', '原子指标', '统计日客房营收', '酒店营收 = SUM(客房收入)', '元', 'DECIMAL(18,2)', 'ods_opr_hotel_lvyun_hotel_master_df', 'revenue'),
    ('L201', 'cancel_ticket_rate', '退票率', 'ord', '计算指标', '取消票数 / 预订票数', '退票率 = 取消票数*100/预订票数', '%', 'DECIMAL(20,6)', 'dws_ord_scenic_ticket_trade_di', 'refund_ratio（各表分别计算）'),
    ('L202', 'verify_ticket_rate', '核销率', 'ord', '计算指标', '验证票数 / 预订票数', '核销率 = 验证票数*100/预订票数', '%', 'DECIMAL(20,6)', 'dws_ord_scenic_ticket_trade_di', 'verify_rate'),
    ('L203', 'avg_order_amt', '客单价', 'ord', '计算指标', '预订金额 / 预订订单数', '客单价 = 预订金额/预订订单数', '元', 'DECIMAL(18,2)', 'dws_ord_scenic_ticket_trade_di', 'avg_price'),
]
M = {x[1]: x for x in METRICS}


def mets(*names, cat='指标'):
    return [(n, M[n][8], cat, f'{M[n][2]}：{M[n][5]}（{M[n][7]}）') for n in names]


def act(*acts, measures=('order_qty', 'ticket_qty', 'sale_amt', 'cost_amt')):
    out = []
    for a in acts:
        for m in measures:
            if f'{a}_{m}' in M:
                out.append(f'{a}_{m}')
    return out


TRADE = act('order', 'pay', 'cancel', 'verify', 'finish', 'revoke', 'print') + ['after_sale_ticket_qty', 'after_sale_refund_amt', 'after_sale_income_amt', 'buyer_qty']

# ---------------------------------------------------------------- 表
# (表名, 中文名, 业务域, 粒度, 上游标准表, 说明, 字段定义, 旧表)
# 字段定义：('union', [核心字段]) 由旧表字段并集生成；或显式 [(名, 类型, 类别, 注释)]
T = []


def t(name, cn, grain, up, note, fields, legacy, part='travel_date'):
    T.append({'name': name, 'cn': cn, 'grain': grain, 'up': up, 'note': note, 'fields': fields, 'legacy': legacy, 'part': part})


# ======================= DIM =======================
t('dim_prd_scenic_df', '景区维度', '1行=1个景区（产品 lid）', 'ods_prd_scenic_df、ods_prd_management_land_df、dim_opr_region_f',
  '景区基础信息 + 类型 / 主题 / 所属地区 / 发布商户；替代旧系统 4 套景区维表', ('union', ['scenic_id', 'scenic_name', 'scenic_type', 'scenic_supplier_id', 'province_code', 'city_code']),
  ['dim_land_d_f', 'dim_attr_scenic_info_df', 'dim_land_topic_d_f', 'dim_prd_ticket_scenic_composite_df', 'dim_resource_land_d_f'], part='')
t('dim_prd_ticket_df', '门票维度', '1行=1张门票（tid）', 'ods_prd_ticket_df、ods_prd_package_tickets_df、dim_prd_scenic_df',
  '门票（票种）属性：所属景区 / 产品类型 / 主子票关系 / 上下架状态', ('union', ['ticket_id', 'ticket_name', 'scenic_id', 'product_id', 'product_type', 'supplier_id']),
  ['dim_prod_d_f', 'dim_attr_ticket_info_df', 'dim_common_supplier_scenic_ticket_f', 'dim_prd_scenic_supplier_relation_f'], part='')
t('dim_prd_ticket_price_zip', '门票价格拉链', '1行=1张门票×1个价格生效区间', 'ods_prd_ticket_price_df', '门票价格变化留痕；旧系统用全量快照 + 拉链两套',
  ('union', ['ticket_id', 'start_date', 'end_date']), ['dim_prod_price_d_f', 'dws_scenic_ticket_price_zipper_di'], part='')
t('dim_prd_resource_df', '资源中心资源维度', '1行=1个资源中心资源（景区 / 产品）', 'ods_prd_resource_land_df、ods_prd_resource_product_df、ods_opr_resource_center_district_df',
  '资源中心的资源、景区属性、考核区域', ('union', ['resource_id']),
  ['dim_resource_center_purchase_d_f', 'dim_resource_center_user_d_f', 'dim_resource_type_d_f', 'dim_res_resource_center_district_2022_d_f',
   'dim_resource_center_district_o_f', 'dws_res_resource_center_land_attr_detail_d_f'], part='')
t('dim_sup_member_df', '商户维度', '1行=1个商户 / 会员账号（member）', 'ods_sup_member_df、ods_sup_member_ext_df、ods_sup_supplier_extinfo_df、ods_sup_customer_certification_df',
  '商户（供应商 / 分销商 / 散客账号）属性：类型、业态、认证、所属集团、对接系统', ('union', ['member_id', 'member_name', 'member_type']),
  ['dim_user_d_f', 'dim_cus_member_info_df', 'dim_user_datav_d_f', 'dim_cus_core_attributes_df', 'dim_cus_user_customer_info_df',
   'dim_bloc_company_d_f', 'ods_c_land_authorize_d_f', 'dim_thirdsystem_d_f', 'dim_user_thirdsystem_d_f', 'dwd_cus_qualification_auth_df', 'dwd_cus_user_base_bind_df', 'dim_sid_white_list_d_f'], part='')
t('dim_sup_member_relation_zip', '商户分销关系拉链', '1行=1对供应商-分销商关系×1个有效区间', 'ods_sup_member_relation_df、ods_trf_evolute_group_df',
  '供应商与分销商的分销关系、分组、价格组；按变化留痕，支撑新增 / 存量分销商', ('union', ['supplier_id', 'distributor_id', 'start_date', 'end_date']),
  ['dim_user_relationship_d_f', 'dim_distributor_group_d_f', 'dim_prod_distribute_d_f'], part='')
t('dim_sup_company_df', 'CRM 客户公司维度', '1行=1个 CRM 客户公司', 'ods_sup_crm_account_df、ods_sup_crm_custom_field_df、ods_opr_crm_home_area_df',
  '公司客户（签约商户）主体：行业、区域、负责人、合作状态；财务部客户属性的基础', ('union', ['company_id', 'company_name']),
  ['dim_cus_company_d_f', 'dim_crm_home_area_d_f', 'dws_cus_pft_crm_account_d_f'], part='')
t('dim_sup_contract_df', '合同维度', '1行=1份合同', 'ods_sup_contract_df、ods_sup_oa_contract_ledger_df', '合同主信息（编号 / 金额 / 起止日期 / 客户 / 负责人）',
  ('union', ['contract_no', 'company_id']), ['dim_contract_d_f', 'dim_contract_id_d_f', 'tmp_contract_d_f', 'dws_contract_d_f'], part='')
t('dim_sup_staff_df', '员工维度', '1行=1个员工（平台员工 / OA 人员）', 'ods_opr_hr_staff_df、ods_opr_hr_department_df、ods_sup_staff_df',
  '员工、部门、岗位；OA 人员表只取非敏感字段（密码字段不同步）', ('union', ['staff_id', 'staff_name', 'department_id']),
  ['dim_plat_staff_d_f', 'dim_staff_group_d_f', 'dwd_staff_basic_d_f', 'dim_oa_department_d_f'], part='')
t('dim_trf_channel_f', '渠道码表', '1行=1个下单渠道 / 分销平台', 'ods_opr_channel_df、ods_opr_distribute_system_type_df、ods_opr_third_purchase_system_df',
  '下单渠道（ordermode）、对接分销平台（OTA / API）、采购平台、一二级渠道分类', ('union', ['channel_code', 'channel_name']),
  ['dim_channel_d_f', 'dim_distribute_ota_o_f', 'dim_distribute_channel_type_o_f', 'dim_trf_ota_channel_f'], part='')
t('dim_fin_pay_channel_f', '支付方式码表', '1行=1种支付方式', 'ods_fin_merchant_payment_method_df', '支付方式编码与名称（微信 / 支付宝 / 授信 / 余额 / 现金…）',
  ('union', ['pay_mode', 'pay_mode_name']), ['dim_pay_channel_o_f'], part='')
t('dim_trf_gate_f', '闸机 / 终端维度', '1行=1个终端（闸机 / 手持机）', 'ods_trf_device_inout_journal_di', '终端号、闸机组、所属景区、终端类型',
  ('union', ['terminal_no', 'gate_group_id', 'scenic_id']), ['dim_input_group_gate_d_f'], part='')
t('dim_opr_region_f', '地区维度', '1行=1个行政区划（国家 / 省 / 市 / 区县）', 'ods_opr_region_area_df、ods_opr_country_region_df、ods_opr_city_df、ods_opr_province_df',
  '统一行政区划；替代旧系统 6 张省市表', ('union', ['region_code', 'region_name', 'parent_code', 'region_level']),
  ['dim_city_d_f', 'dim_province_d_f', 'dim_city_fixed_d_f', 'dim_common_region_area_df'], part='')
t('dim_opr_phone_area_f', '手机号归属地', '1行=1个号段', 'ods_opr_global_phone_area_df、ods_opr_city_phone_df', '号段 → 国家 / 省 / 市，用于游客客源地解析',
  ('union', ['phone_prefix', 'province_code', 'city_code']), ['dim_phone_city_d_f', 'dim_phone_city_fixed_d_f', 'dim_phone_global_d_f', 'dim_common_phone_prefix_area_df', 'dim_common_phone_code_country_df'], part='')
t('dim_opr_idcard_area_f', '身份证地区码', '1行=1个身份证前 6 位', 'ods_opr_identity_area_code_df、ods_opr_idcard_city_df', '证件号前 6 位 → 省 / 市 / 区县',
  ('union', ['area_code', 'province_code', 'city_code']), ['dim_idcard_city_d_f', 'dim_idcard_city_fixed_d_f', 'dim_common_idcard_area_df'], part='')
t('dim_opr_date_f', '日期维度', '1行=1天', 'scripts/dim_date/gen_dim_opr_date_f.py', '与 PFT3.0 共用同一张日期表与生成脚本（节假日、农历、同比对齐日）',
  'pft3', ['dim_date_isoweek_o_f', 'dim_common_date_info_df', 'dim_company_report_date_d_f', 'dim_holiday_calendar', 'quarter_first_date'], part='')
t('dim_opr_holiday_period_f', '节假日放假区间', '1行=1个年度×1个节假日', 'scripts/dim_date/gen_dim_opr_date_f.py', '与 PFT3.0 共用', 'pft3', [], part='')
t('dim_opr_period_f', '统计周期时间表', '1行=1个截止日×1种统计周期', 'dim_opr_date_f、dim_opr_holiday_period_f', '与 PFT3.0 共用：ADS 只存日数据，周 / 月 / 年 / 节假日 / 自定义在查询时关联',
  'pft3', ['cache_tmp_holiday_newdates'], part='')
t('dim_opr_module_package_df', '应用模块 / 套餐维度', '1行=1个应用模块或套餐', 'ods_opr_module_df、ods_opr_module_package_df、ods_opr_module_package_classify_df、ods_opr_module_price_df',
  '平台售卖给商户的应用模块、套餐与价格', ('union', ['module_id', 'module_name', 'package_id']),
  ['dim_pft_module_package_classify_d_f', 'dim_prod_pft_module_package_detail_d_f', 'dim_mkt_module_combo_config_df'], part='')
t('dim_opr_dict_f', '公共码表', '1行=1个码值', 'ods_opr_common_dict_df、ods_opr_order_status_df、ods_opr_land_topic_df', '订单状态、景区主题、各类枚举统一码表',
  [('dict_type', 'STRING', '粒度键', '码表类型，如 order_status / scenic_topic'), ('dict_code', 'STRING', '粒度键', '码值'), ('dict_name', 'STRING', '维度属性', '名称')],
  ['dim_order_status_o_f', 'dim_dataoutput_config_d_i', 'tmp_mid_dim_dataoutput_config', 'dim_opr_dashboard_user_auth_df', 'dwd_opr_dashboard_user_auth_df'], part='')

# ======================= DWD =======================
t('dwd_ord_order_di', '订单明细', '1行=1张子订单（ordernum）', 'ods_ord_order_di、ods_ord_order_addon_di、ods_ord_order_apply_di、ods_ord_order_ticket_taker_di、dim_prd_ticket_df、dim_prd_scenic_df、dim_sup_member_df',
  '订单域唯一的订单明细：主子票、团队、取票人（脱敏）、景区 / 门票 / 供应商 / 渠道冗余，按下单日分区；替代旧系统 13 张订单 DWD / 宽表',
  F(('order_no', 'STRING', '主键', '订单号（子单号 ordernum）', 'ordernum / order_id / orderid'),
    ('main_order_no', 'STRING', '外键', '主票订单号；单票 = 自身，套票子票 = 主票订单号', 'main_order_id / pack_order_main_ordernum'),
    ('order_role', 'STRING', '状态类型', '主子单：MAIN-主票（含单票）/ SUB-套票子票', 'order_type / mo / no_mo'),
    ('team_order_no', 'STRING', '外键', '团队订单号；散客为空', 'team_order_id'),
    ('team_flag', 'INT', '状态类型', '是否团队订单：0-散客 1-团队', 'is_team'),
    ('trade_order_no', 'STRING', '外键', '交易订单号（支付单）', 'trade_order_id'),
    ('remote_order_no', 'STRING', '外键', '远端（OTA / API）订单号', 'remotenum / remote_order_id'),
    ('scenic_id', 'BIGINT', '外键', '景区ID，关联 dim_prd_scenic_df', 'lid / land_id / pack_scenic_id / main_lid'),
    ('ticket_id', 'BIGINT', '外键', '门票ID，关联 dim_prd_ticket_df', 'tid / ticket_id / pack_ticket_id'),
    ('product_id', 'BIGINT', '外键', '产品ID', 'pid / product_id / main_pid'),
    ('product_type', 'STRING', '状态类型', '产品类型：A-景区 B-线路 C-酒店 F-套票 …', 'p_type / product_type / main_product_type'),
    ('supplier_id', 'BIGINT', '外键', '供应商（景区发布商户）ID，关联 dim_sup_member_df', 'aid / land_publisher_id / scenic_publisher_id / main_sid'),
    ('origin_supplier_id', 'BIGINT', '外键', '原始（顶级）供应商ID', 'apply_did / top_supplier_id'),
    ('buyer_id', 'BIGINT', '外键', '购买者ID（直接下单的商户 / 会员）', 'member / booker_id'),
    ('buyer_type', 'STRING', '状态类型', '购买者身份', 'booker_type / buyer_identity'),
    ('seller_id', 'BIGINT', '外键', '销售者（收款方）ID', 'salerid / seller_id'),
    ('distributor_id', 'BIGINT', '外键', '一级分销商ID', 'distributor_id / distribute_1_id'),
    ('distribute_level_qty', 'INT', '度量', '分销链层级数', 'distribute_num'),
    ('order_mode', 'INT', '外键', '下单渠道编码，关联 dim_trf_channel_f', 'ordermode / booking_channel / sales_channel_id / order_channel'),
    ('distribute_system_code', 'STRING', '外键', '对接分销平台（OTA / API）编码', 'distribute_system_type / distributor_is_ota'),
    ('purchase_system_code', 'STRING', '外键', '对接采购平台编码', 'purchase_system_code / procurement_platform_id'),
    ('pay_mode', 'INT', '外键', '支付方式编码，关联 dim_fin_pay_channel_f', 'paymode / pay_way'),
    ('pay_account_type', 'STRING', '状态类型', '付款资金账户类型', 'pay_funding_type / payment_account_type'),
    ('order_status', 'STRING', '状态类型', '订单状态（码表 dim_opr_dict_f.order_status）', 'status / order_status_code / order_status_id'),
    ('pay_status', 'STRING', '状态类型', '支付状态', 'pay_status / order_pay_status'),
    ('ticket_qty', 'BIGINT', '度量', '当前票数', 'tnum / ticket_num / valid_ticket_qty'),
    ('origin_ticket_qty', 'BIGINT', '度量', '下单时原始票数', 'origin_num / origin_ticket_qty'),
    ('verified_ticket_qty', 'BIGINT', '度量', '已验证票数（快照）', 'verified_num'),
    ('refund_ticket_qty', 'BIGINT', '度量', '已退票数（快照）', 'refund_num'),
    ('ticket_price_amt', 'DECIMAL(18,2)', '度量', '销售单价（元）', 'tprice / booking_price / order_price / unit_price'),
    ('sale_price_amt', 'DECIMAL(18,2)', '度量', '实际售价（元，含优惠）', 'sale_price / actual_selling_price'),
    ('cost_price_amt', 'DECIMAL(18,2)', '度量', '结算（供应）单价（元）', 'supply_price / distribute_1_cost_price'),
    ('order_amt', 'DECIMAL(18,2)', '度量', '订单金额（元）', 'totalmoney / original_order_amount'),
    ('pay_amt', 'DECIMAL(18,2)', '度量', '订单支付金额（元）', 'order_pay_amount / booking_pay_amount / booking_amt'),
    ('use_coupon_flag', 'INT', '状态类型', '是否使用优惠：0-否 1-是', 'onsale / use_coupon / is_use_coupon'),
    ('non_refundable_flag', 'INT', '状态类型', '是否不可退可提现：0-否 1-是', 'unioncheck / non_refund_withdraw / is_non_refundable'),
    ('order_time', 'STRING', '时间', '下单时间 yyyy-MM-dd HH:mm:ss', 'ordertime / order_time / booking_time'),
    ('pay_time', 'STRING', '时间', '支付时间', 'pay_time / payment_time'),
    ('play_date', 'STRING', '时间', '计划游玩日期 yyyy-MM-dd', 'playtime / play_time / playdate / estimated_visit_time'),
    ('advance_day_qty', 'INT', '度量', '提前预订天数 = 游玩日 − 下单日', 'pre_booked_days / advance_booking_days'),
    ('valid_start_time', 'STRING', '时间', '有效期开始', 'begintime / begin_time'),
    ('valid_end_time', 'STRING', '时间', '有效期结束', 'endtime / end_time / expiration_time'),
    ('first_verify_time', 'STRING', '时间', '首次验证时间（快照）', 'dtime / verify_time / vertify_time'),
    ('cancel_time', 'STRING', '时间', '取消时间（快照）', 'ctime / cancel_time'),
    ('voucher_code', 'STRING', '退化维度', '凭证码', 'code / verify_code'),
    ('taker_name_mask', 'STRING', '维度属性', '取票人姓名（掩码）', 'ordername / ticket_taker_name / ticket_picker_name'),
    ('taker_phone_hash', 'STRING', '维度属性', '取票人手机号哈希（营销触达时再解密关联）', 'ordertel / contacttel / ticket_taker_mobile / ticket_picker_mobile'),
    ('taker_id_card_hash', 'STRING', '维度属性', '取票人证件号哈希（去重统计用）', 'personid / ticket_taker_idcard / ticket_picker_idcard'),
    ('taker_gender', 'STRING', '维度属性', '取票人性别（证件号解析）', 'ticket_taker_sex / ticket_picker_sex'),
    ('taker_age', 'INT', '维度属性', '取票人年龄（证件号解析）', 'ticket_taker_age / ticket_picker_age'),
    ('taker_province_code', 'STRING', '维度属性', '取票人客源省（证件优先、手机号次之）', 'ticket_taker_province / ticket_taker_province_idcard / ticket_taker_phone_province_code'),
    ('taker_city_code', 'STRING', '维度属性', '取票人客源市', 'ticket_taker_city / ticket_taker_city_idcard / ticket_taker_phone_city_code'),
    ('resource_id', 'BIGINT', '外键', '资源中心资源ID', 'certnum / resource_id'),
    ('resource_center_supplier_id', 'BIGINT', '外键', '资源中心供应商户', 'resource_center_supplier_id'),
    ('resource_center_purchase_id', 'BIGINT', '外键', '资源中心采购商户', 'resource_center_purchase_id'),
    ('mall_supplier_id', 'BIGINT', '外键', '微商城商户ID', 'mall_supplier_account_id'),
    ('test_flag', 'INT', '状态类型', '是否测试订单：0-否 1-是（所有指标默认排除）', 'is_test / order_is_test')),
  ['dwd_order_d_i', 'dwd_ord_order_details_di', 'dwd_ord_order_detail_di', 'dwd_order_forck_d_i', 'dwd_ord_order_item_wide_di', 'dwd_order_d_f_v7', 'dim_order_d_i',
   'dim_order_d_i_dev', 'dwd_ord_group_sub_order_details_di', 'dwd_ord_package_sub_order_details_di', 'dws_ord_order_detail_wide_di', 'dwd_order_boss_cockpit_instance_temp',
   'dwd_r_report_dwm_common_di', 'tmp_src_ord_scenic_ticket_modify_hrs_f', 'temp_begin_make_copy', 'dim_src_table_increment_info_di', 'dwd_sales_tr_marketing_order_d_f'])
t('dwd_ord_order_distribution_di', '订单分销链明细', '1行=1张订单×1级分销', 'ods_ord_order_distribution_split_di、ods_ord_order_distribution_detail_di、dwd_ord_order_di',
  '每级分销的买卖双方、分销价、结算金额；替代 6 张拆单表', F(('order_no', 'STRING', '主键', '订单号', 'ordernum / orderid'), ('distribute_level', 'INT', '主键', '分销层级：1 = 供应商卖给一级分销商 …', 'level'),
    ('seller_id', 'BIGINT', '外键', '本级卖方', 'sellerid / seller_id'), ('buyer_id', 'BIGINT', '外键', '本级买方', 'buyerid / buyer_id'),
    ('price_amt', 'DECIMAL(18,2)', '度量', '本级结算单价（元）', 'price / distribute_price'), ('cost_price_amt', 'DECIMAL(18,2)', '度量', '本级成本单价（元）', 'cost_price'),
    ('ticket_qty', 'BIGINT', '度量', '票数', 'tnum'), ('settle_amt', 'DECIMAL(18,2)', '度量', '本级结算金额（元）', 'money / amount'),
    ('pay_mode', 'INT', '外键', '本级支付方式', 'paymode'), ('scenic_id', 'BIGINT', '外键', '景区ID', 'lid'), ('ticket_id', 'BIGINT', '外键', '门票ID', 'tid'),
    ('order_time', 'STRING', '时间', '下单时间', 'ordertime'), ('test_flag', 'INT', '状态类型', '是否测试订单', 'is_test')),
  ['dwd_split_d_i', 'dwd_order_split_d_i', 'dwd_ord_split_order_details_di', 'dwd_ord_order_distribute_detail_di', 'dwd_ord_order_distribute_summary_di', 'dwd_order_track_split_d_i',
   'dws_distribution_aggregation_d_i'])
t('dwd_ord_order_track_di', '订单操作明细', '1行=1次订单操作（支付 / 修改 / 取消 / 撤销 / 完结 / 取票 / 售后）', 'ods_ord_order_track_di、dwd_ord_order_di',
  '订单状态变化事件；取消、撤销、完结、售后、取票指标的明细来源', F(('track_id', 'BIGINT', '主键', '操作记录ID', 'id'), ('order_no', 'STRING', '外键', '订单号', 'ordernum / order_id'),
    ('track_action', 'STRING', '状态类型', '操作：PAY-支付 / MODIFY-修改 / CANCEL-取消 / REVOKE-撤销 / FINISH-完结 / PRINT-取票 / AFTER_SALE-售后', 'action / track_action'),
    ('action_time', 'STRING', '时间', '操作时间', 'insertTime / ctime / dtime'), ('ticket_qty', 'BIGINT', '度量', '本次操作票数（取消 / 撤销 / 售后为变动票数）', 'tnum / cancel_ticket / revoke_ticket'),
    ('left_ticket_qty', 'BIGINT', '度量', '操作后剩余票数', 'left_num'), ('sale_amt', 'DECIMAL(18,2)', '度量', '本次操作金额（元）', 'cancel_sale_money / revoke_sale_money'),
    ('cost_amt', 'DECIMAL(18,2)', '度量', '本次操作成本（元）', 'cancel_cost_money / revoke_cost_money'), ('refund_amt', 'DECIMAL(18,2)', '度量', '退回金额（元）', 'after_sale_refund_money'),
    ('service_fee_amt', 'DECIMAL(18,2)', '度量', '手续费收入（元）', 'service_money / after_sale_income_money'), ('operator_id', 'BIGINT', '外键', '操作人ID', 'oper_member / operate_id'),
    ('terminal_no', 'STRING', '外键', '操作终端', 'terminal'), ('scenic_id', 'BIGINT', '外键', '景区ID', 'lid'), ('ticket_id', 'BIGINT', '外键', '门票ID', 'tid'),
    ('order_role', 'STRING', '状态类型', '主子单', 'mo / no_mo'), ('test_flag', 'INT', '状态类型', '是否测试订单', 'is_test')),
  ['dwd_order_track_d_i', 'dws_ord_order_track_wide_di'])
t('dwd_ord_verify_di', '核销明细', '1行=1次验证（含年卡核销）', 'ods_ord_order_traveler_track_di、ods_trf_qunar_verify_di、dwd_ord_order_di',
  '验证时间、验证票数、验证终端、验证游客；替代 7 张验证 / 游客验证表', F(('verify_id', 'BIGINT', '主键', '验证记录ID', 'id / verify_id'), ('order_no', 'STRING', '外键', '订单号', 'ordernum / order_id'),
    ('main_order_no', 'STRING', '外键', '主票订单号', 'main_order_id'), ('order_role', 'STRING', '状态类型', '主子单', 'mo / no_mo'),
    ('scenic_id', 'BIGINT', '外键', '景区ID', 'lid / land_id'), ('ticket_id', 'BIGINT', '外键', '门票ID', 'tid'), ('supplier_id', 'BIGINT', '外键', '供应商ID', 'aid'),
    ('distributor_id', 'BIGINT', '外键', '一级分销商ID', 'reseller_id / distributor_id'), ('order_mode', 'INT', '外键', '下单渠道', 'ordermode'),
    ('verify_time', 'STRING', '时间', '验证时间', 'dtime / verify_time / vertify_time'), ('verify_ticket_qty', 'BIGINT', '度量', '本次验证票数', 'tnum / verify_num / verify_ticket'),
    ('verify_sale_amt', 'DECIMAL(18,2)', '度量', '本次验证金额（元）', 'verify_sale_money'), ('verify_cost_amt', 'DECIMAL(18,2)', '度量', '本次验证成本（元）', 'verify_cost_money / cost_money'),
    ('verify_type', 'STRING', '状态类型', '验证方式：闸机 / 手持机 / 人工 / OTA 回传 / 年卡', 'track_action / source'),
    ('terminal_no', 'STRING', '外键', '验证终端号', 'terminal'), ('branch_terminal_no', 'STRING', '外键', '分终端号', 'branchterminal / branch_terminal'),
    ('operator_id', 'BIGINT', '外键', '操作员ID', 'oper_member / opid'), ('annual_card_flag', 'INT', '状态类型', '是否年卡核销：0-否 1-是', 'card_no'),
    ('traveler_qty', 'BIGINT', '度量', '本次验证游客人数', 'visitors'), ('test_flag', 'INT', '状态类型', '是否测试订单', 'is_test')),
  ['dwd_order_verify_d_i', 'dwd_order_verify_d_i_v8', 'dwd_ord_verification_detail_di', 'dwd_ord_traveler_verification_details_di', 'dwd_tourist_verify_d_i',
   'dwd_tourist_verify_d_i_temp', 'dws_ord_traveler_verify_log_wide_di'])
t('dwd_ord_traveler_di', '订单游客明细', '1行=1张订单×1位游客', 'ods_ord_order_traveler_di、ods_ord_order_traveler_ext_di、dim_opr_idcard_area_f、dim_opr_phone_area_f',
  '游客证件（哈希 + 掩码）、性别、年龄段、客源省市（证件 / 手机号解析）；画像类指标的唯一明细来源',
  F(('order_no', 'STRING', '主键', '订单号', 'ordernum / order_id'), ('traveler_seq', 'INT', '主键', '订单内游客序号', 'idx / id'),
    ('scenic_id', 'BIGINT', '外键', '景区ID', 'lid / land_id'), ('ticket_id', 'BIGINT', '外键', '门票ID', 'tid'), ('order_role', 'STRING', '状态类型', '主子单', 'mo / no_mo'),
    ('traveler_name_mask', 'STRING', '维度属性', '游客姓名（掩码）', 'tourist / name'), ('id_card_hash', 'STRING', '维度属性', '证件号哈希', 'idcard / id_card / personid'),
    ('id_card_type', 'STRING', '状态类型', '证件类型', 'voucher_type'), ('phone_hash', 'STRING', '维度属性', '手机号哈希', 'mobile / tel'),
    ('gender', 'STRING', '维度属性', '性别：M / F / U（证件解析）', 'sex / gender'), ('age', 'INT', '维度属性', '年龄（证件解析，按下单日）', 'age'),
    ('age_group', 'STRING', '维度属性', '年龄段：0-7 / 8-17 / 18-27 / 28-40 / 41-60 / 61+ / 未知', 'mo_male_age_0to7 … 透视列'),
    ('province_code', 'STRING', '维度属性', '客源省（证件优先、手机号次之）', 'province / province_code / idcard_province'), ('city_code', 'STRING', '维度属性', '客源市', 'city / city_code'),
    ('district_code', 'STRING', '维度属性', '客源区县', 'country / district'), ('country_code', 'STRING', '维度属性', '国家（境外游客）', 'country_region'),
    ('fellow_qty', 'INT', '度量', '同行人数（同订单游客数）', 'mo_group_1 … 透视列'), ('order_time', 'STRING', '时间', '下单时间', 'ordertime'),
    ('verify_time', 'STRING', '时间', '核销时间（未核销为空）', 'dtime / verify_time'), ('test_flag', 'INT', '状态类型', '是否测试订单', 'is_test')),
  ['dwd_tourist_info_d_i', 'dwd_order_tourist_info_d_i', 'dwd_ord_traveler_booking_details_di', 'dws_ord_traveler_booking_wide_di', 'dwd_ord_order_tourist_shift_detail_di'])
t('dwd_ord_annual_card_trade_di', '年卡交易明细', '1行=1笔年卡交易（售卡 / 续费 / 激活 / 退卡）', 'ods_ord_annual_card_trade_di、ods_ord_annual_card_order_di、ods_ord_annual_card_renew_di、ods_ord_annual_card_active_apply_di',
  '年卡与一卡通交易统一明细', ('union', ['trade_no', 'card_no', 'card_product_id', 'trade_type', 'trade_amt', 'trade_time']), [])
t('dwd_trf_scenic_inout_di', '出入园明细', '1行=1次过闸 / 入园验证', 'ods_trf_device_inout_journal_di、ods_ord_report_terminal_pass_di、dim_trf_gate_f',
  '闸机、手持机出入园记录；替代分钟级明细与实时临时表', ('union', ['scenic_id', 'terminal_no', 'inout_type', 'inout_time', 'person_qty']),
  ['dwd_minutely_inout_detail_d_i', 'dwd_trf_tourist_in_out_details_di', 'tmp_src_trf_scenic_access_record_hrs_f'])
t('dwd_opr_parking_record_di', '停车出入场明细', '1行=1次车辆出入场', 'ods_opr_parking_*（5 个厂商入场 / 出场表）',
  '统一 道尔 / 道尔5 / 科拓 / 帅臣 / 智慧 五个停车系统的入场、出场记录（parking_vendor 区分）', ('union', ['parking_vendor', 'parking_lot_code', 'car_no', 'inout_type', 'inout_time', 'fee_amt']), [])
t('dwd_opr_retail_order_di', '零售订单明细', '1行=1个零售订单商品行（含退货）', 'ods_opr_retail_yinbao_ticket_di、ods_opr_retail_sixun_order_di、ods_opr_retail_xisland_order_di 等',
  '统一 银豹 / 思迅 / 小岛 三个零售系统的销售与退货明细（retail_vendor 区分）', ('union', ['retail_vendor', 'shop_code', 'order_no', 'goods_code', 'item_qty', 'sale_amt', 'refund_flag']), [])
t('dwd_fin_trade_journal_di', '账户交易流水', '1行=1笔账户流水', 'ods_fin_trade_journal_di、ods_fin_account_book_subject_df',
  '平台账户收支流水、科目、余额', ('union', ['journal_id', 'account_id', 'subject_code', 'trade_amt', 'balance_amt', 'trade_time']), ['dwd_pft_trade_journal_d_f'])
t('dwd_sup_member_login_di', '商户登录明细', '1行=1次登录', 'ods_sup_member_login_log_di', '商户账号登录记录（活跃商户口径）', ('union', ['member_id', 'login_time']), ['dwd_company_login_d_f'])
t('dwd_opr_module_open_di', '应用模块开通明细', '1行=1次模块 / 套餐开通或续费', 'ods_opr_module_used_di、ods_opr_module_package_log_di、dim_opr_module_package_df',
  '商户开通、续费、到期应用模块与套餐', ('union', ['member_id', 'module_id', 'open_time', 'expire_time']),
  ['dwd_user_module_d_f', 'dwd_user_package_d_f', 'dwd_mkt_module_combo_open_df', 'dim_user_module_d_f'])
t('dwd_prd_resource_order_di', '资源中心订单明细', '1行=1张经资源中心采购商品产生的订单', 'dwd_ord_order_di、ods_prd_resource_purchase_di、dim_prd_resource_df',
  '资源中心供应 / 采购关系下的订单', ('union', ['order_no', 'resource_id', 'supplier_id', 'purchase_member_id']),
  ['dwd_resource_center_order_d_f', 'dwd_resource_center_order_d_f2'])
t('dwd_trf_page_view_di', '页面访问明细', '1行=1次页面访问', 'ods_prd_resource_search_history_di、微商城埋点', '微商城、资源中心页面访问（PV / UV 口径）',
  ('union', ['page_code', 'user_id', 'visit_time']), ['dwd_user_resource_center_pv_d_f'])
t('dwd_sup_contract_event_di', '合同事件明细', '1行=1个合同事件（开票 / 回款 / 验收 / 回访 / 岗位变更）', 'ods_opr_oa_form_*、ods_sup_contract_df、dim_sup_contract_df',
  'OA 合同流程中的开票、回款、验收、回访记录统一为事件表', ('union', ['contract_no', 'event_type', 'event_time', 'event_amt']),
  ['dwd_project_bill_d_f', 'dwd_project_by_post_d_f', 'dwd_project_call_back_d_f', 'dwd_project_check_d_f'])
t('dwd_sup_customer_visit_di', '客户拜访 / 接待明细', '1行=1次客户拜访或接待', 'ods_sup_oa_customer_visit_ledger_df、ods_opr_oa_form_*', 'CRM 客户拜访、接待记录',
  ('union', ['company_id', 'visit_time', 'staff_id']), ['dwd_mkt_oa_customer_reception_detail_df'])
t('dwd_sup_service_merchant_di', '服务商户明细', '1行=1个服务商户×1个服务项目', 'ods_sup_member_df、ods_sup_cooperation_other_df', '平台服务的商户与合作项目',
  ('union', ['member_id']), ['dwd_service_business_d_f', 'dwd_service_business_d_f_v3', 'dwd_company_cooperation_other_d_f'])
t('dwd_mkt_social_content_di', '舆情内容明细', '1行=1条发布内容 / 评论', 'ods_trf_social_opinion_comment_core_di', '全网舆情内容与评论（外部采集）',
  ('union', ['content_id', 'publish_time', 'platform_code']), ['dwd_content_comment_detail_di', 'dwd_content_publish_info_di'])

# ======================= DWS =======================
t('dws_ord_scenic_ticket_trade_di', '景区门票交易日汇总', '1行=1天×景区×门票×供应商×分销商×下单渠道×支付方式×主子单×团散',
  'dwd_ord_order_di、dwd_ord_order_track_di、dwd_ord_verify_di、dwd_ord_order_distribution_di',
  '预订 / 支付 / 取消 / 验证 / 完结 / 撤销 / 取票 / 售后 × 订单数 / 票数 / 金额 / 成本 统一口径；替代 预定验证报表、终端分销、节假日分析、商户日统计 等 40+ 张汇总表',
  dims('scenic_id', 'ticket_id', 'supplier_id', 'distributor_id', 'order_mode', 'pay_mode', 'order_role', 'team_type') + mets(*TRADE),
  [r'^dws_(daily|monthly|yearly|hourly)_report_(summary|ticket_summary|full_summary)', 'dws_report_checked_d_i', 'dws_report_order_d_i', 'dws_ord_supplier_overview_di',
   'dws_mps_prd_report_summary_di', 'dws_mps_sup_report_summary_di', 'dws_mps_trf_report_summary_di', 'dws_ord_scenic_type_performance_di', 'dws_ord_region_performance_di',
   'dws_order_info_holiday_analysis_d_f', 'dws_verify_info_holiday_analysis_d_f', 'dws_user_report_order_month_d_f', 'dws_company_distributor_order_d_f',
   'dws_cus_order_channel_aids_d_f', 'dws_ord_tourist_overview_di', r'^cache_tmp_(order|verify)_holiday'])
t('dws_ord_scenic_ticket_trade_hrs', '景区门票交易小时汇总', '1行=1小时×景区×门票×下单渠道×主子单', 'dwd_ord_order_di、dwd_ord_verify_di',
  '分时预订 / 验证；替代分时报表与 1 小时实时表', dims('scenic_id', 'ticket_id', 'order_mode', 'order_role', 'stat_hour') + mets(*act('order', 'verify', 'cancel')),
  [r'^dws_daily_report_summary_hour', r'^dws_daily_report_ticket_summary_hour', 'ads_plat_yesterday_order_hour_d_i'], part='travel_date、stat_hour')
t('dws_ord_scenic_traveler_profile_di', '景区游客画像日汇总', '1行=1天×景区×门票×行为（预订 / 核销）×主子单×客源省市×性别×年龄段×同行人数段',
  'dwd_ord_traveler_di、dwd_ord_order_di、dwd_ord_verify_di', '把旧系统 28 个透视列（主子单 × 性别 × 年龄段）和同行人数 4 段改为行，任意维度组合都能查',
  dims('scenic_id', 'ticket_id', 'behavior_type', 'order_role', 'team_type', 'province_code', 'city_code', 'gender', 'age_group', 'fellow_group') + mets('traveler_qty', 'order_order_qty', 'order_ticket_qty', 'verify_ticket_qty'),
  ['dws_ord_traveler_booking_wide_di'])
t('dws_ord_scenic_pre_booking_di', '景区提前预订日汇总', '1行=1天（游玩日）×景区×门票×主子单×提前预订天数段', 'dwd_ord_order_di',
  '按游玩日看提前多少天下单；含预约预估', dims('scenic_id', 'ticket_id', 'order_role', 'advance_day_group') + mets('order_order_qty', 'order_ticket_qty', 'order_sale_amt'),
  ['dws_datav_preplay_estimate_day_d_f'])
t('dws_ord_package_sub_ticket_di', '套票子票预约使用日汇总', '1行=1天×主票×子票', 'dwd_ord_order_di、dwd_ord_verify_di', '套票子票的预约与使用',
  dims('scenic_id', 'main_ticket_id', 'sub_ticket_id') + mets('order_ticket_qty', 'verify_ticket_qty'),
  ['dws_ord_scenic_package_sub_ticket_use_di', 'dws_ord_scenic_pkg_sub_ticket_reserve_di'])
t('dws_trf_scenic_inout_hrs', '景区出入园小时汇总', '1行=1小时×景区×闸机组×终端', 'dwd_trf_scenic_inout_di', '入园 / 出园人次与在园快照；日 / 周 / 月由时间表汇总，替代 5 套出入园周期表',
  dims('scenic_id', 'gate_group_id', 'terminal_no', 'stat_hour') + mets('enter_qty', 'exit_qty', 'in_park_qty'),
  [r'^dws_scenic_inout_', r'^dws_(daily|hourly|monthly|yearly)_terminal_pass', r'^dws_(daily|hourly|monthly|yearly)_report_terminal_pass', r'^dws_(daily|monthly|yearly)_report_(ticket_)?branch_terminal',
   'dws_tps_sup_trf_tourist_di', 'dws_tps_sup_trf_tourist_min', 'dws_trf_tourist_in_out_1d_qty_di'], part='travel_date、stat_hour')
t('dws_ord_annual_card_di', '年卡 / 一卡通日汇总', '1行=1天×景区×年卡产品', 'dwd_ord_annual_card_trade_di、dwd_ord_verify_di', '售卡、激活、核销；一卡通并入',
  dims('scenic_id', 'card_product_id') + mets('card_sale_qty', 'card_sale_amt', 'card_active_qty', 'card_verify_qty'),
  [r'^dws_(daily|monthly|yearly)_report_annual_card', r'^dws_tps_aioc_summary_'])
t('dws_opr_parking_hrs', '停车小时汇总', '1行=1小时×景区×停车场×厂商', 'dwd_opr_parking_record_di', '入场 / 出场车次、收费、停车时长',
  dims('scenic_id', 'parking_lot_code', 'parking_vendor', 'stat_hour') + mets('park_entry_qty', 'park_exit_qty', 'park_fee_amt', 'park_minute_qty'),
  [r'^dws_scenic_park_'], part='travel_date、stat_hour')
t('dws_opr_retail_di', '零售日汇总', '1行=1天×景区×门店×零售系统×商品×支付方式', 'dwd_opr_retail_order_di', '二消零售销售与退货；替代 3 个零售系统 × 日 / 月 / 年 的 21 张表',
  dims('scenic_id', 'shop_code', 'retail_vendor', 'goods_code', 'pay_mode') + mets('retail_order_qty', 'retail_item_qty', 'retail_sale_amt', 'retail_refund_amt'),
  [r'^dws_(prd|sup)_xisland_retail_summary_'])
t('dws_opr_hotel_di', '酒店日汇总', '1行=1天×酒店', 'ods_opr_hotel_lvyun_hotel_master_df', '绿云酒店间夜与营收', dims('hotel_code') + mets('hotel_room_night_qty', 'hotel_revenue_amt'),
  ['dws_sup_hotel_summary_di'])
t('dws_fin_account_trans_di', '账户收支日汇总', '1行=1天×账户×科目', 'dwd_fin_trade_journal_di', '财务平衡：收入、支出、日终余额', dims('account_id', 'subject_code') + mets('account_income_amt', 'account_expense_amt', 'account_balance_amt'), [])
t('dws_sup_member_di', '商户经营日汇总', '1行=1天×商户', 'dwd_sup_member_login_di、dim_sup_member_relation_zip、dim_prd_ticket_df、dwd_opr_module_open_di',
  '登录、分销商新增 / 总数、在售产品、模块开通', dims('member_id') + mets('login_member_qty', 'new_distributor_qty', 'distributor_total_qty', 'onshelf_product_qty', 'module_open_qty'),
  [r'^dws_cus_company_', r'^dws_company_package', 'dws_micromessage_page_view_d_f'])
t('dws_sup_contract_di', '合同日汇总', '1行=1天×合同', 'dwd_sup_contract_event_di、dim_sup_contract_df', '合同、开票、回款', dims('contract_no') + mets('contract_amt', 'invoice_amt', 'payback_amt'),
  [r'^dws_contract_'])
t('dws_prd_resource_center_di', '资源中心日汇总', '1行=1天×资源×供应商', 'dwd_prd_resource_order_di、dim_prd_resource_df', '资源采购与订单',
  dims('resource_id', 'supplier_id') + mets('resource_purchase_qty', 'resource_order_qty', 'order_sale_amt'), [r'^dws_res(ource)?_resource_center_', 'dws_resource_center_land_summary_d_f', 'dws_resource_center_user_d_f', 'dws_resource_center_user_d_f2'])
t('dws_trf_page_view_di', '页面访问日汇总', '1行=1天×页面', 'dwd_trf_page_view_di', 'PV / UV', dims('page_code') + mets('page_pv', 'page_uv_qty'), [])

# ======================= ADS（日粒度；周期在查询时关联 dim_opr_period_f） =======================
ADS_NOTE = '日粒度存储；本周 / 本月 / 本年 / 节假日 / 自定义区间及环比、同比在查询时关联 dim_opr_period_f 计算'
t('ads_ord_scenic_trade_overview_di', '景区经营概览', '1行=1天×景区×门票', 'dws_ord_scenic_ticket_trade_di',
  '景区 / 门票的预订、支付、取消、核销、售后与退票率、核销率、客单价；' + ADS_NOTE,
  dims('scenic_id', 'ticket_id') + mets(*act('order', 'pay', 'cancel', 'verify', 'finish', 'revoke'), 'after_sale_refund_amt', 'buyer_qty', 'cancel_ticket_rate', 'verify_ticket_rate', 'avg_order_amt'),
  ['ads_daily_scenic_summary_d_i', 'ads_daily_scenic_estimate_d_f', r'^ads_(daily|monthly|yearly)_ticket_refund_ratio', r'^ads_(daily|monthly|yearly)_scenic_toi', 'ads_toi_count_d_i',
   'ads_booking_sum_d_f', 'ads_ord_order_booking_metric_di', 'ads_ord_trade_metrics_di', r'^ads_order_holiday_analysis_', r'^ads_verify_holiday_analysis_',
   'ads_everyday_land_booking_number_d_i', 'ads_data_center_report_order_summary_d_i', 'ads_data_center_report_order_summary_o_f', 'ads_order_play_d_f',
   'ads_prd_attraction_visitor_stats_di', 'ads_travel_team_summary_d_f', 'ads_travel_product_summary_d_f'])
t('ads_ord_scenic_channel_di', '景区渠道与分销结构', '1行=1天×景区×门票×下单渠道×分销商×支付方式', 'dws_ord_scenic_ticket_trade_di',
  '渠道、分销商、支付方式的结构与排名；旧系统按 景区 / 票 / 省份 / 全渠道 × 日 / 月 / 年 拆成 20+ 张表，统一为一张；' + ADS_NOTE,
  dims('scenic_id', 'ticket_id', 'order_mode', 'distributor_id', 'pay_mode') + mets(*act('order', 'pay', 'verify', 'cancel')),
  [r'^ads_(daily|monthly|yearly)_(scenic_|ticket_|scenic_ticket_)?(province_)?channel', r'^ads_(daily|monthly|yearly)_(ticket_)?full_channel', 'ads_selling_channel_d_i', 'ads_channel_rank_d_f',
   'ads_channel_rank_d_i', 'ads_plat_distribution_d_f', r'^ads_(daily|monthly|yearly)_supplier_distributor_stat', 'ads_operate_pay_distri_num_d_f'])
t('ads_cus_scenic_traveler_profile_di', '景区游客画像', '1行=1天×景区×门票×行为×主子单×团散×客源省市×性别×年龄段×同行人数段', 'dws_ord_scenic_traveler_profile_di',
  '预订 / 核销游客的客源地、性别年龄、同行人数、取票人画像；旧系统新旧两套共 60+ 张透视表统一为一张；' + ADS_NOTE,
  dims('scenic_id', 'ticket_id', 'behavior_type', 'order_role', 'team_type', 'province_code', 'city_code', 'gender', 'age_group', 'fellow_group') + mets('traveler_qty', 'order_order_qty', 'order_ticket_qty', 'verify_ticket_qty'),
  [r'^ads_(daily|monthly|yearly)_(scenic_)?(ticket_)?(province_)?(fellow_group|sex_age|tourist_|verify_tourist|verify_draw|ticket_verify_draw|order_draw|sub_order_draw|ticket_taker)',
   r'^ads_travel_(age_gender|togerter|tourists_source)', 'ads_tourist_user_persona_d_i', 'ads_tourist_count_d_f', 'ads_source_area_sell_d_f', 'ads_enter_into_tourist_land_distribute_d_i'])
t('ads_ord_scenic_pre_booking_di', '景区提前预订', '1行=1天（游玩日）×景区×门票×主子单×提前天数段', 'dws_ord_scenic_pre_booking_di', '提前预订分布与预约预估；' + ADS_NOTE,
  dims('scenic_id', 'ticket_id', 'order_role', 'advance_day_group') + mets('order_order_qty', 'order_ticket_qty', 'order_sale_amt'),
  [r'^ads_(daily|monthly|yearly)_(scenic_)?(ticket_)?pre_booking'])
t('ads_trf_scenic_passenger_flow_di', '景区客流', '1行=1天×景区×闸机组', 'dws_trf_scenic_inout_hrs、dws_ord_scenic_ticket_trade_di', '入园、出园、在园峰值、核销人次；分时看 dws_trf_scenic_inout_hrs；' + ADS_NOTE,
  dims('scenic_id', 'gate_group_id') + mets('enter_qty', 'exit_qty', 'in_park_qty', 'verify_ticket_qty'),
  ['ads_trf_scenic_passenger_flow_di', 'ads_trf_tourist_in_out_qty', r'^ads_datav_device_', 'ads_everyday_land_enter_into_number_d_i', 'ads_trf_cwd_scenic_traffic_oi'])
t('ads_ord_annual_card_di', '年卡 / 一卡通经营', '1行=1天×景区×年卡产品', 'dws_ord_annual_card_di', '售卡、激活、核销；' + ADS_NOTE,
  dims('scenic_id', 'card_product_id') + mets('card_sale_qty', 'card_sale_amt', 'card_active_qty', 'card_verify_qty'), [])
t('ads_opr_parking_di', '停车经营', '1行=1天×景区×停车场', 'dws_opr_parking_hrs', '车次、收费、平均停车时长；' + ADS_NOTE,
  dims('scenic_id', 'parking_lot_code') + mets('park_entry_qty', 'park_exit_qty', 'park_fee_amt', 'park_minute_qty'), [])
t('ads_opr_retail_di', '二消零售经营', '1行=1天×景区×门店×商品×支付方式', 'dws_opr_retail_di', '销售额、单数、件数、退款；旧系统 银豹 / 思迅 × 汇总 / 商品 / 支付渠道 × 日 / 月 / 年 共 15 张；' + ADS_NOTE,
  dims('scenic_id', 'shop_code', 'goods_code', 'pay_mode') + mets('retail_order_qty', 'retail_item_qty', 'retail_sale_amt', 'retail_refund_amt'),
  [r'^ads_(daily|monthly|yearly)_retail_'])
t('ads_opr_hotel_di', '酒店经营', '1行=1天×酒店', 'dws_opr_hotel_di', '间夜、营收；' + ADS_NOTE, dims('hotel_code') + mets('hotel_room_night_qty', 'hotel_revenue_amt'), [])
t('ads_fin_account_balance_di', '财务平衡', '1行=1天×账户×科目', 'dws_fin_account_trans_di', '账户收支与余额核对；' + ADS_NOTE,
  dims('account_id', 'subject_code') + mets('account_income_amt', 'account_expense_amt', 'account_balance_amt'),
  [r'^ads_daily_(trade_)?account_trans'])
t('ads_sup_merchant_operation_di', '商户经营数据中心', '1行=1天×商户×景区×门票', 'dws_ord_scenic_ticket_trade_di、dws_sup_member_di',
  '商户后台数据中心：订单、产品、渠道、分销商、供应商、游客统计；旧系统 s_company_* 24 张（含 1 小时实时 6 张）统一；' + ADS_NOTE,
  dims('member_id', 'scenic_id', 'ticket_id') + mets(*act('order', 'pay', 'verify', 'cancel'), 'new_distributor_qty', 'distributor_total_qty', 'onshelf_product_qty'),
 [r'^ads_(two_)?s_company_', r'^ads_ai_supplier_', r'^view_company_', r'^ads_(all_dis_member|distributor_add|distributor_total|supplier_total)_count', 'ads_product_onshelf_offshelf_d_i', 'ads_channel_commodity_repurchase_d_f',
   'dwd_all_dis_orders_d_f'])
t('ads_sup_platform_operation_di', '平台经营（内部）', '1行=1天×商户', 'dws_sup_member_di、dws_ord_scenic_ticket_trade_di',
  '平台事业部 / 运营：模块开通、活跃商户、供应 GMV、三方采购；' + ADS_NOTE,
  dims('member_id') + mets('login_member_qty', 'module_open_qty', 'order_sale_amt', 'pay_sale_amt'),
  ['ads_company_order_month_summary_d_f', 'ads_marketing_department_supply_gmv_d_f', 'ads_module_open_rank_d_f', 'ads_operate_lv1_num_d_f', 'ads_plat_map_fly_d_f',
   'ads_plat_third_purchase_order_d_f'])
t('ads_sup_customer_company_df', '客户公司属性（财务）', '1行=1个 CRM 客户公司', 'dim_sup_company_df、dws_sup_member_di、dws_sup_contract_di',
  '财务部客户属性：合同、开票、回款、产品使用、登录活跃（全量快照）', [('company_id', 'BIGINT', '粒度键', 'CRM 客户公司ID')] + mets('contract_amt', 'invoice_amt', 'payback_amt', 'login_member_qty'),
  ['ads_cus_company_d_f', 'ads_cus_landtravel_d_f', r'^cache_landtravel_', 'dws_company_package_it_d_f', 'dws_cus_company_partner_d_f'], part='')
t('ads_prd_resource_center_di', '资源中心经营', '1行=1天×资源×供应商', 'dws_prd_resource_center_di', '资源采购、订单、考核；' + ADS_NOTE,
  dims('resource_id', 'supplier_id') + mets('resource_purchase_qty', 'resource_order_qty', 'order_sale_amt'),
  [r'^ads_res(ource)?_(center|purchase)', 'ads_resource_center_cutchain_order_d_f2'])
t('ads_trf_digital_brain_di', '数字大脑指标', '1行=1天×景区×指标域×指标', 'ads_ord_scenic_trade_overview_di、ads_trf_scenic_passenger_flow_di、ods_trf_ota_ctrip_trade_di、ods_trf_social_opinion_*',
  '数字大脑接口用的纵表（指标名 / 指标值）；由各标准 ADS 组装，不再自行计算；演示景区数据不写入生产',
  [('scenic_id', 'BIGINT', '粒度键', '景区ID'), ('data_domain', 'STRING', '粒度键', '指标域：交易 / 客流 / OTA / 舆情 / 雷达'), ('target_name', 'STRING', '粒度键', '指标名称'),
   ('data_value', 'DECIMAL(20,4)', '指标', '指标值')], ['ads_digital_brain_target_merge_di'])
t('ads_mkt_sms_audience_di', '营销短信人群', '1行=1天×景区×取票人（哈希）', 'dwd_ord_order_di、dwd_ord_traveler_di', '营销短信目标人群（新客 / 复购），手机号只存哈希，发送时再关联',
  [('scenic_id', 'BIGINT', '粒度键', '景区ID'), ('taker_phone_hash', 'STRING', '粒度键', '取票人手机号哈希'), ('new_user_flag', 'INT', '维度属性', '是否新客：0-否 1-是')] + mets('order_order_qty'),
  ['ads_order_draw_d_i', 'ads_order_draw_new_user_d_f'])
t('ads_cus_scenic_customer_insight_mo', '景区客群洞察（外部）', '1行=1月×景区×洞察类型×指标', 'ods_cus_scenic_customer_insight_*',
  'AI 分析结果直通：10 张洞察结果表合并为纵表（insight_type 区分）', [('scenic_id', 'BIGINT', '粒度键', '景区ID'), ('insight_type', 'STRING', '粒度键', '洞察类型：画像 / 热门POI / 来源 / 偏好 / 消费 / 职住 …'),
                                                                     ('item_name', 'STRING', '粒度键', '指标项'), ('item_value', 'DECIMAL(20,4)', '指标', '指标值')],
  [r'^ads_scenic_customer_insight_'], part='travel_month')
t('ads_trf_ota_social_di', 'OTA 与舆情（外部）', '1行=1天×景区×来源平台', 'ods_trf_ota_ctrip_trade_di、ods_trf_ota_ctrip_score_di、dwd_mkt_social_content_di', '携程交易 / 评分与全网舆情（外部采集）',
  [('scenic_id', 'BIGINT', '粒度键', '景区ID'), ('platform_code', 'STRING', '粒度键', '平台：ctrip / douyin / …'), ('ota_order_qty', 'BIGINT', '指标', 'OTA 订单数'), ('ota_score', 'DECIMAL(6,2)', '指标', 'OTA 评分'),
   ('content_qty', 'BIGINT', '指标', '舆情内容数'), ('negative_content_qty', 'BIGINT', '指标', '负面内容数')],
  ['ads_sup_ota_ctrip_score_di', 'ads_sup_ota_ctrip_trade_di', r'^ads_trf_social_opinion_'])

# 旧表的其余处理（不并入新表）：名称 / 正则 -> (处理, 说明)
OTHER = [
    (r'^(dim_marketing_test_analyze|ods_marketing_test)', ('下线', '测试表')),
    (r'^(cache_table|cachetable|result_table)', ('下线', '临时缓存表')),
    (r'_copy$|_dev$|_err$', ('下线', '副本 / 开发 / 错误节点产物')),
    (r'sbs_', ('项目专用', '渡江战役大屏项目数据，按项目单独维护，不进公共层')),
]
