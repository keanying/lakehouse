-- dws.dws_opr_notify_di  通知发送日汇总
-- 粒度：travel_date × tenant_id × notify_channel_type × template_code
-- 来源：dwd_opr_notify_di, dwd_fin_resource_batch_di
-- 生成方式：Spark SQL / Hive；字段 10 个：直接翻译 3 · 规则翻译 3 · 待确认 4
-- 多来源：每个来源表按粒度键先汇总，UNION ALL 后再合并
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT OVERWRITE TABLE dws.dws_opr_notify_di PARTITION (travel_date = '${bizdate}')
SELECT
  u.tenant_id,
  u.notify_channel_type,
  u.template_code,
  SUM(u.notify_send_qty) AS notify_send_qty,
  SUM(u.notify_success_qty) AS notify_success_qty,
  SUM(u.sms_send_qty) AS sms_send_qty,
  SUM(u.notify_fail_qty) AS notify_fail_qty,
  SUM(u.resource_consume_qty) AS resource_consume_qty,
  CURRENT_TIMESTAMP() AS etl_time
FROM (
  -- 来源：dwd_opr_notify_di
  SELECT
    tenant_id AS tenant_id,
    notify_channel_type AS notify_channel_type,
    template_code AS template_code,
    COUNT(notify_no) AS notify_send_qty,
    COUNT(CASE WHEN send_status = 'SUCCESS' THEN 1 END) AS notify_success_qty,
    COUNT(CASE WHEN 1 = 1 THEN 1 END) AS sms_send_qty,  -- 待确认：notify_channel='SMS'
    COUNT(CASE WHEN send_status = 'FAILED' THEN 1 END) AS notify_fail_qty,
    NULL AS resource_consume_qty
  FROM dwd.dwd_opr_notify_di s
  WHERE s.travel_date = '${bizdate}'
  GROUP BY tenant_id, notify_channel_type, template_code
  UNION ALL
  -- 来源：dwd_fin_resource_batch_di
  SELECT
    tenant_id AS tenant_id,
    CAST(NULL AS STRING) AS notify_channel_type,
    CAST(NULL AS STRING) AS template_code,
    NULL AS notify_send_qty,
    NULL AS notify_success_qty,
    NULL AS sms_send_qty,
    NULL AS notify_fail_qty,
    NULL AS resource_consume_qty  -- 待确认：sum(prev_remaining - remaining)
  FROM dwd.dwd_fin_resource_batch_di s
  WHERE s.travel_date = '${bizdate}'
  GROUP BY tenant_id
) u
GROUP BY u.tenant_id, u.notify_channel_type, u.template_code;
