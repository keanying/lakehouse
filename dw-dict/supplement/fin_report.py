"""3.0 财务报表补齐（依据《3.0 通用财务报表 · 需求说明》v1.0、《口径说明》2026-11-24 版与业务原型）。

客户交付字典（data/*.xlsx）不改动；本模块在生成时把下列内容追加进字典，页面与改造版 Excel 一并展示。

对照需求的取舍（第几章见需求说明）：
- 一期 5 张基础表：预收、预付、确认收入、确认成本、余额；二期：费用收支、未结转差额、毛利与净利（派生，查询时计算）
- 授信是支付方式的一种，授信订单同样在下单时计入预收 / 预付，不单列应收、应付（3.1、5.9）
- 售后补偿本期不纳入（第十章 4）
- 维度来自订单；任意维度组合、可排序、出小计（第四章）→ 汇总层与应用层按「全部订单维度」落粒度，查询时按所选维度再聚合
- 期初 / 期末是时点值、可按任意维度拆分（5.7）→ 应用层每个维度组合每天落日终余额，期初取区间首日前一天、期末取末日
- 明细：交易时间、各维度、费用类型（付款 / 退款 / 结算）、业务流水号、业务订单号、关联订单号、票数、金额（原型明细列）；
  余额明细：交易时间、费用类型、所属账本、对方商户、业务流水号、业务订单号、关联订单号、变动金额、快照余额
- 时效：今天实时、昨天及以前 T+1 定版，按日期分段拼接；余额报表始终实时（第六章）
- 未定义费用项进「待归类异常清单」（5.5）
"""
import re

DOM = 'fin'
NOW = "DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss')"
SRC_DOC = '《3.0 通用财务报表 · 需求说明》v1.0（2026-11-24）'

REPORT = "ADV_RECEIPT-预收，ADV_PAYMENT-预付，REVENUE-确认收入，COST-确认成本，EXPENSE-费用收支，BALANCE-仅余额，NONE-不进表"
MEASURE = ("RECEIVE-本期收，REFUND-本期退，TO_REVENUE-转实收（转确认收入），PAY-本期付，RETURN-本期退回，TO_COST-转实付（转确认成本），"
           "CONFIRM-履约收入 / 成本结算，INCOME-费用收入，EXPENSE-费用支出，IN-资金流入，OUT-资金流出")
FEE_TYPE = '费用类型（界面显示，原型「费用类型」列）：付款、退款、结算（核销解冻，界面不出现「解冻」二字）、充值/扣款、提现、应用套餐购买、手续费'

# ---------------------------------------------------------------- 表定义
# (分层, 表名, 中文名, 粒度, 后缀含义, 分区, 来源, 关键字段说明, 上游表, 下游表, 备注, 字段[(名, 类型, 类别, 注释, 加工/来源, 上游字段)])
T = []


def t(layer, name, cn, grain, suffix, part, src, keys, up, down, note, fields):
    T.append(dict(layer=layer, name=name, cn=cn, grain=grain, suffix=suffix, part=part, src=src, keys=keys, up=up, down=down, note=note, fields=fields))


RT_NOTE = '实时表后缀 _rt 待确认'
F_ = 'dwd_fin_merchant_order_fund_di'
# 订单维度（需求 4.1：日期之外的 12 个订单维度；「渠道」取下单渠道类型 小程序 / 窗口 / H5 / OTA）
DIM_FIELDS = [
    ('spu_id', 'BIGINT', '外键', '产品(SPU)ID，关联 dim_prd_spu_zip（维度：产品）', 'dwd_ord_ticket_di.spu_id', 'dwd.dwd_ord_ticket_di.spu_id'),
    ('sku_id', 'BIGINT', '外键', 'SKU ID，关联 dim_prd_sku_zip（维度：票种）', 'dwd_ord_ticket_di.sku_id', 'dwd.dwd_ord_ticket_di.sku_id'),
    ('channel_type', 'STRING', '维度属性', '下单渠道（维度）：MP-小程序，OFFLINE-窗口，H5，API-OTA，PC-后台代下；界面按「小程序 / 窗口 / H5 / OTA」显示', 'dwd_ord_order_group_di.channel_type', 'dwd.dwd_ord_order_group_di.channel_type'),
    ('seller_staff_id', 'BIGINT', '外键', '售票员（维度：订单操作人，operator_type=TENANT_STAFF 时为员工ID；游客自助下单为空，界面显示「—」），关联 dim_sup_staff_zip', "dwd_ord_order_group_di：IF(operator_type='TENANT_STAFF', operator_id, NULL)", 'dwd.dwd_ord_order_group_di.operator_id'),
    ('sale_point_code', 'STRING', '外键', '售票站点（维度）。业务库订单上暂无站点字段，补齐前为空', '待业务库补字段', ''),
    ('payer_tenant_id', 'BIGINT', '外键', '付款方（收侧维度：把钱付给本方的一方）：下级分销商为其租户ID，散客为 0', '支付记录：本方为收款方时的付款方；游客直付为 0', 'dwd.dwd_fin_payment_di.payer_tenant_id'),
    ('payer_type', 'STRING', '状态类型', '付款方类型：DISTRIBUTOR-分销商，CUSTOMER-散客（「没有分销商、自己直接买」，不是空值）', 'OUTBOUND→DISTRIBUTOR，INBOUND→CUSTOMER', 'dwd.dwd_fin_payment_di.pay_direction_type'),
    ('payee_tenant_id', 'BIGINT', '外键', '收款方（付侧维度：本方把钱付给的一方，即上级供应商）；自营票为 0', '支付记录：本方为采购付款方时的收款方；无采购付款为 0', 'dwd.dwd_fin_payment_di.payee_tenant_id'),
    ('payee_type', 'STRING', '状态类型', '收款方类型：SUPPLIER-供应商，SELF-自营（自营票没有外部收款方）', '有采购付款→SUPPLIER，否则 SELF', 'dwd.dwd_fin_payment_di.payee_tenant_id'),
    ('sale_unit_price_amt', 'DECIMAL(18,2)', '维度属性', '卖出单价（收侧维度，元）：本方这张票实际收到的金额（收侧支付记录 amount；按聚合单支付的按票单价占比分摊）', '支付记录（本方为收款方）amount', 'dwd.dwd_fin_payment_di.pay_amt'),
    ('buy_unit_price_amt', 'DECIMAL(18,2)', '维度属性', '买入单价（付侧维度，元）：本方这张票付给上级的金额（采购付款支付记录 amount）', '支付记录（本方为采购付款方）amount', 'dwd.dwd_fin_payment_di.pay_amt'),
    ('receive_pay_method_type', 'STRING', '状态类型', '收款支付方式（收侧维度：下级付给本方的方式）：BALANCE-余额，WECHAT-微信，ALIPAY-支付宝，CREDIT-授信，OFFLINE-线下，ZERO_FEE-0 元单', '支付记录（本方为收款方）pay_method_type', 'dwd.dwd_fin_payment_di.pay_method_type'),
    ('pay_pay_method_type', 'STRING', '状态类型', '付款支付方式（付侧维度：本方付给上级的方式）', '支付记录（本方为采购付款方）pay_method_type', 'dwd.dwd_fin_payment_di.pay_method_type'),
]
DIMS = [x[0] for x in DIM_FIELDS]
DIMSTR = ' × '.join(DIMS)
FACT_FIELDS = [
    ('fund_event_id', 'STRING', '主键', '资金动作ID = 来源单号:票号:本方商户:报表:列', 'CONCAT_WS(:, source_no, ticket_no, merchant_tenant_id, report_code, measure_code)', 'dwd.dwd_fin_payment_di.payment_no、dwd.dwd_fin_refund_payment_di.refund_detail_no、dwd.dwd_fin_frozen_di.frozen_no'),
    ('event_time', 'STRING', '时间', '交易时间（明细「交易时间」列）：收 / 付 = 支付时间，退 / 退回 = 退款到账时间，结算 = 核销解冻时间（支付即结算为支付时间）', '见加工逻辑', 'dwd.dwd_fin_payment_di.pay_time、dwd.dwd_fin_refund_payment_di.finish_time、dwd.dwd_fin_frozen_di.release_time'),
    ('merchant_tenant_id', 'BIGINT', '外键', '本方商户租户ID（报表归属方），关联 dim_sup_tenant_zip', '支付记录收款方 / 采购付款方', 'dwd.dwd_fin_payment_di.payee_tenant_id、dwd.dwd_fin_payment_di.payer_tenant_id'),
    ('report_code', 'STRING', '状态类型', f'报表：{REPORT}', 'dim_fin_report_rule_f', 'dim.dim_fin_report_rule_f.report_code'),
    ('measure_code', 'STRING', '状态类型', f'报表列：{MEASURE}', 'dim_fin_report_rule_f', 'dim.dim_fin_report_rule_f.measure_code'),
    ('fee_type_name', 'STRING', '维度属性', FEE_TYPE + '；订单报表只出现 付款 / 退款 / 结算', 'dim_fin_report_rule_f.fee_type_name', 'dim.dim_fin_report_rule_f.fee_type_name'),
    ('event_amt', 'DECIMAL(18,2)', '度量', '金额（元，正数）：收 / 付 = 支付记录 amount 按票分摊；退 / 退回 = 退款明细按票分摊；结算 = 卖出 / 买入单价', '见加工逻辑', 'dwd.dwd_fin_payment_di.pay_amt、dwd.dwd_fin_refund_payment_di.refund_amt'),
    ('balance_effect_amt', 'DECIMAL(18,2)', '度量', '对本报表余额的影响（元，带符号）：收 / 付 +，退 / 退回 / 转实收 / 转实付 −；履约收入 / 成本结算 +', 'event_amt × dim_fin_report_rule_f.sign_qty', 'dim.dim_fin_report_rule_f.sign_qty'),
    ('ticket_net_qty', 'INT', '度量', '票数（预收 / 预付口径）：售票记正、退款记负、核销不改变票数（需求 3.4、口径说明 7）', '收 / 付 = 1，退 / 退回 = −1，其余 0', 'dwd.dwd_fin_payment_di.ticket_no'),
    ('confirm_ticket_qty', 'INT', '度量', '票数（确认收入 / 确认成本口径）：本次履约确认的票数（核销数量）', '履约收入 / 成本结算 = 1，其余 0', 'dwd.dwd_fin_frozen_di.ticket_no'),
    ('source_type', 'STRING', '状态类型', '来源：PAYMENT-支付记录，REFUND-退款明细，VERIFY-核销解冻，PAY_SETTLE-支付即结算', '见加工逻辑', 'dim.dim_fin_report_rule_f.source_type'),
    ('source_no', 'STRING', '退化维度', '业务流水号（明细列，可复制）：支付流水号 / 退款明细号 / 冻结记录号', '见加工逻辑', 'dwd.dwd_fin_payment_di.payment_no、dwd.dwd_fin_refund_payment_di.refund_detail_no、dwd.dwd_fin_frozen_di.frozen_no'),
    ('payment_no', 'STRING', '退化维度', '本方这一侧的支付记录号', 'dwd_fin_payment_di.payment_no', 'dwd.dwd_fin_payment_di.payment_no'),
    ('order_group_no', 'STRING', '退化维度', '业务订单号（明细列，可复制）：聚合单号', 'dwd_fin_payment_di.order_group_no', 'dwd.dwd_fin_payment_di.order_group_no'),
    ('order_no', 'STRING', '退化维度', '关联订单号（明细列，可复制）：子单号。支付挂聚合单、退款挂子单，统一按票落到子单（需求第十章 3）', 'dwd_ord_ticket_di.order_no', 'dwd.dwd_ord_ticket_di.order_no'),
    ('ticket_no', 'STRING', '退化维度', '票号', 'dwd_fin_payment_di.ticket_no', 'dwd.dwd_fin_payment_di.ticket_no'),
] + DIM_FIELDS + [
    ('settle_timing_type', 'STRING', '状态类型', '结算时点：PAY-支付即结算，VERIFY-核销即结算（取本方收款支付方式的配置，缺省 VERIFY）', 'dim_fin_settle_timing_df', 'dim.dim_fin_settle_timing_df.settle_timing_type'),
]
TD = [('travel_date', 'STRING', '分区', '数据日期，格式 YYYYMMDD（分区字段）', '${bizdate}', ''),
      ('etl_time', 'STRING', 'ETL', 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss', '调度写入', '')]

# ---- DIM
t('DIM', 'dim.dim_fin_report_rule_f', '财务报表归属规则', '1行=1条归属规则（来源 × 流水类型 × 费用项 × 方向 × 冻结事件）', '码表', '无分区（人工维护，变更即生效）',
  f'人工维护：{SRC_DOC} 5.2 归属表、5.4 费用项映射 + 3.0 流水类型枚举', '归属到哪张表、哪一列、正负号、界面费用类型；未命中规则的流水进「待归类」',
  '', 'dwd_fin_merchant_order_fund_di、dwd_fin_balance_detail_di、dwd_fin_merchant_order_fund_rt、dwd_fin_balance_detail_rt',
  '需求 5.5：未定义的费用项不得默认归类，进待归类异常清单；7.4：归属规则配置化（产品侧配置，不发版）；5.6：金额符号与收支方向只允许一种参与计算，本表以 sign_qty 为准', [
      ('rule_code', 'STRING', '主键', '规则编码', '人工维护', ''),
      ('source_type', 'STRING', '状态类型', '来源：PAYMENT-支付记录，REFUND-退款明细，VERIFY-核销解冻，PAY_SETTLE-支付即结算，FUND_FLOW-资金流水', '人工维护', ''),
      ('flow_type', 'STRING', '状态类型', '资金流水类型（source_type=FUND_FLOW 时）：RECHARGE / PAYMENT / REFUND / FREEZE / UNFREEZE / WITHDRAW / FEE / RESOURCE / TRANSFER_OUT / TRANSFER_IN；空=不限', '人工维护', ''),
      ('fee_item_code', 'STRING', '状态类型', '费用项（资金流水 fee_item）；空=不限', '人工维护', ''),
      ('direction_type', 'STRING', '状态类型', '方向（相对本方商户）：IN-收 / 流入，OUT-付 / 支出；空=不限', '人工维护', ''),
      ('frozen_event_type', 'STRING', '状态类型', '冻结事件（解冻时）：VERIFY-核销触发（界面叫「结算」），REFUND-退款释放；空=不限', '人工维护', ''),
      ('report_code', 'STRING', '状态类型', f'归属报表：{REPORT}', '人工维护', ''),
      ('measure_code', 'STRING', '状态类型', f'归属列：{MEASURE}', '人工维护', ''),
      ('fee_type_name', 'STRING', '维度属性', FEE_TYPE, '人工维护', ''),
      ('sign_qty', 'INT', '维度属性', '对归属报表余额的方向：1-增加，−1-减少，0-不影响', '人工维护', ''),
      ('rule_desc', 'STRING', '维度属性', '规则说明（对应需求条目）', '人工维护', ''),
      ('confirm_status', 'STRING', '状态类型', '确认状态：CONFIRMED-已确认，PENDING-待研发 / 产品确认', '人工维护', ''),
      TD[1]])
t('DIM', 'dim.dim_fin_settle_timing_df', '结算时点配置', '1行=1个商户 × 1种支付方式', '天级全量', 'travel_date（YYYYMMDD）',
  '待业务库补字段：结算时点配在支付方式上（需求 5.8），3.0 业务库暂无该字段', '商户 × 支付方式 → 支付即结算 / 核销即结算',
  'ods_fin_merchant_payment_config_df', 'dwd_fin_merchant_order_fund_di、dwd_fin_merchant_order_fund_rt',
  '源端缺口：t_merchant_payment_config 只有收款模式（collection_mode），没有结算时点；字段补齐前全部按「核销即结算」处理；变更只影响变更之后的订单', [
      ('tenant_id', 'BIGINT', '主键', '商户租户ID', 'ods_fin_merchant_payment_config_df.tenant_id', 'ods.ods_fin_merchant_payment_config_df.tenant_id'),
      ('pay_method_type', 'STRING', '主键', '支付方式：BALANCE / WECHAT / ALIPAY / CREDIT / OFFLINE / ZERO_FEE', '待业务库补字段', ''),
      ('settle_timing_type', 'STRING', '状态类型', '结算时点：PAY-支付即结算，VERIFY-核销即结算；缺省 VERIFY', '待业务库补字段；缺省 VERIFY', ''),
      ('valid_start_time', 'STRING', '时间', '配置生效时间：只影响生效之后的订单，历史订单按原时点（需求 5.8）', '待业务库补字段', ''),
      TD[0], TD[1]])

# ---- DWD
t('DWD', 'dwd.dwd_fin_merchant_order_fund_di', '商户订单资金明细（订单报表事实）', '1行=1个本方商户 × 1张票 × 1个资金动作（收 / 退 / 付 / 退回 / 结算）', '天级增量', 'travel_date（YYYYMMDD，= 动作发生日）',
  'dwd_fin_payment_di（收 / 付，← ods_fin_payment_record_di）+ dwd_fin_refund_payment_di / dwd_ord_refund_ticket_di（退 / 退回，← ods_ord_refund_detail_di、ods_ord_refund_order_di）'
  '+ dwd_fin_frozen_di（核销解冻 → 结算，← ods_fin_frozen_record_di）+ dwd_ord_ticket_di / dwd_ord_order_group_di（订单维度）',
  '度量：event_amt、balance_effect_amt、ticket_net_qty、confirm_ticket_qty\n报表 / 列 / 费用类型：report_code、measure_code、fee_type_name\n维度：' + '、'.join(DIMS),
  'dwd_fin_payment_di、dwd_fin_refund_payment_di、dwd_ord_refund_ticket_di、dwd_fin_frozen_di、dwd_ord_ticket_di、dwd_ord_order_group_di、dim_fin_report_rule_f、dim_fin_settle_timing_df',
  'dws_fin_merchant_unsettled_df、dws_fin_merchant_order_fund_di',
  '预收 / 预付 / 确认收入 / 确认成本四张订单报表的汇总来源与下钻、明细页来源（7.3：明细与汇总共用一套归属规则）；'
  '一笔支付在收款方、采购付款方各记一行（买卖两个方向分别记，不是重复）；只取本方商户侧，避免双式记账重复（第十章 2）', FACT_FIELDS + TD)
t('DWD', 'dwd.dwd_fin_balance_detail_di', '商户余额明细（余额报表事实）', '1行=1个本方账户的 1 条资金流水', '天级增量', 'travel_date（YYYYMMDD，= 流水发生日）',
  'dwd_fin_fund_flow_di（← ods_fin_fund_flow_di）+ dim_fin_account_df（只取商户 / 分销商账户）+ dwd_fin_frozen_di（解冻的冻结事件）+ dwd_fin_payment_di（对方商户、业务订单号）+ dim_fin_report_rule_f',
  '度量：change_amt、balance_in_amt、balance_out_amt、balance_after_amt（快照余额）\n归属：report_code、fee_type_name、direction_name\n维度：account_no（账本）、counterparty_tenant_id（对方商户）',
  'dwd_fin_fund_flow_di、dim_fin_account_df、dwd_fin_frozen_di、dwd_fin_payment_di、dim_fin_report_rule_f', 'dws_fin_merchant_balance_di、ads_fin_unclassified_flow_di',
  '余额报表、费用收支报表的汇总来源与下钻、明细页来源；余额列取快照余额（每笔之后的账户余额），不由前几笔累加（5.7）；'
  '核销即结算的订单，下单时的收款、采购划付、冻结在可用余额上相抵，归 NONE 不进余额，解冻（核销）时属于本方的份额以「结算」流入', [
      ('flow_no', 'STRING', '主键', '业务流水号（明细列，可复制）：资金流水号', 'dwd_fin_fund_flow_di.flow_no', 'dwd.dwd_fin_fund_flow_di.flow_no'),
      ('flow_time', 'STRING', '时间', '交易时间', 'dwd_fin_fund_flow_di.flow_time', 'dwd.dwd_fin_fund_flow_di.flow_time'),
      ('merchant_tenant_id', 'BIGINT', '外键', '本方商户租户ID（账户主体），关联 dim_sup_tenant_zip', 'dim_fin_account_df.subject_id', 'dim.dim_fin_account_df.subject_id'),
      ('account_no', 'STRING', '外键', '所属账本（维度：账本），关联 dim_fin_account_df', 'dwd_fin_fund_flow_di.account_no', 'dwd.dwd_fin_fund_flow_di.account_no'),
      ('account_type', 'STRING', '状态类型', '账户类型：MERCHANT-商户，DISTRIBUTOR-分销商', 'dim_fin_account_df.account_type', 'dim.dim_fin_account_df.account_type'),
      ('flow_type', 'STRING', '状态类型', '流水类型（业务库枚举）', 'dwd_fin_fund_flow_di.flow_type', 'dwd.dwd_fin_fund_flow_di.flow_type'),
      ('fee_item_code', 'STRING', '状态类型', '费用项（维度：费用项，费用收支报表用）', 'dwd_fin_fund_flow_di.fee_item_code', 'dwd.dwd_fin_fund_flow_di.fee_item_code'),
      ('frozen_event_type', 'STRING', '状态类型', '冻结事件（解冻流水）：VERIFY-核销触发，REFUND-退款释放', 'dwd_fin_frozen_di.release_event_type', 'dwd.dwd_fin_frozen_di.release_event_type'),
      ('report_code', 'STRING', '状态类型', '归属：BALANCE-仅余额，EXPENSE-费用收支，NONE-不进余额，UNCLASSIFIED-待归类（进异常清单）', 'dim_fin_report_rule_f.report_code', 'dim.dim_fin_report_rule_f.report_code'),
      ('fee_type_name', 'STRING', '维度属性', FEE_TYPE, 'dim_fin_report_rule_f.fee_type_name', 'dim.dim_fin_report_rule_f.fee_type_name'),
      ('direction_name', 'STRING', '维度属性', '收支方向（明细筛选）：流入 / 支出；期初建账不计入方向', '变动金额正负', 'dwd.dwd_fin_fund_flow_di.change_amt'),
      ('change_amt', 'DECIMAL(18,2)', '度量', '变动金额（元，带符号：正=流入，负=支出；与收支方向只取一种参与计算，以本字段为准）', 'dwd_fin_fund_flow_di.change_amt', 'dwd.dwd_fin_fund_flow_di.change_amt'),
      ('balance_in_amt', 'DECIMAL(18,2)', '度量', '计入余额报表的流入（元）：归属为 仅余额 / 费用收支 且金额 > 0', 'IF(report_code IN (BALANCE, EXPENSE) AND change_amt > 0, change_amt, 0)', 'dwd.dwd_fin_fund_flow_di.change_amt'),
      ('balance_out_amt', 'DECIMAL(18,2)', '度量', '计入余额报表的流出（元，正数）', 'IF(report_code IN (BALANCE, EXPENSE) AND change_amt < 0, −change_amt, 0)', 'dwd.dwd_fin_fund_flow_di.change_amt'),
      ('balance_before_amt', 'DECIMAL(18,2)', '度量', '变动前可用余额（元）', 'dwd_fin_fund_flow_di.balance_before_amt', 'dwd.dwd_fin_fund_flow_di.balance_before_amt'),
      ('balance_after_amt', 'DECIMAL(18,2)', '度量', '余额（明细「余额」列，快照值）：本笔之后的账户可用余额（元）', 'dwd_fin_fund_flow_di.balance_after_amt', 'dwd.dwd_fin_fund_flow_di.balance_after_amt'),
      ('counterparty_tenant_id', 'BIGINT', '外键', '对方商户（明细筛选）：订单类为支付记录另一侧的租户（散客 0）；充值 / 提现为银行；费用为平台', '按支付批次号关联支付记录', 'dwd.dwd_fin_payment_di.payer_tenant_id、dwd.dwd_fin_payment_di.payee_tenant_id'),
      ('counterparty_type', 'STRING', '状态类型', '对方类型：DISTRIBUTOR-分销商，SUPPLIER-供应商，CUSTOMER-散客，BANK-银行，PLATFORM-平台，SELF-本方（冻结 / 解冻）', '见加工逻辑', 'dwd.dwd_fin_fund_flow_di.flow_type'),
      ('biz_order_no', 'STRING', '退化维度', '业务订单号（明细列，可复制）：订单类流水对应的聚合单号', '支付记录 order_group_no（按支付批次号）', 'dwd.dwd_fin_payment_di.order_group_no'),
      ('related_no', 'STRING', '退化维度', '关联订单号（明细列，可复制）：流水关联业务号（订单号 / 退款号 / 提现号）', 'dwd_fin_fund_flow_di.related_no', 'dwd.dwd_fin_fund_flow_di.related_no'),
      ('payment_batch_no', 'STRING', '退化维度', '关联支付批次号', 'dwd_fin_fund_flow_di.payment_batch_no', 'dwd.dwd_fin_fund_flow_di.payment_batch_no')] + TD)

# ---- DWS
t('DWS', 'dws.dws_fin_merchant_unsettled_df', '预收预付在途快照', 'travel_date × merchant_tenant_id × report_code × ticket_no', '天级全量', 'travel_date（YYYYMMDD）',
  'dws_fin_merchant_unsettled_df（T-1）+ dwd_fin_merchant_order_fund_di（T）', '时点值：unsettled_amt（日终在途金额）、unsettled_ticket_qty；按票保留全部订单维度',
  'dwd_fin_merchant_order_fund_di', 'ads_fin_order_report_dim_di、ads_fin_merchant_report_di',
  '期初 / 期末的来源（5.7：时点值由累计得出，不独立维护；按维度拆分时每个维度组合各自累计）；在途归零的票不再保留', [
      ('merchant_tenant_id', 'BIGINT', '粒度键', '本方商户租户ID', f'{F_}.merchant_tenant_id', f'dwd.{F_}.merchant_tenant_id'),
      ('report_code', 'STRING', '粒度键', '报表：ADV_RECEIPT-预收，ADV_PAYMENT-预付', f'{F_}.report_code', f'dwd.{F_}.report_code'),
      ('ticket_no', 'STRING', '粒度键', '票号', f'{F_}.ticket_no', f'dwd.{F_}.ticket_no'),
      ('order_no', 'STRING', '退化维度', '子单号', f'{F_}.order_no', f'dwd.{F_}.order_no')]
  + [(n, ty, cat, cm, f'{F_}.{n}', f'dwd.{F_}.{n}') for n, ty, cat, cm, _, _ in DIM_FIELDS]
  + [('unsettled_amt', 'DECIMAL(18,2)', '指标', '在途金额（期末预收 / 期末预付）：截至统计日日终已卖出（已采购）、尚未核销且未退款的金额，单位：元', 'T-1 快照 + 当日 SUM(balance_effect_amt)', f'dwd.{F_}.balance_effect_amt'),
     ('unsettled_ticket_qty', 'BIGINT', '指标', '在途票数：截至统计日日终在途的净票数，单位：张', 'T-1 快照 + 当日 SUM(ticket_net_qty)', f'dwd.{F_}.ticket_net_qty'),
     ('first_event_date', 'STRING', '时间', '首次进入在途的日期（收 / 付日期）', 'MIN(travel_date)', f'dwd.{F_}.travel_date')] + TD)
MEAS = [('receive', 'ADV_RECEIPT', 'RECEIVE', '本期收', '订单卖出金额（不论款项是否到账，含授信；不含渠道手续费）'), ('refund', 'ADV_RECEIPT', 'REFUND', '本期退', '退给下级的金额（履约前退款）'),
        ('to_revenue', 'ADV_RECEIPT', 'TO_REVENUE', '转实收', '因履约（核销；支付即结算为收款时）转入确认收入的金额'),
        ('pay', 'ADV_PAYMENT', 'PAY', '本期付', '向上级采购付款金额'), ('return', 'ADV_PAYMENT', 'RETURN', '本期退回', '上级退回金额'),
        ('to_cost', 'ADV_PAYMENT', 'TO_COST', '转实付', '因履约转入成本确认的金额'),
        ('revenue', 'REVENUE', 'CONFIRM', '履约收入', '因核销确认的收入，按订单实收金额（实收单价 × 核销数量）计量，总额法'),
        ('cost', 'COST', 'CONFIRM', '成本结算', '因核销确认的成本，按订单买入金额（当前级采购成本）计量')]
QTYS = [('sale_ticket_qty', '售票数', '本方收侧售出票数', "measure_code='RECEIVE'", 'ticket_net_qty'),
        ('refund_ticket_qty', '退款票数', '本方收侧退款票数（正数）', "measure_code='REFUND'", '-ticket_net_qty'),
        ('buy_ticket_qty', '采购票数', '本方付侧采购票数', "measure_code='PAY'", 'ticket_net_qty'),
        ('return_ticket_qty', '退回票数', '本方付侧退回票数（正数）', "measure_code='RETURN'", '-ticket_net_qty'),
        ('revenue_ticket_qty', '确认收入票数', '本期履约确认收入的票数', "report_code='REVENUE'", 'confirm_ticket_qty'),
        ('cost_ticket_qty', '确认成本票数', '本期履约确认成本的票数', "report_code='COST'", 'confirm_ticket_qty')]
t('DWS', 'dws.dws_fin_merchant_order_fund_di', '商户订单资金日汇总', 'travel_date × merchant_tenant_id × ' + DIMSTR, '天级增量', 'travel_date（YYYYMMDD）',
  'dwd_fin_merchant_order_fund_di', '原子口径：' + '、'.join(f'{m}_amt' for m, *_ in MEAS) + '、' + '、'.join(q[0] for q in QTYS),
  'dwd_fin_merchant_order_fund_di', 'ads_fin_order_report_dim_di、ads_fin_merchant_report_di',
  '订单四张报表的期间值（5.7）；粒度含全部订单维度（4.2：订单上的所有属性都可作为维度），查询时按所选维度再聚合；维度无值保持为空，界面显示「—」不归入「其他」（4.5）',
  [('merchant_tenant_id', 'BIGINT', '粒度键', '本方商户租户ID，关联 dim_sup_tenant_zip', f'{F_}.merchant_tenant_id', f'dwd.{F_}.merchant_tenant_id')]
  + [(n, ty, '粒度键', cm, f'{F_}.{n}', f'dwd.{F_}.{n}') for n, ty, _, cm, _, _ in DIM_FIELDS]
  + [(f'{m}_amt', 'DECIMAL(18,2)', '指标', f'{cn}：{kou}，单位：元', f"{F_}：SUM(event_amt) where report_code='{r}' and measure_code='{c}'", f'dwd.{F_}.event_amt') for m, r, c, cn, kou in MEAS]
  + [(q, 'BIGINT', '指标', f'{cn}：{kou}，单位：张', f'{F_}：SUM({e}) where {w}', f"dwd.{F_}.{e.lstrip('-')}") for q, cn, kou, w, e in QTYS] + TD)
t('DWS', 'dws.dws_fin_merchant_balance_di', '商户余额与费用日汇总', 'travel_date × merchant_tenant_id × account_no × report_code × fee_type_name × flow_type × fee_item_code', '天级增量', 'travel_date（YYYYMMDD）',
  'dwd_fin_balance_detail_di', '原子口径：fund_in_amt、fund_out_amt、fund_flow_qty（按归属：BALANCE / EXPENSE / NONE / UNCLASSIFIED）',
  'dwd_fin_balance_detail_di', 'ads_fin_balance_report_di、ads_fin_merchant_report_di',
  '余额报表（全部资金流动）与费用收支报表（订单之外的费用项）的期间值', [
      ('merchant_tenant_id', 'BIGINT', '粒度键', '本方商户租户ID（账户主体）', 'dwd_fin_balance_detail_di.merchant_tenant_id', 'dwd.dwd_fin_balance_detail_di.merchant_tenant_id'),
      ('account_no', 'STRING', '粒度键', '账本', 'dwd_fin_balance_detail_di.account_no', 'dwd.dwd_fin_balance_detail_di.account_no'),
      ('report_code', 'STRING', '粒度键', '归属：BALANCE / EXPENSE / NONE / UNCLASSIFIED', 'dwd_fin_balance_detail_di.report_code', 'dwd.dwd_fin_balance_detail_di.report_code'),
      ('fee_type_name', 'STRING', '粒度键', '费用类型（界面）', 'dwd_fin_balance_detail_di.fee_type_name', 'dwd.dwd_fin_balance_detail_di.fee_type_name'),
      ('flow_type', 'STRING', '粒度键', '流水类型', 'dwd_fin_balance_detail_di.flow_type', 'dwd.dwd_fin_balance_detail_di.flow_type'),
      ('fee_item_code', 'STRING', '粒度键', '费用项', 'dwd_fin_balance_detail_di.fee_item_code', 'dwd.dwd_fin_balance_detail_di.fee_item_code'),
      ('fund_in_amt', 'DECIMAL(18,2)', '指标', '资金流入：金额 > 0 的流水合计（各归属都算，余额报表只取 仅余额 / 费用收支），单位：元', 'SUM(change_amt) where change_amt > 0', 'dwd.dwd_fin_balance_detail_di.change_amt'),
      ('fund_out_amt', 'DECIMAL(18,2)', '指标', '资金流出：金额 < 0 的流水合计（正数），单位：元', '-SUM(change_amt) where change_amt < 0', 'dwd.dwd_fin_balance_detail_di.change_amt'),
      ('fund_flow_qty', 'BIGINT', '指标', '流水笔数，单位：笔', 'COUNT(flow_no)', 'dwd.dwd_fin_balance_detail_di.flow_no')] + TD)

# ---- ADS
OR_COLS = [('report_code', 'STRING', '粒度键', '报表：ADV_RECEIPT-预收，ADV_PAYMENT-预付，REVENUE-确认收入，COST-确认成本', '见加工逻辑', f'dwd.{F_}.report_code')]
OR_MEAS = [('in_amt', '本期收 / 本期付', '预收：本期收；预付：本期付'), ('out_amt', '本期退 / 本期退回', '预收：本期退；预付：本期退回'),
           ('trans_amt', '转实收 / 转实付', '预收：转实收；预付：转实付'), ('confirm_amt', '履约收入 / 成本结算', '确认收入：履约收入；确认成本：成本结算'),
           ('close_amt', '期末预收 / 期末预付（日终时点值）', '预收 / 预付：该维度组合统计日日终余额；期初 = 区间首日前一天的 close_amt，期末 = 区间末日的 close_amt'),
           ('net_ticket_qty', '净票数（预收 / 预付）', '售票记正、退款记负、核销不改变票数'), ('confirm_ticket_qty', '核销票数（确认收入 / 确认成本）', '本期履约确认的票数')]
ORD_FIELDS = ([('merchant_tenant_id', 'BIGINT', '粒度键', '本方商户租户ID，关联 dim_sup_tenant_zip', 'dws 各表 merchant_tenant_id', 'dws.dws_fin_merchant_order_fund_di.merchant_tenant_id')] + OR_COLS
              + [(n, ty, '粒度键', cm, f'dws_fin_merchant_order_fund_di.{n}、dws_fin_merchant_unsettled_df.{n}', f'dws.dws_fin_merchant_order_fund_di.{n}') for n, ty, _, cm, _, _ in DIM_FIELDS]
              + [(f, 'BIGINT' if f.endswith('_qty') else 'DECIMAL(18,2)', '指标', f"{cn}：{kou}，单位：{'张' if f.endswith('_qty') else '元'}",
                  'dws_fin_merchant_unsettled_df.unsettled_amt' if f == 'close_amt' else 'dws_fin_merchant_order_fund_di 按报表展开',
                  'dws.dws_fin_merchant_unsettled_df.unsettled_amt' if f == 'close_amt' else 'dws.dws_fin_merchant_order_fund_di.receive_amt') for f, cn, kou in OR_MEAS])
t('ADS', 'ads.ads_fin_order_report_dim_di', '订单报表多维汇总（日）', 'travel_date × merchant_tenant_id × report_code × ' + DIMSTR, '天级增量', 'travel_date（YYYYMMDD）',
  'dws_fin_merchant_order_fund_di（期间值）+ dws_fin_merchant_unsettled_df（日终余额）',
  '预收 / 预付 / 确认收入 / 确认成本四张报表「汇总」页的历史段（T+1 定版）；同步 StarRocks 供报表服务按所选维度现场聚合',
  'dws_fin_merchant_order_fund_di、dws_fin_merchant_unsettled_df', 'ads_fin_order_report_dim_rt',
  '使用端：商户后台 · 财务 · 报表中心 · 订单报表（汇总页）。查询：按所选维度 GROUP BY 并出每层小计（4.5）；期间值 SUM；期初 = 区间首日前一天 close_amt 之和，期末 = 区间末日 close_amt 之和'
  '（时点值不跨期相加，5.7）；按月粒度时每月取月初前一天 / 月末；区间为单日时日期降为筛选条件；预收 / 确认收入只开放收侧维度、预付 / 确认成本只开放付侧维度（4.3、4.4）', ORD_FIELDS + TD)
t('ADS', 'ads.ads_fin_balance_report_di', '余额报表（日 × 账本）', 'travel_date × merchant_tenant_id × account_no', '天级增量', 'travel_date（YYYYMMDD）',
  'dws_fin_account_balance_df（期初 / 期末余额）+ dws_fin_merchant_balance_di（流入 / 流出、充值、提现、费用）',
  '余额报表定版数据（对账、勾稽用；页面查询始终取 ads_fin_balance_report_rt，6.3）',
  'dws_fin_account_balance_df、dws_fin_merchant_balance_di、dim_fin_account_df', '',
  '维度：日期、账本（4.3）；期末 = 期初 + 流入 − 流出 恒等；充值、提现包含在流入 / 流出中，单列字段仅供下钻构成（3.6）', [
      ('merchant_tenant_id', 'BIGINT', '粒度键', '本方商户租户ID', 'dim_fin_account_df.subject_id', 'dim.dim_fin_account_df.subject_id'),
      ('account_no', 'STRING', '粒度键', '账本', 'dws_fin_account_balance_df.account_no', 'dws.dws_fin_account_balance_df.account_no'),
      ('balance_open_amt', 'DECIMAL(18,2)', '指标', '期初余额（日快照）：统计日第一笔流水前的可用余额；无流水取日终可用余额，单位：元', 'dws_fin_account_balance_df.opening_balance_amt', 'dws.dws_fin_account_balance_df.opening_balance_amt'),
      ('balance_in_amt', 'DECIMAL(18,2)', '指标', '资金流入：本期实际进入可用余额的金额（含结算解冻、充值），单位：元', "dws_fin_merchant_balance_di.fund_in_amt where report_code in ('BALANCE','EXPENSE')", 'dws.dws_fin_merchant_balance_di.fund_in_amt'),
      ('balance_out_amt', 'DECIMAL(18,2)', '指标', '资金流出：本期实际离开可用余额的金额（含提现、应用套餐、手续费），单位：元', "dws_fin_merchant_balance_di.fund_out_amt where report_code in ('BALANCE','EXPENSE')", 'dws.dws_fin_merchant_balance_di.fund_out_amt'),
      ('balance_close_amt', 'DECIMAL(18,2)', '指标', '期末余额（日快照）：期初 + 流入 − 流出，单位：元', 'dws_fin_account_balance_df.closing_balance_amt', 'dws.dws_fin_account_balance_df.closing_balance_amt'),
      ('recharge_amt', 'DECIMAL(18,2)', '指标', '其中充值，单位：元', "fund_in_amt where flow_type='RECHARGE'", 'dws.dws_fin_merchant_balance_di.fund_in_amt'),
      ('withdraw_amt', 'DECIMAL(18,2)', '指标', '其中提现，单位：元', "fund_out_amt where flow_type='WITHDRAW'", 'dws.dws_fin_merchant_balance_di.fund_out_amt'),
      ('expense_income_amt', 'DECIMAL(18,2)', '指标', '费用收入（二期 · 费用收支报表），单位：元', "fund_in_amt where report_code='EXPENSE'", 'dws.dws_fin_merchant_balance_di.fund_in_amt'),
      ('expense_out_amt', 'DECIMAL(18,2)', '指标', '费用支出（二期 · 费用收支报表），单位：元', "fund_out_amt where report_code='EXPENSE'", 'dws.dws_fin_merchant_balance_di.fund_out_amt'),
      ('unclassified_flow_qty', 'BIGINT', '指标', '待归类流水笔数（应为 0），单位：笔', "fund_flow_qty where report_code='UNCLASSIFIED'", 'dws.dws_fin_merchant_balance_di.fund_flow_qty')] + TD)
RPT = [('adv_receipt_open_amt', '期初预收', '统计日前一日日终的预收余额（时点值）', 'snap'), ('adv_receipt_receive_amt', '本期收', '订单卖出金额（含授信）', 'sum'),
       ('adv_receipt_refund_amt', '本期退', '退给下级的金额', 'sum'), ('adv_receipt_to_revenue_amt', '转实收', '因履约转入确认收入的金额', 'sum'),
       ('adv_receipt_close_amt', '期末预收', '期初 + 收 − 退 − 转实收（时点值）', 'snap'),
       ('adv_payment_open_amt', '期初预付', '统计日前一日日终的预付余额（时点值）', 'snap'), ('adv_payment_pay_amt', '本期付', '向上级采购付款金额', 'sum'),
       ('adv_payment_return_amt', '本期退回', '上级退回金额', 'sum'), ('adv_payment_to_cost_amt', '转实付', '因履约转入成本确认的金额', 'sum'),
       ('adv_payment_close_amt', '期末预付', '期初 + 付 − 退回 − 转实付（时点值）', 'snap'),
       ('revenue_amt', '履约收入', '因核销确认的收入（总额法）', 'sum'), ('cost_amt', '成本结算', '因核销确认的成本', 'sum'),
       ('net_ticket_qty', '净票数', '售票数 − 退款票数（核销不改变票数）', 'sum'),
       ('balance_open_amt', '期初余额', '统计日第一笔流水前的可用余额（时点值）', 'snap'), ('balance_in_amt', '资金流入', '本期实际进入可用余额的金额', 'sum'),
       ('balance_out_amt', '资金流出', '本期实际离开可用余额的金额', 'sum'), ('balance_close_amt', '期末余额', '期初 + 流入 − 流出（时点值）', 'snap'),
       ('recharge_amt', '充值', '流入中的充值', 'sum'), ('withdraw_amt', '提现', '流出中的提现', 'sum'),
       ('expense_income_amt', '费用收入', '订单之外的收入（二期）', 'sum'), ('expense_out_amt', '费用支出', '订单之外的支出：应用套餐、平台服务费、手续费（二期）', 'sum'),
       ('unclassified_flow_qty', '待归类流水笔数', '未命中归属规则的流水笔数（应为 0）', 'sum')]
RPT_UP = {'adv_receipt_open_amt': 'dws.dws_fin_merchant_unsettled_df.unsettled_amt', 'adv_receipt_close_amt': 'dws.dws_fin_merchant_unsettled_df.unsettled_amt',
          'adv_payment_open_amt': 'dws.dws_fin_merchant_unsettled_df.unsettled_amt', 'adv_payment_close_amt': 'dws.dws_fin_merchant_unsettled_df.unsettled_amt',
          'net_ticket_qty': 'dws.dws_fin_merchant_order_fund_di.sale_ticket_qty、dws.dws_fin_merchant_order_fund_di.refund_ticket_qty'}
for _f in ('balance_open_amt', 'balance_in_amt', 'balance_out_amt', 'balance_close_amt', 'recharge_amt', 'withdraw_amt', 'expense_income_amt', 'expense_out_amt', 'unclassified_flow_qty'):
    RPT_UP[_f] = f'ads.ads_fin_balance_report_di.{_f}'
for _f, _s in (('adv_receipt_receive_amt', 'receive_amt'), ('adv_receipt_refund_amt', 'refund_amt'), ('adv_receipt_to_revenue_amt', 'to_revenue_amt'),
               ('adv_payment_pay_amt', 'pay_amt'), ('adv_payment_return_amt', 'return_amt'), ('adv_payment_to_cost_amt', 'to_cost_amt'), ('revenue_amt', 'revenue_amt'), ('cost_amt', 'cost_amt')):
    RPT_UP[_f] = f'dws.dws_fin_merchant_order_fund_di.{_s}'
t('ADS', 'ads.ads_fin_merchant_report_di', '商户财务报表总览（日）', 'travel_date × merchant_tenant_id', '天级增量', 'travel_date（YYYYMMDD）',
  'ads_fin_order_report_dim_di、ads_fin_balance_report_di', '五张基础报表的商户级总数，勾稽验收（第八章）与二期派生表（未结转差额、毛利与净利）的来源',
  'ads_fin_order_report_dim_di、ads_fin_balance_report_di', 'ads_fin_merchant_report_rt',
  '派生（查询时计算，不落表，原则 5）：未结转差额 = 期末预收 − 期末预付；订单毛利 = 履约收入 − 成本结算；毛利率 = 毛利 ÷ 履约收入；'
  '费用收支净额 = 费用收入 − 费用支出；净利 = 毛利 + 费用收支净额；净利率 = 净利 ÷ 履约收入',
  [('merchant_tenant_id', 'BIGINT', '粒度键', '本方商户租户ID', 'ads_fin_order_report_dim_di.merchant_tenant_id', 'ads.ads_fin_order_report_dim_di.merchant_tenant_id')]
  + [(f, 'BIGINT' if f.endswith('_qty') else 'DECIMAL(18,2)', '指标', f"{cn}（{'日快照' if k == 'snap' else '日'}）：{kou}，单位：{'张' if f == 'net_ticket_qty' else '笔' if f.endswith('_qty') else '元'}",
      '按报表汇总 ads_fin_order_report_dim_di' if f.startswith(('adv_', 'revenue', 'cost', 'net_')) else f'ads_fin_balance_report_di.{f}',
      RPT_UP[f]) for f, cn, kou, k in RPT] + TD)
t('ADS', 'ads.ads_fin_unclassified_flow_di', '待归类资金流水异常清单', '1行=1条未命中归属规则的资金流水', '天级增量', 'travel_date（YYYYMMDD）',
  'dwd_fin_balance_detail_di（report_code = UNCLASSIFIED）', '新增或未声明的费用项不进任何报表，进本清单，由产品确认后补入规则（5.5）',
  'dwd_fin_balance_detail_di', '', '不得默认归入任何一类；补规则后重跑当日即可回归正常报表', [
      ('flow_no', 'STRING', '主键', '资金流水号', 'dwd_fin_balance_detail_di.flow_no', 'dwd.dwd_fin_balance_detail_di.flow_no'),
      ('flow_time', 'STRING', '时间', '交易时间', 'dwd_fin_balance_detail_di.flow_time', 'dwd.dwd_fin_balance_detail_di.flow_time'),
      ('merchant_tenant_id', 'BIGINT', '外键', '本方商户租户ID', 'dwd_fin_balance_detail_di.merchant_tenant_id', 'dwd.dwd_fin_balance_detail_di.merchant_tenant_id'),
      ('account_no', 'STRING', '外键', '账本', 'dwd_fin_balance_detail_di.account_no', 'dwd.dwd_fin_balance_detail_di.account_no'),
      ('flow_type', 'STRING', '状态类型', '流水类型', 'dwd_fin_balance_detail_di.flow_type', 'dwd.dwd_fin_balance_detail_di.flow_type'),
      ('fee_item_code', 'STRING', '状态类型', '费用项', 'dwd_fin_balance_detail_di.fee_item_code', 'dwd.dwd_fin_balance_detail_di.fee_item_code'),
      ('frozen_event_type', 'STRING', '状态类型', '冻结事件', 'dwd_fin_balance_detail_di.frozen_event_type', 'dwd.dwd_fin_balance_detail_di.frozen_event_type'),
      ('change_amt', 'DECIMAL(18,2)', '度量', '变动金额（元）', 'dwd_fin_balance_detail_di.change_amt', 'dwd.dwd_fin_balance_detail_di.change_amt'),
      ('related_no', 'STRING', '退化维度', '关联业务号', 'dwd_fin_balance_detail_di.related_no', 'dwd.dwd_fin_balance_detail_di.related_no')] + TD)

# ---- 实时（今天段；余额报表始终实时）
t('ODS（实时）', 'ods.ods_fin_fund_flow_rt', '资金流水 binlog 流', '同源表，1行=1条源记录（CDC 变更流）', '实时（后缀待定）', '不落地：Flink CDC 源表，作业内直读 binlog',
  'pft-finance.t_fund_flow（Flink CDC 读 binlog）', '', '', 'dwd_fin_balance_detail_rt', RT_NOTE, '@copy:ods.ods_fin_fund_flow_di')
t('ODS（实时）', 'ods.ods_ord_refund_detail_rt', '退款明细 binlog 流', '同源表，1行=1条源记录（CDC 变更流）', '实时（后缀待定）', '不落地：Flink CDC 源表，作业内直读 binlog',
  'pft-order.t_refund_detail（Flink CDC 读 binlog）', '', '', 'dwd_fin_refund_payment_rt', RT_NOTE + '；补齐：今天段的本期退 / 本期退回依赖此流', '@copy:ods.ods_ord_refund_detail_di')
t('DWD（实时）', 'dwd.dwd_fin_refund_payment_rt', '实时退款明细（按支付记录）', '1行=1条退款明细', '实时（后缀待定）', 'StarRocks 按 travel_date 分区',
  'ods_ord_refund_detail_rt + lookup dwd_fin_payment_rt / dwd_ord_refund_rt', '度量：refund_amt', 'ods_ord_refund_detail_rt、dwd_fin_payment_rt、dwd_ord_refund_rt', 'dwd_fin_merchant_order_fund_rt',
  RT_NOTE + '；字段与离线 dwd_fin_refund_payment_di 一致', '@copy:dwd.dwd_fin_refund_payment_di')
t('DWD（实时）', 'dwd.dwd_fin_merchant_order_fund_rt', '实时商户订单资金明细', '1行=1个本方商户 × 1张票 × 1个资金动作', '实时（后缀待定）', 'StarRocks 按 travel_date 分区',
  'dwd_fin_payment_rt + dwd_fin_refund_payment_rt + dwd_fin_frozen_rt（今天）+ Hive 外表 dwd_fin_payment_di / dwd_ord_ticket_di / dwd_ord_order_group_di（历史支付与订单维度）', '同离线 dwd_fin_merchant_order_fund_di',
  'dwd_fin_payment_rt、dwd_fin_refund_payment_rt、dwd_fin_frozen_rt、dwd_ord_order_rt、dwd_fin_payment_di、dwd_ord_ticket_di、dwd_ord_order_group_di、dim_fin_report_rule_f、dim_fin_settle_timing_df',
  'ads_fin_order_report_dim_rt、ads_fin_merchant_report_rt',
  RT_NOTE + '；StarRocks 异步物化视图（1 分钟刷新），与离线同一套 SQL 逻辑（7.3 明细与汇总同规则），今天段明细页与下钻取此表', '@copy:dwd.dwd_fin_merchant_order_fund_di')
t('DWD（实时）', 'dwd.dwd_fin_balance_detail_rt', '实时商户余额明细', '1行=1个本方账户的 1 条资金流水', '实时（后缀待定）', 'StarRocks 按 travel_date 分区（保留全部历史）',
  'ods_fin_fund_flow_rt + lookup dim_fin_account_df / dim_fin_report_rule_f / dwd_fin_frozen_rt / dwd_fin_payment_rt', '同离线 dwd_fin_balance_detail_di',
  'ods_fin_fund_flow_rt、dim_fin_account_df、dim_fin_report_rule_f、dwd_fin_frozen_rt、dwd_fin_payment_rt', 'ads_fin_balance_report_rt',
  RT_NOTE + '；余额报表始终实时（6.3），本表保留全部历史，余额明细页与下钻取此表', '@copy:dwd.dwd_fin_balance_detail_di')
t('ADS（实时）', 'ads.ads_fin_order_report_dim_rt', '订单报表多维汇总（今日实时）', 'merchant_tenant_id × report_code × ' + DIMSTR + '（今日）', '实时（后缀待定）', 'StarRocks 按 travel_date 分区',
  'dwd_fin_merchant_order_fund_rt（今日发生）+ ads_fin_order_report_dim_di（昨日日终余额）', '同 ads_fin_order_report_dim_di',
  'dwd_fin_merchant_order_fund_rt、ads_fin_order_report_dim_di', '',
  '今日段：期间值取实时明细；今日日终余额 = 昨日 close_amt + 今日余额影响。报表服务按日期分段拼接（6.1）：历史段查 ads_fin_order_report_dim_di、今日段查本表，字段一致；'
  '页面底部提示「数据截至 HH:MM，当日仍在变动」（6.2）', '@copy:ads.ads_fin_order_report_dim_di')
t('ADS（实时）', 'ads.ads_fin_balance_report_rt', '余额报表（实时 · 日 × 账本）', 'travel_date × merchant_tenant_id × account_no', '实时（后缀待定）', 'StarRocks 按 travel_date 分区（全部历史）',
  'dwd_fin_balance_detail_rt', '同 ads_fin_balance_report_di', 'dwd_fin_balance_detail_rt', '',
  '余额报表始终实时、不参与分段（6.3）：任意区间都查本表；某账户某天无流水时不出行，报表服务以前一有流水日的期末余额顺延', '@copy:ads.ads_fin_balance_report_di')
t('ADS（实时）', 'ads.ads_fin_merchant_report_rt', '商户财务报表总览（今日实时）', 'merchant_tenant_id × 今日', '实时（后缀待定）', 'StarRocks 按 travel_date 分区',
  'ads_fin_order_report_dim_rt + ads_fin_balance_report_rt', '同 ads_fin_merchant_report_di（今日）', 'ads_fin_order_report_dim_rt、ads_fin_balance_report_rt', '',
  '今日段勾稽用', '@copy:ads.ads_fin_merchant_report_di')

# ---------------------------------------------------------------- 归属规则（5.2 归属表、5.4 费用项映射）
# (编码, 来源, 流水类型, 费用项, 方向, 冻结事件, 报表, 列, 费用类型, 符号, 说明, 确认状态)
RULES = [
    ('FR01', 'PAYMENT', '', '', 'IN', '', 'ADV_RECEIPT', 'RECEIVE', '付款', 1, '下级下单支付（本方为收款方）→ 预收 +（5.2-1）；含授信，授信是支付方式的一种（3.1）', 'CONFIRMED'),
    ('FR02', 'PAYMENT', '', '', 'OUT', '', 'ADV_PAYMENT', 'PAY', '付款', 1, '向上级采购付款 → 预付 +（5.2-4）', 'CONFIRMED'),
    ('FR03', 'REFUND', '', '', 'IN', '', 'ADV_RECEIPT', 'REFUND', '退款', -1, '履约前退款，本方退给下级 → 预收 −（5.2-3）', 'CONFIRMED'),
    ('FR04', 'REFUND', '', '', 'OUT', '', 'ADV_PAYMENT', 'RETURN', '退款', -1, '上级退回 → 预付 −（5.2-6），与 FR03 成对', 'CONFIRMED'),
    ('FR05', 'VERIFY', '', '', 'IN', 'VERIFY', 'ADV_RECEIPT', 'TO_REVENUE', '结算', -1, '核销（收侧）→ 预收 −（5.2-2）', 'CONFIRMED'),
    ('FR06', 'VERIFY', '', '', 'IN', 'VERIFY', 'REVENUE', 'CONFIRM', '结算', 1, '核销（收侧）→ 确认收入 +（5.2-2）', 'CONFIRMED'),
    ('FR07', 'VERIFY', '', '', 'OUT', 'VERIFY', 'ADV_PAYMENT', 'TO_COST', '结算', -1, '核销（付侧）→ 预付 −（5.2-5）', 'CONFIRMED'),
    ('FR08', 'VERIFY', '', '', 'OUT', 'VERIFY', 'COST', 'CONFIRM', '结算', 1, '核销（付侧）→ 确认成本 +（5.2-5）', 'CONFIRMED'),
    ('FR09', 'PAY_SETTLE', '', '', 'IN', '', 'ADV_RECEIPT', 'TO_REVENUE', '结算', -1, '支付即结算：收款同时转实收，同一行收 +、转 −（5.8）', 'PENDING'),
    ('FR10', 'PAY_SETTLE', '', '', 'IN', '', 'REVENUE', 'CONFIRM', '结算', 1, '支付即结算：下单时确认收入（5.8）', 'PENDING'),
    ('FR11', 'PAY_SETTLE', '', '', 'OUT', '', 'ADV_PAYMENT', 'TO_COST', '结算', -1, '支付即结算：成本随收入同时确认（配比）', 'PENDING'),
    ('FR12', 'PAY_SETTLE', '', '', 'OUT', '', 'COST', 'CONFIRM', '结算', 1, '支付即结算：成本随收入同时确认（配比）', 'PENDING'),
    ('FR31', 'FUND_FLOW', 'FREEZE', '', '', '', 'NONE', 'OUT', '冻结', 0, '冻结：不进表（5.2-11）', 'CONFIRMED'),
    ('FR32', 'FUND_FLOW', 'UNFREEZE', '', '', 'REFUND', 'NONE', 'IN', '解冻', 0, '解冻（退款释放）：不进表（5.2-12）', 'CONFIRMED'),
    ('FR33', 'FUND_FLOW', 'UNFREEZE', '', 'IN', 'VERIFY', 'BALANCE', 'IN', '结算', 1, '解冻（核销触发，界面叫「结算」）：本方份额转入可用余额 → 余额流入（3.6、5.8）', 'CONFIRMED'),
    ('FR34', 'FUND_FLOW', 'RECHARGE', '', 'IN', '', 'BALANCE', 'IN', '充值/扣款', 1, '充值：仅余额 +（5.2-9）', 'CONFIRMED'),
    ('FR35', 'FUND_FLOW', 'RECHARGE', '', 'OUT', '', 'BALANCE', 'OUT', '充值/扣款', -1, '扣款：仅余额 −（5.4）', 'CONFIRMED'),
    ('FR36', 'FUND_FLOW', 'WITHDRAW', '', 'OUT', '', 'BALANCE', 'OUT', '提现', -1, '提现：仅余额 −（5.2-10）', 'CONFIRMED'),
    ('FR37', 'FUND_FLOW', 'FEE', '', 'OUT', '', 'EXPENSE', 'EXPENSE', '手续费', -1, '平台服务费 / 手续费：费用收支 · 支出（5.2-8）', 'CONFIRMED'),
    ('FR38', 'FUND_FLOW', 'FEE', '', 'IN', '', 'EXPENSE', 'INCOME', '手续费', 1, '手续费退回：费用收支 · 收入', 'PENDING'),
    ('FR39', 'FUND_FLOW', 'RESOURCE', '', 'OUT', '', 'EXPENSE', 'EXPENSE', '应用套餐购买', -1, '应用套餐购买：费用收支 · 支出，同时计入余额流出（5.2-7、5.4）', 'CONFIRMED'),
    ('FR40', 'FUND_FLOW', 'PAYMENT', '', '', '', 'NONE', '', '付款', 0, '下单收款：订单报表取支付记录；核销即结算订单的收款与冻结 / 采购划付在可用余额上相抵，不进余额（支付即结算订单待结算时点字段补齐后改 BALANCE）', 'PENDING'),
    ('FR41', 'FUND_FLOW', 'REFUND', '', '', '', 'NONE', '', '退款', 0, '订单退款：与退款释放、上级退回在可用余额上相抵，不进余额', 'PENDING'),
    ('FR42', 'FUND_FLOW', 'TRANSFER_OUT', '', '', '', 'NONE', '', '付款', 0, '采购划付（下单时从本单收款中划出）：与收款相抵，不进余额；需求未定义此流水类型', 'PENDING'),
    ('FR43', 'FUND_FLOW', 'TRANSFER_IN', '', '', '', 'NONE', '', '付款', 0, '采购划入：同上；业务库注释未列此值，以实际数据为准', 'PENDING'),
]


def rule_rows():
    return ',\n        '.join("('" + "', '".join(str(x) for x in r[:9]) + f"', {r[9]}, '{r[10]}', '{r[11]}')" for r in RULES)


# ---------------------------------------------------------------- 加工逻辑
P = "travel_date = '${bizdate}'"
Y = "DATE_FORMAT(DATE_SUB(TO_DATE('${bizdate}', 'yyyyMMdd'), 1), 'yyyyMMdd')"
WIN = "travel_date >= DATE_FORMAT(DATE_SUB(TO_DATE('${bizdate}', 'yyyyMMdd'), 400), 'yyyyMMdd')"


def hdr(name, cn, why, perf):
    L = ['-- ' + '=' * 96, f'-- {name}  {cn}', f'-- 依据：{SRC_DOC}', '-- 业务规则：'] + [f'--   · {x}' for x in why] + ['-- 性能：'] + [f'--   · {x}' for x in perf] + ['-- ' + '=' * 96]
    return '\n'.join(L) + '\n'


ETL = {}
ETL['dim_fin_report_rule_f'] = ('hive', hdr('dim.dim_fin_report_rule_f', '财务报表归属规则',
    ['规则表人工维护，改归属只改这里，不发版（7.4）', '资金流水未命中规则的进「待归类」，不得默认归类（5.5）', '同一费用项在不同方向下归入不同的表，方向是判定的必要条件（5.4）',
     'confirm_status=PENDING 的规则依赖研发确认：结算时点字段、采购划付（TRANSFER_OUT/IN）'], ['码表，几十行，下游 BROADCAST']) + f"""
INSERT OVERWRITE TABLE dim.dim_fin_report_rule_f
SELECT rule_code, source_type, flow_type, fee_item_code, direction_type, frozen_event_type, report_code, measure_code, fee_type_name, sign_qty, rule_desc, confirm_status,
       {NOW} AS etl_time
FROM VALUES
        {rule_rows()}
    AS v(rule_code, source_type, flow_type, fee_item_code, direction_type, frozen_event_type, report_code, measure_code, fee_type_name, sign_qty, rule_desc, confirm_status);
""")
ETL['dim_fin_settle_timing_df'] = ('hive', hdr('dim.dim_fin_settle_timing_df', '结算时点配置',
    ['结算时点配在支付方式上，由商户配置决定，不预设映射（5.8）', '业务库暂无该字段：补齐前全部取 VERIFY（核销即结算）'], ['全量小表']) + f"""
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


def fact_sql(dialect):
    """订单资金事实：离线（Spark）与实时（StarRocks 物化视图）同一套逻辑；实时用今天的实时明细 + Hive 外表里的历史支付与订单维度"""
    hive = dialect == 'hive'
    hv = '' if hive else 'hive_catalog.'
    pay_src = (f"(SELECT * FROM dwd.dwd_fin_payment_di WHERE {WIN})" if hive else
               "(SELECT * FROM hive_catalog.dwd.dwd_fin_payment_di WHERE travel_date >= DATE_FORMAT(DATE_SUB(CURDATE(), INTERVAL 400 DAY), '%Y%m%d')\n"
               "           UNION ALL SELECT * FROM dwd.dwd_fin_payment_rt WHERE travel_date = DATE_FORMAT(CURDATE(), '%Y%m%d'))")
    win = WIN if hive else "travel_date >= DATE_FORMAT(DATE_SUB(CURDATE(), INTERVAL 400 DAY), '%Y%m%d')"
    today = f"'${{bizdate}}'" if hive else "DATE_FORMAT(CURDATE(), '%Y%m%d')"
    day = (lambda c: f"DATE_FORMAT({c}, 'yyyyMMdd')") if hive else (lambda c: f"DATE_FORMAT({c}, '%Y%m%d')")
    refund_src = f"dwd.dwd_fin_refund_payment_di WHERE {P}" if hive else "dwd.dwd_fin_refund_payment_rt WHERE travel_date = DATE_FORMAT(CURDATE(), '%Y%m%d')"
    frozen_src = f"dwd.dwd_fin_frozen_di WHERE {P}" if hive else "dwd.dwd_fin_frozen_rt WHERE travel_date = DATE_FORMAT(CURDATE(), '%Y%m%d')"
    settle_src = f"dim.dim_fin_settle_timing_df WHERE {P}" if hive else "hive_catalog.dim.dim_fin_settle_timing_df WHERE travel_date = DATE_FORMAT(DATE_SUB(CURDATE(), INTERVAL 1 DAY), '%Y%m%d')"
    tk_src = (f"dwd.dwd_ord_ticket_di WHERE {WIN}" if hive else f"hive_catalog.dwd.dwd_ord_ticket_di WHERE {win}")
    og_src = (f"dwd.dwd_ord_order_group_di WHERE {WIN}" if hive else f"hive_catalog.dwd.dwd_ord_order_group_di WHERE {win}")
    rt_src = (f"dwd.dwd_ord_refund_ticket_di WHERE {WIN}" if hive else f"hive_catalog.dwd.dwd_ord_refund_ticket_di WHERE {win}")
    rule = 'dim.dim_fin_report_rule_f' if hive else 'hive_catalog.dim.dim_fin_report_rule_f'
    head = (f"INSERT OVERWRITE TABLE dwd.dwd_fin_merchant_order_fund_di PARTITION (travel_date = '${{bizdate}}')\nSELECT /*+ BROADCAST(rl) */" if hive else
            "CREATE MATERIALIZED VIEW IF NOT EXISTS dwd.dwd_fin_merchant_order_fund_rt\nREFRESH ASYNC EVERY (INTERVAL 1 MINUTE)\nAS\n{WITH}\nSELECT\n    DATE_FORMAT(CURDATE(), '%Y%m%d') AS travel_date,")
    side_pairs = ("SELECT 'IN' AS side UNION ALL SELECT 'OUT'")
    body = f"""WITH tk AS (   -- 票：聚合单内按单价占比（全 0 元时均分），用于把按聚合单的支付分摊到票
    SELECT ticket_no, order_no, order_group_no, spu_id, sku_id,
           COALESCE(unit_price_amt / NULLIF(SUM(unit_price_amt) OVER (PARTITION BY order_group_no), 0),
                    1.0 / COUNT(*) OVER (PARTITION BY order_group_no))  AS w
    FROM {tk_src}
),
pay AS (   -- 支付记录落到票（近 400 天：退款 / 核销要回找原支付）
    SELECT p.payment_no, p.order_group_no, COALESCE(NULLIF(p.ticket_no, ''), t.ticket_no) AS ticket_no, p.pay_direction_type, p.pay_method_type,
           CAST(p.pay_amt * IF(p.ticket_no = '', t.w, 1) AS DECIMAL(18,2)) AS amt,
           p.pay_time, p.payee_tenant_id, p.payer_tenant_id
    FROM {pay_src} p
    LEFT JOIN tk t ON p.ticket_no = '' AND t.order_group_no = p.order_group_no
    WHERE p.pay_status IN ('PAID', 'PARTIAL_REFUNDED', 'REFUNDED')
),
side AS (   -- (本方商户, 票) → 收侧 / 付侧支付信息（需求 4.4：三对收付维度分开取）
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
dims AS (   -- 订单维度：产品 / 票种取票，下单渠道 / 售票员取聚合单
    SELECT s.*, t.order_no, t.spu_id, t.sku_id, g.channel_type,
           IF(g.operator_type = 'TENANT_STAFF', g.operator_id, NULL)   AS seller_staff_id,
           CAST(NULL AS STRING)                                         AS sale_point_code,   /* 源端缺口：业务库订单无售票站点 */
           IF(s.out_payment_no IS NULL, 'SELF', 'SUPPLIER')             AS payee_type,
           COALESCE(st.settle_timing_type, 'VERIFY')                    AS settle_timing_type
    FROM side s
    LEFT JOIN tk t ON t.ticket_no = s.ticket_no
    LEFT JOIN (SELECT order_group_no, MAX(channel_type) AS channel_type, MAX(operator_type) AS operator_type, MAX(operator_id) AS operator_id
               FROM {og_src} GROUP BY order_group_no) g ON g.order_group_no = s.order_group_no
    LEFT JOIN (SELECT tenant_id, pay_method_type, settle_timing_type FROM {settle_src}) st
           ON st.tenant_id = s.merchant_tenant_id AND st.pay_method_type = s.receive_pay_method_type
),
ref AS (   -- 当日成功的退款明细落到票：按退款单票金额占比分摊；售后补偿不纳入（需求第十章 4）
    SELECT r.refund_detail_no, r.finish_time, p.ticket_no, p.pay_direction_type, p.payee_tenant_id, p.payer_tenant_id,
           CAST(r.refund_amt * COALESCE(rt.refund_amt / NULLIF(SUM(rt.refund_amt) OVER (PARTITION BY r.refund_detail_no), 0),
                                        1.0 / COUNT(*) OVER (PARTITION BY r.refund_detail_no)) AS DECIMAL(18,2)) AS amt
    FROM (SELECT refund_detail_no, refund_no, payment_no, refund_amt, finish_time FROM {refund_src} AND refund_detail_status = 'SUCCESS') r
    JOIN (SELECT refund_no, ticket_no, MAX(refund_amt) AS refund_amt FROM {rt_src} AND refund_type = 'ORDER_REFUND' GROUP BY refund_no, ticket_no) rt
      ON rt.refund_no = r.refund_no
    JOIN pay p ON p.payment_no = r.payment_no AND p.ticket_no = rt.ticket_no
),
ev AS (   -- 当日资金动作（本方视角）：side IN = 收侧，OUT = 付侧
    SELECT 'PAYMENT' AS source_type, payment_no AS source_no, payee_tenant_id AS merchant_tenant_id, ticket_no, 'IN' AS side, amt, pay_time AS event_time
    FROM pay WHERE {day('pay_time')} = {today}
    UNION ALL
    SELECT 'PAYMENT', payment_no, payer_tenant_id, ticket_no, 'OUT', amt, pay_time
    FROM pay WHERE pay_direction_type = 'OUTBOUND' AND {day('pay_time')} = {today}
    UNION ALL   -- 退款上下游成对冲减（5.2 退款联动）
    SELECT 'REFUND', refund_detail_no, payee_tenant_id, ticket_no, 'IN', amt, finish_time FROM ref
    UNION ALL
    SELECT 'REFUND', refund_detail_no, payer_tenant_id, ticket_no, 'OUT', amt, finish_time FROM ref WHERE pay_direction_type = 'OUTBOUND'
),
verify AS (   -- 核销：票的冻结记录当日因核销解冻（同票多账户取最早）
    SELECT ticket_no, MIN(release_time) AS release_time, MIN(frozen_no) AS frozen_no
    FROM {frozen_src} AND frozen_status = 'RELEASED' AND release_event_type = 'VERIFY'
    GROUP BY ticket_no
),
rows_ AS (
    SELECT source_type, source_no, merchant_tenant_id, ticket_no, side, amt, event_time FROM ev
    UNION ALL   -- 核销即结算：核销时转实收 / 转实付并确认（收侧按卖出单价、付侧按买入单价）
    SELECT 'VERIFY', v.frozen_no, d.merchant_tenant_id, d.ticket_no, s.side, IF(s.side = 'IN', d.sale_unit_price_amt, d.buy_unit_price_amt), v.release_time
    FROM verify v
    JOIN dims d ON d.ticket_no = v.ticket_no AND d.settle_timing_type = 'VERIFY'
    CROSS JOIN ({side_pairs}) s
    WHERE IF(s.side = 'IN', d.in_payment_no, d.out_payment_no) IS NOT NULL
    UNION ALL   -- 支付即结算：收款当日同时转实收并确认（同一行收 +、转 −，5.8）
    SELECT 'PAY_SETTLE', p.source_no, d.merchant_tenant_id, d.ticket_no, s.side, IF(s.side = 'IN', d.sale_unit_price_amt, d.buy_unit_price_amt), p.event_time
    FROM (SELECT source_no, merchant_tenant_id, ticket_no, event_time FROM ev WHERE source_type = 'PAYMENT' AND side = 'IN') p
    JOIN dims d ON d.merchant_tenant_id = p.merchant_tenant_id AND d.ticket_no = p.ticket_no AND d.settle_timing_type = 'PAY'
    CROSS JOIN ({side_pairs}) s
    WHERE IF(s.side = 'IN', d.in_payment_no, d.out_payment_no) IS NOT NULL
)"""
    sel = f"""
    CONCAT_WS(':', r.source_no, r.ticket_no, CAST(r.merchant_tenant_id AS STRING), rl.report_code, rl.measure_code) AS fund_event_id,
    r.event_time,
    r.merchant_tenant_id,
    rl.report_code,
    rl.measure_code,
    rl.fee_type_name,
    r.amt                                                            AS event_amt,
    r.amt * rl.sign_qty                                              AS balance_effect_amt,
    IF(rl.measure_code IN ('RECEIVE', 'PAY'), 1, IF(rl.measure_code IN ('REFUND', 'RETURN'), -1, 0)) AS ticket_net_qty,
    IF(rl.measure_code = 'CONFIRM', 1, 0)                            AS confirm_ticket_qty,
    r.source_type,
    r.source_no,
    IF(r.side = 'IN', d.in_payment_no, d.out_payment_no)             AS payment_no,
    d.order_group_no,
    d.order_no,
    r.ticket_no,
    d.spu_id, d.sku_id, d.channel_type, d.seller_staff_id, d.sale_point_code,
    COALESCE(d.payer_tenant_id, 0)                                   AS payer_tenant_id,
    d.payer_type,
    COALESCE(d.payee_tenant_id, 0)                                   AS payee_tenant_id,
    d.payee_type,
    d.sale_unit_price_amt,
    d.buy_unit_price_amt,
    d.receive_pay_method_type,
    d.pay_pay_method_type,
    d.settle_timing_type{',' if hive else ''}
    {NOW + ' AS etl_time' if hive else ''}
FROM rows_ r
JOIN dims d ON d.merchant_tenant_id = r.merchant_tenant_id AND d.ticket_no = r.ticket_no
JOIN (SELECT * FROM {rule} WHERE source_type IN ('PAYMENT', 'REFUND', 'VERIFY', 'PAY_SETTLE')) rl
  ON rl.source_type = r.source_type AND rl.direction_type = r.side;
"""
    if hive:
        return body + '\n' + head + sel
    return head.replace('{WITH}', body) + sel.replace('\n    CONCAT_WS', '\n    CONCAT_WS', 1)


ETL['dwd_fin_merchant_order_fund_di'] = ('hive', hdr('dwd.dwd_fin_merchant_order_fund_di', '商户订单资金明细（订单报表事实）',
    ['取数来源：支付记录（收 / 付）、退款明细（退 / 退回）、冻结记录核销解冻（结算）——授信订单不产生资金流水，按需求 3.1「下单即计入预收」须以支付记录为准；维度来自订单（原则 3）',
     '一笔支付记录拆成两侧：收款方记「收」，采购付款方记「付」；只取本方商户侧（第十章 2）',
     '金额 = 支付记录 amount（这笔记录实际转移的钱）；支付挂聚合单时按票单价占比分摊到票（第十章 3：按产品拆分须从订单侧取）',
     '退款：只取订单退款（售后补偿本期不纳入），上下游成对冲减；核销：转实收 / 转实付 并确认收入 / 成本；支付即结算：收款当日同时结转',
     '费用类型：付款 / 退款 / 结算（界面不出现「解冻」）；票数：售票记正、退款记负、核销不改变票数，核销票数单列'],
    ['票维度与两侧支付信息先按 (商户, 票) 汇成一行，各类动作只关联一次', '支付 / 票只扫近 400 天分区（票有效期上限）', '归属规则为小表 BROADCAST']) + fact_sql('hive'))
ETL['dwd_fin_merchant_order_fund_rt'] = ('starrocks', hdr('dwd.dwd_fin_merchant_order_fund_rt', '实时商户订单资金明细',
    ['与离线 dwd_fin_merchant_order_fund_di 同一套逻辑（7.3：明细与汇总同规则），只处理今天的支付 / 退款 / 核销', '历史支付、票、聚合单、归属规则、结算时点通过 Hive 外表（hive_catalog）读取'],
    ['StarRocks 异步物化视图，1 分钟刷新；按 travel_date 分区，只刷新今天分区']) + fact_sql('starrocks'))

ETL['dwd_fin_balance_detail_di'] = ('hive', hdr('dwd.dwd_fin_balance_detail_di', '商户余额明细（余额报表事实）',
    ['只取商户 / 分销商账户（平台账户不算），双式记账只算本方这一条（第十章 2）',
     '归属按规则表：命中多条取最具体（带冻结事件 > 带方向 > 带费用项）；都不命中 = UNCLASSIFIED（5.5）',
     '解冻流水分核销 / 退款：关联同账户同票（或同冻结单）的冻结记录（关联键待研发确认）',
     '对方商户：订单类按支付批次号关联支付记录的另一侧（流入取付款方、支出取收款方，散客为 0）；充值 / 提现为银行；费用为平台',
     '余额列取流水本身的变动后余额（快照值），不由前几笔累加（5.7）'],
    ['规则表 BROADCAST；支付记录只取近 400 天、按（批次, 账户）预聚合']) + f"""
WITH f AS (
    SELECT /*+ BROADCAST(a) */ f.flow_no, f.flow_time, f.account_no, a.subject_id AS merchant_tenant_id, a.account_type, f.flow_type, f.fee_item_code,
           f.change_amt, f.balance_before_amt, f.balance_after_amt, f.related_no, f.payment_batch_no,
           IF(f.change_amt >= 0, 'IN', 'OUT') AS direction_type
    FROM dwd.dwd_fin_fund_flow_di f
    JOIN (SELECT account_no, subject_id, account_type FROM dim.dim_fin_account_df WHERE {P} AND account_type IN ('MERCHANT', 'DISTRIBUTOR')) a ON a.account_no = f.account_no
    WHERE f.{P}
),
fe AS (   -- 当日释放的冻结记录：解冻流水的冻结事件
    SELECT account_no, frozen_no, ticket_no, release_event_type FROM dwd.dwd_fin_frozen_di WHERE {P} AND frozen_status = 'RELEASED'
),
m AS (
    SELECT f.*, COALESCE(e1.release_event_type, e2.release_event_type) AS frozen_event_type
    FROM f
    LEFT JOIN fe e1 ON f.flow_type = 'UNFREEZE' AND e1.account_no = f.account_no AND e1.frozen_no = f.related_no
    LEFT JOIN fe e2 ON f.flow_type = 'UNFREEZE' AND e1.frozen_no IS NULL AND e2.account_no = f.account_no AND e2.ticket_no = f.related_no
),
hit AS (   -- 规则匹配：取最具体的一条
    SELECT * FROM (
        SELECT m.flow_no, r.report_code, r.fee_type_name,
               ROW_NUMBER() OVER (PARTITION BY m.flow_no ORDER BY (r.frozen_event_type <> '') DESC, (r.direction_type <> '') DESC, (r.fee_item_code <> '') DESC) AS rn
        FROM m
        JOIN (SELECT * FROM dim.dim_fin_report_rule_f WHERE source_type = 'FUND_FLOW') r
          ON r.flow_type = m.flow_type AND (r.fee_item_code = '' OR r.fee_item_code = m.fee_item_code)
         AND (r.direction_type = '' OR r.direction_type = m.direction_type) AND (r.frozen_event_type = '' OR r.frozen_event_type = COALESCE(m.frozen_event_type, ''))
    ) z WHERE rn = 1
),
pin AS (   -- 流入：本方为收款方的支付记录 → 对方 = 付款方
    SELECT batch_no, payee_account_no AS account_no, MAX(payer_tenant_id) AS cp_id, MAX(pay_direction_type) AS dir, MAX(order_group_no) AS order_group_no
    FROM dwd.dwd_fin_payment_di WHERE {WIN} GROUP BY batch_no, payee_account_no
),
pout AS (  -- 支出：本方为付款方的支付记录 → 对方 = 收款方
    SELECT batch_no, payer_account_no AS account_no, MAX(payee_tenant_id) AS cp_id, MAX(order_group_no) AS order_group_no
    FROM dwd.dwd_fin_payment_di WHERE {WIN} GROUP BY batch_no, payer_account_no
)
INSERT OVERWRITE TABLE dwd.dwd_fin_balance_detail_di PARTITION (travel_date = '${{bizdate}}')
SELECT /*+ BROADCAST(h) */
    m.flow_no,
    m.flow_time,
    m.merchant_tenant_id,
    m.account_no,
    m.account_type,
    m.flow_type,
    COALESCE(m.fee_item_code, '')                                    AS fee_item_code,
    m.frozen_event_type,
    COALESCE(h.report_code, 'UNCLASSIFIED')                          AS report_code,
    COALESCE(h.fee_type_name, m.flow_type)                           AS fee_type_name,
    IF(m.change_amt >= 0, '流入', '支出')                             AS direction_name,
    m.change_amt,
    IF(h.report_code IN ('BALANCE', 'EXPENSE') AND m.change_amt > 0, m.change_amt, 0)   AS balance_in_amt,
    IF(h.report_code IN ('BALANCE', 'EXPENSE') AND m.change_amt < 0, -m.change_amt, 0)  AS balance_out_amt,
    m.balance_before_amt,
    m.balance_after_amt,
    CASE WHEN m.flow_type IN ('RECHARGE', 'WITHDRAW', 'FEE', 'RESOURCE', 'FREEZE', 'UNFREEZE') THEN 0
         WHEN m.direction_type = 'IN' THEN COALESCE(pi.cp_id, 0) ELSE COALESCE(po.cp_id, 0) END              AS counterparty_tenant_id,
    CASE WHEN m.flow_type IN ('RECHARGE', 'WITHDRAW') THEN 'BANK'
         WHEN m.flow_type IN ('FEE', 'RESOURCE') THEN 'PLATFORM'
         WHEN m.flow_type IN ('FREEZE', 'UNFREEZE') THEN 'SELF'
         WHEN m.direction_type = 'IN' THEN IF(pi.dir = 'INBOUND', 'CUSTOMER', 'DISTRIBUTOR')
         ELSE 'SUPPLIER' END                                                                                    AS counterparty_type,
    COALESCE(pi.order_group_no, po.order_group_no)                   AS biz_order_no,
    m.related_no,
    m.payment_batch_no,
    {NOW} AS etl_time
FROM m
LEFT JOIN hit h ON h.flow_no = m.flow_no
LEFT JOIN pin pi ON m.direction_type = 'IN' AND pi.batch_no = m.payment_batch_no AND pi.account_no = m.account_no
LEFT JOIN pout po ON m.direction_type = 'OUT' AND po.batch_no = m.payment_batch_no AND po.account_no = m.account_no;
""")
ETL['dwd_fin_balance_detail_rt'] = ('flink', hdr('dwd.dwd_fin_balance_detail_rt', '实时商户余额明细',
    ['与离线 dwd_fin_balance_detail_di 同口径同字段；只处理新增流水（流水不可变）', '归属规则、账户、冻结记录、支付记录 lookup（缓存 10 分钟）；规则命中多条时按具体程度取第一条'],
    ['lookup join，StarRocks 主键模型表；保留全部历史分区（余额报表始终实时）']) + """
INSERT INTO sr_dwd_fin_balance_detail_rt
SELECT
    DATE_FORMAT(f.create_time, 'yyyyMMdd')                           AS travel_date,
    f.flow_no,
    CAST(f.create_time AS STRING)                                    AS flow_time,
    a.subject_id                                                     AS merchant_tenant_id,
    f.account_no,
    a.account_type,
    f.flow_type,
    COALESCE(f.fee_item, '')                                         AS fee_item_code,
    fz.release_event_type                                            AS frozen_event_type,
    COALESCE(r.report_code, 'UNCLASSIFIED')                          AS report_code,
    COALESCE(r.fee_type_name, f.flow_type)                           AS fee_type_name,
    IF(f.amount >= 0, '流入', '支出')                                 AS direction_name,
    CAST(f.amount AS DECIMAL(18,2)) / 100                            AS change_amt,
    IF(r.report_code IN ('BALANCE', 'EXPENSE') AND f.amount > 0, CAST(f.amount AS DECIMAL(18,2)) / 100, 0)  AS balance_in_amt,
    IF(r.report_code IN ('BALANCE', 'EXPENSE') AND f.amount < 0, -CAST(f.amount AS DECIMAL(18,2)) / 100, 0) AS balance_out_amt,
    CAST(f.balance_before AS DECIMAL(18,2)) / 100                    AS balance_before_amt,
    CAST(f.balance_after AS DECIMAL(18,2)) / 100                     AS balance_after_amt,
    CASE WHEN f.flow_type IN ('RECHARGE', 'WITHDRAW', 'FEE', 'RESOURCE', 'FREEZE', 'UNFREEZE') THEN 0
         WHEN f.amount >= 0 THEN COALESCE(pi.payer_tenant_id, 0) ELSE COALESCE(po.payee_tenant_id, 0) END AS counterparty_tenant_id,
    CASE WHEN f.flow_type IN ('RECHARGE', 'WITHDRAW') THEN 'BANK' WHEN f.flow_type IN ('FEE', 'RESOURCE') THEN 'PLATFORM'
         WHEN f.flow_type IN ('FREEZE', 'UNFREEZE') THEN 'SELF'
         WHEN f.amount >= 0 THEN IF(pi.pay_direction_type = 'INBOUND', 'CUSTOMER', 'DISTRIBUTOR') ELSE 'SUPPLIER' END AS counterparty_type,
    COALESCE(pi.order_group_no, po.order_group_no)                   AS biz_order_no,
    f.related_no,
    f.payment_batch_no,
    f.proc_time                                                      AS event_time
FROM ods_fin_fund_flow_rt f
JOIN dim_fin_account_lookup FOR SYSTEM_TIME AS OF f.proc_time AS a   -- 关联账户维度（维表查找），只保留商户 / 分销商账户
  ON a.account_no = f.account_no AND a.account_type IN ('MERCHANT', 'DISTRIBUTOR')
LEFT JOIN dwd_fin_frozen_rt_lookup FOR SYSTEM_TIME AS OF f.proc_time AS fz   -- 解冻流水关联冻结记录，取冻结原因（核销 / 退款）
  ON f.flow_type = 'UNFREEZE' AND fz.account_no = f.account_no AND fz.frozen_no = f.related_no
LEFT JOIN dim_fin_report_rule_first_lookup FOR SYSTEM_TIME AS OF f.proc_time AS r   -- 规则视图：每个（流水类型, 方向, 冻结事件）已按具体程度取第一条
  ON r.flow_type = f.flow_type AND r.direction_type = IF(f.amount >= 0, 'IN', 'OUT') AND r.frozen_event_type = COALESCE(fz.release_event_type, '')
LEFT JOIN dwd_fin_payment_rt_lookup FOR SYSTEM_TIME AS OF f.proc_time AS pi   -- 入账流水关联支付单，取付款方（交易对手）
  ON f.amount >= 0 AND pi.batch_no = f.payment_batch_no AND pi.payee_account_no = f.account_no
LEFT JOIN dwd_fin_payment_rt_lookup FOR SYSTEM_TIME AS OF f.proc_time AS po   -- 出账流水关联支付单，取收款方（交易对手）
  ON f.amount < 0 AND po.batch_no = f.payment_batch_no AND po.payer_account_no = f.account_no
WHERE f.op_type = 'I';
""")
ETL['dwd_fin_refund_payment_rt'] = ('flink', hdr('dwd.dwd_fin_refund_payment_rt', '实时退款明细（按支付记录）',
    ['与离线 dwd_fin_refund_payment_di 同字段；finish_time = 明细状态变为 SUCCESS 的 binlog 时间', '聚合单号 / 支付方式 / 方向按支付记录号 lookup'], ['CDC 变更流，按退款明细号 upsert']) + """
INSERT INTO sr_dwd_fin_refund_payment_rt
SELECT
    DATE_FORMAT(d.create_time, 'yyyyMMdd')                           AS travel_date,
    d.id                                                             AS refund_detail_id,
    d.refund_detail_no, d.refund_no, d.payment_no,
    CAST(d.refund_amount AS DECIMAL(18,2)) / 100                     AS refund_amt,
    d.refund_channel                                                 AS refund_channel_type,
    d.refund_transaction_no,
    d.refund_detail_status,
    d.tenant_id,
    CAST(d.create_time AS STRING)                                    AS create_time,
    CAST(d.update_time AS STRING)                                    AS update_time,
    p.order_group_no,
    p.pay_method_type,
    p.pay_direction_type,
    IF(d.refund_detail_status = 'SUCCESS', CAST(d.binlog_time AS STRING), CAST(NULL AS STRING)) AS finish_time,
    d.proc_time                                                      AS event_time
FROM ods_ord_refund_detail_rt d
LEFT JOIN dwd_fin_payment_rt_lookup FOR SYSTEM_TIME AS OF d.proc_time AS p ON p.payment_no = d.payment_no;
""")

ETL['dws_fin_merchant_unsettled_df'] = ('hive', hdr('dws.dws_fin_merchant_unsettled_df', '预收预付在途快照',
    ['在途 = T-1 快照 + 当日预收 / 预付的余额影响（收 / 付 +，退 / 退回 / 转实收 / 转实付 −）；归零的票不再保留',
     '期初 = 区间首日前一天快照，期末 = 区间末日快照（5.7）；按票保留全部订单维度，因此按任意维度拆分都成立'],
    ['只读 T-1 一个分区 + 当日明细一个分区，不回扫历史流水']) + f"""
WITH today AS (
    SELECT merchant_tenant_id, report_code, ticket_no, MAX(order_no) AS order_no,
           {', '.join(f'MAX({d}) AS {d}' for d in DIMS)},
           SUM(balance_effect_amt) AS chg_amt, SUM(ticket_net_qty) AS chg_qty
    FROM dwd.dwd_fin_merchant_order_fund_di
    WHERE {P} AND report_code IN ('ADV_RECEIPT', 'ADV_PAYMENT')
    GROUP BY merchant_tenant_id, report_code, ticket_no
),
prev AS (
    SELECT * FROM dws.dws_fin_merchant_unsettled_df WHERE travel_date = {Y}
)
INSERT OVERWRITE TABLE dws.dws_fin_merchant_unsettled_df PARTITION (travel_date = '${{bizdate}}')
SELECT
    COALESCE(n.merchant_tenant_id, p.merchant_tenant_id)            AS merchant_tenant_id,
    COALESCE(n.report_code, p.report_code)                          AS report_code,
    COALESCE(n.ticket_no, p.ticket_no)                              AS ticket_no,
    COALESCE(p.order_no, n.order_no)                                AS order_no,
    {(','+chr(10)+'    ').join(f'COALESCE(p.{d}, n.{d}) AS {d}' for d in DIMS)},
    COALESCE(p.unsettled_amt, 0) + COALESCE(n.chg_amt, 0)           AS unsettled_amt,
    COALESCE(p.unsettled_ticket_qty, 0) + COALESCE(n.chg_qty, 0)    AS unsettled_ticket_qty,
    COALESCE(p.first_event_date, '${{bizdate}}')                     AS first_event_date,
    {NOW} AS etl_time
FROM today n
FULL OUTER JOIN prev p ON p.merchant_tenant_id = n.merchant_tenant_id AND p.report_code = n.report_code AND p.ticket_no = n.ticket_no
WHERE ROUND(COALESCE(p.unsettled_amt, 0) + COALESCE(n.chg_amt, 0), 2) <> 0;
""")
ETL['dws_fin_merchant_order_fund_di'] = ('hive', hdr('dws.dws_fin_merchant_order_fund_di', '商户订单资金日汇总',
    ['期间值（5.7）：本期收 / 退 / 转实收、本期付 / 退回 / 转实付、履约收入、成本结算，及各口径票数', '粒度 = 全部订单维度；维度无值保持为空（界面显示「—」，4.5）'],
    ['一次扫描当日明细，条件聚合出全部列']) + f"""
INSERT OVERWRITE TABLE dws.dws_fin_merchant_order_fund_di PARTITION (travel_date = '${{bizdate}}')
SELECT
    merchant_tenant_id, {', '.join(DIMS)},
    {(','+chr(10)+'    ').join(f"SUM(IF(report_code = '{r}' AND measure_code = '{c}', event_amt, 0)) AS {m}_amt" for m, r, c, *_ in MEAS)},
    {(','+chr(10)+'    ').join(f"SUM(IF({w}, {e}, 0)) AS {q}" for q, cn, kou, w, e in QTYS)},
    {NOW} AS etl_time
FROM dwd.dwd_fin_merchant_order_fund_di
WHERE {P}
GROUP BY merchant_tenant_id, {', '.join(DIMS)};
""")
ETL['dws_fin_merchant_balance_di'] = ('hive', hdr('dws.dws_fin_merchant_balance_di', '商户余额与费用日汇总',
    ['按余额明细汇总：流入 / 流出、笔数；归属与费用类型沿用明细'], ['单表扫描当日分区']) + f"""
INSERT OVERWRITE TABLE dws.dws_fin_merchant_balance_di PARTITION (travel_date = '${{bizdate}}')
SELECT merchant_tenant_id, account_no, report_code, fee_type_name, flow_type, fee_item_code,
       SUM(IF(change_amt > 0, change_amt, 0))                        AS fund_in_amt,
       -SUM(IF(change_amt < 0, change_amt, 0))                       AS fund_out_amt,
       COUNT(flow_no)                                                AS fund_flow_qty,
       {NOW} AS etl_time
FROM dwd.dwd_fin_balance_detail_di
WHERE {P}
GROUP BY merchant_tenant_id, account_no, report_code, fee_type_name, flow_type, fee_item_code;
""")

STACK = """STACK(4,
        -- 每行一个报表：报表编码, 发生额收(in), 发生额付(out), 转实收 / 实付(trans), 确认(confirm), 净票数, 确认票数
        'ADV_RECEIPT', receive_amt, refund_amt, to_revenue_amt, z_amt, sale_ticket_qty - refund_ticket_qty, z_qty,
        'ADV_PAYMENT', pay_amt,     return_amt, to_cost_amt,    z_amt, buy_ticket_qty - return_ticket_qty,  z_qty,
        'REVENUE',     z_amt,       z_amt,      z_amt,          revenue_amt, z_qty,                         revenue_ticket_qty,
        'COST',        z_amt,       z_amt,      z_amt,          cost_amt,    z_qty,                         cost_ticket_qty
    ) AS (report_code, in_amt, out_amt, trans_amt, confirm_amt, net_ticket_qty, confirm_ticket_qty)"""
ETL['ads_fin_order_report_dim_di'] = ('hive', hdr('ads.ads_fin_order_report_dim_di', '订单报表多维汇总（日）',
    ['期间值：日汇总按报表展开成通用列（in / out / trans / confirm），一行一个报表 × 维度组合', '日终余额 close_amt：在途快照按维度组合汇总，没有当日发生的组合也保留（期初 / 期末要用）',
     '只保留有发生额或有余额的组合'],
    ['日汇总、快照各扫一个分区，UNION ALL 后按维度汇总']) + f"""
WITH p AS (   -- 期间值：按报表展开
    SELECT merchant_tenant_id, {', '.join(DIMS)},
           {STACK}
    FROM (   -- 该报表不适用的列补 0（STACK 各行类型须一致）
        SELECT *, CAST(0 AS DECIMAL(18,2)) AS z_amt, CAST(0 AS BIGINT) AS z_qty
        FROM dws.dws_fin_merchant_order_fund_di
        WHERE {P}
    ) s
),
c AS (        -- 日终余额：在途快照按维度组合汇总
    SELECT merchant_tenant_id, report_code, {', '.join(DIMS)}, SUM(unsettled_amt) AS close_amt
    FROM dws.dws_fin_merchant_unsettled_df
    WHERE {P}
    GROUP BY merchant_tenant_id, report_code, {', '.join(DIMS)}
),
u AS (
    SELECT merchant_tenant_id, report_code, {', '.join(DIMS)}, in_amt, out_amt, trans_amt, confirm_amt, CAST(0 AS DECIMAL(18,2)) AS close_amt, net_ticket_qty, confirm_ticket_qty FROM p
    UNION ALL
    SELECT merchant_tenant_id, report_code, {', '.join(DIMS)}, 0, 0, 0, 0, close_amt, 0, 0 FROM c
)
INSERT OVERWRITE TABLE ads.ads_fin_order_report_dim_di PARTITION (travel_date = '${{bizdate}}')
SELECT merchant_tenant_id, report_code, {', '.join(DIMS)},
       SUM(in_amt) AS in_amt, SUM(out_amt) AS out_amt, SUM(trans_amt) AS trans_amt, SUM(confirm_amt) AS confirm_amt, SUM(close_amt) AS close_amt,
       SUM(net_ticket_qty) AS net_ticket_qty, SUM(confirm_ticket_qty) AS confirm_ticket_qty,
       {NOW} AS etl_time
FROM u
GROUP BY merchant_tenant_id, report_code, {', '.join(DIMS)}
HAVING SUM(ABS(in_amt)) + SUM(ABS(out_amt)) + SUM(ABS(trans_amt)) + SUM(ABS(confirm_amt)) + ABS(SUM(close_amt)) > 0;
""")
ETL['ads_fin_order_report_dim_rt'] = ('starrocks', hdr('ads.ads_fin_order_report_dim_rt', '订单报表多维汇总（今日实时）',
    ['今日期间值取实时明细；今日日终余额 = 昨日 close_amt（离线定版，同步到 StarRocks）+ 今日余额影响', '与离线同一套通用列，报表服务按日期分段拼接（6.1）'],
    ['StarRocks 异步物化视图，1 分钟刷新']) + f"""
CREATE MATERIALIZED VIEW IF NOT EXISTS ads.ads_fin_order_report_dim_rt
REFRESH ASYNC EVERY (INTERVAL 1 MINUTE)
AS
WITH d AS (
    SELECT merchant_tenant_id, report_code, {', '.join(DIMS)},
           SUM(IF(measure_code IN ('RECEIVE', 'PAY'), event_amt, 0))          AS in_amt,
           SUM(IF(measure_code IN ('REFUND', 'RETURN'), event_amt, 0))        AS out_amt,
           SUM(IF(measure_code IN ('TO_REVENUE', 'TO_COST'), event_amt, 0))   AS trans_amt,
           SUM(IF(measure_code = 'CONFIRM', event_amt, 0))                    AS confirm_amt,
           SUM(IF(report_code IN ('ADV_RECEIPT', 'ADV_PAYMENT'), balance_effect_amt, 0)) AS chg_amt,
           SUM(ticket_net_qty)                                                AS net_ticket_qty,
           SUM(confirm_ticket_qty)                                            AS confirm_ticket_qty
    FROM dwd.dwd_fin_merchant_order_fund_rt
    WHERE travel_date = DATE_FORMAT(CURDATE(), '%Y%m%d')
    GROUP BY merchant_tenant_id, report_code, {', '.join(DIMS)}
),
y AS (
    SELECT merchant_tenant_id, report_code, {', '.join(DIMS)}, close_amt
    FROM ads.ads_fin_order_report_dim_di
    WHERE travel_date = DATE_FORMAT(DATE_SUB(CURDATE(), INTERVAL 1 DAY), '%Y%m%d') AND close_amt <> 0
),
u AS (
    SELECT merchant_tenant_id, report_code, {', '.join(DIMS)}, in_amt, out_amt, trans_amt, confirm_amt, chg_amt AS close_amt, net_ticket_qty, confirm_ticket_qty FROM d
    UNION ALL
    SELECT merchant_tenant_id, report_code, {', '.join(DIMS)}, 0, 0, 0, 0, close_amt, 0, 0 FROM y
)
SELECT DATE_FORMAT(CURDATE(), '%Y%m%d') AS travel_date,
       merchant_tenant_id, report_code, {', '.join(DIMS)},
       SUM(in_amt) AS in_amt, SUM(out_amt) AS out_amt, SUM(trans_amt) AS trans_amt, SUM(confirm_amt) AS confirm_amt, SUM(close_amt) AS close_amt,
       SUM(net_ticket_qty) AS net_ticket_qty, SUM(confirm_ticket_qty) AS confirm_ticket_qty,
       NOW() AS update_time
FROM u
GROUP BY merchant_tenant_id, report_code, {', '.join(DIMS)};
""")
ETL['ads_fin_balance_report_di'] = ('hive', hdr('ads.ads_fin_balance_report_di', '余额报表（日 × 账本）',
    ['期初 / 期末：账户日快照（当日第一笔流水前 / 最后一笔流水后的可用余额；无流水取日终可用余额）', '流入 / 流出只计归属为 仅余额 / 费用收支 的流水；冻结、退款释放、下单收付相抵部分不进（5.2、勾稽第 7 条说明）'],
    ['两个来源都按账户预聚合后关联']) + f"""
WITH b AS (
    SELECT /*+ BROADCAST(a) */ a.subject_id AS merchant_tenant_id, s.account_no,
           COALESCE(s.opening_balance_amt, s.available_balance_amt) AS balance_open_amt,
           COALESCE(s.closing_balance_amt, s.available_balance_amt) AS balance_close_amt
    FROM (SELECT account_no, available_balance_amt, opening_balance_amt, closing_balance_amt FROM dws.dws_fin_account_balance_df WHERE {P}) s
    JOIN (SELECT account_no, subject_id FROM dim.dim_fin_account_df WHERE {P} AND account_type IN ('MERCHANT', 'DISTRIBUTOR')) a ON a.account_no = s.account_no
),
f AS (
    SELECT merchant_tenant_id, account_no,
           SUM(IF(report_code IN ('BALANCE', 'EXPENSE'), fund_in_amt, 0))  AS balance_in_amt,
           SUM(IF(report_code IN ('BALANCE', 'EXPENSE'), fund_out_amt, 0)) AS balance_out_amt,
           SUM(IF(flow_type = 'RECHARGE', fund_in_amt, 0))                 AS recharge_amt,
           SUM(IF(flow_type = 'WITHDRAW', fund_out_amt, 0))                AS withdraw_amt,
           SUM(IF(report_code = 'EXPENSE', fund_in_amt, 0))                AS expense_income_amt,
           SUM(IF(report_code = 'EXPENSE', fund_out_amt, 0))               AS expense_out_amt,
           SUM(IF(report_code = 'UNCLASSIFIED', fund_flow_qty, 0))         AS unclassified_flow_qty
    FROM dws.dws_fin_merchant_balance_di WHERE {P}
    GROUP BY merchant_tenant_id, account_no
)
INSERT OVERWRITE TABLE ads.ads_fin_balance_report_di PARTITION (travel_date = '${{bizdate}}')
SELECT COALESCE(b.merchant_tenant_id, f.merchant_tenant_id) AS merchant_tenant_id, COALESCE(b.account_no, f.account_no) AS account_no,
       b.balance_open_amt, COALESCE(f.balance_in_amt, 0) AS balance_in_amt, COALESCE(f.balance_out_amt, 0) AS balance_out_amt, b.balance_close_amt,
       COALESCE(f.recharge_amt, 0) AS recharge_amt, COALESCE(f.withdraw_amt, 0) AS withdraw_amt,
       COALESCE(f.expense_income_amt, 0) AS expense_income_amt, COALESCE(f.expense_out_amt, 0) AS expense_out_amt,
       COALESCE(f.unclassified_flow_qty, 0) AS unclassified_flow_qty,
       {NOW} AS etl_time
FROM b
FULL OUTER JOIN f ON f.account_no = b.account_no;
""")
ETL['ads_fin_balance_report_rt'] = ('starrocks', hdr('ads.ads_fin_balance_report_rt', '余额报表（实时 · 日 × 账本）',
    ['余额报表始终实时（6.3）：直接由实时余额明细（保留全部历史）按日 × 账本汇总', '期初 = 当日第一笔流水的变动前余额，期末 = 最后一笔的变动后余额（快照值，5.7）'],
    ['StarRocks 异步物化视图，按 travel_date 分区增量刷新']) + """
CREATE MATERIALIZED VIEW IF NOT EXISTS ads.ads_fin_balance_report_rt
PARTITION BY travel_date
REFRESH ASYNC EVERY (INTERVAL 1 MINUTE)
AS
SELECT travel_date, merchant_tenant_id, account_no,
       MIN_BY(balance_before_amt, flow_time)                         AS balance_open_amt,
       SUM(balance_in_amt)                                           AS balance_in_amt,
       SUM(balance_out_amt)                                          AS balance_out_amt,
       MAX_BY(balance_after_amt, flow_time)                          AS balance_close_amt,
       SUM(IF(flow_type = 'RECHARGE' AND change_amt > 0, change_amt, 0))    AS recharge_amt,
       SUM(IF(flow_type = 'WITHDRAW' AND change_amt < 0, -change_amt, 0))   AS withdraw_amt,
       SUM(IF(report_code = 'EXPENSE' AND change_amt > 0, change_amt, 0))   AS expense_income_amt,
       SUM(IF(report_code = 'EXPENSE' AND change_amt < 0, -change_amt, 0))  AS expense_out_amt,
       SUM(IF(report_code = 'UNCLASSIFIED', 1, 0))                   AS unclassified_flow_qty,
       NOW()                                                         AS update_time
FROM dwd.dwd_fin_balance_detail_rt
GROUP BY travel_date, merchant_tenant_id, account_no;
""")


def merchant_sql(src_dim, src_bal, date_expr, rt):
    yday = Y if not rt else "DATE_FORMAT(DATE_SUB(CURDATE(), INTERVAL 1 DAY), '%Y%m%d')"
    o = f"""WITH o AS (
    SELECT merchant_tenant_id,
           SUM(IF(report_code = 'ADV_RECEIPT', close_amt, 0)) AS adv_receipt_close_amt,
           SUM(IF(report_code = 'ADV_RECEIPT', in_amt, 0))    AS adv_receipt_receive_amt,
           SUM(IF(report_code = 'ADV_RECEIPT', out_amt, 0))   AS adv_receipt_refund_amt,
           SUM(IF(report_code = 'ADV_RECEIPT', trans_amt, 0)) AS adv_receipt_to_revenue_amt,
           SUM(IF(report_code = 'ADV_PAYMENT', close_amt, 0)) AS adv_payment_close_amt,
           SUM(IF(report_code = 'ADV_PAYMENT', in_amt, 0))    AS adv_payment_pay_amt,
           SUM(IF(report_code = 'ADV_PAYMENT', out_amt, 0))   AS adv_payment_return_amt,
           SUM(IF(report_code = 'ADV_PAYMENT', trans_amt, 0)) AS adv_payment_to_cost_amt,
           SUM(IF(report_code = 'REVENUE', confirm_amt, 0))   AS revenue_amt,
           SUM(IF(report_code = 'COST', confirm_amt, 0))      AS cost_amt,
           SUM(IF(report_code = 'ADV_RECEIPT', net_ticket_qty, 0)) AS net_ticket_qty
    FROM {src_dim} WHERE travel_date = {date_expr}
    GROUP BY merchant_tenant_id
),
y AS (   -- 期初 = 前一日期末
    SELECT merchant_tenant_id, SUM(IF(report_code = 'ADV_RECEIPT', close_amt, 0)) AS adv_receipt_open_amt,
           SUM(IF(report_code = 'ADV_PAYMENT', close_amt, 0)) AS adv_payment_open_amt
    FROM ads.ads_fin_order_report_dim_di WHERE travel_date = {yday}
    GROUP BY merchant_tenant_id
),
b AS (
    SELECT merchant_tenant_id, SUM(balance_open_amt) AS balance_open_amt, SUM(balance_in_amt) AS balance_in_amt, SUM(balance_out_amt) AS balance_out_amt,
           SUM(balance_close_amt) AS balance_close_amt, SUM(recharge_amt) AS recharge_amt, SUM(withdraw_amt) AS withdraw_amt,
           SUM(expense_income_amt) AS expense_income_amt, SUM(expense_out_amt) AS expense_out_amt, SUM(unclassified_flow_qty) AS unclassified_flow_qty
    FROM {src_bal} WHERE travel_date = {date_expr}
    GROUP BY merchant_tenant_id
),
k AS (SELECT merchant_tenant_id FROM o UNION SELECT merchant_tenant_id FROM y UNION SELECT merchant_tenant_id FROM b)
"""
    cols = []
    for f, *_ in RPT:
        src = 'y' if f.endswith('_open_amt') and f.startswith('adv') else 'b' if f in RPT_BAL else 'o'
        cols.append(f"COALESCE({src}.{f}, 0) AS {f}")
    return o, cols


RPT_BAL = {'balance_open_amt', 'balance_in_amt', 'balance_out_amt', 'balance_close_amt', 'recharge_amt', 'withdraw_amt', 'expense_income_amt', 'expense_out_amt', 'unclassified_flow_qty'}
_o, _cols = merchant_sql('ads.ads_fin_order_report_dim_di', 'ads.ads_fin_balance_report_di', "'${bizdate}'", False)
ETL['ads_fin_merchant_report_di'] = ('hive', hdr('ads.ads_fin_merchant_report_di', '商户财务报表总览（日）',
    ['五张基础报表的商户级总数 = 多维汇总 / 余额报表按商户相加（明细加总 = 汇总，7.3）', '派生指标（未结转差额、毛利、净利）不落表，查询时由本表字段计算（原则 5）'],
    ['三个来源各按商户预聚合后关联']) + _o + f"""INSERT OVERWRITE TABLE ads.ads_fin_merchant_report_di PARTITION (travel_date = '${{bizdate}}')
SELECT k.merchant_tenant_id,
       {(','+chr(10)+'       ').join(_cols)},
       {NOW} AS etl_time
FROM k
LEFT JOIN o ON o.merchant_tenant_id = k.merchant_tenant_id
LEFT JOIN y ON y.merchant_tenant_id = k.merchant_tenant_id
LEFT JOIN b ON b.merchant_tenant_id = k.merchant_tenant_id;
""")
_o, _cols = merchant_sql('ads.ads_fin_order_report_dim_rt', 'ads.ads_fin_balance_report_rt', "DATE_FORMAT(CURDATE(), '%Y%m%d')", True)
ETL['ads_fin_merchant_report_rt'] = ('starrocks', hdr('ads.ads_fin_merchant_report_rt', '商户财务报表总览（今日实时）',
    ['今日段：订单部分取多维汇总今日实时，期初取昨日离线定版期末；余额取实时余额报表'], ['StarRocks 异步物化视图，1 分钟刷新']) + """CREATE MATERIALIZED VIEW IF NOT EXISTS ads.ads_fin_merchant_report_rt
REFRESH ASYNC EVERY (INTERVAL 1 MINUTE)
AS
""" + _o + f"""SELECT DATE_FORMAT(CURDATE(), '%Y%m%d') AS travel_date,
       k.merchant_tenant_id,
       {(','+chr(10)+'       ').join(_cols)},
       NOW() AS update_time
FROM k
LEFT JOIN o ON o.merchant_tenant_id = k.merchant_tenant_id
LEFT JOIN y ON y.merchant_tenant_id = k.merchant_tenant_id
LEFT JOIN b ON b.merchant_tenant_id = k.merchant_tenant_id;
""")
ETL['ads_fin_unclassified_flow_di'] = ('hive', hdr('ads.ads_fin_unclassified_flow_di', '待归类资金流水异常清单',
    ['未命中归属规则的流水逐条列出（5.5），不进任何报表；产品确认后在归属规则表补规则，重跑当日即可'], ['单表过滤']) + f"""
INSERT OVERWRITE TABLE ads.ads_fin_unclassified_flow_di PARTITION (travel_date = '${{bizdate}}')
SELECT flow_no, flow_time, merchant_tenant_id, account_no, flow_type, fee_item_code, frozen_event_type, change_amt, related_no,
       {NOW} AS etl_time
FROM dwd.dwd_fin_balance_detail_di
WHERE {P} AND report_code = 'UNCLASSIFIED';
""")

# ---------------------------------------------------------------- 质量规则（第八章勾稽 + 通用）
A = "ads.ads_fin_merchant_report_di WHERE travel_date = '${bizdate}'"
DQ = [
    ('ads_fin_merchant_report_di', '一致性', '勾稽 1 · 预收结转：期初预收 + 本期收 − 本期退 − 转实收 = 期末预收', '强', '阻断下游', 'bad_cnt = 0', '第八章 1',
     f"SELECT COUNT(*) AS bad_cnt FROM {A}\n  AND ABS(adv_receipt_open_amt + adv_receipt_receive_amt - adv_receipt_refund_amt - adv_receipt_to_revenue_amt - adv_receipt_close_amt) > 0.01;"),
    ('ads_fin_merchant_report_di', '一致性', '勾稽 2 · 预付结转：期初预付 + 本期付 − 本期退回 − 转实付 = 期末预付', '强', '阻断下游', 'bad_cnt = 0', '第八章 2',
     f"SELECT COUNT(*) AS bad_cnt FROM {A}\n  AND ABS(adv_payment_open_amt + adv_payment_pay_amt - adv_payment_return_amt - adv_payment_to_cost_amt - adv_payment_close_amt) > 0.01;"),
    ('ads_fin_balance_report_di', '一致性', '勾稽 3 · 余额闭合（按账本）：期初余额 + 流入 − 流出 = 期末余额', '强', '阻断下游', 'bad_cnt = 0', '第八章 3；不闭合多半是有流水未归属或归属方向错',
     "SELECT COUNT(*) AS bad_cnt FROM ads.ads_fin_balance_report_di WHERE travel_date = '${bizdate}'\n  AND ABS(balance_open_amt + balance_in_amt - balance_out_amt - balance_close_amt) > 0.01;"),
    ('ads_fin_order_report_dim_di', '一致性', '期初 = 上日期末（每个维度组合）：今日 close − 今日余额变动 = 昨日 close', '强', '阻断下游', 'bad_cnt = 0', '5.7 时点值连续；任意维度拆分都成立',
     "SELECT COUNT(*) AS bad_cnt FROM (\n  SELECT merchant_tenant_id, report_code, SUM(IF(travel_date = '${bizdate}', close_amt - in_amt + out_amt + trans_amt, 0)) AS t_open,\n"
     "         SUM(IF(travel_date <> '${bizdate}', close_amt, 0)) AS y_close\n  FROM ads.ads_fin_order_report_dim_di\n"
     "  WHERE travel_date IN ('${bizdate}', DATE_FORMAT(DATE_SUB(TO_DATE('${bizdate}', 'yyyyMMdd'), 1), 'yyyyMMdd')) AND report_code IN ('ADV_RECEIPT', 'ADV_PAYMENT')\n"
     "  GROUP BY merchant_tenant_id, report_code\n) x WHERE ABS(t_open - y_close) > 0.01;"),
    ('ads_fin_order_report_dim_di', '一致性', '勾稽 6 · 明细汇总一致：多维汇总的发生额 = 订单资金明细加总', '强', '阻断下游', '|ads_v − dwd_v| ≤ 0.01', '第八章 6、7.3 硬约束',
     "SELECT (SELECT SUM(in_amt + out_amt + trans_amt + confirm_amt) FROM ads.ads_fin_order_report_dim_di WHERE travel_date = '${bizdate}') AS ads_v,\n"
     "       (SELECT SUM(event_amt) FROM dwd.dwd_fin_merchant_order_fund_di WHERE travel_date = '${bizdate}') AS dwd_v;"),
    ('ads_fin_balance_report_di', '一致性', '勾稽 6 · 余额明细汇总一致：余额报表流入 / 流出 = 余额明细加总', '强', '阻断下游', '|a − b| ≤ 0.01', '第八章 6',
     "SELECT (SELECT SUM(balance_in_amt - balance_out_amt) FROM ads.ads_fin_balance_report_di WHERE travel_date = '${bizdate}') AS a,\n"
     "       (SELECT SUM(balance_in_amt - balance_out_amt) FROM dwd.dwd_fin_balance_detail_di WHERE travel_date = '${bizdate}') AS b;"),
    ('ads_fin_merchant_report_di', '一致性', '勾稽 7 · 全局守恒：余额变动 = 净利 + 充值 − 提现（二期费用收支就绪后启用）', '弱', '告警', 'bad_cnt = 0',
     '第八章 7；只对「核销即结算」且无在途变动的商户成立，偏差用于排查归属错误',
     f"SELECT COUNT(*) AS bad_cnt FROM {A}\n  AND ABS((balance_close_amt - balance_open_amt) - ((revenue_amt - cost_amt) + (expense_income_amt - expense_out_amt) + recharge_amt - withdraw_amt)) > 0.01;"),
    ('ads_fin_unclassified_flow_di', '一致性', '待归类流水为 0（未定义费用项不得默认归类）', '强', '告警', 'cnt = 0', '5.5：非 0 时查本清单的流水类型 / 费用项，产品确认后补规则',
     "SELECT COUNT(*) AS cnt FROM ads.ads_fin_unclassified_flow_di WHERE travel_date = '${bizdate}';"),
    ('dwd_fin_merchant_order_fund_di', '一致性', '退款联动：下游预收冲减时，有上游的票本方预付也须冲减', '强', '告警', 'bad_cnt = 0', '5.2：只冲预收不冲预付会让预付挂死账',
     "SELECT COUNT(*) AS bad_cnt FROM (\n  SELECT merchant_tenant_id, ticket_no, SUM(IF(measure_code = 'REFUND', 1, 0)) AS r_in, SUM(IF(measure_code = 'RETURN', 1, 0)) AS r_out,\n"
     "         MAX(IF(payee_type = 'SUPPLIER', 1, 0)) AS has_up\n  FROM dwd.dwd_fin_merchant_order_fund_di WHERE travel_date = '${bizdate}' AND measure_code IN ('REFUND', 'RETURN')\n"
     "  GROUP BY merchant_tenant_id, ticket_no\n) x WHERE has_up = 1 AND r_in > 0 AND r_out = 0;"),
    ('dwd_fin_merchant_order_fund_di', '一致性', '按票分摊无损：当日支付记录金额 = 落到票上的收侧金额合计', '强', '告警', '|a − b| ≤ 0.01 × 票数', '聚合单支付按票单价分摊',
     "SELECT p.payment_no, p.pay_amt AS a, f.amt AS b, f.n FROM dwd.dwd_fin_payment_di p\nJOIN (SELECT source_no, SUM(event_amt) AS amt, COUNT(*) AS n FROM dwd.dwd_fin_merchant_order_fund_di\n"
     "      WHERE travel_date = '${bizdate}' AND source_type = 'PAYMENT' AND measure_code = 'RECEIVE' GROUP BY source_no) f ON f.source_no = p.payment_no\n"
     "WHERE p.travel_date = '${bizdate}' AND ABS(p.pay_amt - f.amt) > 0.01 * f.n;"),
    ('dwd_fin_merchant_order_fund_di', '唯一性', '主键唯一（fund_event_id）', '强', '阻断下游', 'dup_cnt = 0', '重复会让报表翻倍',
     "SELECT COUNT(*) AS dup_cnt FROM (\n  SELECT fund_event_id, COUNT(*) AS c FROM dwd.dwd_fin_merchant_order_fund_di WHERE travel_date = '${bizdate}' GROUP BY fund_event_id HAVING c > 1\n) t;"),
    ('dwd_fin_merchant_order_fund_di', '完整性', '本方商户、报表、列、费用类型非空', '强', '阻断下游', 'null_cnt = 0', '',
     "SELECT COUNT(*) AS null_cnt FROM dwd.dwd_fin_merchant_order_fund_di WHERE travel_date = '${bizdate}'\n  AND (merchant_tenant_id IS NULL OR report_code IS NULL OR measure_code IS NULL OR fee_type_name IS NULL);"),
    ('dwd_fin_balance_detail_di', '唯一性', '主键唯一（flow_no）', '强', '阻断下游', 'dup_cnt = 0', '双式记账只取本方账户，一条流水只出现一次',
     "SELECT COUNT(*) AS dup_cnt FROM (\n  SELECT flow_no, COUNT(*) AS c FROM dwd.dwd_fin_balance_detail_di WHERE travel_date = '${bizdate}' GROUP BY flow_no HAVING c > 1\n) t;"),
    ('dwd_fin_balance_detail_di', '一致性', '快照余额连续：同一账本相邻两笔，后一笔变动前余额 = 前一笔变动后余额', '弱', '告警', 'bad_cnt = 0', '5.7：余额列是快照值；不连续说明流水缺失或 balance 口径不是可用余额',
     "SELECT COUNT(*) AS bad_cnt FROM (\n  SELECT balance_before_amt, LAG(balance_after_amt) OVER (PARTITION BY account_no ORDER BY flow_time, flow_no) AS prev_after\n"
     "  FROM dwd.dwd_fin_balance_detail_di WHERE travel_date = '${bizdate}'\n) x WHERE prev_after IS NOT NULL AND ABS(balance_before_amt - prev_after) > 0.01;"),
    ('dws_fin_merchant_unsettled_df', '有效性', '在途金额不为负', '弱', '告警', 'neg_cnt = 0', '为负说明退款 / 核销先于收付入仓（迟到）或分摊误差',
     "SELECT COUNT(*) AS neg_cnt FROM dws.dws_fin_merchant_unsettled_df WHERE travel_date = '${bizdate}' AND unsettled_amt < -0.01;"),
    ('dws_fin_merchant_unsettled_df', '唯一性', '粒度唯一（merchant_tenant_id + report_code + ticket_no）', '强', '阻断下游', 'dup_cnt = 0', '',
     "SELECT COUNT(*) AS dup_cnt FROM (\n  SELECT merchant_tenant_id, report_code, ticket_no, COUNT(*) AS c FROM dws.dws_fin_merchant_unsettled_df WHERE travel_date = '${bizdate}' GROUP BY 1, 2, 3 HAVING c > 1\n) t;"),
]
RT_DQ = [('ads_fin_order_report_dim_rt', '及时性', '数据新鲜度 ≤ 5 分钟', '强', '告警', 'lag_s ≤ 300（营业时间 08:00–22:00）', 'StarRocks 侧每分钟巡检',
          "SELECT TIMESTAMPDIFF(SECOND, MAX(update_time), NOW()) AS lag_s FROM ads.ads_fin_order_report_dim_rt WHERE travel_date = DATE_FORMAT(CURDATE(), '%Y%m%d');"),
         ('ads_fin_balance_report_rt', '一致性', '实时 / 离线余额对账：昨日实时期末 = 离线定版期末', '弱', '告警', '|实时 − 离线| ≤ 0.01', '次日 T+1 完成后对昨日；差异来自 CDC 丢数或迟到',
          "SELECT r.account_no, r.balance_close_amt AS rt_v, d.balance_close_amt AS di_v\nFROM ads.ads_fin_balance_report_rt r\n"
          "JOIN hive_catalog.ads.ads_fin_balance_report_di d ON d.account_no = r.account_no AND d.travel_date = r.travel_date\n"
          "WHERE r.travel_date = '${bizdate}' AND ABS(r.balance_close_amt - d.balance_close_amt) > 0.01;"),
         ('ads_fin_merchant_report_rt', '一致性', '实时 / 离线对账：昨日实时预收期末与离线定版期末差异 ≤ 0.5%', '弱', '告警', '|实时 − 离线| / 离线 ≤ 0.5%', '以离线为准',
          "-- 每日 T+1 后执行：实时作业保留昨日结果快照 ads_fin_merchant_report_rt_hist\nSELECT SUM(adv_receipt_close_amt) FROM ads.ads_fin_merchant_report_rt_hist WHERE travel_date = '${bizdate}';\n"
          "SELECT SUM(adv_receipt_close_amt) FROM ads.ads_fin_merchant_report_di WHERE travel_date = '${bizdate}';")]

# ---------------------------------------------------------------- 待确认事项（源端缺口 / 与需求不一致处，需研发 / 产品确认）
TODO = [
    ('财务报表', '结算时点无字段：需求 5.8 要求配在支付方式上，3.0 业务库 t_merchant_payment_config 只有 collection_mode',
     '业务库补 settle_timing（+ 生效时间）；补齐前全部按「核销即结算」，支付即结算商户的预收会偏大、余额入账时点偏晚', '预收转实收时点、余额流入时点'),
    ('财务报表', '资金流水类型与需求「费用项」对不上：需求列 购买产品 / 退款 / 解冻 / 冻结 / 应用套餐购买 / 充值扣款 / 提现；业务库 flow_type 为 RECHARGE / PAYMENT / REFUND / FREEZE / UNFREEZE / WITHDRAW / FEE / RESOURCE / TRANSFER_OUT / TRANSFER_IN',
     '归属规则表已按 3.0 枚举建好，界面费用类型单列；PENDING 规则（采购划付 TRANSFER_OUT/IN、下单收付在可用余额上相抵）请逐条确认', '余额流入 / 流出'),
    ('财务报表', '解冻流水分不出「核销触发 / 退款释放」：frozen_event 在冻结记录上，资金流水 related_no 对解冻填什么未定义',
     '请研发确认解冻流水 related_no = 冻结单号（或票号）；当前两种都尝试关联', '余额报表「结算」流入'),
    ('财务报表', '需求 7.1「明细来源为同一份资金流水」：授信订单不产生资金流水，按 3.1 又须下单即计入预收',
     '订单四张表以支付记录 / 退款明细 / 核销解冻为来源（同一份规则，7.3 成立），资金流水只用于余额与费用收支', '订单报表明细的「业务流水号」为支付流水号 / 退款明细号 / 冻结记录号'),
    ('财务报表', '订单上没有「售票站点」；需求「卖出单价 = receipt_price」在 3.0 子单表中不存在（只有 unit_price），评审口头提出订单表没有买入价快照',
     '售票站点请研发补字段；卖出 / 买入单价取本方两侧支付记录金额（按票分摊），能区分分销链每一级的价格', '维度「售票站点」暂为空'),
    ('财务报表', '余额报表要求「可用余额」，资金流水 balance_before / after 只有一个余额，是否为可用余额未定义',
     '请研发确认；质量规则「快照余额连续」「余额闭合」会暴露此问题', '期初 / 期末余额'),
    ('财务报表', '支付记录 settle_amount 注释「INBOUND = 售价」与架构文档「利润 = amount − settle_amount」矛盾',
     '报表一律用 amount（这笔记录实际转移的钱）计量；settle_amount 不参与', '分销商的确认收入'),
    ('财务报表', '支付记录 ticket_no 默认空串（按聚合单支付），退款明细按支付记录而不是按票（第十章 3）',
     '支付按票单价占比分摊到票，退款按退款单 refund_items 的票金额占比分摊；尾差 ≤ 每票 1 分（质量规则校验）', '按产品 / 票种下钻的分厘尾差'),
    ('财务报表', '余额明细「对方商户」：资金流水没有对方字段',
     '按支付批次号关联支付记录的另一侧；充值 / 提现记银行、费用记平台；请研发确认流水 payment_batch_no 与支付记录 batch_no 一致', '余额明细「对方商户」筛选'),
    ('财务报表', '实时链路：今天段需要支付记录、退款明细、冻结记录的实时流，以及 Hive 外表读取历史支付与订单维度',
     '已新增 ods_ord_refund_detail_rt / dwd_fin_refund_payment_rt；StarRocks 需配置 hive_catalog；一期若数据管道未就绪按需求 6.4 全部实时查询', '今天段口径与离线一致'),
]


# ---------------------------------------------------------------- 写入字典
def _rows(S, sheet, vals):
    c = {x: i for i, x in enumerate(S[sheet]['cols'])}
    r = [''] * len(c)
    for k, v in vals:
        if k in c:
            r[c[k]] = v
    S[sheet]['rows'].append(r)


def apply(S):
    """把补齐内容追加进字典 sheets（原地修改），返回 (ETL 覆盖, 新增表名集合)"""
    T_, F_s, L_ = S['表清单'], S['字段清单'], S['分层汇总']
    ti = {c: i for i, c in enumerate(T_['cols'])}
    fi = {c: i for i, c in enumerate(F_s['cols'])}
    have = {str(r[ti['表名（库.表）']]) for r in T_['rows']}
    fields_of = {}
    for r in F_s['rows']:
        fields_of.setdefault(str(r[fi['表名（库.表）']]), []).append(r)
    no = max(int(r[ti['序号']]) for r in T_['rows'] if str(r[ti['序号']]).isdigit())
    added = set()
    for x in T:
        if x['name'] in have:
            continue
        no += 1
        _rows(S, '表清单', (('序号', no), ('分层', x['layer']), ('业务域', DOM), ('表名（库.表）', x['name']), ('表中文名', x['cn']), ('粒度', x['grain']),
                            ('后缀含义', x['suffix']), ('分区', x['part']), ('来源', x['src']), ('度量 / 口径 / 关键字段', x['keys']), ('上游表', x['up']),
                            ('下游表', x['down']), ('备注', ('【新增 · 3.0 财务报表】' + x['note']).strip())))
        added.add(x['name'].split('.', 1)[1])
        fl = x['fields']
        if isinstance(fl, str) and fl.startswith('@copy:'):
            src = fl[6:]
            base = fields_of.get(src, [])
            fl = [(r[fi['字段名']], r[fi['类型']], r[fi['字段类别']], r[fi['字段注释']], f"同 {src.split('.', 1)[1]}.{r[fi['字段名']]}", f"{src}.{r[fi['字段名']]}") for r in base
                  if r[fi['字段类别']] != '分区' and r[fi['字段名']] != 'etl_time']
            if x['name'].startswith('ods.'):
                tbl = re.match(r'^([\w-]+\.\w+)', x['src']).group(1)
                fl = [(n, ty, c, cm, f'{tbl}.{n}，Flink CDC 读 binlog', '') for n, ty, c, cm, _, _ in fl if c != 'ETL' or n.startswith('binlog')]
            elif x['name'].startswith('ads.'):
                fl = [('travel_date', 'STRING', '分区', '数据日期，格式 YYYYMMDD', '当日 / 流水日期', '')] + fl + [('update_time', 'STRING', 'ETL', '最近一次刷新时间', '物化视图刷新', '')]
            else:
                fl = [('travel_date', 'STRING', '分区', '数据日期，格式 YYYYMMDD；取事件时间日期', '事件时间', '')] + fl
                if not any(f[0] == 'event_time' for f in fl):
                    fl.append(('event_time', 'STRING', 'ETL', '事件时间（binlog 时间），用于乱序处理', 'binlog', ''))
        new_rows = []
        for i, f in enumerate(fl, 1):
            r = [''] * len(F_s['cols'])
            for k, v in (('分层', x['layer']), ('表名（库.表）', x['name']), ('表中文名', x['cn']), ('序号', i), ('字段名', f[0]), ('类型', f[1]), ('字段类别', f[2]),
                         ('字段注释', f[3]), ('加工 / 来源', f[4]), ('上游字段', f[5])):
                r[fi[k]] = v
            new_rows.append(r)
        F_s['rows'].extend(new_rows)
        fields_of[x['name']] = new_rows
    cn = {x['name'].split('.', 1)[1]: x['cn'] for x in T}
    nq = {}
    for r in DQ + RT_DQ:
        nq[r[0]] = nq.get(r[0], 0) + 1
    # 调度
    plan = [('dim_fin_report_rule_f', 'DIM', 4, 'start.daily'), ('dim_fin_settle_timing_df', 'DIM', 4, 'dq.ods_fin_merchant_payment_config_df'),
            ('dwd_fin_merchant_order_fund_di', 'DWD', 18, 'dq.dwd_fin_payment_di、dq.dwd_fin_refund_payment_di、dq.dwd_ord_refund_ticket_di、dq.dwd_fin_frozen_di、dq.dwd_ord_ticket_di、dq.dwd_ord_order_group_di、dq.dim_fin_report_rule_f、dq.dim_fin_settle_timing_df'),
            ('dwd_fin_balance_detail_di', 'DWD', 18, 'dq.dwd_fin_fund_flow_di、dq.dim_fin_account_df、dq.dwd_fin_frozen_di、dq.dwd_fin_payment_di、dq.dim_fin_report_rule_f'),
            ('dws_fin_merchant_unsettled_df', 'DWS', 20, 'dq.dwd_fin_merchant_order_fund_di'), ('dws_fin_merchant_order_fund_di', 'DWS', 20, 'dq.dwd_fin_merchant_order_fund_di'),
            ('dws_fin_merchant_balance_di', 'DWS', 20, 'dq.dwd_fin_balance_detail_di'),
            ('ads_fin_order_report_dim_di', 'ADS', 26, 'dq.dws_fin_merchant_order_fund_di、dq.dws_fin_merchant_unsettled_df'),
            ('ads_fin_balance_report_di', 'ADS', 26, 'dq.dws_fin_merchant_balance_di、dq.dws_fin_account_balance_df'),
            ('ads_fin_unclassified_flow_di', 'ADS', 26, 'dq.dwd_fin_balance_detail_di'),
            ('ads_fin_merchant_report_di', 'ADS', 28, 'dq.ads_fin_order_report_dim_di、dq.ads_fin_balance_report_di')]
    for tb, layer, step, wait in plan:
        _rows(S, '调度工作流', (('工作流', '日调度'), ('步骤', step), ('节点', tb), ('类型', '任务'), ('说明', cn[tb]), ('分层', layer), ('规则数', 0),
                              ('等待（上游）', wait), ('执行 / 说明', f'sql/{layer.lower()}/{tb}.sql' + ('；完成后同步 StarRocks（报表服务历史段）' if layer == 'ADS' else ''))))
        _rows(S, '调度工作流', (('工作流', '日调度'), ('步骤', step + 1), ('节点', f'dq.{tb}'), ('类型', '质检'), ('说明', cn[tb] + ' 质检'), ('分层', layer),
                              ('失败处理', '阻断'), ('规则数', nq.get(tb, 2)), ('等待（上游）', tb)))
    rt_plan = [('ods_fin_fund_flow_rt', 'ODS', 'Flink CDC 源表：pft-finance.t_fund_flow'), ('ods_ord_refund_detail_rt', 'ODS', 'Flink CDC 源表：pft-order.t_refund_detail'),
               ('dwd_fin_refund_payment_rt', 'DWD', 'Flink 作业 flink_job_fin_report 写 StarRocks'), ('dwd_fin_balance_detail_rt', 'DWD', 'Flink 作业 flink_job_fin_report 写 StarRocks'),
               ('dwd_fin_merchant_order_fund_rt', 'DWD', 'StarRocks 异步物化视图，1 分钟刷新'), ('ads_fin_order_report_dim_rt', 'ADS', 'StarRocks 异步物化视图，1 分钟刷新'),
               ('ads_fin_balance_report_rt', 'ADS', 'StarRocks 异步物化视图，1 分钟刷新'), ('ads_fin_merchant_report_rt', 'ADS', 'StarRocks 异步物化视图，1 分钟刷新')]
    for k, (tb, layer, exe) in enumerate(rt_plan):
        _rows(S, '调度工作流', (('工作流', '实时作业'), ('步骤', 1 + 2 * k), ('节点', tb), ('类型', '任务'), ('说明', cn[tb]), ('分层', layer), ('规则数', 0), ('执行 / 说明', exe)))
        if layer != 'ODS':
            _rows(S, '调度工作流', (('工作流', '实时作业'), ('步骤', 2 + 2 * k), ('节点', f'dq.{tb}'), ('类型', '监控'), ('说明', cn[tb] + ' 监控'), ('分层', layer),
                                  ('失败处理', '告警'), ('规则数', nq.get(tb, 1)), ('等待（上游）', tb)))
    # 质量规则
    qi = {c: i for i, c in enumerate(S['质量规则']['cols'])}
    nid = 1 + max(int(re.sub(r'\D', '', str(r[qi['规则编号']])) or 0) for r in S['质量规则']['rows'])
    for flow, rules in (('日调度', DQ), ('实时作业', RT_DQ)):
        for tb, dim_, text, lvl, fail, expect, note, sql in rules:
            _rows(S, '质量规则', (('规则编号', f'R{nid:04d}'), ('工作流', flow), ('质检节点', f'dq.{tb}'), ('表', tb), ('质量维度', dim_), ('规则', text), ('级别', lvl),
                                ('失败处理', fail), ('期望', expect), ('说明', note), ('检测 SQL', sql)))
            nid += 1
    # DWS 口径
    D_ = S['DWS口径']
    di = {c: i for i, c in enumerate(D_['cols'])}
    na = 1 + max(int(str(r[di['口径编码']])[1:]) for r in D_['rows'] if str(r[di['口径编码']]).startswith('A') and str(r[di['口径编码']])[1:].isdigit())
    code_of = {}

    def kou(en, cn_, k, fx, unit, tcal, src, dws, ads):
        nonlocal na
        _rows(S, 'DWS口径', (('口径编码', f'A{na:03d}'), ('英文名', en), ('中文名', cn_), ('口径类型', '原子指标'), ('业务域', DOM), ('业务口径', k), ('计算公式', fx),
                            ('单位', unit), ('时间口径', tcal), ('数据类型', 'BIGINT' if unit in ('张', '笔') else 'DECIMAL(18,2)'),
                            ('精度/展示', f'整数，单位：{unit}' if unit in ('张', '笔') else '元，保留 2 位小数'), ('来源明细表', src), ('落地 DWS 表', dws), ('被哪些 ADS 表使用', ads)))
        code_of[en] = f'A{na:03d}'
        na += 1
    ADSU = 'ads_fin_order_report_dim_di、ads_fin_order_report_dim_rt、ads_fin_merchant_report_di'
    for m, r_, c_, cn_, k in MEAS:
        kou(f'{m}_amt', cn_, k, f'{cn_} = SUM(金额)；条件：报表={r_}，列={c_}；本方商户视角', '元', '动作发生时间（收 / 付 = 支付，退 = 退款到账，结算 = 核销解冻）',
            F_, 'dws_fin_merchant_order_fund_di', ADSU)
    for q, cn_, k, w, e in QTYS:
        kou(q, cn_, k, f'{cn_} = SUM({e})；条件：{w}', '张', '动作发生时间', F_, 'dws_fin_merchant_order_fund_di', ADSU)
    kou('unsettled_amt', '在途金额（期末预收 / 期末预付）', '截至统计日日终已卖出（已采购）、尚未核销且未退款的金额',
        '在途 = 上日在途 + SUM(当日余额影响)；时点值，取日终快照，不跨期相加', '元', '统计日日终快照', F_, 'dws_fin_merchant_unsettled_df', ADSU)
    kou('fund_in_amt', '资金流入', '本期实际进入可用余额的金额（含结算解冻、充值）', '资金流入 = SUM(变动金额 > 0)；余额报表只取归属 仅余额 / 费用收支', '元', '流水发生时间',
        'dwd_fin_balance_detail_di', 'dws_fin_merchant_balance_di', 'ads_fin_balance_report_di、ads_fin_balance_report_rt、ads_fin_merchant_report_di')
    kou('fund_out_amt', '资金流出', '本期实际离开可用余额的金额（含提现、应用套餐、手续费）', '资金流出 = −SUM(变动金额 < 0)；余额报表只取归属 仅余额 / 费用收支', '元', '流水发生时间',
        'dwd_fin_balance_detail_di', 'dws_fin_merchant_balance_di', 'ads_fin_balance_report_di、ads_fin_balance_report_rt、ads_fin_merchant_report_di')
    # ADS 业务指标：多维汇总（离线 / 实时）× 报表列、余额报表、总览、派生
    A_ = S['ADS业务指标']
    ai = {c: i for i, c in enumerate(A_['cols'])}
    nb = 1 + max(int(re.sub(r'\D', '', str(r[ai['指标编码']])) or 0) for r in A_['rows'])

    def met(name, field, k, fx, unit, rt, base, ads, adscn, grain, src, typ='原子指标', snap=False):
        nonlocal nb
        _rows(S, 'ADS业务指标', (('指标编码', f'B{nb:04d}'), ('业务指标名', name), ('字段名', field), ('业务口径', k), ('计算公式', fx), ('单位', unit),
                                 ('统计周期', '今日' if rt else '当日'), ('修饰词', '—'), ('时间口径', '统计日日终快照' if snap else '动作发生时间'),
                                 ('数据类型', 'BIGINT' if unit in ('张', '笔') else 'DECIMAL(18,6)' if unit == '%' else 'DECIMAL(18,2)'),
                                 ('精度/展示', f'整数，单位：{unit}' if unit in ('张', '笔') else '百分比，保留 2 位' if unit == '%' else '元，保留 2 位小数'),
                                 ('更新频率', '实时（分钟级刷新）' if rt else '每日 T+1'), ('离线/实时', '实时' if rt else '离线'),
                                 ('基础口径', f'{code_of[base]} {base}' if base in code_of else '—'), ('口径类型', typ), ('ADS表', ads), ('ADS表中文名', adscn),
                                 ('分析粒度', grain), ('来源 DWS', src), ('使用端', '商户后台 · 财务 · 报表中心')))
        nb += 1
    REP = [('预收报表', 'ADV_RECEIPT', [('期初预收', 'close_amt', '区间首日前一天的 close_amt 之和（时点值）', 'unsettled_amt', True), ('本期收', 'in_amt', '订单卖出金额（含授信）', 'receive_amt', False),
                                       ('本期退', 'out_amt', '退给下级的金额', 'refund_amt', False), ('转实收', 'trans_amt', '因履约转入确认收入的金额', 'to_revenue_amt', False),
                                       ('期末预收', 'close_amt', '区间末日的 close_amt 之和（时点值）', 'unsettled_amt', True), ('预收净票数', 'net_ticket_qty', '售票记正、退款记负', 'sale_ticket_qty', False)]),
           ('预付报表', 'ADV_PAYMENT', [('期初预付', 'close_amt', '区间首日前一天的 close_amt 之和（时点值）', 'unsettled_amt', True), ('本期付', 'in_amt', '向上级采购付款金额', 'pay_amt', False),
                                       ('本期退回', 'out_amt', '上级退回金额', 'return_amt', False), ('转实付', 'trans_amt', '因履约转入成本确认的金额', 'to_cost_amt', False),
                                       ('期末预付', 'close_amt', '区间末日的 close_amt 之和（时点值）', 'unsettled_amt', True), ('预付净票数', 'net_ticket_qty', '采购记正、退回记负', 'buy_ticket_qty', False)]),
           ('确认收入报表', 'REVENUE', [('履约收入', 'confirm_amt', '因核销确认的收入，按订单实收金额（实收单价 × 核销数量）', 'revenue_amt', False),
                                       ('确认收入票数', 'confirm_ticket_qty', '核销确认的票数', 'revenue_ticket_qty', False)]),
           ('确认成本报表', 'COST', [('成本结算', 'confirm_amt', '因核销确认的成本，按订单买入金额', 'cost_amt', False), ('确认成本票数', 'confirm_ticket_qty', '核销确认的票数', 'cost_ticket_qty', False)])]
    for rt in (False, True):
        ads = 'ads_fin_order_report_dim_rt' if rt else 'ads_fin_order_report_dim_di'
        for rep, code, ms in REP:
            for nm, fld, k, base, snap in ms:
                unit = '张' if fld.endswith('_qty') else '元'
                met(('今日' if rt else '') + nm, fld, f'{rep}：{k}。', f"{nm} = {'取区间首日前一天 / 末日的日终值（时点值）' if snap else 'SUM(日值)'}；条件 report_code = '{code}'；按所选维度 GROUP BY",
                    unit, rt, base, ads, '订单报表多维汇总（今日实时）' if rt else '订单报表多维汇总（日）', 'travel_date × merchant_tenant_id × report_code × 订单维度',
                    'dwd_fin_merchant_order_fund_rt、ads_fin_order_report_dim_di（昨日日终）、dws_fin_merchant_order_fund_di、dws_fin_merchant_unsettled_df（同口径离线表）' if rt else
                    ('dws_fin_merchant_unsettled_df' if snap else 'dws_fin_merchant_order_fund_di'), snap=snap)
        ads = 'ads_fin_balance_report_rt' if rt else 'ads_fin_balance_report_di'
        for nm, fld, k, base, snap in (('期初余额', 'balance_open_amt', '区间首日第一笔流水前的可用余额（时点值）', '—', True), ('资金流入', 'balance_in_amt', '本期实际进入可用余额的金额', 'fund_in_amt', False),
                                       ('资金流出', 'balance_out_amt', '本期实际离开可用余额的金额', 'fund_out_amt', False), ('期末余额', 'balance_close_amt', '区间末日最后一笔流水后的可用余额（时点值）', '—', True)):
            met(('实时' if rt else '') + nm, fld, f'余额报表：{k}。', f"{nm} = {'取区间首日 / 末日值（时点值）' if snap else 'SUM(日值)'}；按日期 × 账本", '元', rt, base, ads,
                '余额报表（实时 · 日 × 账本）' if rt else '余额报表（日 × 账本）', 'travel_date × merchant_tenant_id × account_no',
                'dwd_fin_balance_detail_rt、dws_fin_merchant_balance_di（同口径离线表）' if rt else 'dws_fin_merchant_balance_di、dws_fin_account_balance_df', snap=snap)
    for nm, fx, unit in (('未结转差额', '期末预收 − 期末预付（正：钱先到、服务未履约；负：先付采购款、存在垫资）', '元'), ('订单毛利', '履约收入 − 成本结算', '元'),
                         ('毛利率', '订单毛利 ÷ 履约收入 × 100', '%'), ('费用收支净额', '费用收入 − 费用支出（二期）', '元'),
                         ('净利', '订单毛利 + 费用收支净额（即 毛利 − 费用净支出）', '元'), ('净利率', '净利 ÷ 履约收入 × 100', '%')):
        met(nm, '—', f'派生指标（3.7 / 3.8），不独立取数、不落表，查询时由基础表相加得出（原则 5）。', nm + ' = ' + fx, unit, False, '—',
            'ads_fin_merchant_report_di', '商户财务报表总览（日）', 'travel_date × merchant_tenant_id（亦可按订单维度，取多维汇总）', 'ads_fin_merchant_report_di', typ='派生指标')
    # 总线矩阵
    B_ = S['总线矩阵']
    bi = {c: i for i, c in enumerate(B_['cols'])}
    for layer, tb, cn_ in (('DWS', 'dws.dws_fin_merchant_order_fund_di', '商户订单资金日汇总'), ('DWS', 'dws.dws_fin_merchant_unsettled_df', '预收预付在途快照'),
                           ('DWS', 'dws.dws_fin_merchant_balance_di', '商户余额与费用日汇总'), ('ADS', 'ads.ads_fin_order_report_dim_di', '订单报表多维汇总（日）'),
                           ('ADS', 'ads.ads_fin_balance_report_di', '余额报表（日 × 账本）'), ('ADS', 'ads.ads_fin_merchant_report_di', '商户财务报表总览（日）')):
        r = [''] * len(bi)
        r[bi['分层']], r[bi['表名']], r[bi['中文名']] = layer, tb, cn_
        for d in ('日期', '租户（商户/供应商/分销商）') + (('SKU', '渠道/接入端', '员工', '支付渠道', '产品(SPU)', '分销关系') if ('order' in tb or 'unsettled' in tb) else ('账户',) if 'balance' in tb else ()):
            if d in bi:
                r[bi[d]] = '●'
        B_['rows'].append(r)
    # 分层汇总表数
    li = {c: i for i, c in enumerate(L_['cols'])}
    cnt = {}
    for x in T:
        cnt[x['layer']] = cnt.get(x['layer'], 0) + 1
    for r in L_['rows']:
        if r[li['分层']] in cnt and str(r[li['表数']]).isdigit():
            r[li['表数']] = int(r[li['表数']]) + cnt[r[li['分层']]]
        if r[li['分层']] == '实时链路' and str(r[li['表数']]).isdigit():
            r[li['表数']] = int(r[li['表数']]) + sum(v for k, v in cnt.items() if '实时' in k)
            for lay in ('ODS', 'DWD', 'DWS', 'ADS'):
                k = cnt.get(f'{lay}（实时）', 0)
                if k:
                    r[li['说明']] = re.sub(rf'{lay} (\d+)', lambda m: f'{lay} {int(m.group(1)) + k}', str(r[li['说明']]))
    # 待确认事项
    tdi = {c: i for i, c in enumerate(S['待确认事项']['cols'])}
    n0 = max(int(r[tdi['序号']]) for r in S['待确认事项']['rows'] if str(r[tdi['序号']]).isdigit())
    for k, (cat, q, how, imp) in enumerate(TODO, 1):
        _rows(S, '待确认事项', (('序号', n0 + k), ('类别', cat), ('问题', q), ('当前处理 / 建议', how), ('影响', imp)))
    etl = {}
    layer_of = {x['name'].split('.', 1)[1]: x['layer'] for x in T}
    for name, (kind, sql) in ETL.items():
        L = layer_of[name].replace('（实时）', '')
        path = {'hive': f'sql/{L.lower()}/{name}.sql', 'flink': f'sql/flink/{name}.sql', 'starrocks': f'sql/starrocks/{name}.sql'}[kind]
        review = len(re.findall(r'待确认：', sql))
        nf = sum(1 for r in F_s['rows'] if str(r[fi['表名（库.表）']]).endswith('.' + name))
        etl[name] = {'sql': sql.strip('\n'), 'kind': kind, 'path': path, 'stats': {'auto': 0, 'rule': max(nf - review, 0), 'review': review}}
    return etl, added
