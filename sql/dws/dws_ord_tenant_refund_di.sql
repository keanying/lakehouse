-- dws.dws_ord_tenant_refund_di  商户×SKU 退款日汇总
-- 粒度：travel_date × seller_tenant_id × sku_id × refund_type × initiator_type × refund_reason_desc
-- 来源：dwd_ord_refund_di, dwd_ord_refund_ticket_di
-- 生成方式：Spark SQL / Hive；字段 14 个：直接翻译 5 · 规则翻译 9 · 待确认 0
-- 多来源：每个来源先按粒度键预聚合，UNION ALL 后再汇总

WITH
src_refund AS (                                                               -- 来源「退款单明细」按粒度键预聚合
  SELECT
    seller_tenant_id AS seller_tenant_id,                                     -- 卖家租户ID
    CAST(NULL AS BIGINT) AS sku_id,
    refund_type AS refund_type,                                               -- 退款类型
    initiator_type AS initiator_type,                                         -- 发起方
    refund_reason_desc AS refund_reason_desc,                                 -- 退款原因
    COUNT(refund_no) AS refund_apply_qty,                                     -- 退款申请单数
    COUNT(CASE WHEN refund_status='COMPLETED' THEN refund_no END) AS refund_success_qty,  -- 退款完成单数
    NULL AS refund_ticket_qty,
    NULL AS refund_amt,
    SUM(CASE WHEN refund_status = 'COMPLETED' THEN process_hour_qty END) AS refund_process_hour_qty,  -- 退款处理总时长｜口径：已完成退款的处理时长合计（求平均用）
    COUNT(CASE WHEN refund_status IN ('APPROVED', 'PROCESSING', 'COMPLETED') AND COALESCE(approver_id, 0) = 0 THEN refund_no END) AS auto_approve_refund_qty,  -- 超时自动通过退款单数｜口径：口径说明：退款单没有审批方式字段，按「已通过但没有审批人」认定为超时自动通过
    COUNT(CASE WHEN refund_status='REJECTED' THEN refund_no END) AS refund_reject_qty,  -- 退款驳回单数
    NULL AS verified_refund_ticket_qty
  FROM dwd.dwd_ord_refund_di s                                                -- 来源表「退款单明细」
  WHERE s.travel_date = '${bizdate}'                                          -- 只取当日分区
  GROUP BY seller_tenant_id, refund_type, initiator_type, refund_reason_desc  -- 按粒度键汇总
),
src_refund_ticket AS (                                                        -- 来源「退款票明细」按粒度键预聚合
  SELECT
    seller_tenant_id AS seller_tenant_id,                                     -- 卖家租户ID
    sku_id AS sku_id,                                                         -- SKU ID
    refund_type AS refund_type,                                               -- 退款类型
    initiator_type AS initiator_type,                                         -- 发起方
    refund_reason_desc AS refund_reason_desc,                                 -- 退款原因
    NULL AS refund_apply_qty,
    NULL AS refund_success_qty,
    COUNT(DISTINCT CASE WHEN refund_status = 'COMPLETED' THEN ticket_no END) AS refund_ticket_qty,  -- 退款票数｜口径：退款完成的票
    SUM(CASE WHEN refund_status = 'COMPLETED' THEN refund_amt END) AS refund_amt,  -- 退款金额
    NULL AS refund_process_hour_qty,
    NULL AS auto_approve_refund_qty,
    NULL AS refund_reject_qty,
    COUNT(DISTINCT CASE WHEN refund_status = 'COMPLETED' AND before_ticket_status IN ('PARTIALLY_USED', 'USED') THEN ticket_no END) AS verified_refund_ticket_qty  -- 核销后退款票数｜口径：退款时票已部分 / 全部使用
  FROM dwd.dwd_ord_refund_ticket_di s                                         -- 来源表「退款票明细」
  WHERE s.travel_date = '${bizdate}'                                          -- 只取当日分区
  GROUP BY seller_tenant_id, sku_id, refund_type, initiator_type, refund_reason_desc  -- 按粒度键汇总
),
all_src AS (                                                                  -- 各来源字段已对齐，UNION ALL 合并（比多表 FULL JOIN 少 shuffle）
  SELECT * FROM src_refund
  UNION ALL
  SELECT * FROM src_refund_ticket
)
INSERT OVERWRITE TABLE dws.dws_ord_tenant_refund_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  u.seller_tenant_id,                                                         -- 卖家租户ID
  u.sku_id,                                                                   -- SKU ID
  u.refund_type,                                                              -- 退款类型
  u.initiator_type,                                                           -- 发起方
  u.refund_reason_desc,                                                       -- 退款原因
  SUM(u.refund_apply_qty) AS refund_apply_qty,                                -- 退款申请单数
  SUM(u.refund_success_qty) AS refund_success_qty,                            -- 退款完成单数
  SUM(u.refund_ticket_qty) AS refund_ticket_qty,                              -- 退款票数
  SUM(u.refund_amt) AS refund_amt,                                            -- 退款金额
  SUM(u.refund_process_hour_qty) AS refund_process_hour_qty,                  -- 退款处理总时长
  SUM(u.auto_approve_refund_qty) AS auto_approve_refund_qty,                  -- 超时自动通过退款单数
  SUM(u.refund_reject_qty) AS refund_reject_qty,                              -- 退款驳回单数
  SUM(u.verified_refund_ticket_qty) AS verified_refund_ticket_qty,            -- 核销后退款票数
  CURRENT_TIMESTAMP() AS etl_time                                             -- ETL 加载时间
FROM all_src u
GROUP BY u.seller_tenant_id, u.sku_id, u.refund_type, u.initiator_type, u.refund_reason_desc;  -- 按粒度键汇总
