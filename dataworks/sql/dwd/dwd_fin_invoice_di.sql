-- ================================================================================================
-- dwd.dwd_fin_invoice_di  开票明细
-- 粒度：1行=1次开票（电子发票）
-- 分区：travel_date（YYYYMMDD）
-- 调度：每日，依赖上游 ODS 当日分区与相关维表
-- 上游：ods_fin_invoice_records_df
-- 业务规则 / 修正：
--   · 开票记录为全量快照，按开票日 = bizdate 取当日开票；取票人电话 / 身份证、原始订单报文不进 DWD
--   · 待确认：开票金额不在列上（在 original_order_info 报文里），按订单号关联 dwd_ord_order_di 取订单金额，或上线前确认报文字段
-- ================================================================================================
INSERT OVERWRITE TABLE dwd.dwd_fin_invoice_di PARTITION (travel_date = '${bizdate}')
SELECT
    CAST(id AS BIGINT)                                           AS invoice_record_id,
    CAST(sid AS BIGINT)                                          AS supplier_id,
    CAST(member_id AS BIGINT)                                    AS member_id,
    ordernum                                                     AS order_no,
    out_trade_no,
    serial_num                                                   AS invoice_serial_no,
    invoice_code,
    invoice_num                                                  AS invoice_no,
    enterprise_name,
    tariff_number                                                AS tax_no,
    CAST(sys_id AS INT)                                          AS con_sys_id,
    CAST(invoice_type AS INT)                                    AS invoice_type,
    CAST(records_type AS INT)                                    AS records_type,
    CAST(invoice_status AS INT)                                  AS invoice_status,
    CAST(order_type AS INT)                                      AS order_type,
    IF(COALESCE(red_info, '') <> '', 1, 0)                       AS red_flag,
    source                                                       AS invoice_source,
    reason                                                       AS fail_reason,
    CAST(operator_id AS BIGINT)                                  AS operator_id,
    FROM_UNIXTIME(add_time)                                      AS invoice_time,
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time
FROM ods.ods_fin_invoice_records_df
WHERE travel_date = '${bizdate}'
  AND FROM_UNIXTIME(add_time, 'yyyyMMdd') = '${bizdate}'   -- 全量快照取当日事件
