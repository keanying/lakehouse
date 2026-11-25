-- dwd.dwd_opr_notify_di  通知发送明细
-- 粒度：1行=1次通知发送
-- 来源：ods_opr_notify_record_di
-- 生成方式：Spark SQL / Hive；字段 17 个：直接翻译 16 · 规则翻译 1 · 待确认 0
-- 流水/状态变更类：保留每条变更记录

INSERT OVERWRITE TABLE dwd.dwd_opr_notify_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  a.id                                                 AS notify_id,          -- 通知记录ID（源表主键 id）
  a.notify_no                                          AS notify_no,          -- 通知记录号
  a.template_id                                        AS template_id,        -- 模板ID
  a.recipient_id                                       AS recipient_id,       -- 接收人ID
  a.recipient_type                                     AS recipient_type,     -- 接收人类型
  a.notify_channel                                     AS notify_channel_type,  -- 实际发送渠道
  a.related_business_no                                AS related_business_no,  -- 关联业务号
  a.send_status                                        AS send_status,        -- 状态
  a.send_time                                          AS send_time,          -- 发送时间
  a.fail_reason                                        AS fail_reason_desc,   -- 失败原因
  a.tenant_id                                          AS tenant_id,          -- 租户ID
  a.create_time                                        AS create_time,        -- 创建时间
  a.update_time                                        AS update_time,        -- 更新时间
  j1.template_code                                     AS template_code,      -- 模板编码
  CASE WHEN a.send_status= 'SUCCESS' THEN 1 ELSE 0 END AS send_success_type,  -- 是否发送成功
  1                                                    AS notify_qty,         -- 发送次数
  CURRENT_TIMESTAMP()                                  AS etl_time            -- ETL 加载时间
FROM ods.ods_opr_notify_record_di a                                           -- 主表「通知记录」
LEFT JOIN dim.dim_opr_notify_template_df j1                                   -- 关联「通知模板维度」，取 模板编码
  ON j1.notify_template_id = a.template_id                                    -- 按 template_id→notify_template_id 关联
 AND j1.travel_date = '${bizdate}'                                            -- 只取当日分区
WHERE a.travel_date = '${bizdate}';                                           -- 只取当日分区
