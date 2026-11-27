-- ================================================================================================
-- dwd.dwd_fin_refund_payment_rt  实时退款明细（按支付记录）
-- 依据：《3.0 通用财务报表 · 需求说明》v1.0（2026-11-24）
-- 业务规则：
--   · 与离线 dwd_fin_refund_payment_di 同字段；finish_time = 明细状态变为 SUCCESS 的 binlog 时间
--   · 聚合单号 / 支付方式 / 方向按支付记录号 lookup
-- 性能：
--   · CDC 变更流，按退款明细号 upsert
-- ================================================================================================

INSERT INTO sr_dwd_fin_refund_payment_rt                                          -- 写入 StarRocks 目标表
SELECT
    DATE_FORMAT(d.create_time, 'yyyyMMdd')                           AS travel_date,  -- 数据日期
    d.id                                                             AS refund_detail_id,  -- 退款明细
    d.refund_detail_no, d.refund_no, d.payment_no,
    CAST(d.refund_amount AS DECIMAL(18,2)) / 100                     AS refund_amt,  -- 本次退款金额（元
    d.refund_channel                                                 AS refund_channel_type,  -- 退款渠道
    d.refund_transaction_no,                                                      -- 支付中心返回的退款流水号
    d.refund_detail_status,                                                       -- 明细状态
    d.tenant_id,                                                                  -- 租户ID（分库维度）
    CAST(d.create_time AS STRING)                                    AS create_time,  -- 创建时间
    CAST(d.update_time AS STRING)                                    AS update_time,  -- 更新时间
    p.order_group_no,                                                             -- 聚合单号
    p.pay_method_type,                                                            -- 原支付方式
    p.pay_direction_type,                                                         -- 原资金方向
    IF(d.refund_detail_status = 'SUCCESS', CAST(d.binlog_time AS STRING), CAST(NULL AS STRING)) AS finish_time,  -- 退款到账时间
    d.proc_time                                                      AS event_time  -- 事件时间（binlog 时间）
FROM ods_ord_refund_detail_rt d
LEFT JOIN dwd_fin_payment_rt_lookup FOR SYSTEM_TIME AS OF d.proc_time AS p ON p.payment_no = d.payment_no;
