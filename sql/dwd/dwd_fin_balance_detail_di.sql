-- ================================================================================================
-- dwd.dwd_fin_balance_detail_di  商户余额明细（余额报表事实）
-- 依据：《3.0 通用财务报表 · 需求说明》v1.0（2026-11-24）
-- 业务规则：
--   · 只取商户 / 分销商账户（平台账户不算），双式记账只算本方这一条（第十章 2）
--   · 归属按规则表：命中多条取最具体（带冻结事件 > 带方向 > 带费用项）；都不命中 = UNCLASSIFIED（5.5）
--   · 解冻流水分核销 / 退款：关联同账户同票（或同冻结单）的冻结记录（关联键待研发确认）
--   · 对方商户：订单类按支付批次号关联支付记录的另一侧（流入取付款方、支出取收款方，散客为 0）；充值 / 提现为银行；费用为平台
--   · 余额列取流水本身的变动后余额（快照值），不由前几笔累加（5.7）
-- 性能：
--   · 规则表 BROADCAST；支付记录只取近 400 天、按（批次, 账户）预聚合
-- ================================================================================================

WITH f AS (
    SELECT /*+ BROADCAST(a) */ f.flow_no,
           f.flow_time,                                                           -- 交易时间
           f.account_no,                                                          -- 所属账本
           a.subject_id AS merchant_tenant_id,                                    -- 本方商户租户ID（账户主体）
           a.account_type,                                                        -- 账户类型
           f.flow_type,                                                           -- 流水类型（业务库枚举）
           f.fee_item_code,                                                       -- 费用项
           f.change_amt, f.balance_before_amt, f.balance_after_amt, f.related_no, f.payment_batch_no,
           IF(f.change_amt >= 0, 'IN', 'OUT') AS direction_type                   -- 方向（相对本方商户）
    FROM dwd.dwd_fin_fund_flow_di f
    JOIN (
        SELECT account_no,                                                        -- 所属账本
        subject_id,
        account_type FROM dim.dim_fin_account_df WHERE travel_date = '${bizdate}' AND account_type IN ('MERCHANT', 'DISTRIBUTOR')
    ) a                                                                           -- 主表当日增量，按主键取最新一条
      ON a.account_no = f.account_no                                              -- 按 account_no 关联
    WHERE f.travel_date = '${bizdate}'                                            -- 只取当日分区
),
fe AS (                                                                           -- 当日释放的冻结记录：解冻流水的冻结事件
    SELECT account_no,                                                            -- 所属账本
           frozen_no,
           ticket_no,
           release_event_type FROM dwd.dwd_fin_frozen_di WHERE travel_date = '${bizdate}' AND frozen_status = 'RELEASED'
),
m AS (
    SELECT f.*, COALESCE(e1.release_event_type, e2.release_event_type) AS frozen_event_type  -- 冻结事件（解冻流水）
    FROM f
    LEFT JOIN fe e1
      ON f.flow_type = 'UNFREEZE' AND e1.account_no = f.account_no AND e1.frozen_no = f.related_no  -- 按 account_no、related_no→frozen_no 关联
    LEFT JOIN fe e2
      ON f.flow_type = 'UNFREEZE'
        AND e1.frozen_no IS NULL
        AND e2.account_no = f.account_no
        AND e2.ticket_no = f.related_no
),
hit AS (                                                                          -- 规则匹配：取最具体的一条
    SELECT * FROM (
        SELECT m.flow_no, r.report_code, r.fee_type_name,
               ROW_NUMBER() OVER (                                                -- 同一主键多次变更，按 binlog 时间倒序编号｜去重序号（1 = 最新）
                   PARTITION BY m.flow_no ORDER BY (r.frozen_event_type <> '') DESC,
                   (r.direction_type <> '') DESC,
                   (r.fee_item_code <> '') DESC
               ) AS rn                                                            -- 去重序号（1 = 最新）
        FROM m
        JOIN (SELECT * FROM dim.dim_fin_report_rule_f WHERE source_type = 'FUND_FLOW') r  -- 关联「财务报表归属规则」按键聚合
          ON r.flow_type = m.flow_type AND (r.fee_item_code = '' OR r.fee_item_code = m.fee_item_code)  -- 按 flow_type、fee_item_code 关联
         AND (r.direction_type = '' OR r.direction_type = m.direction_type)
           AND (r.frozen_event_type = '' OR r.frozen_event_type = COALESCE(m.frozen_event_type, ''))
    ) z WHERE rn = 1
),
pin AS (                                                                          -- 流入：本方为收款方的支付记录 → 对方 = 付款方
    SELECT batch_no,
           payee_account_no AS account_no,                                        -- 所属账本
           MAX(payer_tenant_id) AS cp_id,                                         -- 交易对手ID
           MAX(pay_direction_type) AS dir,                                        -- 资金方向
           MAX(order_group_no) AS order_group_no                                  -- 归属聚合单号
    FROM dwd.dwd_fin_payment_di WHERE travel_date >= DATE_FORMAT(DATE_SUB(TO_DATE('${bizdate}', 'yyyyMMdd'), 400), 'yyyyMMdd') GROUP BY batch_no,
    payee_account_no
),
pout AS (                                                                         -- 支出：本方为付款方的支付记录 → 对方 = 收款方
    SELECT batch_no,
           payer_account_no AS account_no,                                        -- 所属账本
           MAX(payee_tenant_id) AS cp_id,                                         -- 交易对手ID
           MAX(order_group_no) AS order_group_no                                  -- 归属聚合单号
    FROM dwd.dwd_fin_payment_di WHERE travel_date >= DATE_FORMAT(DATE_SUB(TO_DATE('${bizdate}', 'yyyyMMdd'), 400), 'yyyyMMdd') GROUP BY batch_no,
    payer_account_no
)
INSERT OVERWRITE TABLE dwd.dwd_fin_balance_detail_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT /*+ BROADCAST(h) */
    m.flow_no,                                                                    -- 业务流水号
    m.flow_time,                                                                  -- 交易时间
    m.merchant_tenant_id,                                                         -- 本方商户租户ID（账户主体）
    m.account_no,                                                                 -- 所属账本
    m.account_type,                                                               -- 账户类型
    m.flow_type,                                                                  -- 流水类型（业务库枚举）
    COALESCE(m.fee_item_code, '')                                    AS fee_item_code,  -- 费用项
    m.frozen_event_type,                                                          -- 冻结事件（解冻流水）
    COALESCE(h.report_code, 'UNCLASSIFIED')                          AS report_code,  -- 归属
    COALESCE(h.fee_type_name, m.flow_type)                           AS fee_type_name,  -- 费用类型
    IF(m.change_amt >= 0, '流入', '支出')                             AS direction_name,  -- 收支方向（明细筛选）
    m.change_amt,                                                                 -- 变动金额
    IF(h.report_code IN ('BALANCE', 'EXPENSE') AND m.change_amt > 0, m.change_amt, 0)   AS balance_in_amt,  -- 计入余额报表的流入（元）
    IF(h.report_code IN ('BALANCE', 'EXPENSE') AND m.change_amt < 0, -m.change_amt, 0)  AS balance_out_amt,  -- 计入余额报表的流出
    m.balance_before_amt,                                                         -- 变动前可用余额（元）
    m.balance_after_amt,                                                          -- 余额
    CASE WHEN m.flow_type IN ('RECHARGE', 'WITHDRAW', 'FEE', 'RESOURCE', 'FREEZE', 'UNFREEZE') THEN 0
         WHEN m.direction_type = 'IN' THEN COALESCE(pi.cp_id, 0) ELSE COALESCE(po.cp_id, 0) END              AS counterparty_tenant_id,  -- 对方商户（明细筛选）
    CASE WHEN m.flow_type IN ('RECHARGE', 'WITHDRAW') THEN 'BANK'
         WHEN m.flow_type IN ('FEE', 'RESOURCE') THEN 'PLATFORM'
         WHEN m.flow_type IN ('FREEZE', 'UNFREEZE') THEN 'SELF'
         WHEN m.direction_type = 'IN' THEN IF(pi.dir = 'INBOUND', 'CUSTOMER', 'DISTRIBUTOR')
         ELSE 'SUPPLIER' END                                                                                    AS counterparty_type,  -- 对方类型
    COALESCE(pi.order_group_no, po.order_group_no)                   AS biz_order_no,  -- 业务订单号
    m.related_no,                                                                 -- 关联订单号
    m.payment_batch_no,                                                           -- 关联支付批次号
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time           -- ETL 加载时间
FROM m
LEFT JOIN hit h ON h.flow_no = m.flow_no
LEFT JOIN pin pi
  ON m.direction_type = 'IN' AND pi.batch_no = m.payment_batch_no AND pi.account_no = m.account_no  -- 按 payment_batch_no→batch_no、account_no 关联
LEFT JOIN pout po
  ON m.direction_type = 'OUT' AND po.batch_no = m.payment_batch_no AND po.account_no = m.account_no;  -- 按 payment_batch_no→batch_no、account_no 关联
