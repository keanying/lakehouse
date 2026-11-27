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
INSERT OVERWRITE TABLE dwd.dwd_fin_invoice_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
    CAST(id AS BIGINT)                                           AS invoice_record_id,  -- 开票记录ID
    CAST(sid AS BIGINT)                                          AS supplier_id,  -- 供应商ID（租户ID）
    CAST(member_id AS BIGINT)                                    AS member_id,    -- 用户ID
    ordernum                                                     AS order_no,     -- 订单号
    out_trade_no,                                                                 -- 订单流水号
    serial_num                                                   AS invoice_serial_no,  -- 开票平台流水号
    invoice_code,                                                                 -- 发票代码
    invoice_num                                                  AS invoice_no,   -- 发票号码
    enterprise_name,                                                              -- 开票企业名称
    tariff_number                                                AS tax_no,       -- 企业税号
    CAST(sys_id AS INT)                                          AS con_sys_id,   -- 对接系统ID
    CAST(invoice_type AS INT)                                    AS invoice_type,  -- 发票类型
    CAST(records_type AS INT)                                    AS records_type,  -- 开票方式
    CAST(invoice_status AS INT)                                  AS invoice_status,  -- 开票状态
    CAST(order_type AS INT)                                      AS order_type,   -- 订单类型
    IF(COALESCE(red_info, '') <> '', 1, 0)                       AS red_flag,     -- 是否有红冲
    source                                                       AS invoice_source,  -- 开票渠道
    reason                                                       AS fail_reason,  -- 开票失败原因
    CAST(operator_id AS BIGINT)                                  AS operator_id,  -- 操作员ID
    FROM_UNIXTIME(add_time)                                      AS invoice_time,  -- 开票时间
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time           -- ETL 加载时间
FROM ods.ods_fin_invoice_records_df
WHERE travel_date = '${bizdate}'                                                  -- 只取当日分区
  AND FROM_UNIXTIME(add_time, 'yyyyMMdd') = '${bizdate}'                          -- 全量快照取当日事件
