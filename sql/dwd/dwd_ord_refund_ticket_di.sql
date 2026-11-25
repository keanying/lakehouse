-- dwd.dwd_ord_refund_ticket_di  退款票明细
-- 粒度：1行=1个退款单里的1张票
-- 来源：ods_ord_refund_order_di（refund_items JSON 展开）+ dwd_ord_ticket_di
-- 生成方式：Spark SQL / Hive；字段 18 个：直接翻译 14 · 规则翻译 3 · 待确认 1
-- ODS 增量按主键取最新一条（ROW_NUMBER），剔除删除记录
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT OVERWRITE TABLE dwd.dwd_ord_refund_ticket_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  a.refund_no                                    AS refund_no,          -- 退款单号
  a.order_group_no                               AS order_group_no,     -- 聚合单号
  GET_JSON_OBJECT(a.refund_items, '$.orderNo')   AS order_no,           -- 子单号
  GET_JSON_OBJECT(a.refund_items, '$.ticketNos') AS ticket_no,          -- 票号
  j1.seller_tenant_id                            AS seller_tenant_id,   -- 卖家租户ID
  j1.sku_id                                      AS sku_id,             -- SKU ID
  j1.play_date                                   AS play_date,          -- 游玩日期
  a.refund_type                                  AS refund_type,        -- 退款类型
  a.refund_status                                AS refund_status,      -- 退款状态
  a.initiator_type                               AS initiator_type,     -- 发起方
  a.refund_reason                                AS refund_reason_desc,  -- 退款原因
  j2.after_status                                AS before_ticket_status,  -- 退票时票状态｜待确认：dwd_ord_ticket_status_log_di.after_status 取退款申请前最后一条
  1                                              AS refund_ticket_qty,  -- 退款票数
  GET_JSON_OBJECT(a.refund_items, '$.amount')    AS refund_amt,         -- 本票分摊退款金额（元）
  a.create_time                                  AS apply_time,         -- 退款申请时间
  j3.finish_time                                 AS finish_time,        -- 退款完成时间
  a.tenant_id                                    AS tenant_id,          -- 租户ID（分库维度）
  CURRENT_TIMESTAMP()                            AS etl_time            -- ETL 加载时间
FROM (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY id ORDER BY binlog_time DESC) AS rn  -- 同一主键多次变更，按 binlog 时间倒序编号
  FROM ods.ods_ord_refund_order_di
  WHERE travel_date = '${bizdate}'                                      -- 只取当日分区
) a                                                                     -- 主表当日增量，按主键取最新一条
LEFT JOIN dwd.dwd_ord_ticket_di j1                                      -- 关联「票明细（出票）」，取 卖家租户ID、SKU ID、游玩日期
  ON j1.order_group_no = a.order_group_no                               -- 按 order_group_no 关联
 AND j1.travel_date = '${bizdate}'                                      -- 只取当日分区
LEFT JOIN dwd.dwd_ord_ticket_status_log_di j2                           -- 关联「票状态流转明细」，取 退票时票状态
  ON j2.order_group_no = a.order_group_no                               -- 按 order_group_no 关联
 AND j2.travel_date = '${bizdate}'                                      -- 只取当日分区
LEFT JOIN dwd.dwd_ord_refund_di j3                                      -- 关联「退款单明细」，取 退款完成时间
  ON j3.refund_no = a.refund_no                                         -- 按 refund_no 关联
 AND j3.travel_date = '${bizdate}'                                      -- 只取当日分区
WHERE a.rn = 1                                                          -- 只保留每个主键的最新一条
  AND a.binlog_op_type <> 'DELETE';                                     -- 剔除源库已删除的记录
