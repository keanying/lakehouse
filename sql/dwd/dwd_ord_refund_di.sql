-- dwd.dwd_ord_refund_di  退款单明细
-- 粒度：1行=1个退款单（refund_no）
-- 来源：ods_ord_refund_order_di
-- 生成方式：Spark SQL / Hive；字段 21 个：直接翻译 18 · 规则翻译 3 · 待确认 0
-- ODS 增量按主键取最新一条（ROW_NUMBER），剔除删除记录

INSERT OVERWRITE TABLE dwd.dwd_ord_refund_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
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
  CURRENT_TIMESTAMP()                                          AS etl_time        -- ETL 加载时间
FROM (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY id ORDER BY binlog_time DESC) AS rn   -- 同一主键多次变更，按 binlog 时间倒序编号
  FROM ods.ods_ord_refund_order_di
  WHERE travel_date = '${bizdate}'                                                -- 只取当日分区
) a                                                                               -- 主表当日增量，按主键取最新一条
LEFT JOIN dwd.dwd_ord_order_group_di j1                                           -- 关联「聚合单明细」，取 卖家租户ID、入口渠道ID
  ON j1.order_group_no = a.order_group_no                                         -- 按 order_group_no 关联
 AND j1.travel_date = '${bizdate}'                                                -- 只取当日分区
WHERE a.rn = 1                                                                    -- 只保留每个主键的最新一条
  AND a.binlog_op_type <> 'DELETE';                                               -- 剔除源库已删除的记录
