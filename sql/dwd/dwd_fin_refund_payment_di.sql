-- dwd.dwd_fin_refund_payment_di  退款资金明细
-- 粒度：1行=1条退款明细（refund_detail_no）
-- 来源：ods_ord_refund_detail_di
-- 生成方式：Spark SQL / Hive；字段 16 个：直接翻译 15 · 规则翻译 1 · 待确认 0
-- ODS 增量按主键取最新一条（ROW_NUMBER），剔除删除记录

INSERT OVERWRITE TABLE dwd.dwd_fin_refund_payment_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  a.id                                                         AS refund_detail_id,  -- 退款明细
  a.refund_detail_no                                           AS refund_detail_no,  -- 退款明细号
  a.refund_no                                                  AS refund_no,      -- 归属退款单号
  a.payment_no                                                 AS payment_no,     -- 关联支付记录号（退款来源）
  ROUND(a.refund_amount / 100, 2)                              AS refund_amt,     -- 本次退款金额（元
  a.refund_channel                                             AS refund_channel_type,  -- 退款渠道
  a.refund_transaction_no                                      AS refund_transaction_no,  -- 支付中心返回的退款流水号
  a.refund_detail_status                                       AS refund_detail_status,  -- 明细状态
  a.tenant_id                                                  AS tenant_id,      -- 租户ID（分库维度）
  a.create_time                                                AS create_time,    -- 创建时间
  a.update_time                                                AS update_time,    -- 更新时间
  j1.order_group_no                                            AS order_group_no,  -- 聚合单号
  j1.pay_method_type                                           AS pay_method_type,  -- 原支付方式
  j1.pay_direction_type                                        AS pay_direction_type,  -- 原资金方向
  CASE WHEN a.refund_detail_status = 'SUCCESS' THEN a.binlog_time END AS finish_time,  -- 退款到账时间
  CURRENT_TIMESTAMP()                                          AS etl_time        -- ETL 加载时间
FROM (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY id ORDER BY binlog_time DESC) AS rn   -- 同一主键多次变更，按 binlog 时间倒序编号
  FROM ods.ods_ord_refund_detail_di
  WHERE travel_date = '${bizdate}'                                                -- 只取当日分区
) a                                                                               -- 主表当日增量，按主键取最新一条
LEFT JOIN dwd.dwd_fin_payment_di j1                                               -- 关联「支付明细」，取 聚合单号、原支付方式、原资金方向
  ON j1.payment_no = a.payment_no                                                 -- 按 payment_no 关联
 AND j1.travel_date = '${bizdate}'                                                -- 只取当日分区
WHERE a.rn = 1                                                                    -- 只保留每个主键的最新一条
  AND a.binlog_op_type <> 'DELETE';                                               -- 剔除源库已删除的记录
