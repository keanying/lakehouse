"""3.0 财务报表补齐（依据《3.0 通用财务报表 · 需求说明》v1.0，2026-11-24）。

客户交付字典（data/*.xlsx）不改动；本模块在生成时把下列内容追加进字典，页面与改造版 Excel 一并展示：
- 归属规则码表、结算时点配置；
- 商户视角订单资金事实（离线 + 实时）：预收 / 预付 / 确认收入 / 确认成本及全部下钻明细的唯一来源；
- 资金流水实时流；预收预付在途快照（期初 / 期末）；订单资金、余额与费用日汇总；
- 商户财务报表 ADS（离线日表 + 实时当日），区间查询：期初取首日、期末取末日、发生额求和；
- 调度、质量规则（需求第八章勾稽关系）、口径、业务指标、待确认事项。
"""
import re

DOM = 'fin'
NOW = "DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss')"
SRC_DOC = '《3.0 通用财务报表 · 需求说明》v1.0（2026-11-24）'

# 报表 / 列编码（全表统一，码值见 dim_fin_report_rule_f）
REPORT = ("ADV_RECEIPT-预收，ADV_PAYMENT-预付，AR-应收，AP-应付，REVENUE-确认收入，COST-确认成本，EXPENSE-费用收支，BALANCE-仅余额，"
          "CREDIT_IN-授信销售在途（未收未提供，不进报表，用于推算应收），CREDIT_OUT-授信采购在途（未付未取得，用于推算应付），NONE-不进表")
MEASURE = ("RECEIVE-本期收，REFUND-本期退，TO_REVENUE-本期转确认收入，PAY-本期付，RETURN-本期退回，TO_COST-本期转确认成本，"
           "CONFIRM-确认（确认收入 / 确认成本本身），ADD-应收 / 应付增加（授信票核销），INCOME-费用收入，EXPENSE-费用支出，IN-流入，OUT-流出")

# ---------------------------------------------------------------- 表定义
# (分层, 表名, 中文名, 粒度, 后缀含义, 分区, 来源, 关键字段说明, 上游表, 下游表, 备注, 字段[(名, 类型, 类别, 注释, 加工/来源, 上游字段)])
T = []


def t(layer, name, cn, grain, suffix, part, src, keys, up, down, note, fields):
    T.append(dict(layer=layer, name=name, cn=cn, grain=grain, suffix=suffix, part=part, src=src, keys=keys, up=up, down=down, note=note, fields=fields))


RT_NOTE = '实时表后缀 _rt 待确认'
SIDE_FIELDS = [
    ('spu_id', 'BIGINT', '外键', '产品(SPU)ID，关联 dim_prd_spu_zip（维度：产品）', 'dwd_ord_ticket_di.spu_id', 'dwd.dwd_ord_ticket_di.spu_id'),
    ('sku_id', 'BIGINT', '外键', 'SKU ID，关联 dim_prd_sku_zip（维度：票种）', 'dwd_ord_ticket_di.sku_id', 'dwd.dwd_ord_ticket_di.sku_id'),
    ('channel_id', 'BIGINT', '外键', '入口渠道ID，关联 dim_trf_channel_df（维度：下单渠道）', 'dwd_ord_order_group_di.channel_id', 'dwd.dwd_ord_order_group_di.channel_id'),
    ('channel_type', 'STRING', '维度属性', '入口渠道类型：MP-小程序，PC，API-API 接口，OFFLINE-线下窗口，H5', 'dwd_ord_order_group_di.channel_type', 'dwd.dwd_ord_order_group_di.channel_type'),
    ('seller_staff_id', 'BIGINT', '外键', '售票员（订单操作人，operator_type=TENANT_STAFF 时为员工ID，否则 0），关联 dim_sup_staff_df', "dwd_ord_order_group_di：IF(operator_type='TENANT_STAFF', operator_id, 0)", 'dwd.dwd_ord_order_group_di.operator_id'),
    ('sale_point_code', 'STRING', '外键', '售票站点（待确认：3.0 订单上没有站点字段，需研发补；当前为空）', '待业务库补字段', ''),
    ('payer_tenant_id', 'BIGINT', '外键', '付款方（收侧维度）：把钱付给本方的一方；下级分销商为其租户ID，散客为 0', '支付记录：本方为收款方时的 payer_tenant_id；游客直付（INBOUND）为 0', 'dwd.dwd_fin_payment_di.payer_tenant_id'),
    ('payer_type', 'STRING', '状态类型', '付款方类型：DISTRIBUTOR-分销商，CUSTOMER-散客', "支付记录：OUTBOUND→DISTRIBUTOR，INBOUND→CUSTOMER", 'dwd.dwd_fin_payment_di.pay_direction_type'),
    ('payee_tenant_id', 'BIGINT', '外键', '收款方（付侧维度）：本方把钱付给的一方，即上级供应商；自营票为 0', '支付记录：本方为采购付款方时的 payee_tenant_id；无采购付款为 0', 'dwd.dwd_fin_payment_di.payee_tenant_id'),
    ('payee_type', 'STRING', '状态类型', '收款方类型：SUPPLIER-供应商，SELF-自营', '有采购付款→SUPPLIER，否则 SELF', 'dwd.dwd_fin_payment_di.payee_tenant_id'),
    ('sale_unit_price_amt', 'DECIMAL(18,2)', '度量', '卖出单价（元）：本方这张票实际收到的金额（收侧支付记录的支付金额；按聚合单支付的按票单价分摊）', '支付记录（本方为收款方）amount，聚合单支付按 dwd_ord_ticket_di.unit_price_amt 占比分摊', 'dwd.dwd_fin_payment_di.pay_amt'),
    ('buy_unit_price_amt', 'DECIMAL(18,2)', '度量', '买入单价（元）：本方这张票付给上级的金额（付侧采购付款支付记录的支付金额）', '支付记录（本方为采购付款方）amount，分摊同上', 'dwd.dwd_fin_payment_di.pay_amt'),
    ('receive_pay_method_type', 'STRING', '状态类型', '收款支付方式（收侧）：下级付给本方的方式 BALANCE / WECHAT / ALIPAY / CREDIT / OFFLINE / ZERO_FEE', '支付记录（本方为收款方）pay_method_type', 'dwd.dwd_fin_payment_di.pay_method_type'),
    ('pay_pay_method_type', 'STRING', '状态类型', '付款支付方式（付侧）：本方付给上级的方式', '支付记录（本方为采购付款方）pay_method_type', 'dwd.dwd_fin_payment_di.pay_method_type'),
]
FACT_FIELDS = [
    ('fund_event_id', 'STRING', '主键', '资金动作ID = 来源单号:票号:本方商户:报表:列', 'CONCAT_WS(:, source_no, ticket_no, merchant_tenant_id, report_code, measure_code)', 'dwd.dwd_fin_payment_di.payment_no、dwd.dwd_fin_refund_payment_di.refund_detail_no、dwd.dwd_fin_frozen_di.frozen_no'),
    ('event_time', 'STRING', '时间', '动作发生时间：收 / 付 = 支付时间，退 / 退回 = 退款到账时间，确认 = 核销解冻时间（支付即结算为支付时间）', '见加工逻辑', 'dwd.dwd_fin_payment_di.pay_time、dwd.dwd_fin_refund_payment_di.finish_time、dwd.dwd_fin_frozen_di.release_time'),
    ('merchant_tenant_id', 'BIGINT', '外键', '本方商户租户ID（报表归属方），关联 dim_sup_tenant_zip', '支付记录收款方 / 采购付款方', 'dwd.dwd_fin_payment_di.payee_tenant_id、dwd.dwd_fin_payment_di.payer_tenant_id'),
    ('report_code', 'STRING', '状态类型', f'报表：{REPORT}', 'dim_fin_report_rule_f', 'dim.dim_fin_report_rule_f.report_code'),
    ('measure_code', 'STRING', '状态类型', f'报表列：{MEASURE}', 'dim_fin_report_rule_f', 'dim.dim_fin_report_rule_f.measure_code'),
    ('event_amt', 'DECIMAL(18,2)', '度量', '发生金额（元，正数）：收 / 付 = 支付记录 amount（按票分摊），退 / 退回 = 退款明细金额（按票分摊），确认 = 卖出 / 买入单价', '见加工逻辑', 'dwd.dwd_fin_payment_di.pay_amt、dwd.dwd_fin_refund_payment_di.refund_amt'),
    ('balance_effect_amt', 'DECIMAL(18,2)', '度量', '对本报表余额的影响（元，带符号）：预收 / 预付的收、付为 +，退、退回、转确认为 −；确认收入 / 成本为 +', 'event_amt × dim_fin_report_rule_f.sign_qty', 'dim.dim_fin_report_rule_f.sign_qty'),
    ('ticket_net_qty', 'INT', '度量', '净票数：售票记 +1、退款记 −1、核销不改变票数（0）', '收 / 付 = 1，退 / 退回 = −1，其余 0', 'dwd.dwd_fin_payment_di.ticket_no'),
    ('source_type', 'STRING', '状态类型', '来源：PAYMENT-支付记录，REFUND-退款明细，VERIFY-核销解冻，PAY_SETTLE-支付即结算', '见加工逻辑', 'dim.dim_fin_report_rule_f.source_type'),
    ('pay_method_group_type', 'STRING', '状态类型', '本侧付款性质：CASH-现款（余额 / 微信 / 支付宝 / 线下 / 0 元），CREDIT-授信（不动现金，走应收 / 应付）', "本侧支付方式 = CREDIT → CREDIT，否则 CASH", 'dwd.dwd_fin_payment_di.pay_method_type'),
    ('source_no', 'STRING', '退化维度', '来源单号：支付流水号 / 退款明细号 / 冻结记录号', '见加工逻辑', 'dwd.dwd_fin_payment_di.payment_no、dwd.dwd_fin_refund_payment_di.refund_detail_no、dwd.dwd_fin_frozen_di.frozen_no'),
    ('payment_no', 'STRING', '退化维度', '对应支付记录号（本方这一侧的支付记录）', 'dwd_fin_payment_di.payment_no', 'dwd.dwd_fin_payment_di.payment_no'),
    ('order_group_no', 'STRING', '退化维度', '聚合单号', 'dwd_fin_payment_di.order_group_no', 'dwd.dwd_fin_payment_di.order_group_no'),
    ('order_no', 'STRING', '退化维度', '子单号（支付挂聚合单、退款挂子单：统一按票落到子单）', 'dwd_ord_ticket_di.order_no', 'dwd.dwd_ord_ticket_di.order_no'),
    ('ticket_no', 'STRING', '退化维度', '票号', 'dwd_fin_payment_di.ticket_no', 'dwd.dwd_fin_payment_di.ticket_no'),
] + SIDE_FIELDS + [
    ('settle_timing_type', 'STRING', '状态类型', '结算时点：PAY-支付即结算，VERIFY-核销即结算（取本方收款支付方式的配置，缺省 VERIFY）', 'dim_fin_settle_timing_df', 'dim.dim_fin_settle_timing_df.settle_timing_type'),
]

# ---- DIM
t('DIM', 'dim.dim_fin_report_rule_f', '财务报表归属规则', '1行=1条归属规则（来源 × 流水类型 × 费用项 × 方向 × 冻结事件）', '码表', '无分区（人工维护，变更即生效）',
  f'人工维护：{SRC_DOC} 第五章归属规则 + 3.0 流水类型枚举', '归属到哪张表、哪一列、正负号；未命中规则的流水进「待归类」',
  '', 'dwd_fin_merchant_order_fund_di、dwd_fin_merchant_order_fund_rt、dws_fin_merchant_balance_di',
  '需求 5.5：未定义的费用项不得默认归类，进待归类异常清单；需求 7.4：归属规则配置化；授信（钱未动）不进预收 / 预付，核销后记应收 / 应付',
  [('rule_code', 'STRING', '主键', '规则编码', '人工维护', ''),
   ('source_type', 'STRING', '状态类型', '来源：PAYMENT-支付记录，REFUND-退款明细，VERIFY-核销解冻，PAY_SETTLE-支付即结算，FUND_FLOW-资金流水', '人工维护', ''),
   ('flow_type', 'STRING', '状态类型', '资金流水类型（source_type=FUND_FLOW 时）：RECHARGE / PAYMENT / REFUND / FREEZE / UNFREEZE / WITHDRAW / FEE / RESOURCE / TRANSFER_OUT / TRANSFER_IN；空=不限', '人工维护', ''),
   ('fee_item_code', 'STRING', '状态类型', '费用项（资金流水 fee_item）；空=不限', '人工维护', ''),
   ('direction_type', 'STRING', '状态类型', '方向（相对本方商户）：IN-收，OUT-付；空=不限', '人工维护', ''),
   ('pay_method_group_type', 'STRING', '状态类型', '付款性质：CASH-现款，CREDIT-授信；空=不限', '人工维护', ''),
   ('frozen_event_type', 'STRING', '状态类型', '冻结事件（解冻时）：VERIFY-核销触发，REFUND-退款释放；空=不限', '人工维护', ''),
   ('report_code', 'STRING', '状态类型', f'归属报表：{REPORT}', '人工维护', ''),
   ('measure_code', 'STRING', '状态类型', f'归属列：{MEASURE}', '人工维护', ''),
   ('sign_qty', 'INT', '维度属性', '对归属报表余额的方向：1-增加，−1-减少', '人工维护', ''),
   ('rule_desc', 'STRING', '维度属性', '规则说明（对应需求条目）', '人工维护', ''),
   ('confirm_status', 'STRING', '状态类型', '确认状态：CONFIRMED-已确认，PENDING-待研发 / 产品确认', '人工维护', ''),
   ('etl_time', 'STRING', 'ETL', 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss', '调度写入', '')])
t('DIM', 'dim.dim_fin_settle_timing_df', '结算时点配置', '1行=1个商户 × 1种支付方式', '天级全量', 'travel_date（YYYYMMDD）',
  '待业务库补字段：结算时点配在支付方式上（需求 5.8），3.0 业务库暂无该字段', '商户 × 支付方式 → 支付即结算 / 核销即结算',
  'ods_fin_merchant_payment_config_df', 'dwd_fin_merchant_order_fund_di、dwd_fin_merchant_order_fund_rt',
  '源端缺口：t_merchant_payment_config 只有收款模式（collection_mode），没有结算时点；字段补齐前全部按「核销即结算」处理',
  [('tenant_id', 'BIGINT', '主键', '商户租户ID', 'ods_fin_merchant_payment_config_df.tenant_id', 'ods.ods_fin_merchant_payment_config_df.tenant_id'),
   ('pay_method_type', 'STRING', '主键', '支付方式：BALANCE / WECHAT / ALIPAY / CREDIT / OFFLINE / ZERO_FEE', '待业务库补字段', ''),
   ('settle_timing_type', 'STRING', '状态类型', '结算时点：PAY-支付即结算，VERIFY-核销即结算；缺省 VERIFY', '待业务库补字段；缺省 VERIFY', ''),
   ('valid_start_time', 'STRING', '时间', '配置生效时间：只影响生效之后的订单，历史订单按原时点（需求 5.8）', '待业务库补字段', ''),
   ('travel_date', 'STRING', '分区', '数据日期，格式 YYYYMMDD（分区字段）', '${bizdate}', ''),
   ('etl_time', 'STRING', 'ETL', 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss', '调度写入', '')])

# ---- DWD
t('DWD', 'dwd.dwd_fin_merchant_order_fund_di', '商户订单资金明细（财务报表事实）', '1行=1个本方商户 × 1张票 × 1个资金动作（收 / 退 / 付 / 退回 / 确认）', '天级增量', 'travel_date（YYYYMMDD，= 动作发生日）',
  'dwd_fin_payment_di（收 / 付，← ods_fin_payment_record_di）+ dwd_fin_refund_payment_di / dwd_ord_refund_ticket_di（退 / 退回，← ods_ord_refund_detail_di、ods_ord_refund_order_di）+ dwd_fin_frozen_di（核销解冻 → 确认，← ods_fin_frozen_record_di）+ dwd_ord_ticket_di / dwd_ord_order_group_di（订单维度）',
  '度量：event_amt、balance_effect_amt、ticket_net_qty\n报表 / 列：report_code、measure_code\n维度：产品、票种、下单渠道、售票员、付款方、收款方、卖出 / 买入单价、收款 / 付款支付方式',
  'dwd_fin_payment_di、dwd_fin_refund_payment_di、dwd_ord_refund_ticket_di、dwd_fin_frozen_di、dwd_ord_ticket_di、dwd_ord_order_group_di、dim_fin_report_rule_f、dim_fin_settle_timing_df',
  'dws_fin_merchant_unsettled_df、dws_fin_merchant_order_fund_di、dws_fin_merchant_credit_df、ads_fin_merchant_report_di',
  '预收 / 预付 / 应收 / 应付 / 确认收入 / 确认成本等订单报表及其下钻明细的唯一来源，全部可追溯到 ODS 基础表（需求 7.3：明细筛选与汇总归属规则一致）；'
  '一笔支付记录在收款方、采购付款方各记一行（买卖两个方向，不是重复记账）；只取本方商户侧，避免双式记账重复（需求第十章风险 2）', FACT_FIELDS + [
      ('travel_date', 'STRING', '分区', '数据日期，格式 YYYYMMDD（分区字段，= 动作发生日）', '${bizdate}', ''),
      ('etl_time', 'STRING', 'ETL', 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss', '调度写入', '')])

# ---- DWS
t('DWS', 'dws.dws_fin_merchant_unsettled_df', '预收预付在途快照', 'travel_date × merchant_tenant_id × report_code × ticket_no', '天级全量', 'travel_date（YYYYMMDD）',
  'dws_fin_merchant_unsettled_df（T-1）+ dwd_fin_merchant_order_fund_di（T）', '时点值：unsettled_amt（日终在途金额）、unsettled_ticket_qty',
  'dwd_fin_merchant_order_fund_di', 'ads_fin_merchant_report_di、dws_fin_merchant_credit_df',
  '期初 / 期末的来源（需求 5.7）：任意维度组合直接对快照求和，不必从头累加流水；在途金额归零的票不再保留；授信在途（CREDIT_IN / CREDIT_OUT）用于推算应收 / 应付', [
      ('merchant_tenant_id', 'BIGINT', '粒度键', '本方商户租户ID，关联 dim_sup_tenant_zip', 'dwd_fin_merchant_order_fund_di.merchant_tenant_id', 'dwd.dwd_fin_merchant_order_fund_di.merchant_tenant_id'),
      ('report_code', 'STRING', '粒度键', '报表：ADV_RECEIPT-预收，ADV_PAYMENT-预付，CREDIT_IN-授信销售在途，CREDIT_OUT-授信采购在途', 'dwd_fin_merchant_order_fund_di.report_code', 'dwd.dwd_fin_merchant_order_fund_di.report_code'),
      ('ticket_no', 'STRING', '粒度键', '票号', 'dwd_fin_merchant_order_fund_di.ticket_no', 'dwd.dwd_fin_merchant_order_fund_di.ticket_no'),
      ('order_no', 'STRING', '退化维度', '子单号', 'dwd_fin_merchant_order_fund_di.order_no', 'dwd.dwd_fin_merchant_order_fund_di.order_no')]
  + [(n, ty, '维度属性' if cat in ('度量',) else cat, cm, f'dwd_fin_merchant_order_fund_di.{n}', f'dwd.dwd_fin_merchant_order_fund_di.{n}') for n, ty, cat, cm, _, _ in SIDE_FIELDS if n != 'sale_point_code']
  + [('unsettled_amt', 'DECIMAL(18,2)', '指标', '在途金额：截至统计日日终已卖出（已采购）、尚未核销且未退款的金额，单位：元', 'T-1 快照 + 当日 SUM(balance_effect_amt)', 'dwd.dwd_fin_merchant_order_fund_di.balance_effect_amt'),
     ('unsettled_ticket_qty', 'BIGINT', '指标', '在途票数：截至统计日日终在途的净票数，单位：张', 'T-1 快照 + 当日 SUM(ticket_net_qty)', 'dwd.dwd_fin_merchant_order_fund_di.ticket_net_qty'),
     ('first_event_date', 'STRING', '时间', '首次进入在途的日期（收 / 付日期）', 'MIN(travel_date)', 'dwd.dwd_fin_merchant_order_fund_di.travel_date'),
     ('travel_date', 'STRING', '分区', '数据日期，格式 YYYYMMDD（分区字段）', '${bizdate}', ''),
     ('etl_time', 'STRING', 'ETL', 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss', '调度写入', '')])
AGG_DIMS = ['spu_id', 'sku_id', 'channel_id', 'seller_staff_id', 'payer_tenant_id', 'payee_tenant_id', 'receive_pay_method_type', 'pay_pay_method_type']
MEAS = [('receive', 'ADV_RECEIPT', 'RECEIVE', '本期收', '现款卖出金额（下级 / 游客已付的钱，不含渠道手续费；授信卖出不在此列，见授信销售）'), ('refund', 'ADV_RECEIPT', 'REFUND', '本期退', '退给下级的金额'),
        ('to_revenue', 'ADV_RECEIPT', 'TO_REVENUE', '本期转确认收入', '因履约（核销；支付即结算为支付）转入确认收入的金额'),
        ('pay', 'ADV_PAYMENT', 'PAY', '本期付', '向上级采购付款金额'), ('return', 'ADV_PAYMENT', 'RETURN', '本期退回', '上级退回金额'),
        ('to_cost', 'ADV_PAYMENT', 'TO_COST', '本期转确认成本', '因履约转入成本确认的金额'),
        ('revenue', 'REVENUE', 'CONFIRM', '确认收入', '因履约确认的收入，按订单实收金额（实收单价 × 核销数量）计量，总额法'),
        ('cost', 'COST', 'CONFIRM', '确认成本', '因履约确认的成本，按订单买入金额计量'),
        ('ar_add', 'AR', 'ADD', '应收增加', '授信卖出的票核销：服务已提供、钱未收，记应收'),
        ('ap_add', 'AP', 'ADD', '应付增加', '授信采购的票核销：服务已取得、钱未付，记应付'),
        ('credit_sale', 'CREDIT_IN', 'RECEIVE', '授信销售', '下级以授信方式采购的金额（只占额度，钱未收）'),
        ('credit_purchase', 'CREDIT_OUT', 'PAY', '授信采购', '本方以授信方式向上级采购的金额（钱未付）')]
t('DWS', 'dws.dws_fin_merchant_order_fund_di', '商户订单资金日汇总', 'travel_date × merchant_tenant_id × ' + ' × '.join(AGG_DIMS), '天级增量', 'travel_date（YYYYMMDD）',
  'dwd_fin_merchant_order_fund_di', '原子口径：' + '、'.join(f'{m}_amt' for m, *_ in MEAS) + '、sale_ticket_qty、refund_ticket_qty',
  'dwd_fin_merchant_order_fund_di', 'ads_fin_merchant_report_di', '订单四张报表的期间值（需求 5.7）；时点值取 dws_fin_merchant_unsettled_df',
  [(d, ty, '粒度键', cm, f'dwd_fin_merchant_order_fund_di.{d}', f'dwd.dwd_fin_merchant_order_fund_di.{d}') for d, ty, _, cm, _, _ in [('merchant_tenant_id', 'BIGINT', '', '本方商户租户ID，关联 dim_sup_tenant_zip', '', '')] + [x for x in SIDE_FIELDS if x[0] in AGG_DIMS]]
  + [(f'{m}_amt', 'DECIMAL(18,2)', '指标', f'{cn}：{kou}，单位：元', f"dwd_fin_merchant_order_fund_di：SUM(event_amt) where report_code='{r}' and measure_code='{c}'", 'dwd.dwd_fin_merchant_order_fund_di.event_amt') for m, r, c, cn, kou in MEAS]
  + [('sale_ticket_qty', 'BIGINT', '指标', '售票数：本方收侧售出票数（售票记正），单位：张', "SUM(ticket_net_qty) where measure_code='RECEIVE'", 'dwd.dwd_fin_merchant_order_fund_di.ticket_net_qty'),
     ('refund_ticket_qty', 'BIGINT', '指标', '退款票数：本方收侧退款票数，单位：张', "-SUM(ticket_net_qty) where measure_code='REFUND'", 'dwd.dwd_fin_merchant_order_fund_di.ticket_net_qty'),
     ('travel_date', 'STRING', '分区', '数据日期，格式 YYYYMMDD（分区字段）', '${bizdate}', ''),
     ('etl_time', 'STRING', 'ETL', 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss', '调度写入', '')])
t('DWS', 'dws.dws_fin_merchant_balance_di', '商户余额与费用日汇总', 'travel_date × merchant_tenant_id × account_no × report_code × flow_type × fee_item_code', '天级增量', 'travel_date（YYYYMMDD）',
  'dwd_fin_fund_flow_di + dim_fin_report_rule_f + dim_fin_account_df', '原子口径：fund_in_amt、fund_out_amt、fund_flow_qty（按归属：BALANCE / EXPENSE / NONE / UNCLASSIFIED）',
  'dwd_fin_fund_flow_di、dim_fin_report_rule_f、dim_fin_account_df', 'ads_fin_merchant_report_di',
  '余额报表（全部资金流动）与费用收支报表（订单之外的费用项）的期间值；未命中归属规则的流水 report_code=UNCLASSIFIED，进待归类异常清单', [
      ('merchant_tenant_id', 'BIGINT', '粒度键', '本方商户租户ID（账户主体），关联 dim_sup_tenant_zip', 'dwd_fin_fund_flow_di.subject_id', 'dwd.dwd_fin_fund_flow_di.subject_id'),
      ('account_no', 'STRING', '粒度键', '账户编号（维度：账本），关联 dim_fin_account_df', 'dwd_fin_fund_flow_di.account_no', 'dwd.dwd_fin_fund_flow_di.account_no'),
      ('report_code', 'STRING', '粒度键', '归属：BALANCE-仅余额，EXPENSE-费用收支，NONE-不进余额（冻结 / 退款释放），UNCLASSIFIED-待归类', 'dim_fin_report_rule_f.report_code', 'dim.dim_fin_report_rule_f.report_code'),
      ('flow_type', 'STRING', '粒度键', '流水类型', 'dwd_fin_fund_flow_di.flow_type', 'dwd.dwd_fin_fund_flow_di.flow_type'),
      ('fee_item_code', 'STRING', '粒度键', '费用项（维度：费用项）', 'dwd_fin_fund_flow_di.fee_item_code', 'dwd.dwd_fin_fund_flow_di.fee_item_code'),
      ('fund_in_amt', 'DECIMAL(18,2)', '指标', '资金流入：本期实际进入可用余额的金额，单位：元', 'SUM(change_amt) where change_amt > 0', 'dwd.dwd_fin_fund_flow_di.change_amt'),
      ('fund_out_amt', 'DECIMAL(18,2)', '指标', '资金流出：本期实际离开可用余额的金额（正数），单位：元', '-SUM(change_amt) where change_amt < 0', 'dwd.dwd_fin_fund_flow_di.change_amt'),
      ('fund_flow_qty', 'BIGINT', '指标', '流水笔数，单位：笔', 'COUNT(flow_no)', 'dwd.dwd_fin_fund_flow_di.flow_no'),
      ('travel_date', 'STRING', '分区', '数据日期，格式 YYYYMMDD（分区字段）', '${bizdate}', ''),
      ('etl_time', 'STRING', 'ETL', 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss', '调度写入', '')])

t('DWS', 'dws.dws_fin_merchant_credit_df', '商户应收应付快照', 'travel_date × merchant_tenant_id × counterparty_tenant_id × report_code（AR / AP）', '天级全量', 'travel_date（YYYYMMDD）',
  'dws_trf_distributor_credit_df（ods_trf_distribution_relation_df.credit_used 日快照）+ dws_fin_merchant_unsettled_df（授信在途）+ dwd_fin_merchant_order_fund_di（核销记应收 / 应付）',
  '时点值：close_amt（应收 / 应付余额）；期间值：add_amt（核销增加）、settle_amt（还款，推算）',
  'dws_trf_distributor_credit_df、dim_trf_distribution_relation_zip、dws_fin_merchant_unsettled_df、dwd_fin_merchant_order_fund_di', 'ads_fin_merchant_report_di',
  '业务库没有授信还款明细：应收 / 应付余额 = 已用授信（分销关系 credit_used 快照）− 授信在途（已卖未核销未退）；还款 = 期初 + 本期增加 − 期末（推算）。'
  '同一笔授信，供应商一侧为应收、分销商一侧为应付，两侧金额应相等（质量规则对账）', [
      ('merchant_tenant_id', 'BIGINT', '粒度键', '本方商户租户ID：应收为授信供应商，应付为授信分销商', 'dim_trf_distribution_relation_zip.supplier_tenant_id / distributor_tenant_id', 'dim.dim_trf_distribution_relation_zip.supplier_tenant_id'),
      ('counterparty_tenant_id', 'BIGINT', '粒度键', '对方租户ID：应收为欠款的分销商，应付为债权供应商', 'dim_trf_distribution_relation_zip.distributor_tenant_id / supplier_tenant_id', 'dim.dim_trf_distribution_relation_zip.distributor_tenant_id'),
      ('report_code', 'STRING', '粒度键', '报表：AR-应收，AP-应付', '常量（与 dwd 报表编码一致）', 'dwd.dwd_fin_merchant_order_fund_di.report_code'),
      ('credit_used_amt', 'DECIMAL(18,2)', '指标', '已用授信：日终分销关系已占用授信额度（含未核销票），单位：元', 'dws_trf_distributor_credit_df.credit_used_amt', 'dws.dws_trf_distributor_credit_df.credit_used_amt'),
      ('credit_unsettled_amt', 'DECIMAL(18,2)', '指标', '授信在途：日终授信卖出 / 采购、尚未核销且未退款的金额，单位：元', "dws_fin_merchant_unsettled_df：SUM(unsettled_amt) where report_code in ('CREDIT_IN','CREDIT_OUT')", 'dws.dws_fin_merchant_unsettled_df.unsettled_amt'),
      ('open_amt', 'DECIMAL(18,2)', '指标', '期初应收 / 应付：上日 close_amt，单位：元', 'T-1 快照 close_amt', 'dws.dws_fin_merchant_credit_df.close_amt'),
      ('add_amt', 'DECIMAL(18,2)', '指标', '本期增加：授信票核销记应收 / 应付的金额，单位：元', "dwd_fin_merchant_order_fund_di：SUM(event_amt) where report_code in ('AR','AP')", 'dwd.dwd_fin_merchant_order_fund_di.event_amt'),
      ('settle_amt', 'DECIMAL(18,2)', '指标', '本期还款（推算）：期初 + 本期增加 − 期末；业务库无还款明细，为负说明核销前提前还款或额度被人工调整，单位：元', 'open_amt + add_amt − close_amt', 'dws.dws_trf_distributor_credit_df.credit_used_amt、dws.dws_fin_merchant_unsettled_df.unsettled_amt'),
      ('close_amt', 'DECIMAL(18,2)', '指标', '期末应收 / 应付：已用授信 − 授信在途（时点值），单位：元', 'credit_used_amt − credit_unsettled_amt', 'dws.dws_trf_distributor_credit_df.credit_used_amt、dws.dws_fin_merchant_unsettled_df.unsettled_amt'),
      ('travel_date', 'STRING', '分区', '数据日期，格式 YYYYMMDD（分区字段）', '${bizdate}', ''),
      ('etl_time', 'STRING', 'ETL', 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss', '调度写入', '')])

# ---- ADS
RPT = [('adv_receipt_open_amt', '期初预收', '截至统计日前一日日终的预收余额（时点值）', 'dws_fin_merchant_unsettled_df（T-1）', 'snap'),
       ('adv_receipt_receive_amt', '本期收', '订单卖出金额（不论款项是否到账，不含渠道手续费）', 'dws_fin_merchant_order_fund_di.receive_amt', 'sum'),
       ('adv_receipt_refund_amt', '本期退', '退给下级的金额', 'dws_fin_merchant_order_fund_di.refund_amt', 'sum'),
       ('adv_receipt_to_revenue_amt', '本期转确认收入', '因履约转入确认收入的金额', 'dws_fin_merchant_order_fund_di.to_revenue_amt', 'sum'),
       ('adv_receipt_close_amt', '期末预收', '截至统计日日终的预收余额 = 期初 + 收 − 退 − 转确认收入（时点值）', 'dws_fin_merchant_unsettled_df（T）', 'snap'),
       ('adv_payment_open_amt', '期初预付', '截至统计日前一日日终的预付余额（时点值）', 'dws_fin_merchant_unsettled_df（T-1）', 'snap'),
       ('adv_payment_pay_amt', '本期付', '向上级采购付款金额', 'dws_fin_merchant_order_fund_di.pay_amt', 'sum'),
       ('adv_payment_return_amt', '本期退回', '上级退回金额', 'dws_fin_merchant_order_fund_di.return_amt', 'sum'),
       ('adv_payment_to_cost_amt', '本期转确认成本', '因履约转入成本确认的金额', 'dws_fin_merchant_order_fund_di.to_cost_amt', 'sum'),
       ('adv_payment_close_amt', '期末预付', '截至统计日日终的预付余额 = 期初 + 付 − 退回 − 转确认成本（时点值）', 'dws_fin_merchant_unsettled_df（T）', 'snap'),
       ('ar_open_amt', '期初应收', '截至统计日前一日日终的应收余额（授信卖出且已核销、下级尚未还款，时点值）', 'dws_fin_merchant_credit_df.open_amt', 'snap'),
       ('ar_add_amt', '本期应收增加', '授信卖出的票本期核销记应收的金额', 'dws_fin_merchant_credit_df.add_amt', 'sum'),
       ('ar_settle_amt', '本期收回', '下级本期还款金额（推算：期初 + 增加 − 期末）', 'dws_fin_merchant_credit_df.settle_amt', 'sum'),
       ('ar_close_amt', '期末应收', '截至统计日日终的应收余额 = 已用授信 − 授信在途（时点值）', 'dws_fin_merchant_credit_df.close_amt', 'snap'),
       ('ap_open_amt', '期初应付', '截至统计日前一日日终的应付余额（授信采购且已核销、本方尚未还款，时点值）', 'dws_fin_merchant_credit_df.open_amt', 'snap'),
       ('ap_add_amt', '本期应付增加', '授信采购的票本期核销记应付的金额', 'dws_fin_merchant_credit_df.add_amt', 'sum'),
       ('ap_settle_amt', '本期偿还', '本方本期还款金额（推算）', 'dws_fin_merchant_credit_df.settle_amt', 'sum'),
       ('ap_close_amt', '期末应付', '截至统计日日终的应付余额（时点值）', 'dws_fin_merchant_credit_df.close_amt', 'snap'),
       ('credit_sale_amt', '授信销售', '下级以授信采购的金额（钱未收，不进预收）', 'dws_fin_merchant_order_fund_di.credit_sale_amt', 'sum'),
       ('credit_purchase_amt', '授信采购', '本方以授信向上级采购的金额（钱未付，不进预付）', 'dws_fin_merchant_order_fund_di.credit_purchase_amt', 'sum'),
       ('revenue_amt', '确认收入', '因履约确认的收入（总额法；含授信票）', 'dws_fin_merchant_order_fund_di.revenue_amt', 'sum'),
       ('cost_amt', '确认成本', '因履约确认的成本', 'dws_fin_merchant_order_fund_di.cost_amt', 'sum'),
       ('net_ticket_qty', '净票数', '售票数 − 退款票数（核销不改变票数）', 'dws_fin_merchant_order_fund_di：sale_ticket_qty − refund_ticket_qty', 'sum'),
       ('balance_open_amt', '期初余额', '统计日第一笔流水前的可用余额（时点值，由流水累计得出）', 'dws_fin_account_balance_df.opening_balance_amt', 'snap'),
       ('balance_in_amt', '资金流入', '本期实际进入可用余额的金额（含充值）', 'dws_fin_merchant_balance_di.fund_in_amt', 'sum'),
       ('balance_out_amt', '资金流出', '本期实际离开可用余额的金额（含提现、费用）', 'dws_fin_merchant_balance_di.fund_out_amt', 'sum'),
       ('balance_close_amt', '期末余额', '统计日日终可用余额 = 期初 + 流入 − 流出（时点值）', 'dws_fin_account_balance_df.closing_balance_amt', 'snap'),
       ('recharge_amt', '充值金额', '流入中的充值（可下钻，余额报表不单列）', "dws_fin_merchant_balance_di：fund_in_amt where flow_type='RECHARGE'", 'sum'),
       ('withdraw_amt', '提现金额', '流出中的提现', "dws_fin_merchant_balance_di：fund_out_amt where flow_type='WITHDRAW'", 'sum'),
       ('expense_income_amt', '费用收入', '订单之外的收入（二期：费用收支报表）', "dws_fin_merchant_balance_di：fund_in_amt where report_code='EXPENSE'", 'sum'),
       ('expense_out_amt', '费用支出', '订单之外的支出：应用套餐、平台服务费、手续费等（二期）', "dws_fin_merchant_balance_di：fund_out_amt where report_code='EXPENSE'", 'sum'),
       ('unclassified_flow_qty', '待归类流水笔数', '未命中归属规则的流水笔数（应为 0，非 0 进待归类异常清单）', "dws_fin_merchant_balance_di：fund_flow_qty where report_code='UNCLASSIFIED'", 'sum')]
ADS_UP = {'adv_receipt_open_amt': 'dws.dws_fin_merchant_unsettled_df.unsettled_amt', 'adv_receipt_close_amt': 'dws.dws_fin_merchant_unsettled_df.unsettled_amt',
          'adv_payment_open_amt': 'dws.dws_fin_merchant_unsettled_df.unsettled_amt', 'adv_payment_close_amt': 'dws.dws_fin_merchant_unsettled_df.unsettled_amt',
          'net_ticket_qty': 'dws.dws_fin_merchant_order_fund_di.sale_ticket_qty、dws.dws_fin_merchant_order_fund_di.refund_ticket_qty',
          'recharge_amt': 'dws.dws_fin_merchant_balance_di.fund_in_amt', 'withdraw_amt': 'dws.dws_fin_merchant_balance_di.fund_out_amt',
          'expense_income_amt': 'dws.dws_fin_merchant_balance_di.fund_in_amt', 'expense_out_amt': 'dws.dws_fin_merchant_balance_di.fund_out_amt',
          'unclassified_flow_qty': 'dws.dws_fin_merchant_balance_di.fund_flow_qty'}
ADS_FIELDS = [('merchant_tenant_id', 'BIGINT', '粒度键', '本方商户租户ID，关联 dim_sup_tenant_zip', 'dws 各表 merchant_tenant_id', 'dws.dws_fin_merchant_order_fund_di.merchant_tenant_id')] + [
    (f, 'BIGINT' if f.endswith('_qty') else 'DECIMAL(18,2)', '指标', f"{cn}（{'日快照' if k == 'snap' else '日'}）：{kou}，单位：{'张' if f == 'net_ticket_qty' else '笔' if f.endswith('_qty') else '元'}", src,
     ADS_UP.get(f) or ('dws.' + src)) for f, cn, kou, src, k in RPT]
t('ADS', 'ads.ads_fin_merchant_report_di', '商户财务报表（日）', 'travel_date × merchant_tenant_id', '天级增量', 'travel_date（YYYYMMDD）',
  'dws_fin_merchant_unsettled_df、dws_fin_merchant_order_fund_di、dws_fin_merchant_balance_di、dws_fin_account_balance_df、dws_fin_merchant_credit_df',
  '一期：预收、预付、应收、应付、确认收入、确认成本、余额；二期：费用收支（费用收入 / 支出）；派生（未结转差额、毛利、净利）查询时计算不落表',
  'dws_fin_merchant_unsettled_df、dws_fin_merchant_order_fund_di、dws_fin_merchant_balance_di、dws_fin_account_balance_df、dws_fin_merchant_credit_df', '',
  '使用端：商户后台 · 财务 · 报表中心（T+1 定版数据）。区间查询：期初取区间首日的 *_open、期末取末日的 *_close、发生额 SUM（时点值不可跨期相加，需求 5.7）；'
  '派生：未结转差额 = adv_receipt_close − adv_payment_close，订单毛利 = revenue − cost，净利 = 毛利 − (expense_out − expense_income)；按产品 / 票种 / 付款方等维度查时直接读 DWD / DWS', ADS_FIELDS + [
      ('travel_date', 'STRING', '分区', '数据日期，格式 YYYYMMDD（分区字段）', '${bizdate}', ''),
      ('etl_time', 'STRING', 'ETL', 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss', '调度写入', '')])

# ---- 实时
FLOW_ODS_FIELDS = None   # 由 apply() 从 ods_fin_fund_flow_di 复制
t('ODS（实时）', 'ods.ods_fin_fund_flow_rt', '资金流水 binlog 流', '同源表，1行=1条源记录（CDC 变更流）', '实时（后缀待定）', '不落地：Flink CDC 源表，作业内直读 binlog',
  'pft-finance.t_fund_flow（Flink CDC 读 binlog）', '', '', 'dwd_fin_fund_flow_rt', RT_NOTE + '；补齐：余额报表当日流入 / 流出、余额明细实时化依赖此流', '@copy:ods.ods_fin_fund_flow_di')
t('DWD（实时）', 'dwd.dwd_fin_fund_flow_rt', '实时资金流水明细', '1行=1条流水（flow_no）', '实时（后缀待定）', 'StarRocks 按 travel_date 分区',
  'ods_fin_fund_flow_rt + dim_fin_account_df + dim_fin_report_rule_f', '度量：change_amt、balance_after_amt；归属：report_code',
  'ods_fin_fund_flow_rt、dim_fin_account_df、dim_fin_report_rule_f、dwd_fin_fund_flow_di', 'ads_fin_merchant_report_rt', RT_NOTE + '；字段与离线 dwd_fin_fund_flow_di 同口径', '@copy:dwd.dwd_fin_fund_flow_di+report')
t('DWD（实时）', 'dwd.dwd_fin_merchant_order_fund_rt', '实时商户订单资金明细', '1行=1个本方商户 × 1张票 × 1个资金动作', '实时（后缀待定）', 'StarRocks 按 travel_date 分区',
  'dwd_fin_payment_rt + dwd_ord_refund_rt + dwd_fin_frozen_rt（Flink），维度 lookup dwd_fin_payment_rt / dwd_ord_ticket_di', '同离线 dwd_fin_merchant_order_fund_di',
  'dwd_fin_payment_rt、dwd_ord_refund_rt、dwd_fin_frozen_rt、dim_fin_report_rule_f、dim_fin_settle_timing_df', 'ads_fin_merchant_report_rt',
  RT_NOTE + '；当日段与离线 T+1 段字段完全一致，报表服务按日期分段拼接（需求第六章）', '@copy:dwd.dwd_fin_merchant_order_fund_di')
t('ADS（实时）', 'ads.ads_fin_merchant_report_rt', '商户财务报表（当日实时）', 'merchant_tenant_id × 今日', '实时（后缀待定）', 'StarRocks 按 travel_date 分区',
  'dwd_fin_merchant_order_fund_rt + dwd_fin_fund_flow_rt + ads_fin_merchant_report_di（T-1 期末作为今日期初）', '同 ads_fin_merchant_report_di（今日）',
  'dwd_fin_merchant_order_fund_rt、dwd_fin_fund_flow_rt、ads_fin_merchant_report_di', '',
  '使用端：商户后台 · 财务 · 报表中心（今日段）。页面提示「数据截至 HH:MM，当日仍在变动」；余额报表始终取此表（需求 6.3）', '@copy:ads.ads_fin_merchant_report_di')

# ---------------------------------------------------------------- 归属规则种子
# (编码, 来源, 流水类型, 费用项, 方向, 付款性质, 冻结事件, 报表, 列, 符号, 说明, 确认状态)
RULES = [
    ('FR01', 'PAYMENT', '', '', 'IN', 'CASH', '', 'ADV_RECEIPT', 'RECEIVE', 1, '下级现款支付（本方为收款方）：钱已收、未提供 → 预收 +（需求 5.2-1）', 'CONFIRMED'),
    ('FR02', 'PAYMENT', '', '', 'OUT', 'CASH', '', 'ADV_PAYMENT', 'PAY', 1, '向上级现款采购（本方为采购付款方）：钱已付、未取得 → 预付 +（5.2-4）', 'CONFIRMED'),
    ('FR03', 'REFUND', '', '', 'IN', 'CASH', '', 'ADV_RECEIPT', 'REFUND', -1, '履约前退款，本方退给下级 → 预收 −（5.2-3）', 'CONFIRMED'),
    ('FR04', 'REFUND', '', '', 'OUT', 'CASH', '', 'ADV_PAYMENT', 'RETURN', -1, '上级退回本方采购款 → 预付 −（5.2-6）', 'CONFIRMED'),
    ('FR05', 'VERIFY', '', '', 'IN', 'CASH', 'VERIFY', 'ADV_RECEIPT', 'TO_REVENUE', -1, '核销（收侧）→ 预收 −（5.2-2）', 'CONFIRMED'),
    ('FR06', 'VERIFY', '', '', 'IN', 'CASH', 'VERIFY', 'REVENUE', 'CONFIRM', 1, '核销（收侧）→ 确认收入 +（5.2-2）', 'CONFIRMED'),
    ('FR07', 'VERIFY', '', '', 'OUT', 'CASH', 'VERIFY', 'ADV_PAYMENT', 'TO_COST', -1, '核销（付侧）→ 预付 −（5.2-5）', 'CONFIRMED'),
    ('FR08', 'VERIFY', '', '', 'OUT', 'CASH', 'VERIFY', 'COST', 'CONFIRM', 1, '核销（付侧）→ 确认成本 +（5.2-5）', 'CONFIRMED'),
    ('FR09', 'PAY_SETTLE', '', '', 'IN', 'CASH', '', 'ADV_RECEIPT', 'TO_REVENUE', -1, '支付即结算：收款同时转确认收入（5.8）', 'PENDING'),
    ('FR10', 'PAY_SETTLE', '', '', 'IN', 'CASH', '', 'REVENUE', 'CONFIRM', 1, '支付即结算：收款同时确认收入（5.8）', 'PENDING'),
    ('FR11', 'PAY_SETTLE', '', '', 'OUT', 'CASH', '', 'ADV_PAYMENT', 'TO_COST', -1, '支付即结算：成本随收入同时确认（配比）', 'PENDING'),
    ('FR12', 'PAY_SETTLE', '', '', 'OUT', 'CASH', '', 'COST', 'CONFIRM', 1, '支付即结算：成本随收入同时确认（配比）', 'PENDING'),
    ('FR13', 'PAYMENT', '', '', 'IN', 'CREDIT', '', 'CREDIT_IN', 'RECEIVE', 1, '下级授信采购：钱未收、未提供 → 不进预收，记授信在途（占用授信额度，不动现金）', 'CONFIRMED'),
    ('FR14', 'PAYMENT', '', '', 'OUT', 'CREDIT', '', 'CREDIT_OUT', 'PAY', 1, '向上级授信采购：钱未付、未取得 → 不进预付，记授信在途', 'CONFIRMED'),
    ('FR15', 'REFUND', '', '', 'IN', 'CREDIT', '', 'CREDIT_IN', 'REFUND', -1, '授信票核销前退款：恢复额度，授信在途 −', 'CONFIRMED'),
    ('FR16', 'REFUND', '', '', 'OUT', 'CREDIT', '', 'CREDIT_OUT', 'RETURN', -1, '授信票核销前退款（付侧）：授信在途 −', 'CONFIRMED'),
    ('FR17', 'VERIFY', '', '', 'IN', 'CREDIT', 'VERIFY', 'CREDIT_IN', 'TO_REVENUE', -1, '授信票核销（收侧）：授信在途 −', 'CONFIRMED'),
    ('FR18', 'VERIFY', '', '', 'IN', 'CREDIT', 'VERIFY', 'AR', 'ADD', 1, '授信票核销（收侧）：已提供、钱未收 → 应收 +（架构文档：授信核销后才记账）', 'CONFIRMED'),
    ('FR19', 'VERIFY', '', '', 'IN', 'CREDIT', 'VERIFY', 'REVENUE', 'CONFIRM', 1, '授信票核销（收侧）→ 确认收入 +', 'CONFIRMED'),
    ('FR20', 'VERIFY', '', '', 'OUT', 'CREDIT', 'VERIFY', 'CREDIT_OUT', 'TO_COST', -1, '授信票核销（付侧）：授信在途 −', 'CONFIRMED'),
    ('FR21', 'VERIFY', '', '', 'OUT', 'CREDIT', 'VERIFY', 'AP', 'ADD', 1, '授信票核销（付侧）：已取得、钱未付 → 应付 +', 'CONFIRMED'),
    ('FR22', 'VERIFY', '', '', 'OUT', 'CREDIT', 'VERIFY', 'COST', 'CONFIRM', 1, '授信票核销（付侧）→ 确认成本 +', 'CONFIRMED'),
    ('FR31', 'FUND_FLOW', 'FREEZE', '', '', '', '', 'NONE', 'OUT', 0, '冻结：不进表（5.2-11）', 'CONFIRMED'),
    ('FR32', 'FUND_FLOW', 'UNFREEZE', '', '', '', 'REFUND', 'NONE', 'IN', 0, '解冻（退款释放）：不进表（5.2-12）', 'PENDING'),
    ('FR33', 'FUND_FLOW', 'UNFREEZE', '', 'IN', '', 'VERIFY', 'BALANCE', 'IN', 1, '解冻（核销触发，界面叫「结算」）：属于本方的份额转入可用余额', 'PENDING'),
    ('FR34', 'FUND_FLOW', 'RECHARGE', '', 'IN', '', '', 'BALANCE', 'IN', 1, '充值：仅余额 +（5.2-9）', 'CONFIRMED'),
    ('FR35', 'FUND_FLOW', 'RECHARGE', '', 'OUT', '', '', 'BALANCE', 'OUT', -1, '扣款：仅余额 −', 'CONFIRMED'),
    ('FR36', 'FUND_FLOW', 'WITHDRAW', '', 'OUT', '', '', 'BALANCE', 'OUT', -1, '提现：仅余额 −（5.2-10）', 'CONFIRMED'),
    ('FR37', 'FUND_FLOW', 'FEE', '', 'OUT', '', '', 'EXPENSE', 'EXPENSE', -1, '平台服务费 / 手续费（fee_item 区分短信费、提现手续费等）：费用收支 · 支出（5.2-8）', 'CONFIRMED'),
    ('FR38', 'FUND_FLOW', 'FEE', '', 'IN', '', '', 'EXPENSE', 'INCOME', 1, '手续费退回 / 返还：费用收支 · 收入', 'PENDING'),
    ('FR39', 'FUND_FLOW', 'RESOURCE', '', 'OUT', '', '', 'EXPENSE', 'EXPENSE', -1, '应用套餐 / 资源包（短信、积分、预警额度）购买：费用收支 · 支出（5.2-7）；资源批次 purchase_no 可回查', 'CONFIRMED'),
    ('FR40', 'FUND_FLOW', 'PAYMENT', '', '', '', '', 'BALANCE', '', 1, '订单收款流水：只影响余额（订单报表取支付记录）', 'CONFIRMED'),
    ('FR41', 'FUND_FLOW', 'REFUND', '', '', '', '', 'BALANCE', '', 1, '订单退款流水：只影响余额（订单报表取退款明细）', 'CONFIRMED'),
    ('FR42', 'FUND_FLOW', 'TRANSFER_OUT', '', 'OUT', '', '', 'BALANCE', 'OUT', -1, '采购扣转出：只影响余额（订单报表取采购付款支付记录）；需求未定义此类型', 'PENDING'),
    ('FR43', 'FUND_FLOW', 'TRANSFER_IN', '', 'IN', '', '', 'BALANCE', 'IN', 1, '采购扣转入：只影响余额；业务库注释未列此值，以实际数据为准', 'PENDING'),
]


def rule_rows():
    return ',\n        '.join("('" + "', '".join(str(x) for x in r[:9]) + f"', {r[9]}, '{r[10]}', '{r[11]}')" for r in RULES)


# ---------------------------------------------------------------- 加工逻辑
P = "travel_date = '${bizdate}'"
BD = "DATE_FORMAT(TO_DATE('${bizdate}', 'yyyyMMdd'), 'yyyy-MM-dd')"
WIN = "travel_date >= DATE_FORMAT(DATE_SUB(TO_DATE('${bizdate}', 'yyyyMMdd'), 400), 'yyyyMMdd')"


def hdr(name, cn, why, perf):
    L = ['-- ' + '=' * 96, f'-- {name}  {cn}', f'-- 依据：{SRC_DOC}', '-- 业务规则：'] + [f'--   · {x}' for x in why] + ['-- 性能：'] + [f'--   · {x}' for x in perf] + ['-- ' + '=' * 96]
    return '\n'.join(L) + '\n'


ETL = {}
ETL['dim_fin_report_rule_f'] = ('hive', hdr('dim.dim_fin_report_rule_f', '财务报表归属规则',
    ['规则表人工维护，改归属只改这里，不发版（需求 7.4）', '资金流水未命中规则的进「待归类」，不得默认归类（需求 5.5）',
     'confirm_status=PENDING 的规则依赖研发确认：结算时点字段、采购扣转（TRANSFER_OUT/IN）、解冻流水的冻结事件'], ['码表，几十行，下游 BROADCAST']) + f"""
INSERT OVERWRITE TABLE dim.dim_fin_report_rule_f
SELECT rule_code, source_type, flow_type, fee_item_code, direction_type, pay_method_group_type, frozen_event_type, report_code, measure_code, sign_qty, rule_desc, confirm_status,
       {NOW} AS etl_time
FROM VALUES
        {rule_rows()}
    AS v(rule_code, source_type, flow_type, fee_item_code, direction_type, pay_method_group_type, frozen_event_type, report_code, measure_code, sign_qty, rule_desc, confirm_status);
""")
ETL['dim_fin_settle_timing_df'] = ('hive', hdr('dim.dim_fin_settle_timing_df', '结算时点配置',
    ['结算时点配在支付方式上，不按渠道写死（需求 5.8）', '待确认：业务库暂无该字段，此处按约定字段名 settle_timing / valid_start_time 读取，字段补齐前全部取 VERIFY（核销即结算）'],
    ['全量小表']) + f"""
INSERT OVERWRITE TABLE dim.dim_fin_settle_timing_df PARTITION (travel_date = '${{bizdate}}')
SELECT
    c.tenant_id,
    m.pay_method_type,
    'VERIFY'                                                         AS settle_timing_type,     -- 待确认：业务库补 settle_timing 后改为 COALESCE(c.settle_timing, 'VERIFY')
    CAST(NULL AS STRING)                                             AS valid_start_time,       -- 待确认：同上
    {NOW} AS etl_time
FROM (SELECT DISTINCT tenant_id FROM ods.ods_fin_merchant_payment_config_df WHERE {P}) c
CROSS JOIN (SELECT pay_method_type FROM VALUES ('BALANCE'), ('WECHAT'), ('ALIPAY'), ('CREDIT'), ('OFFLINE'), ('ZERO_FEE') AS v(pay_method_type)) m;
""")

SIDE_SEL = ',\n        '.join(['t.spu_id', 't.sku_id', 'g.channel_id', 'g.channel_type', "IF(g.operator_type = 'TENANT_STAFF', g.operator_id, 0) AS seller_staff_id",
                                 'CAST(NULL AS STRING) AS sale_point_code /* 待确认：业务库无售票站点 */'])
ETL['dwd_fin_merchant_order_fund_di'] = ('hive', hdr('dwd.dwd_fin_merchant_order_fund_di', '商户订单资金明细（财务报表事实）',
    ['全部来自 ODS 基础表：支付记录（ods_fin_payment_record_di）、退款明细 / 退款单（ods_ord_refund_detail_di / ods_ord_refund_order_di.refund_items）、'
     '冻结记录（ods_fin_frozen_record_di，核销解冻时间取 binlog）、票 / 子单 / 聚合单（ods_ord_ticket_di / ods_ord_order_di / ods_ord_order_group_di）',
     '一笔支付记录拆成两侧：收款方（payee_account_no → 主体）记「收」，采购付款方（payer_account_no → 主体）记「付」；只取商户自己这一侧，双式记账不重复（风险 2）',
     '金额 = 支付记录 amount（这笔记录实际转移的钱，收款方收到、付款方付出）。settle_amount 注释写「INBOUND=售价」与架构文档「利润 = amount − settle_amount」矛盾，不用于计量',
     '支付记录的 ticket_no 默认空串（按聚合单支付）：按票单价 unit_price_amt 占比分摊到聚合单下每张票；退款同理按退款单 refund_items 的票金额占比分摊',
     '现款（余额 / 微信 / 支付宝 / 线下 / 0 元）：支付记 预收 + / 预付 +，退款记 预收 − / 预付 −，核销记 预收 − → 确认收入 +、预付 − → 确认成本 +',
     '授信（pay_method=CREDIT，只占额度不动现金）：支付与核销前退款只记「授信在途」，不进预收 / 预付；核销时记 应收 + / 应付 + 与确认收入 / 成本（架构文档 3.5.2：授信核销后才记账）',
     '支付即结算（结算时点配置，待业务库补字段）：现款收款当日同时确认',
     '维度：产品 / 票种 / 渠道 / 售票员取订单与票；付款方、收款方、卖出 / 买入单价、收款 / 付款支付方式按本方两侧支付记录取（需求 4.4 三对收付维度分开）'],
    ['票维度与两侧支付信息先按 (商户, 票) 汇成一行（side），各类动作只关联一次',
     '支付 / 票只扫近 400 天分区（票有效期上限），按聚合单 / 票号等值关联', '归属规则、结算时点为小表 BROADCAST']) + f"""
WITH tk AS (   -- 票：聚合单内按单价占比（全 0 元时均分）
    SELECT ticket_no, order_no, order_group_no, spu_id, sku_id,
           COALESCE(unit_price_amt / NULLIF(SUM(unit_price_amt) OVER (PARTITION BY order_group_no), 0),
                    1.0 / COUNT(*) OVER (PARTITION BY order_group_no))  AS w
    FROM dwd.dwd_ord_ticket_di
    WHERE {WIN}
),
pay AS (   -- 支付记录落到票（近 400 天，退款 / 核销要回找原支付）
    SELECT p.payment_no, p.order_group_no, COALESCE(NULLIF(p.ticket_no, ''), t.ticket_no) AS ticket_no, p.pay_direction_type, p.pay_method_type,
           CAST(p.pay_amt * IF(p.ticket_no = '', t.w, 1) AS DECIMAL(18,2)) AS amt,
           p.pay_time, p.payee_tenant_id, p.payer_tenant_id,
           IF(p.pay_method_type = 'CREDIT', 'CREDIT', 'CASH')              AS pm_grp
    FROM (SELECT * FROM dwd.dwd_fin_payment_di WHERE {WIN} AND pay_status IN ('PAID', 'PARTIAL_REFUNDED', 'REFUNDED')) p
    LEFT JOIN tk t ON p.ticket_no = '' AND t.order_group_no = p.order_group_no
),
side AS (   -- (本方商户, 票) → 收侧 / 付侧支付信息
    SELECT merchant_tenant_id, ticket_no,
           MAX(IF(side = 'IN', payment_no, NULL))          AS in_payment_no,
           MAX(IF(side = 'IN', amt, NULL))                 AS sale_unit_price_amt,
           MAX(IF(side = 'IN', pay_method_type, NULL))     AS receive_pay_method_type,
           MAX(IF(side = 'IN', counterparty, NULL))        AS payer_tenant_id,
           MAX(IF(side = 'IN', cp_type, NULL))             AS payer_type,
           MAX(IF(side = 'OUT', payment_no, NULL))         AS out_payment_no,
           MAX(IF(side = 'OUT', amt, NULL))                AS buy_unit_price_amt,
           MAX(IF(side = 'OUT', pay_method_type, NULL))    AS pay_pay_method_type,
           MAX(IF(side = 'OUT', counterparty, NULL))       AS payee_tenant_id,
           MAX(order_group_no)                             AS order_group_no
    FROM (
        SELECT payee_tenant_id AS merchant_tenant_id, ticket_no, 'IN' AS side, payment_no, amt, pay_method_type, order_group_no,
               IF(pay_direction_type = 'OUTBOUND', payer_tenant_id, 0) AS counterparty,
               IF(pay_direction_type = 'OUTBOUND', 'DISTRIBUTOR', 'CUSTOMER') AS cp_type
        FROM pay
        UNION ALL
        SELECT payer_tenant_id, ticket_no, 'OUT', payment_no, amt, pay_method_type, order_group_no, payee_tenant_id, 'SUPPLIER'
        FROM pay WHERE pay_direction_type = 'OUTBOUND'
    ) x
    GROUP BY merchant_tenant_id, ticket_no
),
dims AS (
    SELECT /*+ BROADCAST(st) */ s.*, t.order_no,
        {SIDE_SEL},
        COALESCE(st.settle_timing_type, 'VERIFY') AS settle_timing_type
    FROM side s
    LEFT JOIN tk t ON t.ticket_no = s.ticket_no
    LEFT JOIN (SELECT order_group_no, channel_id, channel_type, operator_type, operator_id FROM dwd.dwd_ord_order_group_di WHERE {WIN}) g ON g.order_group_no = s.order_group_no
    LEFT JOIN (SELECT tenant_id, pay_method_type, settle_timing_type FROM dim.dim_fin_settle_timing_df WHERE {P}) st
           ON st.tenant_id = s.merchant_tenant_id AND st.pay_method_type = s.receive_pay_method_type
),
ref AS (   -- 当日成功的退款明细（按支付记录）落到票：按退款单 refund_items 的票金额占比分摊
    SELECT r.refund_detail_no, r.finish_time, p.payment_no, p.ticket_no, p.pay_direction_type, p.payee_tenant_id, p.payer_tenant_id, p.pm_grp,
           CAST(r.refund_amt * COALESCE(rt.refund_amt / NULLIF(SUM(rt.refund_amt) OVER (PARTITION BY r.refund_detail_no), 0),
                                        1.0 / COUNT(*) OVER (PARTITION BY r.refund_detail_no)) AS DECIMAL(18,2)) AS amt
    FROM (SELECT refund_detail_no, refund_no, payment_no, refund_amt, finish_time FROM dwd.dwd_fin_refund_payment_di WHERE {P} AND refund_detail_status = 'SUCCESS') r
    JOIN (SELECT refund_no, ticket_no, refund_amt FROM dwd.dwd_ord_refund_ticket_di WHERE {WIN}) rt ON rt.refund_no = r.refund_no
    JOIN pay p ON p.payment_no = r.payment_no AND p.ticket_no = rt.ticket_no
),
ev AS (   -- 当日资金动作（本方视角）：side IN = 收侧，OUT = 付侧
    -- ① 支付：收 / 付
    SELECT 'PAYMENT' AS source_type, payment_no AS source_no, payee_tenant_id AS merchant_tenant_id, ticket_no, 'IN' AS side, pm_grp, amt, pay_time AS event_time, 1 AS tk
    FROM pay WHERE DATE_FORMAT(pay_time, 'yyyyMMdd') = '${{bizdate}}'
    UNION ALL
    SELECT 'PAYMENT', payment_no, payer_tenant_id, ticket_no, 'OUT', pm_grp, amt, pay_time, 1
    FROM pay WHERE pay_direction_type = 'OUTBOUND' AND DATE_FORMAT(pay_time, 'yyyyMMdd') = '${{bizdate}}'
    UNION ALL
    -- ② 退款：退 / 退回（同一支付记录的收、付两侧成对冲减）
    SELECT 'REFUND', refund_detail_no, payee_tenant_id, ticket_no, 'IN', pm_grp, amt, finish_time, -1 FROM ref
    UNION ALL
    SELECT 'REFUND', refund_detail_no, payer_tenant_id, ticket_no, 'OUT', pm_grp, amt, finish_time, -1 FROM ref WHERE pay_direction_type = 'OUTBOUND'
),
verify AS (   -- ③ 核销：票的冻结记录当日因核销解冻（release_time = 状态变 RELEASED 的 binlog 时间；同票多账户取最早）
    SELECT ticket_no, MIN(release_time) AS release_time, MIN(frozen_no) AS frozen_no
    FROM dwd.dwd_fin_frozen_di
    WHERE {P} AND frozen_status = 'RELEASED' AND release_event_type = 'VERIFY'
    GROUP BY ticket_no
),
rows AS (
    SELECT e.source_type, e.source_no, e.merchant_tenant_id, e.ticket_no, e.side, e.pm_grp, e.amt, e.event_time, e.tk FROM ev e
    UNION ALL
    -- 核销确认：核销即结算的现款票、全部授信票（收侧按卖出单价、付侧按买入单价）
    SELECT 'VERIFY', v.frozen_no, d.merchant_tenant_id, d.ticket_no, s.side, s.pm_grp, IF(s.side = 'IN', d.sale_unit_price_amt, d.buy_unit_price_amt), v.release_time, 0
    FROM verify v
    JOIN dims d ON d.ticket_no = v.ticket_no
    LATERAL VIEW INLINE(ARRAY(STRUCT('IN' AS side, IF(d.receive_pay_method_type = 'CREDIT', 'CREDIT', 'CASH') AS pm_grp),
                              STRUCT('OUT' AS side, IF(d.pay_pay_method_type = 'CREDIT', 'CREDIT', 'CASH') AS pm_grp))) s
    WHERE IF(s.side = 'IN', d.in_payment_no, d.out_payment_no) IS NOT NULL
      AND (d.settle_timing_type = 'VERIFY' OR s.pm_grp = 'CREDIT')
    UNION ALL
    -- 支付即结算：现款收款当日同时确认（成本随收入配比）
    SELECT 'PAY_SETTLE', p.source_no, d.merchant_tenant_id, d.ticket_no, s.side, 'CASH', IF(s.side = 'IN', d.sale_unit_price_amt, d.buy_unit_price_amt), p.event_time, 0
    FROM (SELECT source_no, merchant_tenant_id, ticket_no, event_time FROM ev WHERE source_type = 'PAYMENT' AND side = 'IN' AND pm_grp = 'CASH') p
    JOIN dims d ON d.merchant_tenant_id = p.merchant_tenant_id AND d.ticket_no = p.ticket_no AND d.settle_timing_type = 'PAY'
    LATERAL VIEW EXPLODE(ARRAY('IN', 'OUT')) s AS side
    WHERE IF(s.side = 'IN', d.in_payment_no, d.out_payment_no) IS NOT NULL
      AND COALESCE(IF(s.side = 'IN', d.receive_pay_method_type, d.pay_pay_method_type), '') <> 'CREDIT'
)
INSERT OVERWRITE TABLE dwd.dwd_fin_merchant_order_fund_di PARTITION (travel_date = '${{bizdate}}')
SELECT /*+ BROADCAST(rl) */
    CONCAT_WS(':', r.source_no, r.ticket_no, CAST(r.merchant_tenant_id AS STRING), rl.report_code, rl.measure_code) AS fund_event_id,
    r.event_time,
    r.merchant_tenant_id,
    rl.report_code,
    rl.measure_code,
    r.amt                                                            AS event_amt,
    r.amt * rl.sign_qty                                            AS balance_effect_amt,
    IF(rl.measure_code IN ('RECEIVE', 'PAY', 'REFUND', 'RETURN'), r.tk, 0) AS ticket_net_qty,
    r.source_type,
    r.pm_grp                                                         AS pay_method_group_type,
    r.source_no,
    IF(r.side = 'IN', d.in_payment_no, d.out_payment_no)             AS payment_no,
    d.order_group_no,
    d.order_no,
    r.ticket_no,
    d.spu_id, d.sku_id, d.channel_id, d.channel_type, d.seller_staff_id, d.sale_point_code,
    COALESCE(d.payer_tenant_id, 0)                                   AS payer_tenant_id,
    d.payer_type,
    COALESCE(d.payee_tenant_id, 0)                                   AS payee_tenant_id,
    IF(d.out_payment_no IS NULL, 'SELF', 'SUPPLIER')                 AS payee_type,
    d.sale_unit_price_amt,
    d.buy_unit_price_amt,
    d.receive_pay_method_type,
    d.pay_pay_method_type,
    d.settle_timing_type,
    {NOW} AS etl_time
FROM rows r
JOIN dims d ON d.merchant_tenant_id = r.merchant_tenant_id AND d.ticket_no = r.ticket_no
JOIN (SELECT * FROM dim.dim_fin_report_rule_f WHERE source_type IN ('PAYMENT', 'REFUND', 'VERIFY', 'PAY_SETTLE')) rl
  ON rl.source_type = r.source_type AND rl.direction_type = r.side AND rl.pay_method_group_type = r.pm_grp;
""")

UNS_DIMS = [n for n, *_ in SIDE_FIELDS if n != 'sale_point_code']
ETL['dws_fin_merchant_unsettled_df'] = ('hive', hdr('dws.dws_fin_merchant_unsettled_df', '预收预付在途快照',
    ['在途 = T-1 快照 + 当日预收 / 预付的余额影响（收 / 付 +，退 / 退回 / 转确认 −）；归零的票不再保留', '期初 = T-1 快照，期末 = T 快照（需求 5.7：时点值由累计得出，不独立维护）'],
    ['只读 T-1 一个分区 + 当日明细一个分区，不回扫历史流水', '先按 (商户, 报表, 票) 聚合当日变动再与快照合并']) + f"""
WITH today AS (
    SELECT merchant_tenant_id, report_code, ticket_no, MAX(order_no) AS order_no,
           {', '.join(f'MAX({d}) AS {d}' for d in UNS_DIMS)},
           SUM(balance_effect_amt) AS chg_amt, SUM(ticket_net_qty) AS chg_qty
    FROM dwd.dwd_fin_merchant_order_fund_di
    WHERE {P} AND report_code IN ('ADV_RECEIPT', 'ADV_PAYMENT', 'CREDIT_IN', 'CREDIT_OUT')
    GROUP BY merchant_tenant_id, report_code, ticket_no
),
prev AS (
    SELECT * FROM dws.dws_fin_merchant_unsettled_df
    WHERE travel_date = DATE_FORMAT(DATE_SUB(TO_DATE('${{bizdate}}', 'yyyyMMdd'), 1), 'yyyyMMdd')
)
INSERT OVERWRITE TABLE dws.dws_fin_merchant_unsettled_df PARTITION (travel_date = '${{bizdate}}')
SELECT
    COALESCE(n.merchant_tenant_id, p.merchant_tenant_id)            AS merchant_tenant_id,
    COALESCE(n.report_code, p.report_code)                          AS report_code,
    COALESCE(n.ticket_no, p.ticket_no)                              AS ticket_no,
    COALESCE(p.order_no, n.order_no)                                AS order_no,
    {(','+chr(10)+'    ').join(f'COALESCE(p.{d}, n.{d}){" " * max(1, 46 - 2 * len(d))}AS {d}' for d in UNS_DIMS)},
    COALESCE(p.unsettled_amt, 0) + COALESCE(n.chg_amt, 0)           AS unsettled_amt,
    COALESCE(p.unsettled_ticket_qty, 0) + COALESCE(n.chg_qty, 0)    AS unsettled_ticket_qty,
    COALESCE(p.first_event_date, '${{bizdate}}')                     AS first_event_date,
    {NOW} AS etl_time
FROM today n
FULL OUTER JOIN prev p ON p.merchant_tenant_id = n.merchant_tenant_id AND p.report_code = n.report_code AND p.ticket_no = n.ticket_no
WHERE ROUND(COALESCE(p.unsettled_amt, 0) + COALESCE(n.chg_amt, 0), 2) <> 0;
""")
ETL['dws_fin_merchant_order_fund_di'] = ('hive', hdr('dws.dws_fin_merchant_order_fund_di', '商户订单资金日汇总',
    ['期间值（需求 5.7）：本期收 / 退 / 转、付 / 退回 / 转、确认收入 / 成本，按报表常用维度汇总'], ['一次扫描当日明细，条件聚合出全部列']) + f"""
INSERT OVERWRITE TABLE dws.dws_fin_merchant_order_fund_di PARTITION (travel_date = '${{bizdate}}')
SELECT
    merchant_tenant_id, {', '.join(f'COALESCE({d}, {"0" if d.endswith("_id") else "chr(39)chr(39)"}) AS {d}' for d in AGG_DIMS)},
    {(','+chr(10)+'    ').join(f"SUM(IF(report_code = '{r}' AND measure_code = '{c}', event_amt, 0)) AS {m}_amt" for m, r, c, *_ in MEAS)},
    SUM(IF(measure_code = 'RECEIVE', ticket_net_qty, 0))            AS sale_ticket_qty,
    -SUM(IF(measure_code = 'REFUND', ticket_net_qty, 0))            AS refund_ticket_qty,
    {NOW} AS etl_time
FROM dwd.dwd_fin_merchant_order_fund_di
WHERE {P}
GROUP BY merchant_tenant_id, {', '.join(f'COALESCE({d}, {"0" if d.endswith("_id") else "chr(39)chr(39)"})' for d in AGG_DIMS)};
""".replace('chr(39)chr(39)', "''"))
ETL['dws_fin_merchant_balance_di'] = ('hive', hdr('dws.dws_fin_merchant_balance_di', '商户余额与费用日汇总',
    ['只取商户 / 分销商账户（平台账户不算），双式记账只算本方这一条（风险 2）', '归属按规则表：命中多条时取最具体（带冻结事件 > 带方向 > 只按流水类型）；都不命中 = UNCLASSIFIED（需求 5.5）',
     '解冻流水分核销 / 退款：关联同账户同票的冻结记录；待确认：流水 related_no 对解冻填什么（冻结单号 / 票号）需研发确认'],
    ['规则表 BROADCAST；冻结记录只取当日释放的']) + f"""
WITH f AS (
    SELECT /*+ BROADCAST(a) */ f.flow_no, f.account_no, a.subject_id AS merchant_tenant_id, f.flow_type, f.fee_item_code, f.change_amt, f.related_no,
           IF(f.change_amt >= 0, 'IN', 'OUT') AS direction_type
    FROM dwd.dwd_fin_fund_flow_di f
    JOIN (SELECT account_no, subject_id, account_type FROM dim.dim_fin_account_df WHERE {P} AND account_type IN ('MERCHANT', 'DISTRIBUTOR')) a ON a.account_no = f.account_no
    WHERE f.{P}
),
ev AS (   -- 解冻流水的冻结事件：related_no 对冻结单号或票号（待确认）
    SELECT account_no, frozen_no, ticket_no, release_event_type FROM dwd.dwd_fin_frozen_di WHERE {P} AND frozen_status = 'RELEASED'
),
m AS (
    SELECT f.*, COALESCE(e1.release_event_type, e2.release_event_type) AS frozen_event_type
    FROM f
    LEFT JOIN ev e1 ON f.flow_type = 'UNFREEZE' AND e1.account_no = f.account_no AND e1.frozen_no = f.related_no
    LEFT JOIN ev e2 ON f.flow_type = 'UNFREEZE' AND e1.frozen_no IS NULL AND e2.account_no = f.account_no AND e2.ticket_no = f.related_no
),
hit AS (   -- 规则匹配：取最具体的一条
    SELECT m.flow_no, r.report_code,
           ROW_NUMBER() OVER (PARTITION BY m.flow_no ORDER BY (r.frozen_event_type <> '') DESC, (r.direction_type <> '') DESC, (r.fee_item_code <> '') DESC) AS rn
    FROM m
    JOIN (SELECT * FROM dim.dim_fin_report_rule_f WHERE source_type = 'FUND_FLOW') r
      ON r.flow_type = m.flow_type AND (r.fee_item_code = '' OR r.fee_item_code = m.fee_item_code)
     AND (r.direction_type = '' OR r.direction_type = m.direction_type) AND (r.frozen_event_type = '' OR r.frozen_event_type = m.frozen_event_type)
)
INSERT OVERWRITE TABLE dws.dws_fin_merchant_balance_di PARTITION (travel_date = '${{bizdate}}')
SELECT m.merchant_tenant_id, m.account_no, COALESCE(h.report_code, 'UNCLASSIFIED') AS report_code, m.flow_type, COALESCE(m.fee_item_code, '') AS fee_item_code,
       SUM(IF(m.change_amt > 0, m.change_amt, 0))                    AS fund_in_amt,
       -SUM(IF(m.change_amt < 0, m.change_amt, 0))                   AS fund_out_amt,
       COUNT(m.flow_no)                                              AS fund_flow_qty,
       {NOW} AS etl_time
FROM m
LEFT JOIN (SELECT flow_no, report_code FROM hit WHERE rn = 1) h ON h.flow_no = m.flow_no
GROUP BY m.merchant_tenant_id, m.account_no, COALESCE(h.report_code, 'UNCLASSIFIED'), m.flow_type, COALESCE(m.fee_item_code, '');
""")
Y = "DATE_FORMAT(DATE_SUB(TO_DATE('${bizdate}', 'yyyyMMdd'), 1), 'yyyyMMdd')"


def union_sql(cols, branches):
    """各来源按商户预聚合（未涉及的列补 0）后 UNION ALL —— 按列名生成，避免位置错列"""
    out = []
    for note, key, src, m in branches:
        sel = [f'{key} AS merchant_tenant_id'] + [f'{m[c]} AS {c}' if c in m else f'0 AS {c}' for c in cols]
        out.append(f'    -- {note}\n    SELECT ' + ',\n           '.join(sel) + f'\n    {src}')
    return '\n    UNION ALL\n'.join(out)


ADS_BR = [
    ('在途快照：预收 / 预付 期初（T-1）、期末（T）', 'merchant_tenant_id',
     f"FROM dws.dws_fin_merchant_unsettled_df\n    WHERE travel_date IN ('${{bizdate}}', {Y}) AND report_code IN ('ADV_RECEIPT', 'ADV_PAYMENT')\n    GROUP BY merchant_tenant_id",
     {'adv_receipt_open_amt': "SUM(IF(report_code = 'ADV_RECEIPT' AND travel_date <> '${bizdate}', unsettled_amt, 0))",
      'adv_receipt_close_amt': "SUM(IF(report_code = 'ADV_RECEIPT' AND travel_date = '${bizdate}', unsettled_amt, 0))",
      'adv_payment_open_amt': "SUM(IF(report_code = 'ADV_PAYMENT' AND travel_date <> '${bizdate}', unsettled_amt, 0))",
      'adv_payment_close_amt': "SUM(IF(report_code = 'ADV_PAYMENT' AND travel_date = '${bizdate}', unsettled_amt, 0))"}),
    ('期间值：订单资金（预收 / 预付发生额、确认收入 / 成本、授信销售 / 采购、净票数）', 'merchant_tenant_id',
     "FROM dws.dws_fin_merchant_order_fund_di WHERE travel_date = '${bizdate}'\n    GROUP BY merchant_tenant_id",
     {'adv_receipt_receive_amt': 'SUM(receive_amt)', 'adv_receipt_refund_amt': 'SUM(refund_amt)', 'adv_receipt_to_revenue_amt': 'SUM(to_revenue_amt)',
      'adv_payment_pay_amt': 'SUM(pay_amt)', 'adv_payment_return_amt': 'SUM(return_amt)', 'adv_payment_to_cost_amt': 'SUM(to_cost_amt)',
      'credit_sale_amt': 'SUM(credit_sale_amt)', 'credit_purchase_amt': 'SUM(credit_purchase_amt)',
      'revenue_amt': 'SUM(revenue_amt)', 'cost_amt': 'SUM(cost_amt)', 'net_ticket_qty': 'SUM(sale_ticket_qty) - SUM(refund_ticket_qty)'}),
    ('应收 / 应付：期初、增加、收回 / 偿还、期末', 'merchant_tenant_id',
     "FROM dws.dws_fin_merchant_credit_df WHERE travel_date = '${bizdate}'\n    GROUP BY merchant_tenant_id",
     {f'{k}_{m}_amt': f"SUM(IF(report_code = '{k.upper()}', {m}_amt, 0))" for k in ('ar', 'ap') for m in ('open', 'add', 'settle', 'close')}),
    ('余额：期初 / 期末取账户日快照（同一主体多账户相加）', 'a.subject_id',
     f"FROM (SELECT account_no, opening_balance_amt, closing_balance_amt FROM dws.dws_fin_account_balance_df WHERE travel_date = '${{bizdate}}') b\n"
     f"    JOIN (SELECT account_no, subject_id FROM dim.dim_fin_account_df WHERE travel_date = '${{bizdate}}' AND account_type IN ('MERCHANT', 'DISTRIBUTOR')) a ON a.account_no = b.account_no\n"
     "    GROUP BY a.subject_id",
     {'balance_open_amt': 'SUM(b.opening_balance_amt)', 'balance_close_amt': 'SUM(b.closing_balance_amt)'}),
    ('余额流入 / 流出、费用收支、待归类：取归属后的流水', 'merchant_tenant_id',
     "FROM dws.dws_fin_merchant_balance_di WHERE travel_date = '${bizdate}'\n    GROUP BY merchant_tenant_id",
     {'balance_in_amt': "SUM(IF(report_code IN ('BALANCE', 'EXPENSE'), fund_in_amt, 0))", 'balance_out_amt': "SUM(IF(report_code IN ('BALANCE', 'EXPENSE'), fund_out_amt, 0))",
      'recharge_amt': "SUM(IF(flow_type = 'RECHARGE', fund_in_amt, 0))", 'withdraw_amt': "SUM(IF(flow_type = 'WITHDRAW', fund_out_amt, 0))",
      'expense_income_amt': "SUM(IF(report_code = 'EXPENSE', fund_in_amt, 0))", 'expense_out_amt': "SUM(IF(report_code = 'EXPENSE', fund_out_amt, 0))",
      'unclassified_flow_qty': "SUM(IF(report_code = 'UNCLASSIFIED', fund_flow_qty, 0))"}),
]
_C = [f for f, *_ in RPT]
ETL['ads_fin_merchant_report_di'] = ('hive', hdr('ads.ads_fin_merchant_report_di', '商户财务报表（日）',
    ['基础报表日值：预收 / 预付期初期末取在途快照，应收 / 应付取授信快照，余额取账户快照（时点值）；其余为当日发生额',
     '余额只统计「仅余额 / 费用」归属的流水，冻结与退款释放不进（需求第八章第 7 条说明）',
     '派生指标（未结转差额、毛利、净利）不落表，查询时由本表字段计算（需求核心原则 5）'],
    ['各来源先按商户预聚合，UNION ALL 后汇总，不做明细级关联']) + f"""
WITH x AS (
{union_sql(_C, ADS_BR)}
)
INSERT OVERWRITE TABLE ads.ads_fin_merchant_report_di PARTITION (travel_date = '${{bizdate}}')
SELECT
    merchant_tenant_id,
    {(','+chr(10)+'    ').join(f'SUM({c}){" " * max(1, 28 - len(c))}AS {c}' for c in _C)},
    {NOW} AS etl_time
FROM x
GROUP BY merchant_tenant_id;
""")
ETL['dws_fin_merchant_credit_df'] = ('hive', hdr('dws.dws_fin_merchant_credit_df', '商户应收应付快照',
    ['授信只占额度不动现金（架构文档 3.5.2）：核销前不算应收 / 应付（未收未提供），核销后记应收 / 应付',
     '业务库没有授信还款明细，余额由快照倒推：期末 = 分销关系已用授信 credit_used − 授信在途（已卖未核销未退）；还款 = 期初 + 本期增加 − 期末',
     '同一分销关系：供应商一侧记应收（对方 = 分销商），分销商一侧记应付（对方 = 供应商），两侧应相等'],
    ['分销关系、在途快照均按 (商户, 对方) 预聚合后 FULL JOIN']) + f"""
WITH rel AS (   -- 分销关系日终已用授信（只取授信模式）
    SELECT r.supplier_tenant_id, r.distributor_tenant_id, SUM(c.credit_used_amt) AS credit_used_amt
    FROM (SELECT relation_no, credit_used_amt FROM dws.dws_trf_distributor_credit_df WHERE {P}) c
    JOIN (SELECT relation_no, supplier_tenant_id, distributor_tenant_id FROM dim.dim_trf_distribution_relation_zip
          WHERE payment_mode_type = 'CREDIT' AND start_date <= '${{bizdate}}' AND end_date > '${{bizdate}}') r ON r.relation_no = c.relation_no
    GROUP BY r.supplier_tenant_id, r.distributor_tenant_id
),
used AS (
    SELECT supplier_tenant_id AS merchant_tenant_id, distributor_tenant_id AS counterparty_tenant_id, 'AR' AS report_code, credit_used_amt FROM rel
    UNION ALL
    SELECT distributor_tenant_id, supplier_tenant_id, 'AP', credit_used_amt FROM rel
),
uns AS (   -- 授信在途：收侧对方 = 付款方（下级），付侧对方 = 收款方（上级）
    SELECT merchant_tenant_id, IF(report_code = 'CREDIT_IN', payer_tenant_id, payee_tenant_id) AS counterparty_tenant_id,
           IF(report_code = 'CREDIT_IN', 'AR', 'AP') AS report_code, SUM(unsettled_amt) AS credit_unsettled_amt
    FROM dws.dws_fin_merchant_unsettled_df
    WHERE {P} AND report_code IN ('CREDIT_IN', 'CREDIT_OUT')
    GROUP BY 1, 2, 3
),
adds AS (   -- 本期核销记应收 / 应付
    SELECT merchant_tenant_id, IF(report_code = 'AR', payer_tenant_id, payee_tenant_id) AS counterparty_tenant_id, report_code, SUM(event_amt) AS add_amt
    FROM dwd.dwd_fin_merchant_order_fund_di
    WHERE {P} AND report_code IN ('AR', 'AP')
    GROUP BY 1, 2, 3
),
prev AS (
    SELECT merchant_tenant_id, counterparty_tenant_id, report_code, close_amt AS open_amt
    FROM dws.dws_fin_merchant_credit_df WHERE travel_date = {Y}
),
k AS (
    SELECT merchant_tenant_id, counterparty_tenant_id, report_code FROM used
    UNION SELECT merchant_tenant_id, counterparty_tenant_id, report_code FROM uns
    UNION SELECT merchant_tenant_id, counterparty_tenant_id, report_code FROM adds
    UNION SELECT merchant_tenant_id, counterparty_tenant_id, report_code FROM prev
),
v AS (
    SELECT k.*, COALESCE(u.credit_used_amt, 0) AS credit_used_amt, COALESCE(n.credit_unsettled_amt, 0) AS credit_unsettled_amt,
           COALESCE(p.open_amt, 0) AS open_amt, COALESCE(a.add_amt, 0) AS add_amt,
           COALESCE(u.credit_used_amt, 0) - COALESCE(n.credit_unsettled_amt, 0) AS close_amt
    FROM k
    LEFT JOIN used u ON u.merchant_tenant_id = k.merchant_tenant_id AND u.counterparty_tenant_id = k.counterparty_tenant_id AND u.report_code = k.report_code
    LEFT JOIN uns  n ON n.merchant_tenant_id = k.merchant_tenant_id AND n.counterparty_tenant_id = k.counterparty_tenant_id AND n.report_code = k.report_code
    LEFT JOIN adds a ON a.merchant_tenant_id = k.merchant_tenant_id AND a.counterparty_tenant_id = k.counterparty_tenant_id AND a.report_code = k.report_code
    LEFT JOIN prev p ON p.merchant_tenant_id = k.merchant_tenant_id AND p.counterparty_tenant_id = k.counterparty_tenant_id AND p.report_code = k.report_code
)
INSERT OVERWRITE TABLE dws.dws_fin_merchant_credit_df PARTITION (travel_date = '${{bizdate}}')
SELECT merchant_tenant_id, counterparty_tenant_id, report_code, credit_used_amt, credit_unsettled_amt, open_amt, add_amt,
       open_amt + add_amt - close_amt                                  AS settle_amt,
       close_amt,
       {NOW} AS etl_time
FROM v
WHERE ABS(open_amt) + ABS(add_amt) + ABS(close_amt) + ABS(credit_used_amt) > 0;
""")
ETL['dwd_fin_fund_flow_rt'] = ('flink', hdr('dwd.dwd_fin_fund_flow_rt', '实时资金流水明细',
    ['与离线 dwd_fin_fund_flow_di 同字段，另带归属 report_code（规则同 dim_fin_report_rule_f）', '只处理新增流水（binlog I），流水不可变'],
    ['规则表、账户维表 lookup join（缓存 10 分钟）']) + """
-- Flink SQL：ods_fin_fund_flow_rt（MySQL CDC）→ StarRocks dwd.dwd_fin_fund_flow_rt
INSERT INTO sr_dwd_fin_fund_flow_rt
SELECT
    DATE_FORMAT(f.create_time, 'yyyyMMdd')                           AS travel_date,
    f.id                                                             AS flow_id,
    f.flow_no, f.account_no, f.flow_type,
    CAST(f.amount AS DECIMAL(18,2)) / 100                            AS change_amt,
    CAST(f.balance_before AS DECIMAL(18,2)) / 100                    AS balance_before_amt,
    CAST(f.balance_after AS DECIMAL(18,2)) / 100                     AS balance_after_amt,
    f.related_no, f.payment_batch_no, f.fee_item                     AS fee_item_code,
    f.tenant_id, a.account_type, a.subject_id,
    IF(f.amount >= 0, 1, 2)                                          AS flow_direction_type,
    CAST(f.create_time AS STRING)                                    AS flow_time,
    COALESCE(r.report_code, 'UNCLASSIFIED')                          AS report_code,
    f.proc_time                                                      AS event_time
FROM ods_fin_fund_flow_rt f
LEFT JOIN dim_fin_account_lookup FOR SYSTEM_TIME AS OF f.proc_time AS a ON a.account_no = f.account_no
LEFT JOIN dim_fin_report_rule_lookup FOR SYSTEM_TIME AS OF f.proc_time AS r
       ON r.source_type = 'FUND_FLOW' AND r.flow_type = f.flow_type AND r.direction_type = IF(f.amount >= 0, 'IN', 'OUT')
WHERE f.op_type = 'I';
""")
ETL['dwd_fin_merchant_order_fund_rt'] = ('flink', hdr('dwd.dwd_fin_merchant_order_fund_rt', '实时商户订单资金明细',
    ['与离线 dwd_fin_merchant_order_fund_di 同口径同字段：支付拆收 / 付两侧，退款拆退 / 退回，核销解冻拆确认', '维度（产品 / 票种 / 渠道 / 售票员 / 两侧支付信息）按票 lookup 当日实时支付明细与票维表'],
    ['三条流 UNION ALL 后一次 lookup；lookup 缓存 5 分钟']) + """
-- Flink SQL：dwd_fin_payment_rt + dwd_ord_refund_rt + dwd_fin_frozen_rt → StarRocks dwd.dwd_fin_merchant_order_fund_rt
CREATE TEMPORARY VIEW ev AS
SELECT 'PAYMENT' AS source_type, payment_no AS source_no, payee_tenant_id AS merchant_tenant_id, ticket_no, 'IN' AS side,
       IF(pay_method_type = 'CREDIT', 'CREDIT', 'CASH') AS pm_grp, pay_amt AS amt, pay_time AS event_time, 1 AS tk, proc_time
FROM dwd_fin_payment_rt WHERE pay_status = 'PAID'
UNION ALL
SELECT 'PAYMENT', payment_no, payer_tenant_id, ticket_no, 'OUT', IF(pay_method_type = 'CREDIT', 'CREDIT', 'CASH'), pay_amt, pay_time, 1, proc_time
FROM dwd_fin_payment_rt WHERE pay_status = 'PAID' AND pay_direction_type = 'OUTBOUND'
UNION ALL
SELECT 'VERIFY', frozen_no, CAST(NULL AS BIGINT), ticket_no, 'ALL', CAST(NULL AS STRING), CAST(NULL AS DECIMAL(18,2)), CAST(release_time AS STRING), 0, proc_time
FROM dwd_fin_frozen_rt WHERE frozen_status = 'RELEASED' AND release_event_type = 'VERIFY';
-- 聚合单支付（ticket_no 为空）的分摊在物化视图 mv_fin_ticket_side 内完成，与离线同口径；此处 ticket_no 为空的支付由视图按票展开
-- 退款：待确认——实时链路只有退款单流（dwd_ord_refund_rt），退款明细（按支付记录）无实时流；需补 ods_ord_refund_detail_rt 后按离线同口径拆退 / 退回

INSERT INTO sr_dwd_fin_merchant_order_fund_rt
SELECT DATE_FORMAT(CAST(e.event_time AS TIMESTAMP), 'yyyyMMdd') AS travel_date,
       CONCAT_WS(':', e.source_no, e.ticket_no, CAST(COALESCE(e.merchant_tenant_id, s.merchant_tenant_id) AS STRING), r.report_code, r.measure_code) AS fund_event_id,
       e.event_time, COALESCE(e.merchant_tenant_id, s.merchant_tenant_id) AS merchant_tenant_id, r.report_code, r.measure_code,
       COALESCE(e.amt, IF(r.direction_type = 'IN', s.sale_unit_price_amt, s.buy_unit_price_amt)) AS event_amt,
       COALESCE(e.amt, IF(r.direction_type = 'IN', s.sale_unit_price_amt, s.buy_unit_price_amt)) * r.sign_qty AS balance_effect_amt,
       IF(r.measure_code IN ('RECEIVE', 'PAY'), e.tk, 0) AS ticket_net_qty,
       e.source_type, r.pay_method_group_type, e.source_no, s.payment_no, s.order_group_no, s.order_no, e.ticket_no,
       s.spu_id, s.sku_id, s.channel_id, s.channel_type, s.seller_staff_id, CAST(NULL AS STRING) AS sale_point_code,
       s.payer_tenant_id, s.payer_type, s.payee_tenant_id, s.payee_type, s.sale_unit_price_amt, s.buy_unit_price_amt,
       s.receive_pay_method_type, s.pay_pay_method_type, s.settle_timing_type
FROM ev e
-- 票 × 商户的两侧支付信息与订单维度：StarRocks 物化视图 mv_fin_ticket_side（由 dwd_fin_payment_rt + dwd_fin_payment_di 汇总），按票 lookup
JOIN mv_fin_ticket_side_lookup FOR SYSTEM_TIME AS OF e.proc_time AS s
  ON s.ticket_no = e.ticket_no AND (e.merchant_tenant_id IS NULL OR s.merchant_tenant_id = e.merchant_tenant_id)
JOIN dim_fin_report_rule_lookup FOR SYSTEM_TIME AS OF e.proc_time AS r
  ON r.source_type = e.source_type
 AND (   (r.direction_type = e.side AND r.pay_method_group_type = e.pm_grp)
      OR (e.side = 'ALL' AND IF(r.direction_type = 'IN', s.in_payment_no, s.out_payment_no) IS NOT NULL
          AND r.pay_method_group_type = IF(IF(r.direction_type = 'IN', s.receive_pay_method_type, s.pay_pay_method_type) = 'CREDIT', 'CREDIT', 'CASH')
          AND (s.settle_timing_type = 'VERIFY' OR r.pay_method_group_type = 'CREDIT')));
""")
ETL['ads_fin_merchant_report_rt'] = ('starrocks', hdr('ads.ads_fin_merchant_report_rt', '商户财务报表（当日实时）',
    ['今日段：期初 = 昨日离线定版期末（ads_fin_merchant_report_di T-1），发生额取实时明细，期末 = 期初 + 发生；应收 / 应付今日段不含还款（还款无明细，日终由授信快照倒推）', '余额报表始终实时（需求 6.3）：期末余额取账户实时可用余额'],
    ['StarRocks 异步物化视图，1 分钟刷新；分段拼接：报表服务对历史日期读 ads_fin_merchant_report_di、今日读本表，字段一致']) + """
CREATE MATERIALIZED VIEW ads.ads_fin_merchant_report_rt
REFRESH ASYNC EVERY (INTERVAL 1 MINUTE)
AS
WITH d AS (
    SELECT merchant_tenant_id,
           SUM(IF(report_code = 'ADV_RECEIPT' AND measure_code = 'RECEIVE', event_amt, 0))    AS adv_receipt_receive_amt,
           SUM(IF(report_code = 'ADV_RECEIPT' AND measure_code = 'REFUND', event_amt, 0))     AS adv_receipt_refund_amt,
           SUM(IF(report_code = 'ADV_RECEIPT' AND measure_code = 'TO_REVENUE', event_amt, 0)) AS adv_receipt_to_revenue_amt,
           SUM(IF(report_code = 'ADV_PAYMENT' AND measure_code = 'PAY', event_amt, 0))        AS adv_payment_pay_amt,
           SUM(IF(report_code = 'ADV_PAYMENT' AND measure_code = 'RETURN', event_amt, 0))     AS adv_payment_return_amt,
           SUM(IF(report_code = 'ADV_PAYMENT' AND measure_code = 'TO_COST', event_amt, 0))    AS adv_payment_to_cost_amt,
           SUM(IF(report_code = 'REVENUE', event_amt, 0))                                    AS revenue_amt,
           SUM(IF(report_code = 'COST', event_amt, 0))                                       AS cost_amt,
           SUM(ticket_net_qty)                                                               AS net_ticket_qty,
           SUM(IF(report_code = 'ADV_RECEIPT', balance_effect_amt, 0))                        AS adv_receipt_chg,
           SUM(IF(report_code = 'ADV_PAYMENT', balance_effect_amt, 0))                        AS adv_payment_chg,
           SUM(IF(report_code = 'AR', event_amt, 0))                                         AS ar_add_amt,
           SUM(IF(report_code = 'AP', event_amt, 0))                                         AS ap_add_amt,
           SUM(IF(report_code = 'CREDIT_IN' AND measure_code = 'RECEIVE', event_amt, 0))     AS credit_sale_amt,
           SUM(IF(report_code = 'CREDIT_OUT' AND measure_code = 'PAY', event_amt, 0))        AS credit_purchase_amt
    FROM dwd.dwd_fin_merchant_order_fund_rt
    WHERE travel_date = DATE_FORMAT(NOW(), '%Y%m%d')
    GROUP BY merchant_tenant_id
),
b AS (
    SELECT subject_id AS merchant_tenant_id,
           SUM(IF(report_code IN ('BALANCE', 'EXPENSE') AND change_amt > 0, change_amt, 0))  AS balance_in_amt,
           -SUM(IF(report_code IN ('BALANCE', 'EXPENSE') AND change_amt < 0, change_amt, 0)) AS balance_out_amt,
           SUM(IF(flow_type = 'RECHARGE' AND change_amt > 0, change_amt, 0))                 AS recharge_amt,
           -SUM(IF(flow_type = 'WITHDRAW' AND change_amt < 0, change_amt, 0))                AS withdraw_amt,
           SUM(IF(report_code = 'EXPENSE' AND change_amt > 0, change_amt, 0))                AS expense_income_amt,
           -SUM(IF(report_code = 'EXPENSE' AND change_amt < 0, change_amt, 0))               AS expense_out_amt,
           SUM(IF(report_code = 'UNCLASSIFIED', 1, 0))                                       AS unclassified_flow_qty
    FROM dwd.dwd_fin_fund_flow_rt
    WHERE travel_date = DATE_FORMAT(NOW(), '%Y%m%d') AND account_type IN ('MERCHANT', 'DISTRIBUTOR')
    GROUP BY subject_id
),
y AS (SELECT * FROM ads.ads_fin_merchant_report_di WHERE travel_date = DATE_FORMAT(DATE_SUB(NOW(), INTERVAL 1 DAY), '%Y%m%d')),
k AS (SELECT merchant_tenant_id FROM d UNION SELECT merchant_tenant_id FROM b UNION SELECT merchant_tenant_id FROM y)
SELECT
    DATE_FORMAT(NOW(), '%Y%m%d')                                                             AS travel_date,
    k.merchant_tenant_id,
    COALESCE(y.adv_receipt_close_amt, 0)                                                     AS adv_receipt_open_amt,
    COALESCE(d.adv_receipt_receive_amt, 0)                                                   AS adv_receipt_receive_amt,
    COALESCE(d.adv_receipt_refund_amt, 0)                                                    AS adv_receipt_refund_amt,
    COALESCE(d.adv_receipt_to_revenue_amt, 0)                                                AS adv_receipt_to_revenue_amt,
    COALESCE(y.adv_receipt_close_amt, 0) + COALESCE(d.adv_receipt_chg, 0)                    AS adv_receipt_close_amt,
    COALESCE(y.adv_payment_close_amt, 0)                                                     AS adv_payment_open_amt,
    COALESCE(d.adv_payment_pay_amt, 0)                                                       AS adv_payment_pay_amt,
    COALESCE(d.adv_payment_return_amt, 0)                                                    AS adv_payment_return_amt,
    COALESCE(d.adv_payment_to_cost_amt, 0)                                                   AS adv_payment_to_cost_amt,
    COALESCE(y.adv_payment_close_amt, 0) + COALESCE(d.adv_payment_chg, 0)                    AS adv_payment_close_amt,
    COALESCE(y.ar_close_amt, 0)                                                              AS ar_open_amt,
    COALESCE(d.ar_add_amt, 0)                                                                AS ar_add_amt,
    0                                                                                        AS ar_settle_amt,      -- 还款无明细，日终由快照倒推
    COALESCE(y.ar_close_amt, 0) + COALESCE(d.ar_add_amt, 0)                                  AS ar_close_amt,       -- 不含今日还款
    COALESCE(y.ap_close_amt, 0)                                                              AS ap_open_amt,
    COALESCE(d.ap_add_amt, 0)                                                                AS ap_add_amt,
    0                                                                                        AS ap_settle_amt,
    COALESCE(y.ap_close_amt, 0) + COALESCE(d.ap_add_amt, 0)                                  AS ap_close_amt,
    COALESCE(d.credit_sale_amt, 0)                                                           AS credit_sale_amt,
    COALESCE(d.credit_purchase_amt, 0)                                                       AS credit_purchase_amt,
    COALESCE(d.revenue_amt, 0)                                                               AS revenue_amt,
    COALESCE(d.cost_amt, 0)                                                                  AS cost_amt,
    COALESCE(d.net_ticket_qty, 0)                                                            AS net_ticket_qty,
    COALESCE(y.balance_close_amt, 0)                                                         AS balance_open_amt,
    COALESCE(b.balance_in_amt, 0)                                                            AS balance_in_amt,
    COALESCE(b.balance_out_amt, 0)                                                           AS balance_out_amt,
    COALESCE(y.balance_close_amt, 0) + COALESCE(b.balance_in_amt, 0) - COALESCE(b.balance_out_amt, 0) AS balance_close_amt,
    COALESCE(b.recharge_amt, 0)                                                              AS recharge_amt,
    COALESCE(b.withdraw_amt, 0)                                                              AS withdraw_amt,
    COALESCE(b.expense_income_amt, 0)                                                        AS expense_income_amt,
    COALESCE(b.expense_out_amt, 0)                                                           AS expense_out_amt,
    COALESCE(b.unclassified_flow_qty, 0)                                                     AS unclassified_flow_qty,
    NOW()                                                                                    AS update_time
FROM k
LEFT JOIN d ON d.merchant_tenant_id = k.merchant_tenant_id
LEFT JOIN b ON b.merchant_tenant_id = k.merchant_tenant_id
LEFT JOIN y ON y.merchant_tenant_id = k.merchant_tenant_id;
""")

# ---------------------------------------------------------------- 质量规则（需求第八章勾稽 + 通用）
def recon(sql_bad):
    return sql_bad


DQ = [
    ('ads_fin_merchant_report_di', '一致性', '勾稽 1 · 预收结转：期初 + 收 − 退 − 转确认收入 = 期末', '强', '阻断下游', 'bad_cnt = 0', '需求第八章第 1 条',
     "SELECT COUNT(*) AS bad_cnt FROM ads.ads_fin_merchant_report_di WHERE travel_date = '${bizdate}'\n  AND ABS(adv_receipt_open_amt + adv_receipt_receive_amt - adv_receipt_refund_amt - adv_receipt_to_revenue_amt - adv_receipt_close_amt) > 0.01;"),
    ('ads_fin_merchant_report_di', '一致性', '勾稽 2 · 预付结转：期初 + 付 − 退回 − 转确认成本 = 期末', '强', '阻断下游', 'bad_cnt = 0', '需求第八章第 2 条',
     "SELECT COUNT(*) AS bad_cnt FROM ads.ads_fin_merchant_report_di WHERE travel_date = '${bizdate}'\n  AND ABS(adv_payment_open_amt + adv_payment_pay_amt - adv_payment_return_amt - adv_payment_to_cost_amt - adv_payment_close_amt) > 0.01;"),
    ('ads_fin_merchant_report_di', '一致性', '勾稽 3 · 余额闭合：期初余额 + 流入 − 流出 = 期末余额', '强', '阻断下游', 'bad_cnt = 0', '需求第八章第 3 条；不闭合多半是有流水未归属（待归类）或冻结流水改了可用余额',
     "SELECT COUNT(*) AS bad_cnt FROM ads.ads_fin_merchant_report_di WHERE travel_date = '${bizdate}'\n  AND ABS(balance_open_amt + balance_in_amt - balance_out_amt - balance_close_amt) > 0.01;"),
    ('ads_fin_merchant_report_di', '一致性', '勾稽 4 · 期初 = 上日期末（预收 / 预付 / 余额）', '强', '阻断下游', 'bad_cnt = 0', '时点值连续性；需求 5.7',
     "SELECT COUNT(*) AS bad_cnt FROM ads.ads_fin_merchant_report_di t\nJOIN ads.ads_fin_merchant_report_di y ON y.merchant_tenant_id = t.merchant_tenant_id\n  AND y.travel_date = DATE_FORMAT(DATE_SUB(TO_DATE('${bizdate}', 'yyyyMMdd'), 1), 'yyyyMMdd')\nWHERE t.travel_date = '${bizdate}'\n  AND (ABS(t.adv_receipt_open_amt - y.adv_receipt_close_amt) > 0.01 OR ABS(t.adv_payment_open_amt - y.adv_payment_close_amt) > 0.01 OR ABS(t.balance_open_amt - y.balance_close_amt) > 0.01);"),
    ('ads_fin_merchant_report_di', '一致性', '勾稽 6 · 明细汇总一致：报表发生额 = 资金明细加总', '强', '阻断下游', '|ads_v − dwd_v| ≤ 0.01', '需求第八章第 6 条、7.3 硬约束',
     "SELECT (SELECT SUM(adv_receipt_receive_amt + adv_receipt_refund_amt + adv_receipt_to_revenue_amt + adv_payment_pay_amt + adv_payment_return_amt + adv_payment_to_cost_amt + revenue_amt + cost_amt + ar_add_amt + ap_add_amt)\n          FROM ads.ads_fin_merchant_report_di WHERE travel_date = '${bizdate}') AS ads_v,\n       (SELECT SUM(event_amt) FROM dwd.dwd_fin_merchant_order_fund_di WHERE travel_date = '${bizdate}'\n          AND report_code IN ('ADV_RECEIPT', 'ADV_PAYMENT', 'REVENUE', 'COST', 'AR', 'AP')) AS dwd_v;"),
    ('dwd_fin_merchant_order_fund_di', '一致性', '授信不进预收 / 预付：付款性质为授信的动作只能落授信在途 / 应收 / 应付 / 确认', '强', '阻断下游', 'bad_cnt = 0', '授信只占额度不动现金；落进预收 / 预付会虚增负债 / 资产',
     "SELECT COUNT(*) AS bad_cnt FROM dwd.dwd_fin_merchant_order_fund_di WHERE travel_date = '${bizdate}' AND pay_method_group_type = 'CREDIT' AND report_code IN ('ADV_RECEIPT', 'ADV_PAYMENT');"),
    ('dwd_fin_merchant_order_fund_di', '一致性', '按票分摊无损：当日支付记录金额 = 落到票上的收侧金额合计', '强', '告警', '|a − b| ≤ 0.01 × 票数', '支付记录 ticket_no 为空时按票单价分摊，尾差不超过每票 1 分',
     "SELECT p.payment_no, p.pay_amt AS a, f.amt AS b, f.n FROM dwd.dwd_fin_payment_di p\nJOIN (SELECT source_no, SUM(event_amt) AS amt, COUNT(*) AS n FROM dwd.dwd_fin_merchant_order_fund_di\n      WHERE travel_date = '${bizdate}' AND source_type = 'PAYMENT' AND measure_code = 'RECEIVE' GROUP BY source_no) f ON f.source_no = p.payment_no\nWHERE p.travel_date = '${bizdate}' AND ABS(p.pay_amt - f.amt) > 0.01 * f.n;"),
    ('dws_fin_merchant_credit_df', '一致性', '应收应付双边对账：全平台应收合计 = 应付合计（同一笔授信两侧各记一次）', '强', '告警', '|ar − ap| ≤ 0.01', '',
     "SELECT SUM(IF(report_code = 'AR', close_amt, 0)) AS ar, SUM(IF(report_code = 'AP', close_amt, 0)) AS ap FROM dws.dws_fin_merchant_credit_df WHERE travel_date = '${bizdate}';"),
    ('dws_fin_merchant_credit_df', '有效性', '推算还款不为负、期末不为负', '弱', '告警', 'bad_cnt = 0', '为负：核销前提前还款、授信额度人工调整、或授信在途与已用授信口径不一致，需研发确认还款流程',
     "SELECT COUNT(*) AS bad_cnt FROM dws.dws_fin_merchant_credit_df WHERE travel_date = '${bizdate}' AND (settle_amt < -0.01 OR close_amt < -0.01);"),
    ('ads_fin_merchant_report_di', '一致性', '待归类流水为 0（未定义费用项不得默认归类）', '强', '告警', 'cnt = 0', '需求 5.5：非 0 时到 dws_fin_merchant_balance_di 查 report_code=UNCLASSIFIED 的流水类型 / 费用项，产品确认后补规则',
     "SELECT SUM(unclassified_flow_qty) AS cnt FROM ads.ads_fin_merchant_report_di WHERE travel_date = '${bizdate}';"),
    ('dwd_fin_merchant_order_fund_di', '一致性', '退款联动：下游预收冲减时，同一票本方的预付也须冲减', '强', '告警', 'bad_cnt = 0', '需求 5.2：只冲预收不冲预付会让预付挂死账',
     "SELECT COUNT(*) AS bad_cnt FROM (\n  SELECT merchant_tenant_id, ticket_no,\n         SUM(IF(measure_code = 'REFUND', 1, 0)) AS r_in, SUM(IF(measure_code = 'RETURN', 1, 0)) AS r_out, MAX(IF(payee_type = 'SUPPLIER', 1, 0)) AS has_up\n  FROM dwd.dwd_fin_merchant_order_fund_di WHERE travel_date = '${bizdate}' AND measure_code IN ('REFUND', 'RETURN')\n  GROUP BY merchant_tenant_id, ticket_no\n) x WHERE has_up = 1 AND r_in > 0 AND r_out = 0;"),
    ('dwd_fin_merchant_order_fund_di', '唯一性', '主键唯一（fund_event_id）', '强', '阻断下游', 'dup_cnt = 0', '重复会让报表翻倍',
     "SELECT COUNT(*) AS dup_cnt FROM (\n  SELECT fund_event_id, COUNT(*) AS c FROM dwd.dwd_fin_merchant_order_fund_di WHERE travel_date = '${bizdate}' GROUP BY fund_event_id HAVING c > 1\n) t;"),
    ('dwd_fin_merchant_order_fund_di', '完整性', '本方商户、报表、列非空', '强', '阻断下游', 'null_cnt = 0', '',
     "SELECT COUNT(*) AS null_cnt FROM dwd.dwd_fin_merchant_order_fund_di WHERE travel_date = '${bizdate}' AND (merchant_tenant_id IS NULL OR report_code IS NULL OR measure_code IS NULL);"),
    ('dws_fin_merchant_unsettled_df', '有效性', '在途金额符号：预收、预付在途不应为负', '弱', '告警', 'neg_cnt = 0', '为负说明退款 / 核销先于收付入仓（迟到）或折算误差',
     "SELECT COUNT(*) AS neg_cnt FROM dws.dws_fin_merchant_unsettled_df WHERE travel_date = '${bizdate}' AND unsettled_amt < -0.01;"),
    ('dws_fin_merchant_unsettled_df', '唯一性', '粒度唯一（merchant_tenant_id + report_code + ticket_no）', '强', '阻断下游', 'dup_cnt = 0', '',
     "SELECT COUNT(*) AS dup_cnt FROM (\n  SELECT merchant_tenant_id, report_code, ticket_no, COUNT(*) AS c FROM dws.dws_fin_merchant_unsettled_df WHERE travel_date = '${bizdate}' GROUP BY 1, 2, 3 HAVING c > 1\n) t;"),
    ('dws_fin_merchant_balance_di', '一致性', '对账：余额流入 / 流出合计与 dws_fin_account_flow_di 一致（商户 / 分销商账户）', '弱', '告警', '|a − b| ≤ 0.01', '同一份流水两种汇总',
     "SELECT (SELECT SUM(fund_in_amt - fund_out_amt) FROM dws.dws_fin_merchant_balance_di WHERE travel_date = '${bizdate}') AS a,\n       (SELECT SUM(f.fund_in_amt - f.fund_out_amt) FROM dws.dws_fin_account_flow_di f JOIN dim.dim_fin_account_df d ON d.account_no = f.account_no AND d.travel_date = '${bizdate}'\n        WHERE f.travel_date = '${bizdate}' AND d.account_type IN ('MERCHANT', 'DISTRIBUTOR')) AS b;"),
]
RT_DQ = [('ads_fin_merchant_report_rt', '及时性', '数据新鲜度 ≤ 5 分钟', '强', '告警', 'lag_s ≤ 300（营业时间 08:00–22:00）', 'StarRocks 侧每分钟巡检',
          "SELECT TIMESTAMPDIFF(SECOND, MAX(update_time), NOW()) AS lag_s FROM ads.ads_fin_merchant_report_rt WHERE travel_date = DATE_FORMAT(NOW(), '%Y%m%d');"),
         ('ads_fin_merchant_report_rt', '一致性', '实时 / 离线对账：昨日实时期末与离线定版期末差异 ≤ 0.5%', '弱', '告警', '|实时 − 离线| / 离线 ≤ 0.5%', '次日 T+1 完成后对昨日段；差异来自 CDC 丢数或迟到，以离线为准',
          "-- 每日 T+1 后执行：实时作业保留昨日结果快照 ads_fin_merchant_report_rt_hist\nSELECT SUM(adv_receipt_close_amt) FROM ads.ads_fin_merchant_report_rt_hist WHERE travel_date = '${bizdate}';\nSELECT SUM(adv_receipt_close_amt) FROM ads.ads_fin_merchant_report_di WHERE travel_date = '${bizdate}';")]

# ---------------------------------------------------------------- 待确认事项（源端缺口，需研发 / 产品确认）
TODO = [
    ('财务报表', '结算时点无字段：需求要求配在支付方式上（支付即结算 / 核销即结算），3.0 业务库 t_merchant_payment_config 只有 collection_mode',
     '业务库补 settle_timing（+ 生效时间）；补齐前 dim_fin_settle_timing_df 全部取「核销即结算」', '预收转确认收入的时点、余额入账时点；支付即结算商户的预收会偏大'),
    ('财务报表', '资金流水类型与需求「费用项」对不上：需求列 购买产品 / 退款 / 解冻 / 冻结 / 应用套餐购买 / 充值扣款 / 提现；业务库 flow_type 为 RECHARGE / PAYMENT / REFUND / FREEZE / UNFREEZE / WITHDRAW / FEE / RESOURCE / TRANSFER_OUT / TRANSFER_IN，fee_item 存短信费、提现手续费等',
     '归属规则表 dim_fin_report_rule_f 已按 3.0 枚举建好，PENDING 的规则（采购扣转、资源包、解冻）请产品 / 研发逐条确认', '按需求原文实现会把采购扣转全部判为待归类，预付整表为空'),
    ('财务报表', '解冻流水分不出「核销触发 / 退款释放」：frozen_event 在冻结记录上，资金流水没有冻结单号，related_no 对解冻填什么未定义',
     '请研发确认解冻流水 related_no = 冻结单号（或票号）；当前按两种都尝试关联', '确认收入 / 余额会混入退款释放的钱'),
    ('财务报表', '授信不动现金（只占额度，架构文档 3.5.2「核销后才记应付」），按「钱 × 服务」口径不属于预收 / 预付；需求文档没有应收 / 应付报表',
     '已按口径处理：授信支付记授信在途（不进预收 / 预付），核销时记应收 / 应付 + 确认收入 / 成本；新增 dws_fin_merchant_credit_df 与 ADS 应收 / 应付列。请产品确认是否单出应收 / 应付报表',
     '若按需求原文「下单即进预收」，授信销售会虚增预收（负债）'),
    ('财务报表', '授信还款没有明细表：业务库只有分销关系 t_distribution_relation.credit_used（已用授信）快照',
     '应收 / 应付期末 = 已用授信 − 授信在途，本期还款 = 期初 + 增加 − 期末（推算）；请研发确认还款是否会落资金流水（flow_type / fee_item）或补还款记录表',
     '还款无法下钻到单据；核销前提前还款会使推算还款为负'),
    ('财务报表', '支付记录 settle_amount 注释「INBOUND = 售价、OUTBOUND = 向上采购价」与架构文档「利润 = amount − settle_amount」（4 级分销示例 D1 收 85、向上付 80）矛盾',
     '报表一律用 amount（这笔记录实际转移的钱）计量收 / 付 / 卖出单价 / 买入单价；settle_amount 不参与', '若误用 settle_amount，分销商的确认收入会少掉自己的利润'),
    ('财务报表', '支付记录 ticket_no 默认空串（按聚合单支付），退款明细按支付记录而不是按票',
     '按票单价 unit_price_amt 占比把支付分摊到票，退款按退款单 refund_items 的票金额占比分摊；尾差 ≤ 每票 1 分（质量规则校验）。请研发确认 INBOUND / OUTBOUND 是否都按票拆记录',
     '分摊不影响商户级报表合计，只影响按票 / 产品下钻的分厘尾差'),
    ('财务报表', '售后补偿退款（refund_type = COMPENSATION）没有对应票，当前按退款单 refund_items 落票，没有票的补偿退款不进报表',
     '请产品确认补偿退款归属：冲减确认收入，还是记费用支出', '补偿退款金额会在预收 / 确认收入中缺失'),
    ('财务报表', '订单上没有「售票站点」；需求提到的 receipt_price 在 3.0 子单表中不存在（只有 unit_price）',
     '售票站点请研发补字段；卖出 / 买入单价改取本方两侧支付记录的结算金额（已有，带票号）', '维度「售票站点」暂为空'),
    ('财务报表', '余额报表要求统计「可用余额」，资金流水 balance_before / after 只有一个余额，冻结 / 解冻流水是否改动可用余额未定义',
     '请研发确认；勾稽 3（余额闭合）会暴露此问题', '余额流入 / 流出与期末余额可能对不上'),
    ('财务报表', '实时链路缺资金流水流与退款明细流', '新增 ods_fin_fund_flow_rt（已登记）；退款明细（按支付记录）实时流待补 ods_ord_refund_detail_rt',
     '当日余额流入 / 流出、当日退款 / 退回在实时段缺失'),
]


# ---------------------------------------------------------------- 写入字典
def apply(S):
    """把补齐内容追加进字典 sheets（原地修改），返回 (ETL 覆盖, 新增表名集合)"""
    T_, F_, W_, Q_, D_, A_, B_, L_, TD_ = (S[k] for k in ('表清单', '字段清单', '调度工作流', '质量规则', 'DWS口径', 'ADS业务指标', '总线矩阵', '分层汇总', '待确认事项'))
    ti = {c: i for i, c in enumerate(T_['cols'])}
    fi = {c: i for i, c in enumerate(F_['cols'])}
    have = {str(r[ti['表名（库.表）']]) for r in T_['rows']}
    fields_of = {}
    for r in F_['rows']:
        fields_of.setdefault(str(r[fi['表名（库.表）']]), []).append(r)
    no = max(int(r[ti['序号']]) for r in T_['rows'] if str(r[ti['序号']]).isdigit())
    added = set()
    for x in T:
        if x['name'] in have:
            continue
        no += 1
        row = [''] * len(T_['cols'])
        for k, v in (('序号', no), ('分层', x['layer']), ('业务域', DOM), ('表名（库.表）', x['name']), ('表中文名', x['cn']), ('粒度', x['grain']), ('后缀含义', x['suffix']),
                     ('分区', x['part']), ('来源', x['src']), ('度量 / 口径 / 关键字段', x['keys']), ('上游表', x['up']), ('下游表', x['down']),
                     ('备注', ('【新增 · 3.0 财务报表】' + x['note']).strip())):
            row[ti[k]] = v
        T_['rows'].append(row)
        added.add(x['name'].split('.', 1)[1])
        fl = x['fields']
        if isinstance(fl, str) and fl.startswith('@copy:'):
            src = fl[6:].split('+')[0]
            base = [list(r) for r in fields_of.get(src, [])]
            fl = [(r[fi['字段名']], r[fi['类型']], r[fi['字段类别']], r[fi['字段注释']], f"同 {src.split('.', 1)[1]}.{r[fi['字段名']]}", f"{src}.{r[fi['字段名']]}") for r in base
                  if r[fi['字段类别']] not in ('分区',) and r[fi['字段名']] not in ('etl_time',)]
            if '+report' in x['fields']:
                fl.append(('report_code', 'STRING', '状态类型', '归属：BALANCE / EXPENSE / NONE / UNCLASSIFIED（规则同 dim_fin_report_rule_f）', 'dim_fin_report_rule_f.report_code', 'dim.dim_fin_report_rule_f.report_code'))
            if 'ods' in x['name']:
                fl = [(n, ty, c, cm, f"pft-finance.t_fund_flow.{n}，Flink CDC 读 binlog", '') for n, ty, c, cm, _, _ in fl if c != 'ETL' or n.startswith('binlog')]
            elif 'ads' in x['name']:
                fl = [f for f in fl if f[0] != 'travel_date'] + [('update_time', 'STRING', 'ETL', '最近一次刷新时间，格式 yyyy-MM-dd HH:mm:ss', '物化视图刷新', '')]
                fl = [('travel_date', 'STRING', '分区', '数据日期，格式 YYYYMMDD（= 今日）', '当日', '')] + fl
            else:
                fl = [('travel_date', 'STRING', '分区', '数据日期，格式 YYYYMMDD；取事件时间日期', '事件时间', '')] + fl
                if not any(f[0] == 'event_time' for f in fl):
                    fl.append(('event_time', 'STRING', 'ETL', '事件时间（binlog 时间），用于窗口计算与乱序处理', 'binlog', ''))
        new_rows = []
        for i, f in enumerate(fl, 1):
            r = [''] * len(F_['cols'])
            for k, v in (('分层', x['layer']), ('表名（库.表）', x['name']), ('表中文名', x['cn']), ('序号', i), ('字段名', f[0]), ('类型', f[1]), ('字段类别', f[2]),
                         ('字段注释', f[3]), ('加工 / 来源', f[4]), ('上游字段', f[5])):
                r[fi[k]] = v
            new_rows.append(r)
        F_['rows'].extend(new_rows)
        fields_of[x['name']] = new_rows   # 后面的实时表 @copy 要用到
    # 调度
    wi = {c: i for i, c in enumerate(W_['cols'])}

    def w(flow, step, node, typ, desc, layer, fail, nrule, wait, cross, exe):
        r = [''] * len(W_['cols'])
        for k, v in (('工作流', flow), ('步骤', step), ('节点', node), ('类型', typ), ('说明', desc), ('分层', layer), ('失败处理', fail), ('规则数', nrule),
                     ('等待（上游）', wait), ('跨流程依赖', cross), ('执行 / 说明', exe)):
            if k in wi:
                r[wi[k]] = v
        W_['rows'].append(r)
    nq = collections_counter(DQ)
    plan = [('dim_fin_report_rule_f', 'DIM', 4, 'start.daily'), ('dim_fin_settle_timing_df', 'DIM', 4, 'dq.ods_fin_merchant_payment_config_df'),
            ('dwd_fin_merchant_order_fund_di', 'DWD', 18, 'dq.dwd_fin_payment_di、dq.dwd_fin_refund_payment_di、dq.dwd_ord_refund_ticket_di、dq.dwd_fin_frozen_di、dq.dwd_ord_ticket_di、dq.dwd_ord_order_group_di、dq.dim_fin_report_rule_f、dq.dim_fin_settle_timing_df'),
            ('dws_fin_merchant_unsettled_df', 'DWS', 20, 'dq.dwd_fin_merchant_order_fund_di'), ('dws_fin_merchant_order_fund_di', 'DWS', 20, 'dq.dwd_fin_merchant_order_fund_di'),
            ('dws_fin_merchant_balance_di', 'DWS', 20, 'dq.dwd_fin_fund_flow_di、dq.dwd_fin_frozen_di、dq.dim_fin_report_rule_f、dq.dim_fin_account_df'),
            ('dws_fin_merchant_credit_df', 'DWS', 22, 'dq.dws_fin_merchant_unsettled_df、dq.dws_trf_distributor_credit_df、dq.dim_trf_distribution_relation_zip'),
            ('ads_fin_merchant_report_di', 'ADS', 28, 'dq.dws_fin_merchant_unsettled_df、dq.dws_fin_merchant_order_fund_di、dq.dws_fin_merchant_balance_di、dq.dws_fin_account_balance_df、dq.dws_fin_merchant_credit_df')]
    cn = {x['name'].split('.', 1)[1]: x['cn'] for x in T}
    for tb, layer, step, wait in plan:
        w('日调度', step, tb, '任务', cn[tb], layer, '', 0, wait, '', f'sql/{layer.lower()}/{tb}.sql')
        w('日调度', step + 1, f'dq.{tb}', '质检', cn[tb] + ' 质检', layer, '阻断', nq.get(tb, 2), tb, '', '')
    w('实时作业', 1, 'ods_fin_fund_flow_rt', '任务', '资金流水 binlog 流', 'ODS', '', 0, '', '', 'Flink CDC 源表：pft-finance.t_fund_flow')
    for k, (tb, layer, src, sink) in enumerate([('dwd_fin_fund_flow_rt', 'DWD', 'ods_fin_fund_flow_rt', 'dwd_fin_fund_flow_rt'),
                                                ('dwd_fin_merchant_order_fund_rt', 'DWD', 'dwd_fin_payment_rt、dwd_fin_frozen_rt', 'dwd_fin_merchant_order_fund_rt'),
                                                ('ads_fin_merchant_report_rt', 'ADS', 'dwd_fin_merchant_order_fund_rt、dwd_fin_fund_flow_rt', 'ads_fin_merchant_report_rt')]):
        w('实时作业', 3 + 2 * k, tb, '任务', cn[tb], layer, '', 0, 'dq.' + src.split('、')[0], '',
          ('Flink 作业 flink_job_fin_merchant_report 写入 StarRocks' if layer == 'DWD' else 'StarRocks 异步物化视图，1 分钟刷新'))
        w('实时作业', 4 + 2 * k, f'dq.{tb}', '监控', cn[tb] + ' 监控', layer, '告警', 1, tb, '', '')
    # 质量规则
    qi = {c: i for i, c in enumerate(Q_['cols'])}
    nid = 1 + max(int(re.sub(r'\D', '', str(r[qi['规则编号']])) or 0) for r in Q_['rows'])
    for flow, rules in (('日调度', DQ), ('实时作业', RT_DQ)):
        for tb, dim_, text, lvl, fail, expect, note, sql in rules:
            r = [''] * len(Q_['cols'])
            for k, v in (('规则编号', f'R{nid:04d}'), ('工作流', flow), ('质检节点', f'dq.{tb}'), ('表', tb), ('质量维度', dim_), ('规则', text), ('级别', lvl),
                         ('失败处理', fail), ('期望', expect), ('说明', note), ('检测 SQL', sql)):
                r[qi[k]] = v
            Q_['rows'].append(r)
            nid += 1
    # DWS 口径（订单资金原子口径）与 ADS 业务指标
    di = {c: i for i, c in enumerate(D_['cols'])}
    acodes = [int(str(r[di['口径编码']])[1:]) for r in D_['rows'] if str(r[di['口径编码']]).startswith('A') and str(r[di['口径编码']])[1:].isdigit()]
    na = max(acodes) + 1
    code_of = {}
    for m, r_, c_, cn_, kou in MEAS + [('sale_ticket', 'ADV_RECEIPT', 'RECEIVE', '售票数', '本方收侧售出票数（售票记正）'), ('refund_ticket', 'ADV_RECEIPT', 'REFUND', '退款票数', '本方收侧退款票数')]:
        en = f'{m}_qty' if m.endswith('ticket') else f'{m}_amt'
        r = [''] * len(D_['cols'])
        for k, v in (('口径编码', f'A{na:03d}'), ('英文名', en), ('中文名', cn_), ('口径类型', '原子指标'), ('业务域', DOM), ('业务口径', kou),
                     ('计算公式', f"{cn_} = SUM({'净票数' if en.endswith('_qty') else '发生金额'})；条件：报表={r_}，列={c_}；本方商户视角"), ('单位', '张' if en.endswith('_qty') else '元'),
                     ('时间口径', '动作发生时间（收 / 付 = 支付时间，退 = 退款到账时间，确认 = 核销解冻时间）'), ('数据类型', 'BIGINT' if en.endswith('_qty') else 'DECIMAL(18,2)'),
                     ('精度/展示', '整数，单位：张' if en.endswith('_qty') else '元，保留 2 位小数'), ('来源明细表', 'dwd_fin_merchant_order_fund_di'),
                     ('落地 DWS 表', 'dws_fin_merchant_order_fund_di'), ('被哪些 ADS 表使用', 'ads_fin_merchant_report_di、ads_fin_merchant_report_rt')):
            if k in di:
                r[di[k]] = v
        D_['rows'].append(r)
        code_of[en] = f'A{na:03d}'
        na += 1
    for en, cn_, kou, fx, srcd, dws in (
            ('unsettled_amt', '在途金额', '截至统计日日终已卖出（已采购）、尚未核销且未退款的金额', '在途金额 = 上日在途 + SUM(当日余额影响)；时点值，取统计日日终快照',
             'dwd_fin_merchant_order_fund_di', 'dws_fin_merchant_unsettled_df'),
            ('add_amt', '应收 / 应付增加', '授信卖出（采购）的票本期核销记应收 / 应付的金额', '应收 / 应付增加 = SUM(核销时的卖出 / 买入单价)，条件：付款性质 = 授信',
             'dwd_fin_merchant_order_fund_di', 'dws_fin_merchant_credit_df'),
            ('close_amt', '应收 / 应付余额', '授信卖出（采购）且已核销、尚未还款的金额', '应收 / 应付余额 = 已用授信 − 授信在途；时点值，取统计日日终快照',
             'dws_trf_distributor_credit_df、dws_fin_merchant_unsettled_df', 'dws_fin_merchant_credit_df'),
            ('settle_amt', '应收收回 / 应付偿还', '本期授信还款金额（推算，业务库无还款明细）', '还款 = 期初余额 + 本期增加 − 期末余额',
             'dws_fin_merchant_credit_df', 'dws_fin_merchant_credit_df')):
        r = [''] * len(D_['cols'])
        snap = '时点值' in fx
        for k, v in (('口径编码', f'A{na:03d}'), ('英文名', en), ('中文名', cn_), ('口径类型', '原子指标'), ('业务域', DOM), ('业务口径', kou),
                     ('计算公式', fx), ('单位', '元'), ('时间口径', '统计日日终快照' if snap else '统计日'), ('数据类型', 'DECIMAL(18,2)'),
                     ('精度/展示', '元，保留 2 位小数'), ('来源明细表', srcd), ('落地 DWS 表', dws), ('被哪些 ADS 表使用', 'ads_fin_merchant_report_di')):
            if k in di:
                r[di[k]] = v
        D_['rows'].append(r)
        code_of[en] = f'A{na:03d}'
        na += 1
    ai = {c: i for i, c in enumerate(A_['cols'])}
    nb = 1 + max(int(re.sub(r'\D', '', str(r[ai['指标编码']])) or 0) for r in A_['rows'])
    for rt in (False, True):
        for f, cn_, kou, src, k in RPT:
            base = {'adv_receipt_receive_amt': 'receive_amt', 'adv_receipt_refund_amt': 'refund_amt', 'adv_receipt_to_revenue_amt': 'to_revenue_amt', 'adv_payment_pay_amt': 'pay_amt',
                    'adv_payment_return_amt': 'return_amt', 'adv_payment_to_cost_amt': 'to_cost_amt', 'revenue_amt': 'revenue_amt', 'cost_amt': 'cost_amt',
                    'ar_add_amt': 'add_amt', 'ap_add_amt': 'add_amt', 'credit_sale_amt': 'credit_sale_amt', 'credit_purchase_amt': 'credit_purchase_amt',
                    'ar_settle_amt': 'settle_amt', 'ap_settle_amt': 'settle_amt', 'net_ticket_qty': 'sale_ticket_qty'}.get(f)
            if k == 'snap' and 'adv_' in f:
                base = 'unsettled_amt'
            elif k == 'snap' and f[:3] in ('ar_', 'ap_'):
                base = 'close_amt'
            bc = f'{code_of[base]} {base}' if base in code_of else '—'
            unit = '张' if f == 'net_ticket_qty' else '笔' if f.endswith('_qty') else '元'
            r = [''] * len(A_['cols'])
            vals = (('指标编码', f'B{nb:04d}'), ('业务指标名', ('今日' if rt else '') + cn_), ('字段名', f), ('业务口径', kou + '。'),
                    ('计算公式', f"{cn_} = {'取区间首日 / 末日值（时点值）' if k == 'snap' else 'SUM(日值)'}；来源 {src}"), ('单位', unit),
                    ('统计周期', '今日' if rt else '当日'), ('修饰词', '—'),
                    ('时间口径', '统计日日终快照' if k == 'snap' else '动作发生时间'), ('数据类型', 'BIGINT' if f.endswith('_qty') else 'DECIMAL(18,2)'),
                    ('精度/展示', f'{unit}，保留 2 位小数' if unit == '元' else f'整数，单位：{unit}'), ('更新频率', '实时（分钟级刷新）' if rt else '每日 T+1'),
                    ('离线/实时', '实时' if rt else '离线'), ('基础口径', bc), ('口径类型', '原子指标'),
                    ('ADS表', 'ads_fin_merchant_report_rt' if rt else 'ads_fin_merchant_report_di'), ('ADS表中文名', '商户财务报表（当日实时）' if rt else '商户财务报表（日）'),
                    ('分析粒度', 'merchant_tenant_id × 今日' if rt else 'travel_date × merchant_tenant_id'),
                    ('来源 DWS', f"dwd_fin_merchant_order_fund_rt、dwd_fin_fund_flow_rt、ads_fin_merchant_report_di（昨日期末）、{src.split('.')[0].split('（')[0].split('：')[0]}（同口径离线表，今日段口径一致）" if rt else src.split('.')[0].split('（')[0].split('：')[0]), ('使用端', '商户后台 · 财务 · 报表中心'))
            for kk, v in vals:
                if kk in ai:
                    r[ai[kk]] = v
            A_['rows'].append(r)
            nb += 1
    # 总线矩阵
    bi = {c: i for i, c in enumerate(B_['cols'])}
    for layer, tb, cn_ in (('DWS', 'dws.dws_fin_merchant_order_fund_di', '商户订单资金日汇总'), ('DWS', 'dws.dws_fin_merchant_unsettled_df', '预收预付在途快照'),
                           ('DWS', 'dws.dws_fin_merchant_balance_di', '商户余额与费用日汇总'), ('DWS', 'dws.dws_fin_merchant_credit_df', '商户应收应付快照'),
                           ('ADS', 'ads.ads_fin_merchant_report_di', '商户财务报表（日）')):
        r = [''] * len(B_['cols'])
        r[bi['分层']], r[bi['表名']], r[bi['中文名']] = layer, tb, cn_
        for d in ('日期', '租户（商户/供应商/分销商）') + (('SKU', '渠道/接入端', '员工', '支付渠道', '产品(SPU)') if 'order' in tb or 'unsettled' in tb else ('账户',) if 'balance' in tb else ('分销关系',) if 'credit' in tb else ()):
            if d in bi:
                r[bi[d]] = '●'
        B_['rows'].append(r)
    # 分层汇总表数
    li = {c: i for i, c in enumerate(L_['cols'])}
    cnt = {}
    for x in T:
        cnt[x['layer']] = cnt.get(x['layer'], 0) + 1
    off = {k: v for k, v in cnt.items() if '实时' not in k}
    rtn = sum(v for k, v in cnt.items() if '实时' in k)
    for r in L_['rows']:
        if r[li['分层']] in off and str(r[li['表数']]).isdigit():
            r[li['表数']] = int(r[li['表数']]) + off[r[li['分层']]]
        if r[li['分层']] == '实时链路' and str(r[li['表数']]).isdigit():
            r[li['表数']] = int(r[li['表数']]) + rtn
            for lay in ('ODS', 'DWD', 'DWS', 'ADS'):
                k = cnt.get(f'{lay}（实时）', 0)
                if k:
                    r[li['说明']] = re.sub(rf'{lay} (\d+)', lambda m: f'{lay} {int(m.group(1)) + k}', str(r[li['说明']]))
    # 待确认事项
    tdi = {c: i for i, c in enumerate(TD_['cols'])}
    n0 = max(int(r[tdi['序号']]) for r in TD_['rows'] if str(r[tdi['序号']]).isdigit())
    for k, (cat, q, how, imp) in enumerate(TODO, 1):
        r = [''] * len(TD_['cols'])
        for kk, v in (('序号', n0 + k), ('类别', cat), ('问题', q), ('当前处理 / 建议', how), ('影响', imp)):
            r[tdi[kk]] = v
        TD_['rows'].append(r)
    etl = {}
    layer_of = {x['name'].split('.', 1)[1]: x['layer'] for x in T}
    for name, (kind, sql) in ETL.items():
        L = layer_of[name].replace('（实时）', '')
        path = {'hive': f'sql/{L.lower()}/{name}.sql', 'flink': f'sql/flink/{name}.sql', 'starrocks': f'sql/starrocks/{name}.sql'}[kind]
        review = sql.count('待确认')
        nf = sum(1 for r in F_['rows'] if str(r[fi['表名（库.表）']]).endswith('.' + name))
        etl[name] = {'sql': sql.strip('\n'), 'kind': kind, 'path': path, 'stats': {'auto': max(nf - review, 0), 'rule': 0, 'review': review}}
    return etl, added


def collections_counter(rules):
    c = {}
    for r in rules:
        c[r[0]] = c.get(r[0], 0) + 1
    return c
