-- dwd.dwd_ord_refund_di  退款单明细
-- 粒度：1行=1个退款单（refund_no）
-- 来源：ods_ord_refund_order_di
-- 生成方式：Spark SQL / Hive；字段 21 个：直接翻译 18 · 规则翻译 3 · 待确认 0
-- 主表增量先去重再关联；每个 WITH 逻辑块只取用到的列并先过滤分区

WITH
refund_order_rn AS (                                                              -- 「退款单」当日增量，同一主键按 binlog 时间倒序编号
  SELECT approve_time, approver_id, binlog_time, create_time, id, initiator_id, initiator_type,
         order_group_no, refund_amount, refund_items, refund_no, refund_reason, refund_status,
         refund_type, tenant_id, update_time, binlog_op_type,
         ROW_NUMBER() OVER (PARTITION BY id ORDER BY binlog_time DESC) AS rn      -- 同一主键多次变更，按 binlog 时间倒序编号
  FROM ods.ods_ord_refund_order_di
  WHERE travel_date = '${bizdate}'                                                -- 只取当日分区
),
refund_order_latest AS (                                                          -- 「退款单」每个主键只保留最新一条，剔除已删除记录
  SELECT approve_time, approver_id, binlog_time, create_time, id, initiator_id, initiator_type,
         order_group_no, refund_amount, refund_items, refund_no, refund_reason, refund_status,
         refund_type, tenant_id, update_time
  FROM refund_order_rn
  WHERE rn = 1
    AND binlog_op_type <> 'DELETE'                                                -- 剔除源库已删除的记录
),
order_group_dtl AS (                                                              -- 「聚合单明细」当日数据，只取用到的列
  SELECT channel_id, order_group_no, seller_tenant_id
  FROM dwd.dwd_ord_order_group_di
  WHERE travel_date = '${bizdate}'                                                -- 只取当日分区
)
INSERT OVERWRITE TABLE dwd.dwd_ord_refund_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  refund_order_latest.id                                       AS refund_id,      -- 退款单ID（源表主键 id）
  refund_order_latest.refund_no                                AS refund_no,      -- 退款单号
  refund_order_latest.order_group_no                           AS order_group_no,  -- 归属聚合单号
  refund_order_latest.refund_type                              AS refund_type,    -- 退款类型
  refund_order_latest.refund_reason                            AS refund_reason_desc,  -- 退款原因
  ROUND(refund_order_latest.refund_amount / 100, 2)            AS refund_amt,     -- 退款总金额（元）
  refund_order_latest.refund_status                            AS refund_status,  -- 状态
  refund_order_latest.initiator_type                           AS initiator_type,  -- 发起方
  refund_order_latest.initiator_id                             AS initiator_id,   -- 发起方ID
  refund_order_latest.approver_id                              AS approver_id,    -- 审批人ID
  refund_order_latest.approve_time                             AS approve_time,   -- 审批时间
  refund_order_latest.tenant_id                                AS tenant_id,      -- 租户ID（分库维度）
  refund_order_latest.create_time                              AS create_time,    -- 创建时间
  refund_order_latest.update_time                              AS update_time,    -- 更新时间
  order_group_dtl.seller_tenant_id                             AS seller_tenant_id,  -- 卖家租户ID
  order_group_dtl.channel_id                                   AS channel_id,     -- 入口渠道ID
  refund_order_latest.create_time                              AS apply_time,     -- 退款申请时间
  CASE WHEN refund_order_latest.refund_status = 'COMPLETED' THEN refund_order_latest.binlog_time END AS finish_time,  -- 退款完成时间
  ROUND((UNIX_TIMESTAMP(CASE WHEN refund_order_latest.refund_status = 'COMPLETED' THEN refund_order_latest.binlog_time END) - UNIX_TIMESTAMP(refund_order_latest.create_time)) / 3600, 2) AS process_hour_qty,  -- 退款处理时长
  SIZE(FLATTEN(FROM_JSON(refund_order_latest.refund_items, 'array<struct<orderNo:string,ticketNos:array<string>,amount:bigint>>').ticketNos)) AS refund_ticket_qty,  -- 退款票数
  CURRENT_TIMESTAMP()                                          AS etl_time        -- ETL 加载时间
FROM refund_order_latest
LEFT JOIN order_group_dtl                                                         -- 关联「聚合单明细」，取 卖家租户ID、入口渠道ID
  ON order_group_dtl.order_group_no = refund_order_latest.order_group_no;         -- 按 order_group_no 关联
