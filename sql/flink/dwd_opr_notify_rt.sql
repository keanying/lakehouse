-- dwd.dwd_opr_notify_rt  实时通知发送
-- 粒度：1行=1次通知发送
-- 来源：ods_opr_notify_record_rt
-- 生成方式：Flink SQL（CDC 源表 → StarRocks 主键模型表；维表 Lookup Join）；字段 18 个：直接翻译 16 · 规则翻译 2 · 待确认 0
-- 源表 ods.*_rt 为 Flink CDC 表（含 proc_time AS PROCTIME()），目标表在 StarRocks catalog 中

INSERT INTO dwd.dwd_opr_notify_rt
SELECT
  DATE_FORMAT(a.create_time, 'yyyyMMdd')               AS travel_date,
  a.id                                                 AS notify_id,
  a.notify_no                                          AS notify_no,
  a.template_id                                        AS template_id,
  a.recipient_id                                       AS recipient_id,
  a.recipient_type                                     AS recipient_type,
  a.notify_channel                                     AS notify_channel_type,
  a.related_business_no                                AS related_business_no,
  a.send_status                                        AS send_status,
  a.send_time                                          AS send_time,
  a.fail_reason                                        AS fail_reason_desc,
  a.tenant_id                                          AS tenant_id,
  a.create_time                                        AS create_time,
  a.update_time                                        AS update_time,
  j1.template_code                                     AS template_code,
  CASE WHEN a.send_status= 'SUCCESS' THEN 1 ELSE 0 END AS send_success_type,
  1                                                    AS notify_qty,
  CURRENT_TIMESTAMP                                    AS event_time
FROM ods.ods_opr_notify_record_rt a
LEFT JOIN dim.dim_opr_notify_template_df FOR SYSTEM_TIME AS OF a.proc_time AS j1
  ON j1.notify_template_id = a.template_id;
