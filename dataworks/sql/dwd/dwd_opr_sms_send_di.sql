-- ================================================================================================
-- dwd.dwd_opr_sms_send_di  订单短信发送明细
-- 粒度：1行=1条订单短信
-- 分区：travel_date（YYYYMMDD）
-- 调度：每日，依赖上游 ODS 当日分区与相关维表
-- 上游：ods_opr_sms_journal_di
-- 业务规则 / 修正：
--   · 短信正文（smstxt）含游客信息，不进 DWD；待确认：api_code / report_code 成功码值上线前与短信平台确认
-- ================================================================================================
INSERT OVERWRITE TABLE dwd.dwd_opr_sms_send_di PARTITION (travel_date = '${bizdate}')
SELECT
    CAST(id AS BIGINT)                                           AS sms_id,
    CAST(aid AS BIGINT)                                          AS supplier_id,
    ordernum                                                     AS order_no,
    mobile                                                       AS phone_mask,
    IF(tob = 'Y', 1, 0)                                          AS supplier_sms_flag,
    CAST(platformid AS INT)                                      AS platform_id,
    CAST(channel AS INT)                                         AS send_channel,
    CAST(api_code AS INT)                                        AS api_code,
    CAST(report_code AS INT)                                     AS report_code,
    CAST(is_resend AS INT)                                       AS resend_flag,
    CAST(wordscnt AS BIGINT)                                     AS word_qty,
    CAST(msgcnt AS BIGINT)                                       AS sms_qty,
    FROM_UNIXTIME(send_time)                                     AS send_time,
    FROM_UNIXTIME(report_time)                                   AS report_time,
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time
FROM ods.ods_opr_sms_journal_di
WHERE travel_date = '${bizdate}'
