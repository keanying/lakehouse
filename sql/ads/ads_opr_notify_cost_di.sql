-- ads.ads_opr_notify_cost_di  通知与短信消耗
-- 粒度：travel_date × tenant_id
-- 来源：dws_opr_notify_di
-- 生成方式：Spark SQL / Hive；字段 16 个：直接翻译 4 · 规则翻译 12 · 待确认 0
-- 来源先按粒度键预聚合

WITH
src_notify AS (                                                                   -- 来源「通知发送日汇总」按粒度键预聚合
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
),
merged AS (                                                                       -- 按粒度键汇总，计算派生指标
  SELECT
    u.tenant_id,                                                                  -- 租户ID
    u.sms_notify_send_qty,                                                        -- 短信通知发送数（日）
    u.mini_notify_send_qty,                                                       -- 小程序消息通知发送数（日）
    u.email_notify_send_qty,                                                      -- 邮件通知发送数（日）
    u.webhook_notify_send_qty,                                                    -- Webhook通知发送数（日）
    u.sms_notify_success_numerator_qty,                                           -- 短信通知成功率分子（日）
    u.sms_notify_success_denominator_qty,                                         -- 短信通知成功率分母（日）
    u.mini_notify_success_numerator_qty,                                          -- 小程序消息通知成功率分子（日）
    u.mini_notify_success_denominator_qty,                                        -- 小程序消息通知成功率分母（日）
    u.email_notify_success_numerator_qty,                                         -- 邮件通知成功率分子（日）
    u.email_notify_success_denominator_qty,                                       -- 邮件通知成功率分母（日）
    u.webhook_notify_success_numerator_qty,                                       -- Webhook通知成功率分子（日）
    u.webhook_notify_success_denominator_qty,                                     -- Webhook通知成功率分母（日）
    u.resource_consume_qty,                                                       -- 资源包消耗量（日快照）
    u.notify_fail_qty,                                                            -- 通知失败数（日）
    CURRENT_TIMESTAMP() AS etl_time                                               -- ETL 加载时间
  FROM src_notify u
),
tenant_cur AS (                                                                   -- 「租户（商户/供应商/分销商）维度」当前有效版本，只取名称类字段
  SELECT tenant_id, tenant_name
  FROM dim.dim_sup_tenant_zip
  WHERE travel_date = '${bizdate}' AND end_date = '9999-12-31'                    -- 取当日分区里的拉链当前有效版本
)
INSERT OVERWRITE TABLE ads.ads_opr_notify_cost_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  merged.tenant_id,                                                               -- 租户ID
  tenant_cur.tenant_name AS tenant_name,                                          -- 租户名称
  merged.sms_notify_send_qty,                                                     -- 短信通知发送数（日）
  merged.mini_notify_send_qty,                                                    -- 小程序消息通知发送数（日）
  merged.email_notify_send_qty,                                                   -- 邮件通知发送数（日）
  merged.webhook_notify_send_qty,                                                 -- Webhook通知发送数（日）
  merged.sms_notify_success_numerator_qty,                                        -- 短信通知成功率分子（日）
  merged.sms_notify_success_denominator_qty,                                      -- 短信通知成功率分母（日）
  merged.mini_notify_success_numerator_qty,                                       -- 小程序消息通知成功率分子（日）
  merged.mini_notify_success_denominator_qty,                                     -- 小程序消息通知成功率分母（日）
  merged.email_notify_success_numerator_qty,                                      -- 邮件通知成功率分子（日）
  merged.email_notify_success_denominator_qty,                                    -- 邮件通知成功率分母（日）
  merged.webhook_notify_success_numerator_qty,                                    -- Webhook通知成功率分子（日）
  merged.webhook_notify_success_denominator_qty,                                  -- Webhook通知成功率分母（日）
  merged.resource_consume_qty,                                                    -- 资源包消耗量（日快照）
  merged.notify_fail_qty,                                                         -- 通知失败数（日）
  merged.etl_time                                                                 -- ETL 加载时间
FROM merged
LEFT JOIN tenant_cur                                                              -- 关联「租户（商户/供应商/分销商）维度」，补 tenant_name
  ON tenant_cur.tenant_id = merged.tenant_id;                                     -- 按 tenant_id 关联
