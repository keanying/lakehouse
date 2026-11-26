-- dwd.dwd_ord_refund_ticket_di  退款票明细
-- 粒度：1行=1个退款单里的1张票
-- 来源：ods_ord_refund_order_di（refund_items JSON 展开）+ dwd_ord_ticket_di
-- 生成方式：Spark SQL / Hive；字段 18 个：直接翻译 14 · 规则翻译 3 · 待确认 1
-- 主表增量先去重再关联；每个 WITH 逻辑块只取用到的列并先过滤分区
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

WITH
refund_order_rn AS (                                                              -- 「退款单」当日增量，同一主键按 binlog 时间倒序编号
  SELECT create_time, id, initiator_type, order_group_no, refund_items, refund_no, refund_reason,
         refund_status, refund_type, tenant_id, binlog_op_type,
         ROW_NUMBER() OVER (PARTITION BY id ORDER BY binlog_time DESC) AS rn      -- 同一主键多次变更，按 binlog 时间倒序编号
  FROM ods.ods_ord_refund_order_di
  WHERE travel_date = '${bizdate}'                                                -- 只取当日分区
),
refund_order_latest AS (                                                          -- 「退款单」每个主键只保留最新一条，剔除已删除记录
  SELECT create_time, id, initiator_type, order_group_no, refund_items, refund_no, refund_reason,
         refund_status, refund_type, tenant_id
  FROM refund_order_rn
  WHERE rn = 1
    AND binlog_op_type <> 'DELETE'                                                -- 剔除源库已删除的记录
),
ticket_dtl AS (                                                                   -- 「票明细（出票）」当日数据，只取用到的列
  SELECT order_group_no, play_date, seller_tenant_id, sku_id
  FROM dwd.dwd_ord_ticket_di
  WHERE travel_date = '${bizdate}'                                                -- 只取当日分区
),
ticket_status_log_dtl AS (                                                        -- 「票状态流转明细」当日数据，只取用到的列
  SELECT after_status, order_group_no
  FROM dwd.dwd_ord_ticket_status_log_di
  WHERE travel_date = '${bizdate}'                                                -- 只取当日分区
),
refund_dtl AS (                                                                   -- 「退款单明细」当日数据，只取用到的列
  SELECT finish_time, refund_no
  FROM dwd.dwd_ord_refund_di
  WHERE travel_date = '${bizdate}'                                                -- 只取当日分区
)
INSERT OVERWRITE TABLE dwd.dwd_ord_refund_ticket_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  refund_order_latest.refund_no                                AS refund_no,      -- 退款单号
  refund_order_latest.order_group_no                           AS order_group_no,  -- 聚合单号
  GET_JSON_OBJECT(refund_order_latest.refund_items, '$.orderNo') AS order_no,     -- 子单号
  GET_JSON_OBJECT(refund_order_latest.refund_items, '$.ticketNos') AS ticket_no,  -- 票号
  ticket_dtl.seller_tenant_id                                  AS seller_tenant_id,  -- 卖家租户ID
  ticket_dtl.sku_id                                            AS sku_id,         -- SKU ID
  ticket_dtl.play_date                                         AS play_date,      -- 游玩日期
  refund_order_latest.refund_type                              AS refund_type,    -- 退款类型
  refund_order_latest.refund_status                            AS refund_status,  -- 退款状态
  refund_order_latest.initiator_type                           AS initiator_type,  -- 发起方
  refund_order_latest.refund_reason                            AS refund_reason_desc,  -- 退款原因
  ticket_status_log_dtl.after_status                           AS before_ticket_status,  -- 退票时票状态｜待确认：dwd_ord_ticket_status_log_di.after_status 取退款申请前最后一条
  1                                                            AS refund_ticket_qty,  -- 退款票数
  GET_JSON_OBJECT(refund_order_latest.refund_items, '$.amount') AS refund_amt,    -- 本票分摊退款金额（元）
  refund_order_latest.create_time                              AS apply_time,     -- 退款申请时间
  refund_dtl.finish_time                                       AS finish_time,    -- 退款完成时间
  refund_order_latest.tenant_id                                AS tenant_id,      -- 租户ID（分库维度）
  CURRENT_TIMESTAMP()                                          AS etl_time        -- ETL 加载时间
FROM refund_order_latest
LEFT JOIN ticket_dtl                                                              -- 关联「票明细（出票）」，取 卖家租户ID、SKU ID、游玩日期
  ON ticket_dtl.order_group_no = refund_order_latest.order_group_no               -- 按 order_group_no 关联
LEFT JOIN ticket_status_log_dtl                                                   -- 关联「票状态流转明细」，取 退票时票状态
  ON ticket_status_log_dtl.order_group_no = refund_order_latest.order_group_no    -- 按 order_group_no 关联
LEFT JOIN refund_dtl                                                              -- 关联「退款单明细」，取 退款完成时间
  ON refund_dtl.refund_no = refund_order_latest.refund_no;                        -- 按 refund_no 关联
