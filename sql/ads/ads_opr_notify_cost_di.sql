-- ads.ads_opr_notify_cost_di  通知与短信消耗
-- 粒度：travel_date × tenant_id
-- 来源：dws_opr_notify_di
-- 生成方式：Spark SQL / Hive；字段 16 个：直接翻译 4 · 规则翻译 12 · 待确认 0

INSERT OVERWRITE TABLE ads.ads_opr_notify_cost_di PARTITION (travel_date = '${bizdate}')
SELECT
  x.tenant_id,
  d1.tenant_name AS tenant_name,
  x.sms_notify_send_qty,
  x.mini_notify_send_qty,
  x.email_notify_send_qty,
  x.webhook_notify_send_qty,
  x.sms_notify_success_numerator_qty,
  x.sms_notify_success_denominator_qty,
  x.mini_notify_success_numerator_qty,
  x.mini_notify_success_denominator_qty,
  x.email_notify_success_numerator_qty,
  x.email_notify_success_denominator_qty,
  x.webhook_notify_success_numerator_qty,
  x.webhook_notify_success_denominator_qty,
  x.resource_consume_qty,
  x.notify_fail_qty,
  x.etl_time
FROM (
SELECT
  u.tenant_id,
  SUM(u.sms_notify_send_qty) AS sms_notify_send_qty,
  SUM(u.mini_notify_send_qty) AS mini_notify_send_qty,
  SUM(u.email_notify_send_qty) AS email_notify_send_qty,
  SUM(u.webhook_notify_send_qty) AS webhook_notify_send_qty,
  SUM(u.sms_notify_success_numerator_qty) AS sms_notify_success_numerator_qty,
  SUM(u.sms_notify_success_denominator_qty) AS sms_notify_success_denominator_qty,
  SUM(u.mini_notify_success_numerator_qty) AS mini_notify_success_numerator_qty,
  SUM(u.mini_notify_success_denominator_qty) AS mini_notify_success_denominator_qty,
  SUM(u.email_notify_success_numerator_qty) AS email_notify_success_numerator_qty,
  SUM(u.email_notify_success_denominator_qty) AS email_notify_success_denominator_qty,
  SUM(u.webhook_notify_success_numerator_qty) AS webhook_notify_success_numerator_qty,
  SUM(u.webhook_notify_success_denominator_qty) AS webhook_notify_success_denominator_qty,
  SUM(u.resource_consume_qty) AS resource_consume_qty,
  SUM(u.notify_fail_qty) AS notify_fail_qty,
  CURRENT_TIMESTAMP() AS etl_time
FROM (
  -- 来源：dws_opr_notify_di
  SELECT
    tenant_id AS tenant_id,
    SUM(CASE WHEN notify_channel_type = 'SMS' THEN notify_send_qty END) AS sms_notify_send_qty,
    SUM(CASE WHEN notify_channel_type = 'MINI_PROGRAM_MSG' THEN notify_send_qty END) AS mini_notify_send_qty,
    SUM(CASE WHEN notify_channel_type = 'EMAIL' THEN notify_send_qty END) AS email_notify_send_qty,
    SUM(CASE WHEN notify_channel_type = 'WEBHOOK' THEN notify_send_qty END) AS webhook_notify_send_qty,
    SUM(CASE WHEN notify_channel_type = 'SMS' THEN notify_success_qty END) AS sms_notify_success_numerator_qty,
    SUM(CASE WHEN notify_channel_type = 'SMS' THEN notify_send_qty END) AS sms_notify_success_denominator_qty,
    SUM(CASE WHEN notify_channel_type = 'MINI_PROGRAM_MSG' THEN notify_success_qty END) AS mini_notify_success_numerator_qty,
    SUM(CASE WHEN notify_channel_type = 'MINI_PROGRAM_MSG' THEN notify_send_qty END) AS mini_notify_success_denominator_qty,
    SUM(CASE WHEN notify_channel_type = 'EMAIL' THEN notify_success_qty END) AS email_notify_success_numerator_qty,
    SUM(CASE WHEN notify_channel_type = 'EMAIL' THEN notify_send_qty END) AS email_notify_success_denominator_qty,
    SUM(CASE WHEN notify_channel_type = 'WEBHOOK' THEN notify_success_qty END) AS webhook_notify_success_numerator_qty,
    SUM(CASE WHEN notify_channel_type = 'WEBHOOK' THEN notify_send_qty END) AS webhook_notify_success_denominator_qty,
    SUM(resource_consume_qty) AS resource_consume_qty,
    SUM(notify_fail_qty) AS notify_fail_qty
  FROM dws.dws_opr_notify_di s
  WHERE s.travel_date = '${bizdate}'
  GROUP BY tenant_id
) u
GROUP BY u.tenant_id
) x
LEFT JOIN dim.dim_sup_tenant_zip d1 ON d1.tenant_id = x.tenant_id AND d1.travel_date = '${bizdate}' AND d1.end_date = '9999-12-31';
