-- dwd.dwd_ord_refund_rt  实时退款明细
-- 粒度：1行=1个退款单（refund_no）
-- 来源：ods_ord_refund_order_rt
-- 生成方式：Flink SQL（CDC 源表 → StarRocks 主键模型表；维表 Lookup Join）；字段 22 个：直接翻译 18 · 规则翻译 4 · 待确认 0
-- 源表 ods.*_rt 为 Flink CDC 表（含 proc_time AS PROCTIME()），目标表在 StarRocks catalog 中

INSERT INTO dwd.dwd_ord_refund_rt                                                 -- 写入 StarRocks 目标表
SELECT
  DATE_FORMAT(a.create_time, 'yyyyMMdd')                       AS travel_date,    -- 数据日期
  a.id                                                         AS refund_id,      -- 退款单ID（源表主键 id）
  a.refund_no                                                  AS refund_no,      -- 退款单号
  a.order_group_no                                             AS order_group_no,  -- 归属聚合单号
  a.refund_type                                                AS refund_type,    -- 退款类型
  a.refund_reason                                              AS refund_reason_desc,  -- 退款原因
  ROUND(a.refund_amount / 100, 2)                              AS refund_amt,     -- 退款总金额（元）
  a.refund_status                                              AS refund_status,  -- 状态
  a.initiator_type                                             AS initiator_type,  -- 发起方
  a.initiator_id                                               AS initiator_id,   -- 发起方ID
  a.approver_id                                                AS approver_id,    -- 审批人ID
  a.approve_time                                               AS approve_time,   -- 审批时间
  a.tenant_id                                                  AS tenant_id,      -- 租户ID（分库维度）
  a.create_time                                                AS create_time,    -- 创建时间
  a.update_time                                                AS update_time,    -- 更新时间
  j1.seller_tenant_id                                          AS seller_tenant_id,  -- 卖家租户ID
  j1.channel_id                                                AS channel_id,     -- 入口渠道ID
  a.create_time                                                AS apply_time,     -- 退款申请时间
  CASE WHEN a.refund_status = 'COMPLETED' THEN a.binlog_time END AS finish_time,  -- 退款完成时间
  (CASE WHEN a.refund_status = 'COMPLETED' THEN a.binlog_time END) - (a.create_time) AS process_hour_qty,  -- 退款处理时长
  GET_JSON_OBJECT(a.refund_items, '$.ticketNos')               AS refund_ticket_qty,  -- 退款票数
  CURRENT_TIMESTAMP                                            AS event_time      -- 事件时间（binlog 时间）
FROM ods.ods_ord_refund_order_rt a                                                -- 主表「退款单 binlog 流」
LEFT JOIN dwd.dwd_ord_order_group_di j1                                           -- 关联「聚合单明细」，取 卖家租户ID、入口渠道ID
  ON j1.order_group_no = a.order_group_no                                         -- 按 order_group_no 关联
 AND j1.travel_date = '${bizdate}';                                               -- 只取当日分区
