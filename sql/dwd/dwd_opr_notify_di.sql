-- dwd.dwd_opr_notify_di  通知发送明细
-- 粒度：1行=1次通知发送
-- 来源：ods_opr_notify_record_di
-- 生成方式：Spark SQL / Hive；字段 17 个：直接翻译 16 · 规则翻译 1 · 待确认 0
-- 流水/状态变更类：保留每条变更记录

INSERT OVERWRITE TABLE dwd.dwd_opr_notify_di PARTITION (travel_date = '${bizdate}')
SELECT
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
  CURRENT_TIMESTAMP()                                  AS etl_time
FROM ods.ods_opr_notify_record_di a
LEFT JOIN dim.dim_opr_notify_template_df j1
  ON j1.notify_template_id = a.template_id
 AND j1.travel_date = '${bizdate}'
WHERE a.travel_date = '${bizdate}';
