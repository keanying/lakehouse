-- dws.dws_opr_notify_di  通知发送日汇总
-- 粒度：travel_date × tenant_id × notify_channel_type × template_code
-- 来源：dwd_opr_notify_di, dwd_fin_resource_batch_di
-- 生成方式：Spark SQL / Hive；字段 10 个：直接翻译 3 · 规则翻译 3 · 待确认 4
-- 多来源：每个来源先按粒度键预聚合，UNION ALL 后再汇总
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

WITH
src_notify AS (                                           -- 来源「通知发送明细」按粒度键预聚合
  SELECT
    tenant_id AS tenant_id,                               -- 租户ID
    notify_channel_type AS notify_channel_type,           -- 通知渠道
    template_code AS template_code,                       -- 通知模板编码
    COUNT(notify_no) AS notify_send_qty,                  -- 通知发送数
    COUNT(CASE WHEN send_status = 'SUCCESS' THEN 1 END) AS notify_success_qty,  -- 通知成功数
    COUNT(CASE WHEN 1 = 1 THEN 1 END) AS sms_send_qty,    -- 短信发送数｜待确认：notify_channel='SMS'
    COUNT(CASE WHEN send_status = 'FAILED' THEN 1 END) AS notify_fail_qty,  -- 通知失败数
    NULL AS resource_consume_qty
  FROM dwd.dwd_opr_notify_di s                            -- 来源表「通知发送明细」
  WHERE s.travel_date = '${bizdate}'                      -- 只取当日分区
  GROUP BY tenant_id, notify_channel_type, template_code  -- 按粒度键汇总
),
src_resource_batch AS (                                   -- 来源「资源包购买/消耗明细」按粒度键预聚合
  SELECT
    tenant_id AS tenant_id,                               -- 租户ID
    CAST(NULL AS STRING) AS notify_channel_type,
    CAST(NULL AS STRING) AS template_code,
    NULL AS notify_send_qty,
    NULL AS notify_success_qty,
    NULL AS sms_send_qty,
    NULL AS notify_fail_qty,
    NULL AS resource_consume_qty                          -- 待确认：sum(prev_remaining - remaining)
  FROM dwd.dwd_fin_resource_batch_di s                    -- 来源表「资源包购买/消耗明细」
  WHERE s.travel_date = '${bizdate}'                      -- 只取当日分区
  GROUP BY tenant_id                                      -- 按粒度键汇总
),
all_src AS (                                              -- 各来源字段已对齐，UNION ALL 合并（比多表 FULL JOIN 少 shuffle）
  SELECT * FROM src_notify
  UNION ALL
  SELECT * FROM src_resource_batch
)
INSERT OVERWRITE TABLE dws.dws_opr_notify_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  u.tenant_id,                                            -- 租户ID
  u.notify_channel_type,                                  -- 通知渠道
  u.template_code,                                        -- 通知模板编码
  SUM(u.notify_send_qty) AS notify_send_qty,              -- 通知发送数
  SUM(u.notify_success_qty) AS notify_success_qty,        -- 通知成功数
  SUM(u.sms_send_qty) AS sms_send_qty,                    -- 短信发送数
  SUM(u.notify_fail_qty) AS notify_fail_qty,              -- 通知失败数
  SUM(u.resource_consume_qty) AS resource_consume_qty,    -- 资源包消耗量
  CURRENT_TIMESTAMP() AS etl_time                         -- ETL 加载时间
FROM all_src u
GROUP BY u.tenant_id, u.notify_channel_type, u.template_code;  -- 按粒度键汇总
