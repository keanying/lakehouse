-- dws.dws_sup_staff_operate_di  员工操作日汇总
-- 粒度：travel_date × tenant_id × staff_id
-- 来源：dwd_ord_order_di + dwd_ord_verify_di + dwd_ord_refund_di
-- 生成方式：手写（结构不适合按字段自动翻译）；业务规则：
--   · 员工 = 订单操作人（operator_type = TENANT_STAFF 的 operator_id）/ 核销操作人 / 发起退款的商户员工（initiator_type = MERCHANT 的 initiator_id）
--   · 原自动生成版本把退款按审批人归属、代下单没有员工粒度，此处按发起人 / 操作人改正
-- 性能：
--   · 三个来源各自按（租户, 员工）预聚合后 UNION ALL

WITH x AS (
    SELECT tenant_id, operator_id AS staff_id,
           COUNT(DISTINCT order_no) AS staff_order_qty,                  -- 员工代下单数
           SUM(CASE WHEN pay_time IS NOT NULL THEN unit_price_amt * buy_ticket_qty END) AS staff_pay_amt,  -- 员工代下单支付金额
           0 AS staff_verify_qty, 0 AS staff_refund_qty                  -- 员工发起退款单数
    FROM dwd.dwd_ord_order_di
    WHERE travel_date = '${bizdate}' AND operator_type = 'TENANT_STAFF'  -- 只取当日分区，并按条件过滤
    GROUP BY tenant_id, operator_id                                      -- 按粒度键汇总
    UNION ALL
    SELECT tenant_id, operator_id, 0, 0, COUNT(CASE WHEN verify_result_type = 'SUCCESS' THEN verify_no END), 0
    FROM dwd.dwd_ord_verify_di
    WHERE travel_date = '${bizdate}' AND operator_id > 0                 -- 只取当日分区，并按条件过滤
    GROUP BY tenant_id, operator_id                                      -- 按粒度键汇总
    UNION ALL
    SELECT tenant_id, initiator_id, 0, 0, 0, COUNT(refund_no)
    FROM dwd.dwd_ord_refund_di
    WHERE travel_date = '${bizdate}' AND initiator_type = 'MERCHANT'     -- 只取当日分区，并按条件过滤
    GROUP BY tenant_id, initiator_id                                     -- 按粒度键汇总
)
INSERT OVERWRITE TABLE dws.dws_sup_staff_operate_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT tenant_id, staff_id,
       SUM(staff_order_qty)  AS staff_order_qty,                         -- 员工代下单数
       SUM(staff_pay_amt)    AS staff_pay_amt,                           -- 员工代下单支付金额
       SUM(staff_verify_qty) AS staff_verify_qty,                        -- 员工核销次数
       SUM(staff_refund_qty) AS staff_refund_qty,                        -- 员工发起退款单数
       CURRENT_TIMESTAMP() AS etl_time                                   -- ETL 加载时间
FROM x
GROUP BY tenant_id, staff_id;                                            -- 按粒度键汇总
