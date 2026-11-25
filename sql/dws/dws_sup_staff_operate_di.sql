-- dws.dws_sup_staff_operate_di  员工操作日汇总（窗口/导游/核销员）
-- 粒度：travel_date × tenant_id × staff_id
-- 来源：dwd_ord_order_group_di, dwd_ord_verify_di, dwd_ord_refund_di
-- 生成方式：Spark SQL / Hive；字段 7 个：直接翻译 2 · 规则翻译 1 · 待确认 4
-- 多来源：每个来源表按粒度键先汇总，UNION ALL 后再合并
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT OVERWRITE TABLE dws.dws_sup_staff_operate_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  u.tenant_id,                                  -- 租户ID
  u.staff_id,                                   -- 员工ID
  SUM(u.staff_order_qty) AS staff_order_qty,    -- 员工代下单数
  SUM(u.staff_pay_amt) AS staff_pay_amt,        -- 员工代下单支付金额
  SUM(u.staff_verify_qty) AS staff_verify_qty,  -- 员工核销次数
  SUM(u.staff_refund_qty) AS staff_refund_qty,  -- 员工发起退款单数
  CURRENT_TIMESTAMP() AS etl_time               -- ETL 加载时间
FROM (
  -- 来源：dwd_ord_order_di
  SELECT
    tenant_id AS tenant_id,                     -- 租户ID
    CAST(NULL AS BIGINT) AS staff_id,           -- 员工ID
    COUNT(CASE WHEN operator_type='TENANT_STAFF' THEN order_no END) AS staff_order_qty,  -- 员工代下单数
    NULL AS staff_pay_amt,                      -- 员工代下单支付金额｜待确认：sum(pay_amt) where operator_type='TENANT_STAFF'
    NULL AS staff_verify_qty,                   -- 员工核销次数
    NULL AS staff_refund_qty                    -- 员工发起退款单数
  FROM dwd.dwd_ord_order_di s                   -- 来源表「子单明细」
  WHERE s.travel_date = '${bizdate}'            -- 只取当日分区
  GROUP BY tenant_id                            -- 按粒度键汇总
  UNION ALL                                     -- 合并各来源
  -- 来源：dwd_ord_verify_di
  SELECT
    tenant_id AS tenant_id,                     -- 租户ID
    operator_id AS staff_id,                    -- 员工ID
    NULL AS staff_order_qty,                    -- 员工代下单数
    NULL AS staff_pay_amt,                      -- 员工代下单支付金额
    COUNT(CASE WHEN 1 = 1 THEN verify_no END) AS staff_verify_qty,  -- 员工核销次数｜待确认：group by operator_id
    NULL AS staff_refund_qty                    -- 员工发起退款单数
  FROM dwd.dwd_ord_verify_di s                  -- 来源表「核销明细（权益级）」
  WHERE s.travel_date = '${bizdate}'            -- 只取当日分区
  GROUP BY tenant_id, operator_id               -- 按粒度键汇总
  UNION ALL                                     -- 合并各来源
  -- 来源：dwd_ord_refund_di
  SELECT
    tenant_id AS tenant_id,                     -- 租户ID
    approver_id AS staff_id,                    -- 员工ID
    NULL AS staff_order_qty,                    -- 员工代下单数
    NULL AS staff_pay_amt,                      -- 员工代下单支付金额
    NULL AS staff_verify_qty,                   -- 员工核销次数
    COUNT(CASE WHEN 1 = 1 THEN refund_no END) AS staff_refund_qty  -- 员工发起退款单数｜待确认：group by initiator_id
  FROM dwd.dwd_ord_refund_di s                  -- 来源表「退款单明细」
  WHERE s.travel_date = '${bizdate}'            -- 只取当日分区
  GROUP BY tenant_id, approver_id               -- 按粒度键汇总
) u                                             -- 各来源合并后的明细
GROUP BY u.tenant_id, u.staff_id;               -- 按粒度键汇总
