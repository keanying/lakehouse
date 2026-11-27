-- dwd.dwd_ord_refund_ticket_di  退款票明细
-- 粒度：1行=1个退款单里的1张票
-- 来源：ods_ord_refund_order_di + dwd_ord_ticket_di + dwd_ord_ticket_status_log_di + dwd_ord_refund_di
-- 生成方式：手写（结构不适合按字段自动翻译）；业务规则：
--   · refund_items 是 JSON 数组 [{orderNo, ticketNos[], amount}]：先展开子单、再展开票号，一行一张票
--   · 本票退款金额 = 该子单退款金额（分）÷ 票数 ÷ 100
--   · 退票时票状态 = 退款申请时间之前最后一条票状态流转的变更后状态；无流转记录 = 可用
--   · 原自动生成版本按聚合单关联票 / 状态流转（一对多放大）、对数组直接取 $.orderNo，此处重写
-- 性能：
--   · 票、状态流转只取近 400 天，按票号关联

WITH r AS (
    SELECT id, refund_no, order_group_no, refund_type, refund_reason, refund_status, refund_items, initiator_type, tenant_id, create_time,
           ROW_NUMBER() OVER (PARTITION BY id ORDER BY binlog_time DESC) AS rn, binlog_op_type  -- 同一主键多次变更，按 binlog 时间倒序编号
    FROM ods.ods_ord_refund_order_di WHERE travel_date = '${bizdate}'
),
it AS (                                                                           -- 一行 = 一张退款票
    SELECT r.refund_no, r.order_group_no, r.refund_type, r.refund_reason, r.refund_status, r.initiator_type, r.tenant_id, r.create_time,
           i.orderNo AS order_no, tk AS ticket_no,                                -- 票号
           CAST(i.amount AS DECIMAL(18,2)) / NULLIF(SIZE(i.ticketNos), 0) / 100 AS refund_amt  -- 本票分摊退款金额（元）
    FROM r
    LATERAL VIEW EXPLODE(FROM_JSON(r.refund_items, 'array<struct<orderNo:string,ticketNos:array<string>,amount:bigint>>')) e AS i
    LATERAL VIEW EXPLODE(i.ticketNos) t AS tk
    WHERE r.rn = 1 AND r.binlog_op_type <> 'DELETE'                               -- 剔除源库已删除的记录
),
ticket AS (
    SELECT ticket_no, MAX(seller_tenant_id) AS seller_tenant_id, MAX(sku_id) AS sku_id, MAX(play_date) AS play_date
    FROM dwd.dwd_ord_ticket_di WHERE travel_date >= DATE_FORMAT(DATE_SUB(TO_DATE('${bizdate}', 'yyyyMMdd'), 400), 'yyyyMMdd') GROUP BY ticket_no
),
st AS (                                                                           -- 退款申请前最后一次票状态
    SELECT it.refund_no, it.ticket_no, MAX_BY(l.after_status, l.change_time) AS before_status
    FROM it
    JOIN (SELECT ticket_no, after_status, change_time FROM dwd.dwd_ord_ticket_status_log_di WHERE travel_date >= DATE_FORMAT(DATE_SUB(TO_DATE('${bizdate}', 'yyyyMMdd'), 400), 'yyyyMMdd')) l  -- 关联「票状态流转明细」按键聚合
      ON l.ticket_no = it.ticket_no AND l.change_time < it.create_time            -- 按 ticket_no 关联
    GROUP BY it.refund_no, it.ticket_no                                           -- 按粒度键汇总
),
fin AS (
    SELECT refund_no, MAX(finish_time) AS finish_time FROM dwd.dwd_ord_refund_di WHERE travel_date = '${bizdate}' GROUP BY refund_no
)
INSERT OVERWRITE TABLE dwd.dwd_ord_refund_ticket_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
    it.refund_no, it.order_group_no, it.order_no, it.ticket_no,
    tk.seller_tenant_id, tk.sku_id, tk.play_date,
    it.refund_type, it.refund_status, it.initiator_type, it.refund_reason AS refund_reason_desc,  -- 退款原因
    COALESCE(st.before_status, 'AVAILABLE')                       AS before_ticket_status,  -- 退票时票状态
    1                                                             AS refund_ticket_qty,  -- 退款票数
    ROUND(it.refund_amt, 2)                                       AS refund_amt,  -- 本票分摊退款金额（元）
    it.create_time                                                AS apply_time,  -- 退款申请时间
    fin.finish_time,                                                              -- 退款完成时间
    it.tenant_id,                                                                 -- 租户ID（分库维度）
    CURRENT_TIMESTAMP() AS etl_time                                               -- ETL 加载时间
FROM it
LEFT JOIN ticket tk ON tk.ticket_no = it.ticket_no
LEFT JOIN st ON st.refund_no = it.refund_no AND st.ticket_no = it.ticket_no
LEFT JOIN fin ON fin.refund_no = it.refund_no;
