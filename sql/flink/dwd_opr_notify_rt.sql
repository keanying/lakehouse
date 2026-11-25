-- dwd.dwd_opr_notify_rt  实时通知发送
-- 粒度：1行=1次通知发送
-- 来源：ods_opr_notify_record_rt
-- 生成方式：Flink SQL（CDC 源表 → StarRocks 主键模型表；维表 Lookup Join）；字段 18 个：直接翻译 16 · 规则翻译 2 · 待确认 0
-- 源表 ods.*_rt 为 Flink CDC 表（含 proc_time AS PROCTIME()），目标表在 StarRocks catalog 中

INSERT INTO dwd.dwd_opr_notify_rt                                             -- 写入 StarRocks 目标表
SELECT
  DATE_FORMAT(a.create_time, 'yyyyMMdd')               AS travel_date,        -- 数据日期
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
  CURRENT_TIMESTAMP                                    AS event_time          -- 事件时间（binlog 时间）
FROM ods.ods_opr_notify_record_rt a                                           -- 主表「通知记录 binlog 流」
LEFT JOIN dim.dim_opr_notify_template_df FOR SYSTEM_TIME AS OF a.proc_time AS j1  -- 关联「通知模板维度」，取 模板编码
  ON j1.notify_template_id = a.template_id;                                   -- 按 template_id→notify_template_id 关联
