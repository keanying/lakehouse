-- ads.ads_opr_notify_cost_di  通知与短信消耗
-- 粒度：travel_date × tenant_id
-- 来源：dws_opr_notify_di
-- 生成方式：Spark SQL / Hive；字段 16 个：直接翻译 4 · 规则翻译 12 · 待确认 0

INSERT OVERWRITE TABLE ads.ads_opr_notify_cost_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  x.tenant_id,                                                                    -- 租户ID
  d1.tenant_name AS tenant_name,                                                  -- 租户名称
  x.sms_notify_send_qty,                                                          -- 短信通知发送数（日）
  x.mini_notify_send_qty,                                                         -- 小程序消息通知发送数（日）
  x.email_notify_send_qty,                                                        -- 邮件通知发送数（日）
  x.webhook_notify_send_qty,                                                      -- Webhook通知发送数（日）
  x.sms_notify_success_numerator_qty,                                             -- 短信通知成功率分子（日）
  x.sms_notify_success_denominator_qty,                                           -- 短信通知成功率分母（日）
  x.mini_notify_success_numerator_qty,                                            -- 小程序消息通知成功率分子（日）
  x.mini_notify_success_denominator_qty,                                          -- 小程序消息通知成功率分母（日）
  x.email_notify_success_numerator_qty,                                           -- 邮件通知成功率分子（日）
  x.email_notify_success_denominator_qty,                                         -- 邮件通知成功率分母（日）
  x.webhook_notify_success_numerator_qty,                                         -- Webhook通知成功率分子（日）
  x.webhook_notify_success_denominator_qty,                                       -- Webhook通知成功率分母（日）
  x.resource_consume_qty,                                                         -- 资源包消耗量（日快照）
  x.notify_fail_qty,                                                              -- 通知失败数（日）
  x.etl_time                                                                      -- ETL 加载时间
FROM (
SELECT
  u.tenant_id,                                                                    -- 租户ID
  SUM(u.sms_notify_send_qty) AS sms_notify_send_qty,                              -- 短信通知发送数（日）
  SUM(u.mini_notify_send_qty) AS mini_notify_send_qty,                            -- 小程序消息通知发送数（日）
  SUM(u.email_notify_send_qty) AS email_notify_send_qty,                          -- 邮件通知发送数（日）
  SUM(u.webhook_notify_send_qty) AS webhook_notify_send_qty,                      -- Webhook通知发送数（日）
  SUM(u.sms_notify_success_numerator_qty) AS sms_notify_success_numerator_qty,    -- 短信通知成功率分子（日）
  SUM(u.sms_notify_success_denominator_qty) AS sms_notify_success_denominator_qty,  -- 短信通知成功率分母（日）
  SUM(u.mini_notify_success_numerator_qty) AS mini_notify_success_numerator_qty,  -- 小程序消息通知成功率分子（日）
  SUM(u.mini_notify_success_denominator_qty) AS mini_notify_success_denominator_qty,  -- 小程序消息通知成功率分母（日）
  SUM(u.email_notify_success_numerator_qty) AS email_notify_success_numerator_qty,  -- 邮件通知成功率分子（日）
  SUM(u.email_notify_success_denominator_qty) AS email_notify_success_denominator_qty,  -- 邮件通知成功率分母（日）
  SUM(u.webhook_notify_success_numerator_qty) AS webhook_notify_success_numerator_qty,  -- Webhook通知成功率分子（日）
  SUM(u.webhook_notify_success_denominator_qty) AS webhook_notify_success_denominator_qty,  -- Webhook通知成功率分母（日）
  SUM(u.resource_consume_qty) AS resource_consume_qty,                            -- 资源包消耗量（日快照）
  SUM(u.notify_fail_qty) AS notify_fail_qty,                                      -- 通知失败数（日）
  CURRENT_TIMESTAMP() AS etl_time                                                 -- ETL 加载时间
FROM (
  -- 来源：dws_opr_notify_di
  SELECT
    tenant_id AS tenant_id,                                                       -- 租户ID
    SUM(CASE WHEN notify_channel_type = 'SMS' THEN notify_send_qty END) AS sms_notify_send_qty,  -- 短信通知发送数（日）
    SUM(CASE WHEN notify_channel_type = 'MINI_PROGRAM_MSG' THEN notify_send_qty END) AS mini_notify_send_qty,  -- 小程序消息通知发送数（日）
    SUM(CASE WHEN notify_channel_type = 'EMAIL' THEN notify_send_qty END) AS email_notify_send_qty,  -- 邮件通知发送数（日）
    SUM(CASE WHEN notify_channel_type = 'WEBHOOK' THEN notify_send_qty END) AS webhook_notify_send_qty,  -- Webhook通知发送数（日）
    SUM(CASE WHEN notify_channel_type = 'SMS' THEN notify_success_qty END) AS sms_notify_success_numerator_qty,  -- 短信通知成功率分子（日）
    SUM(CASE WHEN notify_channel_type = 'SMS' THEN notify_send_qty END) AS sms_notify_success_denominator_qty,  -- 短信通知成功率分母（日）
    SUM(CASE WHEN notify_channel_type = 'MINI_PROGRAM_MSG' THEN notify_success_qty END) AS mini_notify_success_numerator_qty,  -- 小程序消息通知成功率分子（日）
    SUM(CASE WHEN notify_channel_type = 'MINI_PROGRAM_MSG' THEN notify_send_qty END) AS mini_notify_success_denominator_qty,  -- 小程序消息通知成功率分母（日）
    SUM(CASE WHEN notify_channel_type = 'EMAIL' THEN notify_success_qty END) AS email_notify_success_numerator_qty,  -- 邮件通知成功率分子（日）
    SUM(CASE WHEN notify_channel_type = 'EMAIL' THEN notify_send_qty END) AS email_notify_success_denominator_qty,  -- 邮件通知成功率分母（日）
    SUM(CASE WHEN notify_channel_type = 'WEBHOOK' THEN notify_success_qty END) AS webhook_notify_success_numerator_qty,  -- Webhook通知成功率分子（日）
    SUM(CASE WHEN notify_channel_type = 'WEBHOOK' THEN notify_send_qty END) AS webhook_notify_success_denominator_qty,  -- Webhook通知成功率分母（日）
    SUM(resource_consume_qty) AS resource_consume_qty,                            -- 资源包消耗量（日快照）
    SUM(notify_fail_qty) AS notify_fail_qty                                       -- 通知失败数（日）
  FROM dws.dws_opr_notify_di s                                                    -- 来源表「通知发送日汇总」
  WHERE s.travel_date = '${bizdate}'                                              -- 只取当日分区
  GROUP BY tenant_id                                                              -- 按粒度键汇总
) u                                                                               -- 各来源合并后的明细
GROUP BY u.tenant_id                                                              -- 按粒度键汇总
) x                                                                               -- 汇总结果，外层再补维度名称
LEFT JOIN dim.dim_sup_tenant_zip d1 ON d1.tenant_id = x.tenant_id AND d1.travel_date = '${bizdate}' AND d1.end_date = '9999-12-31';  -- 关联「租户（商户/供应商/分销商）维度」，取维度名称
