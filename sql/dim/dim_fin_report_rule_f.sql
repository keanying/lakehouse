-- ================================================================================================
-- dim.dim_fin_report_rule_f  财务报表归属规则
-- 依据：《3.0 通用财务报表 · 需求说明》v1.0（2026-11-24）
-- 业务规则：
--   · 规则表人工维护，改归属只改这里，不发版（7.4）
--   · 资金流水未命中规则的进「待归类」，不得默认归类（5.5）
--   · 同一费用项在不同方向下归入不同的表，方向是判定的必要条件（5.4）
--   · confirm_status=PENDING 的规则依赖研发确认：结算时点字段、采购划付（TRANSFER_OUT/IN）
-- 性能：
--   · 码表，几十行，下游 BROADCAST
-- ================================================================================================

INSERT OVERWRITE TABLE dim.dim_fin_report_rule_f                            -- 整表覆盖写入
SELECT rule_code, source_type, flow_type, fee_item_code, direction_type, frozen_event_type, report_code, measure_code, fee_type_name, sign_qty, rule_desc, confirm_status,
       DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time  -- ETL 加载时间
FROM VALUES
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
        ('FR43', 'FUND_FLOW', 'TRANSFER_IN', '', '', '', 'NONE', '', '付款', 0, '采购划入：同上；业务库注释未列此值，以实际数据为准', 'PENDING')
    AS v(rule_code, source_type, flow_type, fee_item_code, direction_type, frozen_event_type, report_code, measure_code, fee_type_name, sign_qty, rule_desc, confirm_status);
