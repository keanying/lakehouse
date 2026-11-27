-- ================================================================================================
-- dim.dim_fin_report_rule_f  财务报表归属规则
-- 依据：《3.0 通用财务报表 · 需求说明》v1.0（2026-11-24）
-- 业务规则：
--   · 规则表人工维护，改归属只改这里，不发版（需求 7.4）
--   · 资金流水未命中规则的进「待归类」，不得默认归类（需求 5.5）
--   · confirm_status=PENDING 的规则依赖研发确认：结算时点字段、采购扣转（TRANSFER_OUT/IN）、解冻流水的冻结事件
-- 性能：
--   · 码表，几十行，下游 BROADCAST
-- ================================================================================================

INSERT OVERWRITE TABLE dim.dim_fin_report_rule_f                            -- 整表覆盖写入
SELECT rule_code, source_type, flow_type, fee_item_code, direction_type, pay_method_group_type, frozen_event_type, report_code, measure_code, sign_qty, rule_desc, confirm_status,
       DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time  -- ETL 加载时间
FROM VALUES
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
        ('FR43', 'FUND_FLOW', 'TRANSFER_IN', '', 'IN', '', '', 'BALANCE', 'IN', 1, '采购扣转入：只影响余额；业务库注释未列此值，以实际数据为准', 'PENDING')
    AS v(rule_code, source_type, flow_type, fee_item_code, direction_type, pay_method_group_type, frozen_event_type, report_code, measure_code, sign_qty, rule_desc, confirm_status);
