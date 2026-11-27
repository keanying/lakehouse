-- ================================================================================================
-- dwd.dwd_opr_sms_send_di  订单短信发送明细
-- 粒度：1行=1条订单短信
-- 分区：travel_date（YYYYMMDD）
-- 调度：每日，依赖上游 ODS 当日分区与相关维表
-- 上游：ods_opr_sms_journal_di
-- 业务规则 / 修正：
--   · 短信正文（smstxt）含游客信息，不进 DWD；待确认：api_code / report_code 成功码值上线前与短信平台确认
-- ================================================================================================
INSERT OVERWRITE TABLE dwd.dwd_opr_sms_send_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
    CAST(id AS BIGINT)                                           AS sms_id,       -- 短信记录ID
    CAST(aid AS BIGINT)                                          AS supplier_id,  -- 供应商ID（租户ID）
    ordernum                                                     AS order_no,     -- 订单号
    mobile                                                       AS phone_mask,   -- 手机号（ODS 已脱敏）
    IF(tob = 'Y', 1, 0)                                          AS supplier_sms_flag,  -- 是否供应商短信
    CAST(platformid AS INT)                                      AS platform_id,  -- 短信发送平台ID
    CAST(channel AS INT)                                         AS send_channel,  -- 发送渠道
    CAST(api_code AS INT)                                        AS api_code,     -- API 调用发送状态
    CAST(report_code AS INT)                                     AS report_code,  -- 用户接收状态
    CAST(is_resend AS INT)                                       AS resend_flag,  -- 是否重发
    CAST(wordscnt AS BIGINT)                                     AS word_qty,     -- 字数
    CAST(msgcnt AS BIGINT)                                       AS sms_qty,      -- 计费条数
    FROM_UNIXTIME(send_time)                                     AS send_time,    -- 最后发送时间
    FROM_UNIXTIME(report_time)                                   AS report_time,  -- 接收回执时间
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time           -- ETL 加载时间
FROM ods.ods_opr_sms_journal_di
WHERE travel_date = '${bizdate}'                                                  -- 只取当日分区
