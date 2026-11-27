"""补全自动生成加工逻辑里的「待确认」字段。

etl_gen 按字典的「加工 / 来源」描述翻译 SQL；描述是业务语言、或需要跨表 / 递归 / 前后快照比较时，生成器只能先填
NULL 或 CASE WHEN 1 = 1 占位。本模块在生成之后按表补齐，三种方式：
- LINE：替换某字段的占位表达式（来源 CTE 内，字段直接用来源表列名）；
- SUB ：在生成 SQL 上做文本替换（补关联、改关联键 / 粒度键）；
- FULL：结构不适合自动生成的表整表手写（累计快照、递归层级、库存快照等）。
每条都写明口径；用到业务库没有的字段或枚举时，按现有字段近似并在注释里写「口径说明」，同时登记到待确认事项。
"""
import re

BD = "'${bizdate}'"
BDD = "'${bizdate_dash}'"
Y = "DATE_FORMAT(DATE_SUB(TO_DATE('${bizdate}', 'yyyyMMdd'), 1), 'yyyyMMdd')"
WIN400 = "travel_date >= DATE_FORMAT(DATE_SUB(TO_DATE('${bizdate}', 'yyyyMMdd'), 400), 'yyyyMMdd')"
NOW = "CURRENT_TIMESTAMP()"

# 关联片段 ------------------------------------------------------------------------------------------
REAL_BUYER = ("LEFT JOIN (SELECT customer_id AS rb_customer_id, customer_type AS rb_customer_type FROM dim.dim_cus_customer_zip\n"
              "           WHERE travel_date = '${bizdate}' AND end_date = '9999-12-31') rb ON rb.rb_customer_id = s.buyer_customer_id")
REAL_BUYER_COND = "s.pay_time IS NOT NULL AND s.buyer_customer_id > 0 AND rb.rb_customer_type = 'REAL'"
TICKET_ONE = (f"LEFT JOIN (SELECT ticket_no AS tk_no, MAX(delay_active_type) AS tk_delay, MIN(issue_time) AS tk_issue_time, MIN(first_verify_time) AS tk_first_verify_time\n"
              f"           FROM dwd.dwd_ord_ticket_di WHERE {WIN400} GROUP BY ticket_no) tk ON tk.tk_no = s.ticket_no")
ACTIVATE = "tk.tk_delay = 1 AND s.before_status = 'AVAILABLE' AND s.after_status IN ('PARTIALLY_USED', 'USED')"
UNVERIFIED = "ticket_status IN ('AVAILABLE', 'PARTIALLY_USED') AND valid_end_date >= '${bizdate_dash}'"
PENDING_ACT = "delay_active_type = 1 AND first_verify_time IS NULL AND ticket_status = 'AVAILABLE'"


def zip_changed(alias, key, col, val):
    """拉链表今日新开版本里 col 变成 val（上一版本不是 val）：上一版本 = 结束日为昨天的版本"""
    return (f"LEFT JOIN (SELECT {key} AS {alias}_key, {col} AS {alias}_{col} FROM {{tbl}}\n"
            f"           WHERE travel_date = '${{bizdate}}' AND end_date = '${{bizdate_prev_dash}}') {alias} ON {alias}.{alias}_key = s.{key}")


LINE = {
    'dws_cus_tenant_growth_di': {
        'new_customer_qty': ("COUNT(CASE WHEN customer_type = 'REAL' THEN customer_id END)", "只计真人注册账号，剔除商户代下单占位买家（customer_type = TENANT_DEFAULT）"),
        'register_pay_customer_qty': ("COUNT(CASE WHEN customer_type = 'REAL' AND fp.fp_first_pay_date = '${bizdate_dash}' THEN customer_id END)",
                                      "当日注册且当日首次支付的真人游客（首次支付日取 dws_cus_customer_lifetime_df）"),
        'certified_customer_qty': ("COUNT(CASE WHEN auth_status = 'PERSON_CERTIFIED' AND start_date = '${bizdate_dash}' AND COALESCE(pv.pv_auth_status, '') <> 'PERSON_CERTIFIED' THEN customer_id END)",
                                   "今日新开拉链版本为已实名、上一版本不是已实名"),
    },
    'dws_cus_tenant_growth_rt': {
        'new_customer_qty': ("COUNT(CASE WHEN customer_type = 'REAL' THEN customer_id END)", "只计真人注册账号，剔除占位买家"),
    },
    'dws_sup_tenant_trade_di': {
        'new_customer_qty': ("COUNT(CASE WHEN customer_type = 'REAL' THEN customer_id END)", "只计真人注册账号，剔除占位买家"),
    },
    'dws_sup_tenant_onboard_di': {
        'tenant_cert_apply_qty': ("COUNT(CASE WHEN auth_status = 'PENDING_REVIEW' AND start_date = '${bizdate_dash}' AND COALESCE(pv.pv_auth_status, '') <> 'PENDING_REVIEW' THEN tenant_id END)",
                                  "今日新开拉链版本认证状态变为审核中（提交认证）"),
        'tenant_cert_pass_qty': ("COUNT(CASE WHEN auth_status = 'CERTIFIED' AND start_date = '${bizdate_dash}' AND COALESCE(pv.pv_auth_status, '') <> 'CERTIFIED' THEN tenant_id END)",
                                 "今日新开拉链版本认证状态变为已认证"),
    },
    'dws_fin_account_balance_df': {
        'opening_balance_amt': ("MIN_BY(balance_before_amt, flow_id)", "当日第一笔流水的变动前余额（按流水主键自增顺序）"),
        'closing_balance_amt': ("MAX_BY(balance_after_amt, flow_id)", "当日最后一笔流水的变动后余额"),
    },
    'dws_fin_account_flow_di': {
        'withdraw_fail_qty': ("COUNT(CASE WHEN withdraw_status IN ('FAILED', 'REJECTED') THEN withdraw_no END)", "提现失败或被驳回"),
    },
    'dws_fin_account_frozen_di': {
        'expire_release_amt': ("SUM(CASE WHEN frozen_status = 'RELEASED' AND DATE_FORMAT(release_time, 'yyyyMMdd') = '${bizdate}' "
                               "AND COALESCE(release_event_type, '') NOT IN ('VERIFY', 'REFUND') THEN freeze_amt END)",
                               "口径说明：冻结记录没有释放原因字段，按「当日释放、且冻结事件既不是核销也不是退款」认定为过期兜底释放"),
    },
    'dws_fin_tenant_pay_method_di': {
        'refund_payment_amt': ("SUM(CASE WHEN refund_detail_status = 'SUCCESS' THEN refund_amt END)", "退款明细成功"),
        'invoice_order_qty': ("COUNT(DISTINCT CASE WHEN invoice_status = 'INVOICED' AND invoice_subject_type = 'MERCHANT_TO_VISITOR' THEN order_group_no END)",
                              "已开票、商户给游客开票"),
    },
    'dws_opr_approval_di': {
        'approval_minute_qty': ("SUM(CASE WHEN finish_time IS NOT NULL THEN approval_minute_qty END)", "已结束审批的耗时合计（求平均耗时用）"),
        'approval_timeout_qty': ("COUNT(CASE WHEN timeout_type = 1 THEN instance_no END)", "完成时间晚于超时时间，或进行中已超时"),
    },
    'dws_opr_complaint_di': {
        'complaint_resolved_qty': ("COUNT(CASE WHEN complaint_status IN ('RESOLVED', 'CLOSED') THEN complaint_no END)", "已解决或已关闭"),
        'complaint_overdue_qty': ("COUNT(CASE WHEN sla_timeout_type = 1 THEN complaint_no END)", "解决时间（未解决取当前时间）晚于 SLA 截止"),
    },
    'dws_opr_complaint_rt': {
        'complaint_resolved_qty': ("COUNT(CASE WHEN complaint_status IN ('RESOLVED', 'CLOSED') THEN complaint_no END)", "已解决或已关闭"),
        'complaint_overdue_qty': ("COUNT(CASE WHEN sla_timeout_type = 1 THEN complaint_no END)", "超 SLA"),
    },
    'dws_opr_device_di': {
        'online_minute_qty': ("SUM(CASE WHEN before_status = 'ACTIVE' THEN status_minute_qty END)",
                              "状态日志每条记前一状态持续分钟数，前一状态为有效（在线）的累加；当前未结束的区间次日补记"),
    },
    'dws_opr_notify_di': {
        'resource_consume_qty': ("SUM(consume_qty)", "资源批次日消耗量 = 昨日剩余 − 今日剩余（不含新购）"),
    },
    'dws_opr_package_subscription_df': {
        'active_subscription_qty': ("COUNT(DISTINCT CASE WHEN TO_DATE(start_time) <= '${bizdate_dash}' AND TO_DATE(expire_time) >= '${bizdate_dash}' AND subscription_status <> 'CANCELLED' THEN subscription_no END)",
                                    "快照日处于生效期、未取消的订购"),
        'package_amt': ("SUM(CASE WHEN TO_DATE(start_time) <= '${bizdate_dash}' AND TO_DATE(expire_time) >= '${bizdate_dash}' AND subscription_status <> 'CANCELLED' THEN package_amt END)",
                        "生效订购的套餐价格合计（DWD 已转元，不再除 100）"),
        'expiring_30d_subscription_qty': ("COUNT(DISTINCT CASE WHEN TO_DATE(expire_time) BETWEEN '${bizdate_dash}' AND DATE_ADD('${bizdate_dash}', 30) AND subscription_status <> 'CANCELLED' THEN subscription_no END)",
                                          "到期日在快照日起 30 天内"),
        'package_renew_qty': ("COUNT(DISTINCT CASE WHEN subscription_type = 'RENEW' AND TO_DATE(start_time) <= '${bizdate_dash}' AND TO_DATE(expire_time) >= '${bizdate_dash}' THEN subscription_no END)",
                              "生效订购中类型为续费的"),
    },
    'dws_opr_risk_rule_hit_di': {
        'blacklist_add_qty': ("COUNT(CASE WHEN change_type = 'ADD' THEN blacklist_no END)", "黑名单变更类型为新增"),
    },
    'dws_ord_combo_sku_trade_di': {
        'refund_ticket_qty': ("COUNT(DISTINCT CASE WHEN refund_status = 'COMPLETED' THEN ticket_no END)", "退款完成的票"),
    },
    'dws_ord_sku_play_date_booking_df': {
        'refund_ticket_qty': ("COUNT(DISTINCT CASE WHEN refund_status = 'COMPLETED' THEN ticket_no END)", "退款完成的票"),
        'advance_book_day_qty': ("SUM(CASE WHEN pay_time IS NOT NULL THEN DATEDIFF(play_date, TO_DATE(pay_time)) * buy_ticket_qty END)",
                                 "（游玩日 − 支付日）× 票数，求平均提前天数用"),
    },
    'dws_ord_tenant_entitlement_di': {
        'entitlement_total_qty': ("SUM(max_qty)", "计次 / 选择型权益的最大可用次数合计"),
        'quota_total_amt': ("SUM(CASE WHEN entitlement_type = 'QUOTA' THEN quota_amt END)", "额度型权益的额度合计（元）"),
        'activate_ticket_qty': (f"COUNT(DISTINCT CASE WHEN {ACTIVATE} THEN s.ticket_no END)", "延迟激活票首次使用即激活：状态由可用变为部分使用 / 已使用"),
        'activate_delay_day_qty': (f"SUM(CASE WHEN {ACTIVATE} THEN DATEDIFF(TO_DATE(s.change_time), TO_DATE(tk.tk_issue_time)) END)",
                                   "激活日 − 出票日（出票即支付完成），求平均激活延迟用"),
        'pending_activate_ticket_qty': (f"COUNT(CASE WHEN {PENDING_ACT} THEN ticket_no END)", "延迟激活且尚未首次核销的可用票"),
    },
    'dws_ord_tenant_ticket_stock_df': {
        'ticket_stock_qty': ("COUNT(DISTINCT ticket_no)", "按票状态（粒度键）计票存量"),
        'unverified_ticket_qty': (f"COUNT(DISTINCT CASE WHEN {UNVERIFIED} THEN ticket_no END)", "可用 / 部分使用、且未过有效期"),
        'unverified_amt': (f"SUM(CASE WHEN {UNVERIFIED} THEN unit_price_amt END)", "未核销在途票的单价合计（预收口径）"),
        'pending_activate_ticket_qty': (f"COUNT(CASE WHEN {PENDING_ACT} THEN ticket_no END)", "延迟激活且尚未首次核销的可用票"),
    },
    'dws_ord_tenant_refund_di': {
        'refund_process_hour_qty': ("SUM(CASE WHEN refund_status = 'COMPLETED' THEN process_hour_qty END)", "已完成退款的处理时长合计（求平均用）"),
        'auto_approve_refund_qty': ("COUNT(CASE WHEN refund_status IN ('APPROVED', 'PROCESSING', 'COMPLETED') AND COALESCE(approver_id, 0) = 0 THEN refund_no END)",
                                    "口径说明：退款单没有审批方式字段，按「已通过但没有审批人」认定为超时自动通过"),
        'refund_ticket_qty': ("COUNT(DISTINCT CASE WHEN refund_status = 'COMPLETED' THEN ticket_no END)", "退款完成的票"),
        'verified_refund_ticket_qty': ("COUNT(DISTINCT CASE WHEN refund_status = 'COMPLETED' AND before_ticket_status IN ('PARTIALLY_USED', 'USED') THEN ticket_no END)",
                                       "退款时票已部分 / 全部使用"),
    },
    'dws_ord_tenant_sku_channel_trade_di': {
        'order_qty': ("COUNT(DISTINCT CASE WHEN s.parent_order_no = '' THEN s.order_no END)", "不含套票子项（parent_order_no 非空的子单）"),
        'pay_buyer_qty': (f"COUNT(DISTINCT CASE WHEN {REAL_BUYER_COND} THEN s.buyer_customer_id END)", "已支付的真人买家，剔除匿名与占位买家"),
        'pay_buyer_bitmap': (f"BITMAP_UNION(TO_BITMAP(CASE WHEN {REAL_BUYER_COND} THEN s.buyer_customer_id END))", "同上，去重位图"),
        'cancel_amt': ("SUM(CASE WHEN s.cancel_time IS NOT NULL THEN s.order_amt END)", "已取消子单的下单金额"),
        'advance_book_day_qty': ("SUM(CASE WHEN s.pay_time IS NOT NULL THEN DATEDIFF(s.play_date, TO_DATE(s.pay_time)) * s.buy_ticket_qty END)",
                                 "（游玩日 − 支付日）× 票数"),
        'pay_minute_qty': ("SUM(CASE WHEN before_status = 'PENDING_PAY' AND after_status = 'PAID' THEN stay_minute_qty END)", "待支付 → 已支付的停留分钟（下单到支付耗时）"),
        'timeout_cancel_order_qty': ("COUNT(CASE WHEN s.before_status = 'PENDING_PAY' AND s.after_status = 'CANCELLED' AND s.change_time >= og.og_pay_timeout_time THEN s.order_no END)",
                                     "待支付 → 已取消，且取消时间不早于聚合单支付超时时间"),
    },
    'dws_ord_tenant_sku_trade_rt': {
        'pay_order_qty': ("COUNT(DISTINCT CASE WHEN order_status = 'PAID' AND pay_time IS NOT NULL THEN order_no END)", "当前状态已支付"),
        'pay_buyer_qty': ("COUNT(DISTINCT CASE WHEN pay_time IS NOT NULL AND buyer_customer_id > 0 AND buyer_type = 'CUSTOMER' THEN buyer_customer_id END)",
                          "口径说明：实时窗口内不关联游客维表，占位买家在当日离线结果中剔除"),
        'order_qty': ("COUNT(DISTINCT CASE WHEN parent_order_no = '' THEN order_no END)", "不含套票子项"),
        'cancel_order_qty': ("COUNT(DISTINCT CASE WHEN order_status = 'CANCELLED' THEN order_no END)", "当前状态已取消"),
        'staff_pay_amt': ("SUM(CASE WHEN operator_type = 'TENANT_STAFF' AND pay_time IS NOT NULL THEN unit_price_amt * buy_ticket_qty END)", "员工代下单的支付金额"),
        'refund_ticket_qty': ("SUM(CASE WHEN refund_status = 'COMPLETED' THEN refund_ticket_qty END)", "退款完成的票数"),
    },
    'dws_ord_tenant_sku_verify_di': {
        'verify_amt': ("SUM(CASE WHEN s.verify_result_type = 'SUCCESS' THEN s.verify_amt END)",
                       "核销成功的核销金额；DWD 已按「票单价 ÷ 可核销次数」分摊到每次核销，同一张票合计不超过票价"),
        'verify_after_pay_day_qty': ("SUM(CASE WHEN s.verify_result_type = 'SUCCESS' AND s.verify_time = tk.tk_first_verify_time THEN DATEDIFF(TO_DATE(s.verify_time), TO_DATE(tk.tk_issue_time)) END)",
                                     "票的首次核销日 − 出票日（每张票只在首次核销那次记）"),
    },
    'dws_ord_tenant_sku_verify_rt': {
        'verify_amt': ("SUM(CASE WHEN verify_result_type = 'SUCCESS' THEN verify_amt END)", "核销成功的核销金额（DWD 已按可核销次数分摊）"),
    },
    'dws_prd_sku_price_di': {
        'list_price_amt': ("MAX(CASE WHEN price_date = '${bizdate_dash}' THEN list_price_amt END)", "价格日历中统计日当天生效的挂牌价"),
    },
    'dws_trf_distributor_credit_df': {
        'new_distribution_relation_qty': ("COUNT(DISTINCT CASE WHEN TO_DATE(create_time) = '${bizdate_dash}' THEN relation_no END)", "统计日新建的分销关系"),
    },
    'dws_inv_sku_stock_rt': {},
    'ads_ord_refund_analysis_di': {
        'ota_refund_ticket_qty': ("SUM(CASE WHEN initiator_type = 'OTA' THEN refund_ticket_qty END)", "退款发起方 = OTA"),
        'ota_refund_amt': ("SUM(CASE WHEN initiator_type = 'OTA' THEN refund_amt END)", "退款发起方 = OTA"),
    },
    'ads_sup_tenant_trade_wk': {
        'pay_amt_wow_rate': ("ROUND((u.pay_amt - p.p_pay_amt) * 100 / NULLIF(p.p_pay_amt, 0), 6)", "（本周 − 上一周）÷ 上一周 × 100；上一周为 0 时为空"),
    },
    'ads_sup_tenant_trade_mo': {
        'pay_amt_mom_rate': ("ROUND((u.pay_amt - p.p_pay_amt) * 100 / NULLIF(p.p_pay_amt, 0), 6)", "（本月 − 上月）÷ 上月 × 100；上月为 0 时为空"),
    },
    'ads_inv_realtime_stock_rt': {
        'prededuct_5m_qty': ("COALESCE(c.c_prededuct_qty, 0)", "近 5 分钟预扣变动的冻结量（实时库存变动明细）"),
        'prededuct_release_5m_qty': ("COALESCE(c.c_release_qty, 0)", "近 5 分钟回滚释放的冻结量"),
    },
}

ORDER_GROUP_TIMEOUT = (f"LEFT JOIN (SELECT order_group_no AS og_no, MAX(pay_timeout_time) AS og_pay_timeout_time FROM dwd.dwd_ord_order_group_di\n"
                       f"           WHERE {WIN400} GROUP BY order_group_no) og ON og.og_no = s.order_group_no")
SUB = {
    'dws_cus_tenant_growth_di': [
        ("FROM dwd.dwd_cus_customer_register_di s",
         "FROM dwd.dwd_cus_customer_register_di s\nLEFT JOIN (SELECT buyer_customer_id AS fp_customer_id, MIN(first_pay_date) AS fp_first_pay_date FROM dws.dws_cus_customer_lifetime_df\n"
         "           WHERE travel_date = '${bizdate}' GROUP BY buyer_customer_id) fp ON fp.fp_customer_id = s.customer_id"),
        ("FROM dim.dim_cus_customer_zip s", "FROM dim.dim_cus_customer_zip s\n" + zip_changed('pv', 'customer_id', 'auth_status', '').replace('{tbl}', 'dim.dim_cus_customer_zip')),
    ],
    'dws_sup_tenant_onboard_di': [
        ("FROM dim.dim_sup_tenant_zip s", "FROM dim.dim_sup_tenant_zip s\n" + zip_changed('pv', 'tenant_id', 'auth_status', '').replace('{tbl}', 'dim.dim_sup_tenant_zip')),
    ],
    'dws_ord_tenant_entitlement_di': [("FROM dwd.dwd_ord_ticket_status_log_di s", "FROM dwd.dwd_ord_ticket_status_log_di s\n" + TICKET_ONE)],
    'dws_ord_tenant_sku_verify_di': [("FROM dwd.dwd_ord_verify_di s", "FROM dwd.dwd_ord_verify_di s\n" + TICKET_ONE)],
    'dws_ord_tenant_sku_channel_trade_di': [
        ("FROM dwd.dwd_ord_order_di s", "FROM dwd.dwd_ord_order_di s\n" + REAL_BUYER),
        ("FROM dwd.dwd_ord_order_status_log_di s", "FROM dwd.dwd_ord_order_status_log_di s\n" + ORDER_GROUP_TIMEOUT),
    ],
    'ads_sup_tenant_trade_wk': [
        ("  FROM src_tenant_trade u",
         "  FROM src_tenant_trade u\n  LEFT JOIN (SELECT seller_tenant_id AS p_tenant_id, SUM(pay_amt) AS p_pay_amt FROM dws.dws_sup_tenant_trade_di\n"
         "             WHERE travel_date BETWEEN DATE_FORMAT(DATE_SUB(TO_DATE('${last_week_start}', 'yyyyMMdd'), 7), 'yyyyMMdd')\n"
         "                                   AND DATE_FORMAT(DATE_SUB(TO_DATE('${last_week_end}', 'yyyyMMdd'), 7), 'yyyyMMdd')\n"
         "             GROUP BY seller_tenant_id) p ON p.p_tenant_id = u.seller_tenant_id   -- 上一周（同长度区间）支付金额"),
    ],
    'ads_sup_tenant_trade_mo': [
        ("  FROM src_tenant_trade u",
         "  FROM src_tenant_trade u\n  LEFT JOIN (SELECT seller_tenant_id AS p_tenant_id, SUM(pay_amt) AS p_pay_amt FROM dws.dws_sup_tenant_trade_di\n"
         "             WHERE travel_date BETWEEN DATE_FORMAT(ADD_MONTHS(TO_DATE('${last_month_start}', 'yyyyMMdd'), -1), 'yyyyMMdd')\n"
         "                                   AND DATE_FORMAT(DATE_SUB(TO_DATE('${last_month_start}', 'yyyyMMdd'), 1), 'yyyyMMdd')\n"
         "             GROUP BY seller_tenant_id) p ON p.p_tenant_id = u.seller_tenant_id   -- 上上月（上月的环比基期）支付金额"),
    ],
    'ads_inv_realtime_stock_rt': [
        ("  FROM src_sku_stock u",
         "  FROM src_sku_stock u\n  LEFT JOIN (SELECT sku_id AS c_sku_id, pool_no AS c_pool_no,\n"
         "                    SUM(CASE WHEN change_type = 'PRE_DEDUCT' THEN ABS(frozen_change_qty) END) AS c_prededuct_qty,\n"
         "                    SUM(CASE WHEN change_type = 'ROLLBACK' THEN ABS(frozen_change_qty) END) AS c_release_qty\n"
         "             FROM dwd.dwd_inv_pool_change_rt\n"
         "             WHERE change_time >= DATE_SUB(NOW(), INTERVAL 5 MINUTE)\n"
         "             GROUP BY sku_id, pool_no) c ON c.c_sku_id = u.sku_id AND c.c_pool_no = u.pool_no   -- 近 5 分钟库存变动"),
    ],
}

# 整表手写 ------------------------------------------------------------------------------------------
FULL = {}


def hdr(full, cn, src, rules, perf):
    return '\n'.join([f'-- {full}  {cn}', f'-- 来源：{src}', '-- 生成方式：手写（结构不适合按字段自动翻译）；业务规则：']
                     + [f'--   · {x}' for x in rules] + ['-- 性能：'] + [f'--   · {x}' for x in perf]) + '\n\n'


FULL['dws_cus_customer_lifetime_df'] = ('hive', hdr('dws.dws_cus_customer_lifetime_df', '游客累计至今汇总', 'dws_cus_customer_lifetime_df（T-1）+ dws_cus_customer_trade_di + dim_cus_customer_zip', [
    '累计口径用「昨日快照 + 今日增量」滚动，不回扫全部历史；首次上线需按日期顺序回刷一次',
    '首次 / 最近支付日、累计单数 / 金额：昨日快照与今日支付合并；近 30 天：读 30 个日分区',
    '复购（buyer_type = 1）：近 30 天支付子单数 ≥ 2',
    '支付买家：真人买家（customer_type = REAL），剔除匿名与商户代下单占位买家；本行（游客 × 商户）有支付记 1',
    '老客买家：今日支付、且首次支付早于今日'], ['只读 T-1 一个快照分区 + 30 个日汇总分区；游客维表只取当前版本的 REAL 账号'])
    + f"""WITH today AS (   -- 今日支付
    SELECT buyer_customer_id, seller_tenant_id, SUM(pay_order_qty) AS pay_order_qty, SUM(pay_amt) AS pay_amt
    FROM dws.dws_cus_customer_trade_di
    WHERE travel_date = '${{bizdate}}' AND pay_order_qty > 0
    GROUP BY buyer_customer_id, seller_tenant_id
),
prev AS (         -- 昨日快照
    SELECT buyer_customer_id, seller_tenant_id, first_pay_date, last_pay_date, total_pay_order_qty, total_pay_amt
    FROM dws.dws_cus_customer_lifetime_df
    WHERE travel_date = {Y}
),
d30 AS (          -- 近 30 天（含今日）
    SELECT buyer_customer_id, seller_tenant_id, SUM(pay_order_qty) AS pay_order_30d_qty, SUM(pay_amt) AS pay_30d_amt
    FROM dws.dws_cus_customer_trade_di
    WHERE travel_date BETWEEN DATE_FORMAT(DATE_SUB(TO_DATE('${{bizdate}}', 'yyyyMMdd'), 29), 'yyyyMMdd') AND '${{bizdate}}'
    GROUP BY buyer_customer_id, seller_tenant_id
),
real_buyer AS (   -- 真人账号
    SELECT customer_id FROM dim.dim_cus_customer_zip
    WHERE travel_date = '${{bizdate}}' AND end_date = '9999-12-31' AND customer_type = 'REAL'
),
m AS (
    SELECT COALESCE(t.buyer_customer_id, p.buyer_customer_id) AS buyer_customer_id,
           COALESCE(t.seller_tenant_id, p.seller_tenant_id) AS seller_tenant_id,
           COALESCE(p.first_pay_date, IF(t.buyer_customer_id IS NOT NULL, '${{bizdate_dash}}', NULL)) AS first_pay_date,
           IF(t.buyer_customer_id IS NOT NULL, '${{bizdate_dash}}', p.last_pay_date) AS last_pay_date,
           COALESCE(p.total_pay_order_qty, 0) + COALESCE(t.pay_order_qty, 0) AS total_pay_order_qty,
           COALESCE(p.total_pay_amt, 0) + COALESCE(t.pay_amt, 0) AS total_pay_amt,
           t.buyer_customer_id IS NOT NULL AS paid_today
    FROM today t
    FULL OUTER JOIN prev p ON p.buyer_customer_id = t.buyer_customer_id AND p.seller_tenant_id = t.seller_tenant_id
)
INSERT OVERWRITE TABLE dws.dws_cus_customer_lifetime_df PARTITION (travel_date = '${{bizdate}}')
SELECT /*+ BROADCAST(r) */
    m.buyer_customer_id,
    m.seller_tenant_id,
    m.first_pay_date,
    m.last_pay_date,
    m.total_pay_order_qty,
    m.total_pay_amt,
    COALESCE(d.pay_order_30d_qty, 0)                                              AS pay_order_30d_qty,
    COALESCE(d.pay_30d_amt, 0)                                                    AS pay_30d_amt,
    CAST(IF(COALESCE(d.pay_order_30d_qty, 0) >= 2, 1, 0) AS TINYINT)              AS buyer_type,
    IF(m.paid_today AND r.customer_id IS NOT NULL, 1, 0)                          AS pay_buyer_qty,
    TO_BITMAP(IF(m.paid_today AND r.customer_id IS NOT NULL, m.buyer_customer_id, NULL)) AS pay_buyer_bitmap,
    IF(m.paid_today AND r.customer_id IS NOT NULL AND m.first_pay_date < '${{bizdate_dash}}', 1, 0) AS repeat_buyer_qty,
    TO_BITMAP(IF(m.paid_today AND r.customer_id IS NOT NULL AND m.first_pay_date < '${{bizdate_dash}}', m.buyer_customer_id, NULL)) AS repeat_buyer_bitmap,
    {NOW} AS etl_time
FROM m
LEFT JOIN d30 d ON d.buyer_customer_id = m.buyer_customer_id AND d.seller_tenant_id = m.seller_tenant_id
LEFT JOIN real_buyer r ON r.customer_id = m.buyer_customer_id;
""")

FULL['dws_sup_tenant_lifetime_df'] = ('hive', hdr('dws.dws_sup_tenant_lifetime_df', '商户累计至今汇总', 'dws_sup_tenant_lifetime_df（T-1）+ dws_sup_tenant_trade_di', [
    '字典原写来源为游客交易汇总，商户口径应取商户经营日汇总 dws_sup_tenant_trade_di（同一份订单，粒度更合适）',
    '累计用「昨日快照 + 今日」滚动；近 30 天读 30 个日分区；动销 = 当日支付金额 > 0'], ['只读 T-1 快照 + 30 个日分区'])
    + f"""WITH today AS (
    SELECT seller_tenant_id, SUM(pay_amt) AS pay_amt
    FROM dws.dws_sup_tenant_trade_di WHERE travel_date = '${{bizdate}}' AND pay_amt > 0
    GROUP BY seller_tenant_id
),
prev AS (
    SELECT seller_tenant_id, first_pay_date, last_pay_date, total_pay_amt
    FROM dws.dws_sup_tenant_lifetime_df WHERE travel_date = {Y}
),
d30 AS (
    SELECT seller_tenant_id, SUM(pay_amt) AS pay_30d_amt, COUNT(DISTINCT IF(pay_amt > 0, travel_date, NULL)) AS active_day_30d_qty
    FROM dws.dws_sup_tenant_trade_di
    WHERE travel_date BETWEEN DATE_FORMAT(DATE_SUB(TO_DATE('${{bizdate}}', 'yyyyMMdd'), 29), 'yyyyMMdd') AND '${{bizdate}}'
    GROUP BY seller_tenant_id
)
INSERT OVERWRITE TABLE dws.dws_sup_tenant_lifetime_df PARTITION (travel_date = '${{bizdate}}')
SELECT
    COALESCE(t.seller_tenant_id, p.seller_tenant_id)                                  AS seller_tenant_id,
    COALESCE(p.first_pay_date, IF(t.seller_tenant_id IS NOT NULL, '${{bizdate_dash}}', NULL)) AS first_pay_date,
    IF(t.seller_tenant_id IS NOT NULL, '${{bizdate_dash}}', p.last_pay_date)            AS last_pay_date,
    COALESCE(p.total_pay_amt, 0) + COALESCE(t.pay_amt, 0)                             AS total_pay_amt,
    COALESCE(d.pay_30d_amt, 0)                                                        AS pay_30d_amt,
    COALESCE(d.active_day_30d_qty, 0)                                                 AS active_day_30d_qty,
    IF(t.seller_tenant_id IS NOT NULL, 1, 0)                                          AS active_tenant_qty,
    TO_BITMAP(t.seller_tenant_id)                                                     AS active_tenant_bitmap,
    {NOW} AS etl_time
FROM today t
FULL OUTER JOIN prev p ON p.seller_tenant_id = t.seller_tenant_id
LEFT JOIN d30 d ON d.seller_tenant_id = COALESCE(t.seller_tenant_id, p.seller_tenant_id);
""")

FULL['dws_trf_distributor_trade_di'] = ('hive', hdr('dws.dws_trf_distributor_trade_di', '分销商×供应商×SKU×层级 分销日汇总', 'dwd_trf_distribution_settle_di + dwd_ord_refund_ticket_di', [
    '一行明细 = 采购链上一级的一笔采购付款：分销商（付款方）向供应商（收款方）采购；只取 2 级及以上（1 级为游客付款）',
    '售出 = 本级售价 sale_amt（支付记录 amount），采购 = 本级结算价 settle_amt，利润 = profit_amt',
    '分销层级合计：每张票取其最大层级，只记在该票的最大层级那一行，粒度汇总后求平均层级用',
    '退款票：退款完成的票按票号回找当日及历史采购链（近 400 天），落到对应分销商 / 供应商 / 层级',
    '动销分销商：本行有分销票即为 1（粒度含分销商），任意周期用位图去重'], ['采购链明细按票号关联退款票，只取近 400 天分区'])
    + f"""WITH settle AS (
    SELECT distributor_tenant_id, supplier_tenant_id, sku_id, chain_level_no, ticket_no, sale_amt, settle_amt, profit_amt,
           MAX(chain_level_no) OVER (PARTITION BY ticket_no) AS max_level_no
    FROM dwd.dwd_trf_distribution_settle_di
    WHERE travel_date = '${{bizdate}}' AND chain_level_no >= 2   -- 1 级为游客付款给末级分销商，不算分销采购
),
chain AS (        -- 退款票回找采购链
    SELECT ticket_no, distributor_tenant_id, supplier_tenant_id, sku_id, chain_level_no
    FROM dwd.dwd_trf_distribution_settle_di
    WHERE {WIN400} AND chain_level_no >= 2
    GROUP BY ticket_no, distributor_tenant_id, supplier_tenant_id, sku_id, chain_level_no
),
refund AS (
    SELECT c.distributor_tenant_id, c.supplier_tenant_id, c.sku_id, c.chain_level_no, COUNT(DISTINCT r.ticket_no) AS refund_ticket_qty
    FROM (SELECT DISTINCT ticket_no FROM dwd.dwd_ord_refund_ticket_di WHERE travel_date = '${{bizdate}}' AND refund_status = 'COMPLETED') r
    JOIN chain c ON c.ticket_no = r.ticket_no
    GROUP BY c.distributor_tenant_id, c.supplier_tenant_id, c.sku_id, c.chain_level_no
),
agg AS (
    SELECT distributor_tenant_id, supplier_tenant_id, sku_id, chain_level_no,
           COUNT(DISTINCT ticket_no)                                         AS distribution_ticket_qty,
           SUM(sale_amt)                                                     AS distribution_sale_amt,
           SUM(settle_amt)                                                   AS distribution_purchase_amt,
           SUM(profit_amt)                                                   AS distribution_profit_amt,
           SUM(IF(chain_level_no = max_level_no, chain_level_no, 0))         AS chain_level_qty
    FROM settle
    GROUP BY distributor_tenant_id, supplier_tenant_id, sku_id, chain_level_no
)
INSERT OVERWRITE TABLE dws.dws_trf_distributor_trade_di PARTITION (travel_date = '${{bizdate}}')
SELECT
    COALESCE(a.distributor_tenant_id, r.distributor_tenant_id)       AS distributor_tenant_id,
    COALESCE(a.supplier_tenant_id, r.supplier_tenant_id)             AS supplier_tenant_id,
    COALESCE(a.sku_id, r.sku_id)                                     AS sku_id,
    COALESCE(a.chain_level_no, r.chain_level_no)                     AS chain_level_no,
    COALESCE(a.distribution_ticket_qty, 0)                           AS distribution_ticket_qty,
    COALESCE(a.distribution_sale_amt, 0)                             AS distribution_sale_amt,
    COALESCE(a.distribution_purchase_amt, 0)                         AS distribution_purchase_amt,
    COALESCE(a.distribution_profit_amt, 0)                           AS distribution_profit_amt,
    COALESCE(r.refund_ticket_qty, 0)                                 AS refund_ticket_qty,
    COALESCE(a.chain_level_qty, 0)                                   AS chain_level_qty,
    IF(a.distribution_ticket_qty > 0, 1, 0)                          AS active_distributor_qty,
    TO_BITMAP(IF(a.distribution_ticket_qty > 0, a.distributor_tenant_id, NULL)) AS active_distributor_bitmap,
    {NOW} AS etl_time
FROM agg a
FULL OUTER JOIN refund r
  ON r.distributor_tenant_id = a.distributor_tenant_id AND r.supplier_tenant_id = a.supplier_tenant_id
 AND r.sku_id = a.sku_id AND r.chain_level_no = a.chain_level_no;
""")

FULL['dws_sup_staff_operate_di'] = ('hive', hdr('dws.dws_sup_staff_operate_di', '员工操作日汇总', 'dwd_ord_order_di + dwd_ord_verify_di + dwd_ord_refund_di', [
    '员工 = 订单操作人（operator_type = TENANT_STAFF 的 operator_id）/ 核销操作人 / 发起退款的商户员工（initiator_type = MERCHANT 的 initiator_id）',
    '原自动生成版本把退款按审批人归属、代下单没有员工粒度，此处按发起人 / 操作人改正'], ['三个来源各自按（租户, 员工）预聚合后 UNION ALL'])
    + f"""WITH x AS (
    SELECT tenant_id, operator_id AS staff_id,
           COUNT(DISTINCT order_no) AS staff_order_qty,
           SUM(CASE WHEN pay_time IS NOT NULL THEN unit_price_amt * buy_ticket_qty END) AS staff_pay_amt,
           0 AS staff_verify_qty, 0 AS staff_refund_qty
    FROM dwd.dwd_ord_order_di
    WHERE travel_date = '${{bizdate}}' AND operator_type = 'TENANT_STAFF'
    GROUP BY tenant_id, operator_id
    UNION ALL
    SELECT tenant_id, operator_id, 0, 0, COUNT(CASE WHEN verify_result_type = 'SUCCESS' THEN verify_no END), 0
    FROM dwd.dwd_ord_verify_di
    WHERE travel_date = '${{bizdate}}' AND operator_id > 0
    GROUP BY tenant_id, operator_id
    UNION ALL
    SELECT tenant_id, initiator_id, 0, 0, 0, COUNT(refund_no)
    FROM dwd.dwd_ord_refund_di
    WHERE travel_date = '${{bizdate}}' AND initiator_type = 'MERCHANT'
    GROUP BY tenant_id, initiator_id
)
INSERT OVERWRITE TABLE dws.dws_sup_staff_operate_di PARTITION (travel_date = '${{bizdate}}')
SELECT tenant_id, staff_id,
       SUM(staff_order_qty)  AS staff_order_qty,
       SUM(staff_pay_amt)    AS staff_pay_amt,
       SUM(staff_verify_qty) AS staff_verify_qty,
       SUM(staff_refund_qty) AS staff_refund_qty,
       {NOW} AS etl_time
FROM x
GROUP BY tenant_id, staff_id;
""")

FULL['dws_inv_sku_stock_df'] = ('hive', hdr('dws.dws_inv_sku_stock_df', 'SKU 库存日快照', 'dwd_inv_pool_snapshot_df + dim_inv_unit_df + dwd_inv_pool_change_di', [
    '一行 = 一个库存池（池编号唯一确定 SKU、游玩日、房型、场次），库存量取池日快照',
    '已售 = 总量 − 可售 − 冻结；售罄 = 在售且可售为 0',
    '座位 / 房间：从资源个体维表按池统计总数与已占用数（快照）',
    '预扣 / 确认 / 回滚：当日库存池变动，取冻结量变化的绝对值'], ['三个来源都按池编号预聚合后左关联池快照'])
    + f"""WITH pool AS (
    SELECT pool_no, sku_id, play_date, room_type_code, show_time, total_qty, available_qty, frozen_qty, sold_qty, pool_status
    FROM dwd.dwd_inv_pool_snapshot_df WHERE travel_date = '${{bizdate}}'
),
unit AS (
    SELECT pool_no, COUNT(unit_no) AS unit_total_qty, COUNT(CASE WHEN unit_status = 'OCCUPIED' THEN unit_no END) AS unit_occupied_qty
    FROM dim.dim_inv_unit_df WHERE travel_date = '${{bizdate}}'
    GROUP BY pool_no
),
chg AS (
    SELECT pool_no,
           SUM(CASE WHEN change_type = 'PRE_DEDUCT' THEN ABS(frozen_change_qty) END) AS prededuct_qty,
           SUM(CASE WHEN change_type = 'CONFIRM' THEN ABS(frozen_change_qty) END)    AS prededuct_confirm_qty,
           SUM(CASE WHEN change_type = 'ROLLBACK' THEN ABS(frozen_change_qty) END)   AS prededuct_release_qty
    FROM dwd.dwd_inv_pool_change_di WHERE travel_date = '${{bizdate}}'
    GROUP BY pool_no
)
INSERT OVERWRITE TABLE dws.dws_inv_sku_stock_df PARTITION (travel_date = '${{bizdate}}')
SELECT
    p.sku_id, p.pool_no, p.play_date, p.room_type_code, p.show_time,
    p.total_qty                                                       AS stock_total_qty,
    p.available_qty                                                   AS stock_available_qty,
    p.frozen_qty                                                      AS stock_frozen_qty,
    p.total_qty - p.available_qty - p.frozen_qty                      AS stock_sold_qty,
    IF(p.pool_status = 'ON_SALE' AND p.available_qty = 0, 1, 0)       AS sellout_pool_qty,
    COALESCE(u.unit_occupied_qty, 0)                                  AS unit_occupied_qty,
    COALESCE(u.unit_total_qty, 0)                                     AS unit_total_qty,
    COALESCE(c.prededuct_qty, 0)                                      AS prededuct_qty,
    COALESCE(c.prededuct_confirm_qty, 0)                              AS prededuct_confirm_qty,
    COALESCE(c.prededuct_release_qty, 0)                              AS prededuct_release_qty,
    {NOW} AS etl_time
FROM pool p
LEFT JOIN unit u ON u.pool_no = p.pool_no
LEFT JOIN chg c ON c.pool_no = p.pool_no;
""")

FULL['dws_inv_sku_stock_rt'] = ('flink', hdr('dws.dws_inv_sku_stock_rt', 'SKU 实时库存', 'ods_inv_inventory_pool_rt（CDC，当前库存）+ dwd_inv_pool_change_rt（当日变动）', [
    '库存量取库存池 CDC 当前值（Flink 把 CDC 源当作随变更更新的表，聚合结果自动回撤）；与离线同口径：已售 = 总量 − 可售 − 冻结，售罄 = 在售且可售为 0',
    '预扣 / 回滚释放：当日库存变动的冻结量绝对值',
    '原自动生成版本对变动类型求和、对变动前总量求和，口径错误，此处重写'], ['两路结果按（SKU, 池）常规关联，写 StarRocks 主键模型表'])
    + """INSERT INTO dws.dws_inv_sku_stock_rt
SELECT
    DATE_FORMAT(CURRENT_TIMESTAMP, 'yyyyMMdd')                          AS travel_date,
    p.sku_id,
    p.pool_no,
    p.total_quantity                                                   AS stock_total_qty,
    p.available_quantity                                               AS stock_available_qty,
    p.frozen_quantity                                                  AS stock_frozen_qty,
    p.total_quantity - p.available_quantity - p.frozen_quantity        AS stock_sold_qty,
    IF(p.pool_status = 'ON_SALE' AND p.available_quantity = 0, 1, 0)   AS sellout_pool_qty,
    COALESCE(c.prededuct_qty, 0)                                       AS prededuct_qty,
    COALESCE(c.prededuct_release_qty, 0)                               AS prededuct_release_qty,
    CURRENT_TIMESTAMP                                                  AS update_time
FROM ods_inv_inventory_pool_rt p
LEFT JOIN (
    SELECT pool_no,
           SUM(CASE WHEN change_type = 'PRE_DEDUCT' THEN ABS(frozen_change_qty) END) AS prededuct_qty,
           SUM(CASE WHEN change_type = 'ROLLBACK' THEN ABS(frozen_change_qty) END)   AS prededuct_release_qty
    FROM dwd_inv_pool_change_rt
    WHERE travel_date = DATE_FORMAT(CURRENT_TIMESTAMP, 'yyyyMMdd')
    GROUP BY pool_no
) c ON c.pool_no = p.pool_no
WHERE p.deleted = 0;
""")

# ============================================================ DIM / DWD
RAW = {}
AGE_BAND = ("CASE WHEN {a} IS NULL THEN 'UNKNOWN' WHEN {a} < 18 THEN '0_17' WHEN {a} <= 25 THEN '18_25' WHEN {a} <= 35 THEN '26_35' "
            "WHEN {a} <= 45 THEN '36_45' WHEN {a} <= 60 THEN '46_60' ELSE '60_PLUS' END")


def age_of(birth, ref):
    return f"FLOOR(MONTHS_BETWEEN(TO_DATE({ref}), TO_DATE({birth})) / 12)"


ID_BIRTH = "IF(ticket_person_latest.id_type = 'ID_CARD' AND LENGTH(ticket_person_latest.id_number) >= 17, TO_DATE(SUBSTR(ticket_person_latest.id_number, 7, 8), 'yyyyMMdd'), NULL)"
ID_AGE = age_of(ID_BIRTH, 'ticket_dtl.play_date')
LVL = lambda r, ps: '(1' + ''.join(f' + IF({p}.id IS NULL, 0, 1)' for p in ps) + ')'


def chain_cols(r, sup, dis):
    """采购链层级：r 为本关系，p1..p3 为逐级上级关系；level1 = 源头供应商，levelN = 第 N-1 级关系的分销商"""
    L = LVL(r, ['p1', 'p2', 'p3'])
    by = lambda col, m: 'CASE ' + L + ' ' + ' '.join(f'WHEN {k} THEN {v}.{col}' for k, v in m) + ' END'
    return {
        'chain_level_no': (L, '本关系往上逐级找上级关系（parent_relation_id，最多 4 级）的层数'),
        'level1_tenant_id': (by(sup, [(1, r), (2, 'p1'), (3, 'p2'), (4, 'p3')]), '最顶层关系的供应商 = 源头供应商'),
        'level2_tenant_id': (by(dis, [(1, r), (2, 'p1'), (3, 'p2'), (4, 'p3')]), '最顶层关系的分销商'),
        'level3_tenant_id': (by(dis, [(2, r), (3, 'p1'), (4, 'p2')]), '第 2 层关系的分销商'),
        'level4_tenant_id': (by(dis, [(3, r), (4, 'p1')]), '第 3 层关系的分销商'),
    }


LINE.update({
    'dim_cus_customer_zip': {'age_band_code': (AGE_BAND.format(a=age_of('customer_latest.birthday', "'${bizdate_dash}'")), '按生日算统计日年龄后分段')},
    'dwd_cus_customer_register_di': {'age_band_code': (AGE_BAND.format(a=age_of('customer_latest.birthday', 'customer_latest.create_time')), '按生日算注册时年龄后分段')},
    'dim_opr_currency_f': {'decimal_digit_qty': ("CASE WHEN i18n_currency_src.currency_code IN ('JPY', 'KRW') THEN 0 ELSE 2 END", 'ISO 4217：日元、韩元无小数，其余 2 位')},
    'dim_opr_package_df': {'app_code_list_desc': ('paa.app_code_list', '套餐绑定的应用编码，去重排序后逗号拼接')},
    'dim_sup_role_df': {'permission_code_list_desc': ('rpa.permission_code_list', '角色绑定的权限编码，去重排序后逗号拼接')},
    'dim_sup_staff_zip': {'role_code_list_desc': ('sra.role_code_list', '员工绑定的角色编码，去重排序后逗号拼接'),
                          'role_name_list_desc': ('sra.role_name_list', '员工绑定的角色名称，去重排序后逗号拼接')},
    'dim_sup_tenant_zip': {'package_id': ('package_subscription_latest.package_id', '快照日处于生效期的订购中，生效时间最晚的一笔')},
    'dim_trf_distribution_relation_zip': chain_cols('distribution_relation_src', 'supplier_tenant_id', 'distributor_tenant_id'),
    'dwd_trf_distribution_credit_rt': chain_cols('a', 'supplier_tenant_id', 'distributor_tenant_id'),
    'dwd_fin_fund_flow_di': {'flow_direction_type': ('CASE WHEN fund_flow_latest.amount >= 0 THEN 1 ELSE 2 END', '变动金额 ≥ 0 为入账（1），< 0 为出账（2）')},
    'dwd_fin_resource_batch_di': {'consume_qty': ('GREATEST(COALESCE(batch_prev.prev_remaining, resource_batch_chg.total_quantity) - resource_batch_chg.remaining_quantity, 0)',
                                                  '昨日剩余 − 今日剩余；今日新建批次按 总量 − 剩余；不含新购')},
    'dwd_inv_pool_change_di': {
        'change_type': ("CASE WHEN fd > 0 AND ad < 0 THEN 'PRE_DEDUCT' WHEN fd < 0 AND ad > 0 THEN 'ROLLBACK' WHEN fd < 0 AND COALESCE(ad, 0) = 0 THEN 'CONFIRM' ELSE 'ADJUST' END"
                        .replace('fd', '(inventory_pool_chg.frozen_quantity - LAG(inventory_pool_chg.frozen_quantity) OVER (PARTITION BY inventory_pool_chg.id ORDER BY inventory_pool_chg.binlog_time))')
                        .replace('ad', '(inventory_pool_chg.available_quantity - LAG(inventory_pool_chg.available_quantity) OVER (PARTITION BY inventory_pool_chg.id ORDER BY inventory_pool_chg.binlog_time))'),
                        '冻结增、可售减 = 预扣；冻结减、可售增 = 回滚；冻结减、可售不变 = 确认（转已售）；其余 = 人工调整'),
        'order_no': ('CAST(NULL AS STRING)', '源端缺口：库存池变更没有记录引起变动的订单（数量型库存池无法回溯），已登记待确认事项')},
    'dwd_inv_pool_change_rt': {
        'change_type': ("CASE WHEN fd > 0 AND ad < 0 THEN 'PRE_DEDUCT' WHEN fd < 0 AND ad > 0 THEN 'ROLLBACK' WHEN fd < 0 AND COALESCE(ad, 0) = 0 THEN 'CONFIRM' ELSE 'ADJUST' END"
                        .replace('fd', '(a.frozen_quantity - LAG(a.frozen_quantity) OVER (PARTITION BY a.id ORDER BY a.binlog_time))')
                        .replace('ad', '(a.available_quantity - LAG(a.available_quantity) OVER (PARTITION BY a.id ORDER BY a.binlog_time))'),
                        '同离线：按冻结 / 可售变化方向判定'),
        'order_no': ('CAST(NULL AS STRING)', '源端缺口：同离线')},
    'dwd_opr_approval_di': {
        'finish_time': ("CASE WHEN approval_instance_latest.instance_status IN ('APPROVED', 'REJECTED', 'CANCELLED') THEN approval_instance_latest.update_time END",
                        '状态为终态（通过 / 拒绝 / 取消）时的最后更新时间'),
        'timeout_type': ("CASE WHEN COALESCE(CASE WHEN approval_instance_latest.instance_status IN ('APPROVED', 'REJECTED', 'CANCELLED') THEN approval_instance_latest.update_time END, CURRENT_TIMESTAMP()) > approval_instance_latest.timeout_at THEN 1 ELSE 0 END",
                         '结束时间（进行中取当前时间）晚于节点截止时间')},
    'dwd_opr_audit_log_di': {'night_action_type': ('CASE WHEN HOUR(audit_log_chg.create_time) < 6 THEN 1 ELSE 0 END', '0~6 点（不含 6 点）的操作')},
    'dwd_opr_blacklist_log_di': {'change_type': ("CASE blacklist_chg.blacklist_status WHEN 'ACTIVE' THEN 'ADD' WHEN 'EXPIRED' THEN 'EXPIRE' WHEN 'REVOKED' THEN 'REVOKE' END",
                                                 '每条变更记录按变更后状态：有效 = 新增，已过期 = 到期失效，已撤销 = 撤销')},
    'dwd_opr_complaint_di': {
        'create_time_hour_no': ('HOUR(complaint_latest.create_time)', '投诉提交时间取小时'),
        'sla_timeout_type': ("CASE WHEN COALESCE(CASE WHEN complaint_latest.complaint_status IN ('RESOLVED', 'CLOSED') THEN complaint_latest.binlog_time END, CURRENT_TIMESTAMP()) > complaint_latest.sla_deadline THEN 1 ELSE 0 END",
                             '解决时间（未解决取当前时间）晚于 SLA 截止')},
    'dwd_opr_complaint_rt': {
        'create_time_hour_no': ('HOUR(a.create_time)', '投诉提交时间取小时'),
        'sla_timeout_type': ("CASE WHEN COALESCE(CASE WHEN a.complaint_status IN ('RESOLVED', 'CLOSED') THEN a.binlog_time END, CURRENT_TIMESTAMP) > a.sla_deadline THEN 1 ELSE 0 END", '同离线')},
    'dwd_opr_device_status_log_rt': {
        'before_status': ('CAST(NULL AS STRING)', '口径说明：CDC 流只带变更后镜像，变更前状态由离线日表补齐（设备在线时长等指标取离线）'),
        'after_status': ('a.device_status', 'CDC 变更后状态')},
    'dwd_ord_order_group_di': {
        'first_pay_time': ('payment_record_latest.first_pay_time', '近 400 天支付记录中，收款（INBOUND）且已支付的最早支付时间'),
        'order_ticket_qty': ('order_latest.order_ticket_qty', '聚合单下子单购买数量合计')},
    'dwd_ord_ticket_di': {
        'delay_active_type': ("CASE WHEN ticket_latest.valid_start IS NULL OR ticket_latest.valid_start = '' OR ticket_latest.valid_start LIKE '1970-01-01%' THEN 1 ELSE 0 END",
                              '有效期起始为空或默认值（首次核销时回填）即延迟激活'),
        'first_verify_time': ('verify_dtl.first_verify_time', '近 400 天核销成功记录的最早时间')},
    'dwd_ord_ticket_person_di': {
        'origin_country_code': ('region_dim.country_code', '身份证前 6 位行政区划码关联地区维表'),
        'origin_province_code': ('region_dim.province_code', '同上'),
        'age_year_qty': (ID_AGE, '身份证第 7~14 位出生日期到游玩日的周岁；非身份证为空'),
        'age_band_code': (AGE_BAND.format(a=ID_AGE), '按游玩时周岁分段'),
        'gender_type': ("CASE WHEN ticket_person_latest.id_type <> 'ID_CARD' OR LENGTH(ticket_person_latest.id_number) < 17 THEN 'UNKNOWN' "
                        "WHEN CAST(SUBSTR(ticket_person_latest.id_number, 17, 1) AS INT) % 2 = 1 THEN 'MALE' ELSE 'FEMALE' END", '身份证第 17 位奇数为男、偶数为女')},
    'dwd_ord_verify_di': {'verify_person_qty': ('CASE WHEN binding_cnt.b_open = 1 OR COALESCE(binding_cnt.b_person_qty, 0) = 0 THEN 1 ELSE binding_cnt.b_person_qty END',
                                                '按票 + 权益的绑定人数；开放争抢模式或未绑定人记 1')},
    'dwd_ord_verify_rt': {'verify_person_qty': ('1', '口径说明：实时按 1 人计；绑定多人的共享权益以离线人数为准')},
    'dwd_ord_refund_ticket_di': {},
    'dwd_prd_sku_version_di': {
        'new_version_no': ('sku_version_snapshot_chg.version + 1', '快照记录的是变更前版本号，变更后 = 变更前 + 1'),
        'price_change_type': ("CASE WHEN COALESCE(GET_JSON_OBJECT(sku_version_snapshot_chg.snapshot_data, '$.priceChangeLog.oldPrice'), '') <> "
                              "COALESCE(GET_JSON_OBJECT(sku_version_snapshot_chg.snapshot_data, '$.priceChangeLog.newPrice'), '') THEN 1 ELSE 0 END", '变更前后价格不同即改价')},
    'dwd_trf_distribution_settle_di': {
        'chain_level_no': ('(1 + IF(d1.item_no IS NULL, 0, 1) + IF(d2.item_no IS NULL, 0, 1) + IF(d3.item_no IS NULL, 0, 1))',
                           '同一批量支付内沿 depend_on_item 往前数：游客付款 = 1，之后每级采购 +1'),
        'relation_no': ('distribution_relation_cur.relation_no', '按 收款方 = 供应商、付款方 = 分销商 匹配当前有效分销关系')},
})

SUB.update({
    'dim_opr_package_df': [
        ('', 'app_dim AS (', "pkg_app_agg AS (   -- 套餐包含的应用编码（去重排序拼接）\n"
         "  SELECT b.package_id, CONCAT_WS(',', SORT_ARRAY(COLLECT_SET(a.app_code))) AS app_code_list\n"
         "  FROM (SELECT package_id, app_id FROM ods.ods_opr_app_binding_df WHERE travel_date = '${bizdate}') b\n"
         "  JOIN (SELECT app_id, app_code FROM dim.dim_opr_app_df WHERE travel_date = '${bizdate}') a ON a.app_id = b.app_id\n"
         "  GROUP BY b.package_id\n),\napp_dim AS ("),
        ('', 'LEFT JOIN app_dim', 'LEFT JOIN pkg_app_agg paa'),
        ('', 'ON app_dim.app_id = package_src.id', 'ON paa.package_id = package_src.id')],
    'dim_sup_role_df': [
        ('', 'sys_permission_src AS (', "role_perm_agg AS (   -- 角色拥有的权限编码（去重排序拼接）\n"
         "  SELECT rp.role_id, CONCAT_WS(',', SORT_ARRAY(COLLECT_SET(p.permission_code))) AS permission_code_list\n"
         "  FROM (SELECT role_id, permission_id FROM ods.ods_sup_sys_role_permission_df WHERE travel_date = '${bizdate}') rp\n"
         "  JOIN (SELECT id, permission_code FROM ods.ods_sup_sys_permission_df WHERE travel_date = '${bizdate}') p ON p.id = rp.permission_id\n"
         "  GROUP BY rp.role_id\n),\nsys_permission_src AS ("),
        ('', 'LEFT JOIN sys_permission_src', 'LEFT JOIN role_perm_agg rpa'),
        ('', 'ON sys_permission_src.id = sys_role_src.id', 'ON rpa.role_id = sys_role_src.id')],
    'dim_sup_staff_zip': [
        ('', 'role_dim AS (', "staff_role_agg AS (   -- 员工绑定的角色（去重排序拼接）\n"
         "  SELECT ur.user_id, CONCAT_WS(',', SORT_ARRAY(COLLECT_SET(r.role_code))) AS role_code_list,\n"
         "         CONCAT_WS(',', SORT_ARRAY(COLLECT_SET(r.role_name))) AS role_name_list\n"
         "  FROM (SELECT user_id, role_id FROM ods.ods_sup_sys_user_role_df WHERE travel_date = '${bizdate}') ur\n"
         "  JOIN (SELECT id, role_code, role_name FROM ods.ods_sup_sys_role_df WHERE travel_date = '${bizdate}') r ON r.id = ur.role_id\n"
         "  GROUP BY ur.user_id\n),\nrole_dim AS ("),
        ('', 'LEFT JOIN sys_role_src', 'LEFT JOIN staff_role_agg sra'),
        ('', 'ON sys_role_src.id = tenant_staff_src.id', 'ON sra.user_id = tenant_staff_src.id'),
        ('', 'LEFT JOIN sys_user_role_src', ''), ('', 'ON sys_user_role_src.id = tenant_staff_src.id', ''),
        ('', 'LEFT JOIN role_dim', ''), ('', 'ON role_dim.role_id = sys_user_role_src.role_id', '')],
    'dim_prd_sku_attr_df': [
        ('dict_dim AS (', 'SELECT dict_id, dict_name', 'SELECT dict_type_code, dict_code, dict_name'),
        ('', 'ON dict_dim.dict_id = sku_meta_value_src.id', 'ON dict_dim.dict_type_code = sku_meta_value_src.attribute_code AND dict_dim.dict_code = sku_meta_value_src.attribute_value   -- 口径说明：属性值按 字典类型 = 属性代码 匹配中文名')],
    'dim_sup_tenant_zip': [
        ('package_subscription_rn AS (', 'SELECT expire_at, id, package_id, tenant_id, binlog_op_type,', 'SELECT expire_at, start_at, subscription_status, id, package_id, tenant_id, binlog_op_type,'),
        ('package_subscription_rn AS (', "WHERE travel_date = '${bizdate}'", f'WHERE {WIN400}   -- 订购可能早于今天，取近 400 天'),
        ('package_subscription_latest AS (', 'SELECT expire_at, id, package_id, tenant_id',
         'SELECT tenant_id, MAX_BY(package_id, start_at) AS package_id, MAX_BY(expire_at, start_at) AS expire_at'),
        ('package_subscription_latest AS (', "AND binlog_op_type <> 'DELETE'",
         "AND binlog_op_type <> 'DELETE'\n    AND subscription_status = 'ACTIVE' AND TO_DATE(start_at) <= '${bizdate_dash}' AND TO_DATE(expire_at) >= '${bizdate_dash}'\n  GROUP BY tenant_id")],
    'dim_trf_distribution_relation_zip': [
        ('src AS (', 'FROM distribution_relation_src', "FROM distribution_relation_src\n"
         "    LEFT JOIN distribution_relation_src p1 ON p1.id = distribution_relation_src.parent_relation_id   -- 上一级关系\n"
         "    LEFT JOIN distribution_relation_src p2 ON p2.id = p1.parent_relation_id\n"
         "    LEFT JOIN distribution_relation_src p3 ON p3.id = p2.parent_relation_id")],
    'dwd_trf_distribution_credit_rt': [
        ('', 'FROM ods.ods_trf_distribution_relation_rt a', "FROM ods.ods_trf_distribution_relation_rt a\n"
         "LEFT JOIN ods.ods_trf_distribution_relation_rt p1 ON p1.id = a.parent_relation_id   -- 上一级关系（CDC 表常规关联，随变更更新）\n"
         "LEFT JOIN ods.ods_trf_distribution_relation_rt p2 ON p2.id = p1.parent_relation_id\n"
         "LEFT JOIN ods.ods_trf_distribution_relation_rt p3 ON p3.id = p2.parent_relation_id")],
    'dwd_fin_resource_batch_di': [
        ('', 'package_subscription_dtl AS (', f"batch_prev AS (   -- 昨日批次快照的剩余量\n"
         f"  SELECT id AS prev_id, remaining_quantity AS prev_remaining FROM ods.ods_fin_resource_batch_df WHERE travel_date = {Y}\n),\n"
         f"purchase_flow AS (   -- 购买流水 → 订购单号（流水 related_no）\n"
         f"  SELECT flow_no, MAX(related_no) AS related_no FROM dwd.dwd_fin_fund_flow_di WHERE {WIN400} AND flow_type = 'RESOURCE' GROUP BY flow_no\n),\n"
         "package_subscription_dtl AS ("),
        ('package_subscription_dtl AS (', 'SELECT package_id, subscription_id', 'SELECT subscription_no, MAX(package_id) AS package_id'),
        ('package_subscription_dtl AS (', "WHERE travel_date = '${bizdate}'", f'WHERE {WIN400}\n  GROUP BY subscription_no'),
        ('', 'LEFT JOIN package_subscription_dtl', 'LEFT JOIN purchase_flow ON purchase_flow.flow_no = resource_batch_chg.purchase_no\nLEFT JOIN batch_prev ON batch_prev.prev_id = resource_batch_chg.id\nLEFT JOIN package_subscription_dtl'),
        ('', 'ON package_subscription_dtl.subscription_id = resource_batch_chg.id', 'ON package_subscription_dtl.subscription_no = purchase_flow.related_no   -- 口径说明：资源包购买流水的关联单号 = 订购单号')],
    'dwd_inv_pool_change_di': [('', 'LEFT JOIN inventory_unit_latest', ''), ('', 'ON inventory_unit_latest.pool_no = inventory_pool_chg.pool_no', '')],
    'dwd_inv_pool_change_rt': [('', 'LEFT JOIN ods.ods_inv_inventory_unit_rt j1', ''), ('', 'ON j1.pool_no = a.pool_no', '')],   # 按池号关联资源个体会一对多放大
    'dwd_ord_order_group_di': [
        ('payment_record_rn AS (', 'SELECT id, order_group_no, pay_time, binlog_op_type,', 'SELECT id, order_group_no, pay_time, pay_direction, pay_status, binlog_op_type,'),
        ('payment_record_rn AS (', "WHERE travel_date = '${bizdate}'", f'WHERE {WIN400}   -- 支付可能早于聚合单今天的变更，取近 400 天'),
        ('payment_record_latest AS (', 'SELECT id, order_group_no, pay_time',
         "SELECT order_group_no, MIN(CASE WHEN pay_direction = 'INBOUND' AND pay_status IN ('PAID', 'PARTIAL_REFUNDED', 'REFUNDED') THEN pay_time END) AS first_pay_time"),
        ('payment_record_latest AS (', "AND binlog_op_type <> 'DELETE'", "AND binlog_op_type <> 'DELETE'\n  GROUP BY order_group_no"),
        ('order_rn AS (', "WHERE travel_date = '${bizdate}'", f'WHERE {WIN400}   -- 子单随聚合单创建，聚合单后续变更时需回看'),
        ('order_latest AS (', 'SELECT id, order_group_no, quantity', 'SELECT order_group_no, SUM(quantity) AS order_ticket_qty'),
        ('order_latest AS (', "AND binlog_op_type <> 'DELETE'", "AND binlog_op_type <> 'DELETE'\n  GROUP BY order_group_no")],
    'dwd_ord_ticket_di': [
        ('verify_dtl AS (', 'SELECT create_time, ticket_no', 'SELECT ticket_no, MIN(create_time) AS first_verify_time'),
        ('verify_dtl AS (', "WHERE travel_date = '${bizdate}'", f"WHERE {WIN400} AND verify_result_type = 'SUCCESS'\n  GROUP BY ticket_no")],
    'dwd_ord_ticket_person_di': [
        ('region_dim AS (', 'SELECT city_code, city_name, country_code, province_code, province_name, region_id',
         'SELECT city_code, city_name, country_code, province_code, province_name, id_card_prefix_code'),
        ('', 'ON region_dim.region_id = ticket_person_latest.id',
         "ON region_dim.id_card_prefix_code = IF(ticket_person_latest.id_type = 'ID_CARD', SUBSTR(ticket_person_latest.id_number, 1, 6), NULL)   -- 身份证前 6 位 = 区县行政区划码")],
    'dwd_ord_verify_di': [
        ('', 'verify_point_dim AS (', f"binding_cnt AS (   -- 每张票每个权益的绑定人数\n"
         f"  SELECT ticket_no AS b_ticket_no, entitlement_no AS b_ent_no,\n"
         f"         MAX(IF(binding_type = 'OPEN' OR person_code = '', 1, 0)) AS b_open,\n"
         f"         COUNT(DISTINCT IF(person_code <> '', person_code, NULL)) AS b_person_qty\n"
         f"  FROM dwd.dwd_ord_entitlement_binding_di WHERE {WIN400}\n  GROUP BY ticket_no, entitlement_no\n),\nverify_point_dim AS ("),
        ('', 'LEFT JOIN verify_point_dim', 'LEFT JOIN binding_cnt\n  ON binding_cnt.b_ticket_no = verify_record_chg.ticket_no AND binding_cnt.b_ent_no = verify_record_chg.entitlement_no\nLEFT JOIN verify_point_dim')],
    'dwd_trf_distribution_settle_di': [
        ('distribution_relation_cur AS (', 'SELECT relation_id, relation_no', 'SELECT relation_no, supplier_tenant_id AS rel_supplier_id, distributor_tenant_id AS rel_distributor_id'),
        ('', 'LEFT JOIN ticket_dtl', 'LEFT JOIN payment_dtl d1 ON d1.batch_no = payment_dtl.batch_no AND d1.item_no = payment_dtl.depend_on_item_no   -- 依赖的上一笔支付\n'
         'LEFT JOIN payment_dtl d2 ON d2.batch_no = d1.batch_no AND d2.item_no = d1.depend_on_item_no\n'
         'LEFT JOIN payment_dtl d3 ON d3.batch_no = d2.batch_no AND d3.item_no = d2.depend_on_item_no\nLEFT JOIN ticket_dtl'),
        ('', 'ON distribution_relation_cur.relation_id = payment_dtl.id',
         'ON distribution_relation_cur.rel_supplier_id = payment_dtl.payee_tenant_id AND distribution_relation_cur.rel_distributor_id = payment_dtl.payer_tenant_id')],
    'dwd_opr_approval_di': [],
})
RAW.update({
    'dwd_opr_approval_di': [("UNIX_TIMESTAMP(approval_instance_latest.instance_status)",
                             "UNIX_TIMESTAMP(CASE WHEN approval_instance_latest.instance_status IN ('APPROVED', 'REJECTED', 'CANCELLED') THEN approval_instance_latest.update_time END)")],
    'dim_trf_distribution_relation_zip': [("ROUND(distribution_relation_src.credit_limit - distribution_relation_src.credit_used /100, 2)",
                                           "ROUND((distribution_relation_src.credit_limit - distribution_relation_src.credit_used) / 100, 2)")],
    'dwd_ord_refund_di': [("GET_JSON_OBJECT(refund_order_latest.refund_items, '$[0].ticketNos')",
                           "SIZE(FLATTEN(FROM_JSON(refund_order_latest.refund_items, 'array<struct<orderNo:string,ticketNos:array<string>,amount:bigint>>').ticketNos))")],
    'dwd_ord_refund_rt': [("GET_JSON_OBJECT(a.refund_items, '$[0].ticketNos')",
                           "CAST((CHAR_LENGTH(JSON_QUERY(a.refund_items, '$[*].ticketNos[*]' WITH UNCONDITIONAL ARRAY WRAPPER)) "
                           "- CHAR_LENGTH(REPLACE(JSON_QUERY(a.refund_items, '$[*].ticketNos[*]' WITH UNCONDITIONAL ARRAY WRAPPER), '\"', ''))) / 2 AS INT)")],
})

FULL['dim_sup_org_df'] = ('hive', hdr('dim.dim_sup_org_df', '部门维度', 'ods_sup_org_df', [
    '层级 / 路径 / 一二级部门：沿 parent_org_id 逐级向上自关联（最多 5 级），0 = 顶级',
    '一级部门 = 最顶层祖先（自身为顶级时取自身），二级部门 = 顶层往下第 2 层'], ['部门表小，自关联 4 次'])
    + """WITH o AS (
    SELECT id, org_no, org_name, parent_org_id, tenant_id, org_status, create_time, update_time
    FROM ods.ods_sup_org_df WHERE travel_date = '${bizdate}'
),
x AS (
    SELECT o.*, p1.id AS p1_id, p1.org_name AS p1_name, p2.id AS p2_id, p2.org_name AS p2_name,
           p3.id AS p3_id, p3.org_name AS p3_name, p4.id AS p4_id, p4.org_name AS p4_name,
           1 + IF(p1.id IS NULL, 0, 1) + IF(p2.id IS NULL, 0, 1) + IF(p3.id IS NULL, 0, 1) + IF(p4.id IS NULL, 0, 1) AS lvl
    FROM o
    LEFT JOIN o p1 ON p1.id = o.parent_org_id
    LEFT JOIN o p2 ON p2.id = p1.parent_org_id
    LEFT JOIN o p3 ON p3.id = p2.parent_org_id
    LEFT JOIN o p4 ON p4.id = p3.parent_org_id
)
INSERT OVERWRITE TABLE dim.dim_sup_org_df PARTITION (travel_date = '${bizdate}')
SELECT
    id AS org_id, org_no, org_name, parent_org_id, tenant_id, org_status, create_time, update_time,
    lvl                                                                                   AS org_level_no,
    CONCAT_WS('/', p4_name, p3_name, p2_name, p1_name, org_name)                          AS org_path_desc,
    CASE lvl WHEN 1 THEN id WHEN 2 THEN p1_id WHEN 3 THEN p2_id WHEN 4 THEN p3_id ELSE p4_id END             AS level1_org_id,
    CASE lvl WHEN 1 THEN org_name WHEN 2 THEN p1_name WHEN 3 THEN p2_name WHEN 4 THEN p3_name ELSE p4_name END AS level1_org_name,
    CASE lvl WHEN 2 THEN id WHEN 3 THEN p1_id WHEN 4 THEN p2_id WHEN 5 THEN p3_id END                       AS level2_org_id,
    CASE lvl WHEN 2 THEN org_name WHEN 3 THEN p1_name WHEN 4 THEN p2_name WHEN 5 THEN p3_name END           AS level2_org_name,
    CURRENT_TIMESTAMP() AS etl_time
FROM x;
""")

FULL['dim_opr_region_f'] = ('hive', hdr('dim.dim_opr_region_f', '地区维度', 'ods_opr_region_df + ods_opr_i18n_translation_df + ods_opr_country_df', [
    '省 / 市 / 区县编码：沿 parent_id 向上自关联，取层级为 1 / 2 / 3 的祖先（含自身）的行政区划码',
    '名称：翻译表 zh-CN（表 t_region、字段 region_name、实体 = 地区 ID）；翻译缺失时取完整路径最后一段；省市区名称取完整路径对应段',
    '身份证前 6 位 = 区县行政区划码，客源地解析按此关联'], ['地区表约数千行，全量覆盖'])
    + """WITH r AS (
    SELECT id, region_code, parent_id, country_code, region_level, region_path, region_status, sort_order, create_time, update_time
    FROM ods.ods_opr_region_df WHERE travel_date = '${bizdate}'
),
tr AS (   -- 地区中文名（口径说明：翻译表的表名 / 字段名按 t_region.region_name 约定）
    SELECT entity_id, MAX(field_value) AS name_cn
    FROM ods.ods_opr_i18n_translation_df
    WHERE travel_date = '${bizdate}' AND table_name = 't_region' AND field_name = 'region_name' AND locale = 'zh-CN'
    GROUP BY entity_id
),
x AS (
    SELECT r.*, p1.region_code AS c1, p1.region_level AS l1, p2.region_code AS c2, p2.region_level AS l2,
           p3.region_code AS c3, p3.region_level AS l3, p4.region_code AS c4, p4.region_level AS l4
    FROM r
    LEFT JOIN r p1 ON p1.id = r.parent_id
    LEFT JOIN r p2 ON p2.id = p1.parent_id
    LEFT JOIN r p3 ON p3.id = p2.parent_id
    LEFT JOIN r p4 ON p4.id = p3.parent_id
),
country_src AS (
    SELECT country_code, iso3_code FROM ods.ods_opr_country_df WHERE travel_date = '${bizdate}'
)
INSERT OVERWRITE TABLE dim.dim_opr_region_f
SELECT /*+ BROADCAST(country_src) */
    x.id AS region_id, x.region_code, x.parent_id, x.country_code, x.region_level AS region_level_no, x.region_path AS region_path_desc,
    x.region_status, x.sort_order AS sort_no, x.create_time, x.update_time,
    COALESCE(tr.name_cn, ELEMENT_AT(SPLIT(x.region_path, '/'), -1))                       AS region_name,
    SPLIT(x.region_path, '/')[0]                                                           AS country_name,
    c.iso3_code,
    COALESCE(IF(x.region_level = 1, x.region_code, NULL), IF(x.l1 = 1, x.c1, NULL), IF(x.l2 = 1, x.c2, NULL), IF(x.l3 = 1, x.c3, NULL), IF(x.l4 = 1, x.c4, NULL)) AS province_code,
    SPLIT(x.region_path, '/')[1]                                                           AS province_name,
    COALESCE(IF(x.region_level = 2, x.region_code, NULL), IF(x.l1 = 2, x.c1, NULL), IF(x.l2 = 2, x.c2, NULL), IF(x.l3 = 2, x.c3, NULL)) AS city_code,
    SPLIT(x.region_path, '/')[2]                                                           AS city_name,
    COALESCE(IF(x.region_level = 3, x.region_code, NULL), IF(x.l1 = 3, x.c1, NULL), IF(x.l2 = 3, x.c2, NULL)) AS district_code,
    SPLIT(x.region_path, '/')[3]                                                           AS district_name,
    IF(x.region_level = 3, x.region_code, NULL)                                            AS id_card_prefix_code,
    CURRENT_TIMESTAMP() AS etl_time
FROM x
LEFT JOIN tr ON tr.entity_id = x.id
LEFT JOIN country_src c ON c.country_code = x.country_code;
""")

FULL['dwd_ord_refund_ticket_di'] = ('hive', hdr('dwd.dwd_ord_refund_ticket_di', '退款票明细', 'ods_ord_refund_order_di + dwd_ord_ticket_di + dwd_ord_ticket_status_log_di + dwd_ord_refund_di', [
    'refund_items 是 JSON 数组 [{orderNo, ticketNos[], amount}]：先展开子单、再展开票号，一行一张票',
    '本票退款金额 = 该子单退款金额（分）÷ 票数 ÷ 100',
    '退票时票状态 = 退款申请时间之前最后一条票状态流转的变更后状态；无流转记录 = 可用',
    '原自动生成版本按聚合单关联票 / 状态流转（一对多放大）、对数组直接取 $.orderNo，此处重写'], ['票、状态流转只取近 400 天，按票号关联'])
    + f"""WITH r AS (
    SELECT id, refund_no, order_group_no, refund_type, refund_reason, refund_status, refund_items, initiator_type, tenant_id, create_time,
           ROW_NUMBER() OVER (PARTITION BY id ORDER BY binlog_time DESC) AS rn, binlog_op_type
    FROM ods.ods_ord_refund_order_di WHERE travel_date = '${{bizdate}}'
),
it AS (   -- 一行 = 一张退款票
    SELECT r.refund_no, r.order_group_no, r.refund_type, r.refund_reason, r.refund_status, r.initiator_type, r.tenant_id, r.create_time,
           i.orderNo AS order_no, tk AS ticket_no,
           CAST(i.amount AS DECIMAL(18,2)) / NULLIF(SIZE(i.ticketNos), 0) / 100 AS refund_amt
    FROM r
    LATERAL VIEW EXPLODE(FROM_JSON(r.refund_items, 'array<struct<orderNo:string,ticketNos:array<string>,amount:bigint>>')) e AS i
    LATERAL VIEW EXPLODE(i.ticketNos) t AS tk
    WHERE r.rn = 1 AND r.binlog_op_type <> 'DELETE'
),
ticket AS (
    SELECT ticket_no, MAX(seller_tenant_id) AS seller_tenant_id, MAX(sku_id) AS sku_id, MAX(play_date) AS play_date
    FROM dwd.dwd_ord_ticket_di WHERE {WIN400} GROUP BY ticket_no
),
st AS (   -- 退款申请前最后一次票状态
    SELECT it.refund_no, it.ticket_no, MAX_BY(l.after_status, l.change_time) AS before_status
    FROM it
    JOIN (SELECT ticket_no, after_status, change_time FROM dwd.dwd_ord_ticket_status_log_di WHERE {WIN400}) l
      ON l.ticket_no = it.ticket_no AND l.change_time < it.create_time
    GROUP BY it.refund_no, it.ticket_no
),
fin AS (
    SELECT refund_no, MAX(finish_time) AS finish_time FROM dwd.dwd_ord_refund_di WHERE travel_date = '${{bizdate}}' GROUP BY refund_no
)
INSERT OVERWRITE TABLE dwd.dwd_ord_refund_ticket_di PARTITION (travel_date = '${{bizdate}}')
SELECT
    it.refund_no, it.order_group_no, it.order_no, it.ticket_no,
    tk.seller_tenant_id, tk.sku_id, tk.play_date,
    it.refund_type, it.refund_status, it.initiator_type, it.refund_reason AS refund_reason_desc,
    COALESCE(st.before_status, 'AVAILABLE')                       AS before_ticket_status,
    1                                                             AS refund_ticket_qty,
    ROUND(it.refund_amt, 2)                                       AS refund_amt,
    it.create_time                                                AS apply_time,
    fin.finish_time,
    it.tenant_id,
    CURRENT_TIMESTAMP() AS etl_time
FROM it
LEFT JOIN ticket tk ON tk.ticket_no = it.ticket_no
LEFT JOIN st ON st.refund_no = it.refund_no AND st.ticket_no = it.ticket_no
LEFT JOIN fin ON fin.refund_no = it.refund_no;
""")

FULL['dwd_opr_device_status_log_di'] = ('hive', hdr('dwd.dwd_opr_device_status_log_di', '设备状态变更明细', 'ods_opr_device_df（今日、昨日两个日快照）', [
    '设备表是日全量快照：今日状态与昨日不同（或新设备）即记一条变更；变更前 = 昨日状态，变更后 = 今日状态',
    '前一状态持续时长 = 本次变更时间 − 上一次变更时间（取历史变更明细，没有则取设备创建时间）',
    '口径说明：日快照只能看到日终状态，一天内多次切换只记最终一次'], ['只读两个快照分区 + 近 400 天变更明细的每设备最大变更时间'])
    + f"""WITH t AS (
    SELECT id, device_no, tenant_id, device_type, device_group_id, poi_id, device_status, last_heartbeat, update_time, create_time
    FROM ods.ods_opr_device_df WHERE travel_date = '${{bizdate}}'
),
y AS (
    SELECT id, device_status FROM ods.ods_opr_device_df WHERE travel_date = {Y}
),
last_chg AS (
    SELECT device_id, MAX(change_time) AS last_change_time
    FROM dwd.dwd_opr_device_status_log_di WHERE {WIN400} AND travel_date < '${{bizdate}}'
    GROUP BY device_id
)
INSERT OVERWRITE TABLE dwd.dwd_opr_device_status_log_di PARTITION (travel_date = '${{bizdate}}')
SELECT
    t.id AS device_id, t.device_no, t.tenant_id, t.device_type, t.device_group_id, t.poi_id,
    y.device_status                                               AS before_status,
    t.device_status                                               AS after_status,
    t.last_heartbeat                                              AS last_heartbeat_time,
    t.update_time                                                 AS change_time,
    ROUND((UNIX_TIMESTAMP(t.update_time) - UNIX_TIMESTAMP(COALESCE(lc.last_change_time, t.create_time))) / 60, 2) AS status_minute_qty,
    CURRENT_TIMESTAMP() AS etl_time
FROM t
LEFT JOIN y ON y.id = t.id
LEFT JOIN last_chg lc ON lc.device_id = t.id
WHERE y.id IS NULL OR y.device_status <> t.device_status;
""")

FULL['dwd_prd_sku_price_calendar_df'] = ('hive', hdr('dwd.dwd_prd_sku_price_calendar_df', 'SKU每日生效价日历', 'ods_prd_price_point_di（全部历史取最新）+ ods_prd_pricing_rule_df + dim_opr_date_f', [
    '日历：统计日起未来 90 天 × 每个 SKU × 渠道 × 扩展维度',
    '命中价格点：在生效期内，按 单日价（10）> 区间价（5）> 星期价（3）> 默认价（0）取类别最高、再按优先级最高的一条',
    '星期掩码 bit0 = 周一 … bit6 = 周日',
    '规则价：同 SKU 生效期内优先级最高的定价规则；PERCENT 按比例、FIXED 按固定加减；口径说明：params 的 JSON 键名（percent / amount）待研发确认，MATRIX 暂不计算'],
    ['价格点表小，取全部历史分区按主键取最新；日期维表广播'])
    + f"""WITH pp AS (   -- 价格点最新状态
    SELECT id, price_no, sku_id, channel, date_single, date_from, date_to, weekday_mask, ext_dims, price, priority, effective_from, effective_to, tenant_id
    FROM (
        SELECT p.*, ROW_NUMBER() OVER (PARTITION BY id ORDER BY binlog_time DESC) AS rn
        FROM ods.ods_prd_price_point_di p WHERE travel_date <= '${{bizdate}}'
    ) z
    WHERE rn = 1 AND binlog_op_type <> 'DELETE'
),
d AS (   -- 未来 90 天
    SELECT date_code AS price_date
    FROM dim.dim_opr_date_f
    WHERE date_code BETWEEN '${{bizdate_dash}}' AND DATE_FORMAT(DATE_ADD(TO_DATE('${{bizdate_dash}}'), 89), 'yyyy-MM-dd')
),
hit AS (
    SELECT /*+ BROADCAST(d) */ pp.sku_id, d.price_date, COALESCE(pp.channel, 'DEFAULT') AS price_channel_code, COALESCE(pp.ext_dims, '') AS ext_dim_desc,
           pp.price_no, pp.price, pp.priority, pp.tenant_id,
           CASE WHEN pp.date_single IS NOT NULL THEN 10 WHEN pp.date_from IS NOT NULL THEN 5 WHEN pp.weekday_mask IS NOT NULL THEN 3 ELSE 0 END AS cls
    FROM pp CROSS JOIN d
    WHERE (pp.effective_from IS NULL OR TO_DATE(pp.effective_from) <= d.price_date)
      AND (pp.effective_to IS NULL OR TO_DATE(pp.effective_to) >= d.price_date)
      AND (pp.date_single IS NULL OR TO_DATE(pp.date_single) = d.price_date)
      AND (pp.date_from IS NULL OR d.price_date BETWEEN TO_DATE(pp.date_from) AND TO_DATE(pp.date_to))
      AND (pp.weekday_mask IS NULL OR (SHIFTRIGHT(pp.weekday_mask, (DAYOFWEEK(d.price_date) + 5) % 7) & 1) = 1)
),
best AS (
    SELECT * FROM (
        SELECT hit.*, ROW_NUMBER() OVER (PARTITION BY sku_id, price_date, price_channel_code, ext_dim_desc ORDER BY cls DESC, priority DESC) AS rk FROM hit
    ) z WHERE rk = 1
),
rule AS (
    SELECT rule_no, sku_id, calculator, params, priority, effective_from, effective_to
    FROM ods.ods_prd_pricing_rule_df WHERE travel_date = '${{bizdate}}'
),
rule_hit AS (
    SELECT * FROM (
        SELECT b.sku_id, b.price_date, b.price_channel_code, b.ext_dim_desc, r.rule_no, r.calculator, r.params,
               ROW_NUMBER() OVER (PARTITION BY b.sku_id, b.price_date, b.price_channel_code, b.ext_dim_desc ORDER BY r.priority DESC) AS rk
        FROM best b
        JOIN rule r ON r.sku_id = b.sku_id
         AND (r.effective_from IS NULL OR TO_DATE(r.effective_from) <= b.price_date)
         AND (r.effective_to IS NULL OR TO_DATE(r.effective_to) >= b.price_date)
    ) z WHERE rk = 1
)
INSERT OVERWRITE TABLE dwd.dwd_prd_sku_price_calendar_df PARTITION (travel_date = '${{bizdate}}')
SELECT
    b.sku_id, b.price_date, b.price_channel_code, b.ext_dim_desc,
    b.price_no                                                    AS hit_price_no,
    b.cls                                                         AS hit_priority_no,
    ROUND(b.price / 100, 2)                                       AS list_price_amt,
    rh.rule_no                                                    AS pricing_rule_no,
    IF(rh.rule_no IS NULL, 0, 1)                                  AS rule_price_type,
    ROUND(CASE rh.calculator
            WHEN 'PERCENT' THEN b.price / 100 * CAST(GET_JSON_OBJECT(rh.params, '$.percent') AS DECIMAL(18,4)) / 100
            WHEN 'FIXED'   THEN b.price / 100 + CAST(GET_JSON_OBJECT(rh.params, '$.amount') AS DECIMAL(18,2)) / 100
            ELSE b.price / 100 END, 2)                            AS final_price_amt,
    b.tenant_id,
    CURRENT_TIMESTAMP() AS etl_time
FROM best b
LEFT JOIN rule_hit rh ON rh.sku_id = b.sku_id AND rh.price_date = b.price_date AND rh.price_channel_code = b.price_channel_code AND rh.ext_dim_desc = b.ext_dim_desc;
""")

TODO_DIM = [
    ('加工逻辑', '库存池变更没有记录引起变动的订单号', 'dwd_inv_pool_change_di/rt.order_no 暂为空；请研发在库存流水中记录 order_no', '库存变动无法追溯到订单'),
    ('加工逻辑', '定价规则 params 的 JSON 键名未定义', '规则价按 PERCENT = params.percent、FIXED = params.amount（分）计算，MATRIX 暂不计算；请研发确认', 'dwd_prd_sku_price_calendar_df.final_price_amt'),
    ('加工逻辑', '证件号在业务库已脱敏，客源地 / 年龄 / 性别依赖身份证第 1~6、7~14、17 位', '按 18 位身份证规则解析；请确认脱敏规则保留这些位（或改为入仓前解析）', '游客客源地、年龄段、性别'),
    ('加工逻辑', '资源批次 purchase_no 引用资金流水，资金流水的 related_no 是否为套餐订购单号未确认', '按 流水 related_no = 订购单号 关联来源套餐', 'dwd_fin_resource_batch_di.package_id'),
    ('加工逻辑', '地区名称取翻译表 t_region.region_name（zh-CN）为约定，未在业务库文档中确认', '翻译缺失时取完整路径最后一段', 'dim_opr_region_f.region_name'),
]

# 新增依赖登记到待确认事项（字段 / 枚举缺口）
TODO_BASE = [
    ('加工逻辑', '冻结记录没有「释放原因」字段，过期兜底释放无法直接识别', '按「当日释放、且冻结事件不是核销 / 退款」认定（dws_fin_account_frozen_di.expire_release_amt）；请研发确认过期释放的 frozen_event 取值', '过期释放金额'),
    ('加工逻辑', '退款单没有审批方式字段，超时自动通过无法直接识别', '按「已通过但没有审批人」认定（dws_ord_tenant_refund_di.auto_approve_refund_qty）；请研发确认自动通过时 approver_id 的取值', '自动通过退款单数'),
    ('加工逻辑', '实时链路不关联游客维表，实时「支付买家数」含商户代下单占位买家', '当日离线结果剔除；如需实时剔除，实时作业 lookup 游客维表', '实时支付买家数略偏大'),
]

TODO = TODO_BASE + TODO_DIM

# 客户字典里的字段定义错误：编码 / 编号被标成金额（DECIMAL + 分转元），生成时改正，改造版字典里同步
DICT_FIX = [
    ('dwd.dwd_fin_resource_batch_di', 'resource_type', {'类型': 'STRING', '字段注释': '资源类型：SMS-短信，POINTS-积分，ALARM_QUOTA-预警额度',
                                                        '加工 / 来源': 'ods_fin_resource_batch_df.resource_type'}),
    ('dim.dim_inv_shared_pool_df', 'shared_pool_no', {'类型': 'STRING', '字段注释': '共享池编号（分销商独立池，软配额模式）',
                                                      '加工 / 来源': 'ods_inv_shared_inventory_pool_df.shared_pool_no'}),
]


def fix_dict(S):
    """改正字典字段定义，返回 {短表名: 改造说明}"""
    F = S['字段清单']
    fi = {c: i for i, c in enumerate(F['cols'])}
    out = {}
    for tbl, fld, vals in DICT_FIX:
        for r in F['rows']:
            if r[fi['表名（库.表）']] == tbl and r[fi['字段名']] == fld:
                for k, v in vals.items():
                    r[fi[k]] = v
                out.setdefault(tbl.split('.', 1)[1], []).append(f'{fld} 是编码不是金额：类型改为 STRING，去掉分转元')
    return {t: '；'.join(v) for t, v in out.items()}


# --------------------------------------------------------------------------------------------------
def _cn(D, t, f):
    for x in D.f.get(t, []):
        if x['n'] == f:
            c = re.match(r'^([^：:，,；;（(]+)', x['cmt'] or '')
            return (c.group(1) if c else x['cmt']).strip()
    return f


def apply(etl, D, annotate):
    """etl：etl_gen.generate 的结果（原地修改）；D：etl_gen.Dict；annotate：etl_gen.annotate"""
    log = []
    for t, (kind, sql) in FULL.items():
        if t not in etl:
            continue
        sql = annotate(sql.strip('\n'), t, D)
        head, _, rest = sql.partition('\n')
        etl[t]['sql'] = head + f"\n-- 粒度：{D.t[t]['grain']}\n" + rest
        etl[t]['kind'] = kind
    for t, subs in SUB.items():
        if t not in etl:
            continue
        s = etl[t]['sql']
        for item in subs:
            anchor, old, new = item if len(item) == 3 else ('', *item)
            old, new = old.strip(), new.lstrip(' ')
            pos = s.find(anchor) if anchor else 0
            if pos < 0:
                raise ValueError(f'{t}: 找不到锚点 {anchor!r}')
            pat = re.compile(r'^(\s*)' + re.escape(old) + r'([^\n]*)$', re.M)
            m = pat.search(s, pos)
            if not m:
                raise ValueError(f'{t}: 找不到 {old!r}')
            ind, rest = m.group(1), m.group(2) or ''
            code_rest, _, cmt = rest.partition('--')
            keep = ';' if ';' in code_rest else ''
            lines_new = new.split('\n')
            if cmt.strip() and '待确认' not in cmt and new:
                lines_new[0] += '  --' + cmt.rstrip()
            lines_new[-1] += keep
            s = s[:m.start()] + ind + ('\n' + ind).join(lines_new) + s[m.end():]
        etl[t]['sql'] = s
    for t, reps in RAW.items():
        if t not in etl:
            continue
        for old, new in reps:
            if old not in etl[t]['sql']:
                raise ValueError(f'{t}: 找不到 {old!r}')
            etl[t]['sql'] = etl[t]['sql'].replace(old, new)
    for t, fields in LINE.items():
        if t not in etl:
            continue
        lines = etl[t]['sql'].split('\n')
        for f, (expr, note) in fields.items():
            hit = False
            for i, l in enumerate(lines):
                if '待确认' not in l or l.lstrip().startswith('--'):
                    continue
                m = re.match(rf'^(\s*)(.*?)\s+AS\s+{f}(,?)\s*(--.*)?$', l)
                if m:
                    lines[i] = f"{m.group(1)}{expr} AS {f}{m.group(3)}  -- {_cn(D, t, f)}｜口径：{note}"
                    hit = True
            if not hit:
                log.append(f'{t}.{f} 未找到待确认行')
        etl[t]['sql'] = '\n'.join(lines)
    # 重新统计：待确认 = 仍带「待确认：」的代码行
    for t, e in etl.items():
        lines = e['sql'].split('\n')
        rv = sum(1 for l in lines if '待确认：' in l and not l.lstrip().startswith('--'))
        old = e['stats'].get('review', 0)
        if t in FULL:
            n = len(D.f.get(t, []))
            e['stats'] = {'auto': 0, 'rule': n - rv, 'review': rv}
        elif rv != old:
            e['stats'] = {**e['stats'], 'rule': e['stats'].get('rule', 0) + max(old - rv, 0), 'review': rv}
        s = e['sql']
        s = re.sub(r'(规则翻译 )\d+( · 待确认 )\d+', lambda m: f"{m.group(1)}{e['stats']['rule']}{m.group(2)}{rv}", s)
        if rv == 0:
            s = re.sub(r'^-- 标「待确认」的字段：[^\n]*\n', '', s, flags=re.M)
        e['sql'] = s
    return log
