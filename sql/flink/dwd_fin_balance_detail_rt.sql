-- ================================================================================================
-- dwd.dwd_fin_balance_detail_rt  实时商户余额明细
-- 依据：《3.0 通用财务报表 · 需求说明》v1.0（2026-11-24）
-- 业务规则：
--   · 与离线 dwd_fin_balance_detail_di 同口径同字段；只处理新增流水（流水不可变）
--   · 归属规则、账户、冻结记录、支付记录 lookup（缓存 10 分钟）；规则命中多条时按具体程度取第一条
-- 性能：
--   · lookup join，StarRocks 主键模型表；保留全部历史分区（余额报表始终实时）
-- ================================================================================================

INSERT INTO sr_dwd_fin_balance_detail_rt                                          -- 写入 StarRocks 目标表
SELECT
    DATE_FORMAT(f.create_time, 'yyyyMMdd')                           AS travel_date,  -- 数据日期
    f.flow_no,                                                                    -- 业务流水号
    CAST(f.create_time AS STRING)                                    AS flow_time,  -- 交易时间
    a.subject_id                                                     AS merchant_tenant_id,  -- 本方商户租户ID（账户主体）
    f.account_no,                                                                 -- 所属账本
    a.account_type,                                                               -- 账户类型
    f.flow_type,                                                                  -- 流水类型（业务库枚举）
    COALESCE(f.fee_item, '')                                         AS fee_item_code,  -- 费用项
    fz.release_event_type                                            AS frozen_event_type,  -- 冻结事件（解冻流水）
    COALESCE(r.report_code, 'UNCLASSIFIED')                          AS report_code,  -- 归属
    COALESCE(r.fee_type_name, f.flow_type)                           AS fee_type_name,  -- 费用类型
    IF(f.amount >= 0, '流入', '支出')                                 AS direction_name,  -- 收支方向（明细筛选）
    CAST(f.amount AS DECIMAL(18,2)) / 100                            AS change_amt,  -- 变动金额
    IF(                                                                           -- 计入余额报表的流入（元）
        r.report_code IN ('BALANCE', 'EXPENSE') AND f.amount > 0,
        CAST(f.amount AS DECIMAL(18,2)) / 100,
        0
    )  AS balance_in_amt,                                                         -- 计入余额报表的流入（元）
    IF(                                                                           -- 计入余额报表的流出
        r.report_code IN ('BALANCE', 'EXPENSE') AND f.amount < 0,
        -CAST(f.amount AS DECIMAL(18,2)) / 100,
        0
    ) AS balance_out_amt,                                                         -- 计入余额报表的流出
    CAST(f.balance_before AS DECIMAL(18,2)) / 100                    AS balance_before_amt,  -- 变动前可用余额（元）
    CAST(f.balance_after AS DECIMAL(18,2)) / 100                     AS balance_after_amt,  -- 余额
    CASE WHEN f.flow_type IN ('RECHARGE', 'WITHDRAW', 'FEE', 'RESOURCE', 'FREEZE', 'UNFREEZE') THEN 0
         WHEN f.amount >= 0 THEN COALESCE(pi.payer_tenant_id, 0) ELSE COALESCE(po.payee_tenant_id, 0) END AS counterparty_tenant_id,  -- 对方商户（明细筛选）
    CASE
        WHEN f.flow_type IN ('RECHARGE', 'WITHDRAW') THEN 'BANK'
        WHEN f.flow_type IN ('FEE', 'RESOURCE') THEN 'PLATFORM'
         WHEN f.flow_type IN ('FREEZE', 'UNFREEZE') THEN 'SELF'
         WHEN f.amount >= 0 THEN IF(                                              -- 对方类型
             pi.pay_direction_type = 'INBOUND',
             'CUSTOMER',
             'DISTRIBUTOR'
         ) ELSE 'SUPPLIER' END AS counterparty_type,                              -- 对方类型
    COALESCE(pi.order_group_no, po.order_group_no)                   AS biz_order_no,  -- 业务订单号
    f.related_no,                                                                 -- 关联订单号
    f.payment_batch_no,                                                           -- 关联支付批次号
    f.proc_time                                                      AS event_time  -- 事件时间（binlog 时间）
FROM ods_fin_fund_flow_rt f
JOIN dim_fin_account_lookup FOR SYSTEM_TIME AS OF f.proc_time AS a                -- 关联账户维度（维表查找），只保留商户 / 分销商账户
  ON a.account_no = f.account_no AND a.account_type IN ('MERCHANT', 'DISTRIBUTOR')  -- 按 account_no 关联
LEFT JOIN dwd_fin_frozen_rt_lookup FOR SYSTEM_TIME AS OF f.proc_time AS fz        -- 解冻流水关联冻结记录，取冻结原因（核销 / 退款）
  ON f.flow_type = 'UNFREEZE' AND fz.account_no = f.account_no AND fz.frozen_no = f.related_no  -- 按 account_no、related_no→frozen_no 关联
LEFT JOIN dim_fin_report_rule_first_lookup FOR SYSTEM_TIME AS OF f.proc_time AS r  -- 规则视图：每个（流水类型, 方向, 冻结事件）已按具体程度取第一条
  ON r.flow_type = f.flow_type                                                    -- 按 flow_type 关联
    AND r.direction_type = IF(f.amount >= 0, 'IN', 'OUT')
    AND r.frozen_event_type = COALESCE(fz.release_event_type, '')
LEFT JOIN dwd_fin_payment_rt_lookup FOR SYSTEM_TIME AS OF f.proc_time AS pi       -- 入账流水关联支付单，取付款方（交易对手）
  ON f.amount >= 0 AND pi.batch_no = f.payment_batch_no AND pi.payee_account_no = f.account_no  -- 按 payment_batch_no→batch_no、account_no→payee_account_no 关联
LEFT JOIN dwd_fin_payment_rt_lookup FOR SYSTEM_TIME AS OF f.proc_time AS po       -- 出账流水关联支付单，取收款方（交易对手）
  ON f.amount < 0 AND po.batch_no = f.payment_batch_no AND po.payer_account_no = f.account_no  -- 按 payment_batch_no→batch_no、account_no→payer_account_no 关联
WHERE f.op_type = 'I';
