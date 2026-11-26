-- dwd.dwd_fin_refund_payment_di  退款资金明细
-- 粒度：1行=1条退款明细（refund_detail_no）
-- 来源：ods_ord_refund_detail_di
-- 生成方式：Spark SQL / Hive；字段 16 个：直接翻译 15 · 规则翻译 1 · 待确认 0
-- 主表增量先去重再关联；每个 WITH 逻辑块只取用到的列并先过滤分区

WITH
refund_detail_rn AS (                                                             -- 「退款明细（按支付记录）」当日增量，同一主键按 binlog 时间倒序编号
  SELECT binlog_time, create_time, id, payment_no, refund_amount, refund_channel, refund_detail_no,
         refund_detail_status, refund_no, refund_transaction_no, tenant_id, update_time, binlog_op_type,
         ROW_NUMBER() OVER (PARTITION BY id ORDER BY binlog_time DESC) AS rn      -- 同一主键多次变更，按 binlog 时间倒序编号
  FROM ods.ods_ord_refund_detail_di
  WHERE travel_date = '${bizdate}'                                                -- 只取当日分区
),
refund_detail_latest AS (                                                         -- 「退款明细（按支付记录）」每个主键只保留最新一条，剔除已删除记录
  SELECT binlog_time, create_time, id, payment_no, refund_amount, refund_channel, refund_detail_no,
         refund_detail_status, refund_no, refund_transaction_no, tenant_id, update_time
  FROM refund_detail_rn
  WHERE rn = 1
    AND binlog_op_type <> 'DELETE'                                                -- 剔除源库已删除的记录
),
payment_dtl AS (                                                                  -- 「支付明细」当日数据，只取用到的列
  SELECT order_group_no, pay_direction_type, pay_method_type, payment_no
  FROM dwd.dwd_fin_payment_di
  WHERE travel_date = '${bizdate}'                                                -- 只取当日分区
)
INSERT OVERWRITE TABLE dwd.dwd_fin_refund_payment_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  refund_detail_latest.id                                      AS refund_detail_id,  -- 退款明细
  refund_detail_latest.refund_detail_no                        AS refund_detail_no,  -- 退款明细号
  refund_detail_latest.refund_no                               AS refund_no,      -- 归属退款单号
  refund_detail_latest.payment_no                              AS payment_no,     -- 关联支付记录号（退款来源）
  ROUND(refund_detail_latest.refund_amount / 100, 2)           AS refund_amt,     -- 本次退款金额（元
  refund_detail_latest.refund_channel                          AS refund_channel_type,  -- 退款渠道
  refund_detail_latest.refund_transaction_no                   AS refund_transaction_no,  -- 支付中心返回的退款流水号
  refund_detail_latest.refund_detail_status                    AS refund_detail_status,  -- 明细状态
  refund_detail_latest.tenant_id                               AS tenant_id,      -- 租户ID（分库维度）
  refund_detail_latest.create_time                             AS create_time,    -- 创建时间
  refund_detail_latest.update_time                             AS update_time,    -- 更新时间
  payment_dtl.order_group_no                                   AS order_group_no,  -- 聚合单号
  payment_dtl.pay_method_type                                  AS pay_method_type,  -- 原支付方式
  payment_dtl.pay_direction_type                               AS pay_direction_type,  -- 原资金方向
  CASE WHEN refund_detail_latest.refund_detail_status = 'SUCCESS' THEN refund_detail_latest.binlog_time END AS finish_time,  -- 退款到账时间
  CURRENT_TIMESTAMP()                                          AS etl_time        -- ETL 加载时间
FROM refund_detail_latest
LEFT JOIN payment_dtl                                                             -- 关联「支付明细」，取 聚合单号、原支付方式、原资金方向
  ON payment_dtl.payment_no = refund_detail_latest.payment_no;                    -- 按 payment_no 关联
