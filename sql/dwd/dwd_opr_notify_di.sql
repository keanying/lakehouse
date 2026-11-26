-- dwd.dwd_opr_notify_di  通知发送明细
-- 粒度：1行=1次通知发送
-- 来源：ods_opr_notify_record_di
-- 生成方式：Spark SQL / Hive；字段 17 个：直接翻译 16 · 规则翻译 1 · 待确认 0
-- 流水/状态变更类：保留每条变更记录；每个 WITH 逻辑块只取用到的列并先过滤分区；小维表广播关联

WITH
notify_record_chg AS (                                                            -- 主表「通知记录」：保留每条变更记录，只取用到的列
  SELECT create_time, fail_reason, id, notify_channel, notify_no, recipient_id, recipient_type,
         related_business_no, send_status, send_time, template_id, tenant_id, update_time
  FROM ods.ods_opr_notify_record_di
  WHERE travel_date = '${bizdate}'                                                -- 只取当日分区
),
notify_template_dim AS (                                                          -- 「通知模板维度」当日数据，只取用到的列
  SELECT notify_template_id, template_code
  FROM dim.dim_opr_notify_template_df
  WHERE travel_date = '${bizdate}'                                                -- 只取当日分区
)
INSERT OVERWRITE TABLE dwd.dwd_opr_notify_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT  /*+ BROADCAST(notify_template_dim) */
  notify_record_chg.id                                         AS notify_id,      -- 通知记录ID（源表主键 id）
  notify_record_chg.notify_no                                  AS notify_no,      -- 通知记录号
  notify_record_chg.template_id                                AS template_id,    -- 模板ID
  notify_record_chg.recipient_id                               AS recipient_id,   -- 接收人ID
  notify_record_chg.recipient_type                             AS recipient_type,  -- 接收人类型
  notify_record_chg.notify_channel                             AS notify_channel_type,  -- 实际发送渠道
  notify_record_chg.related_business_no                        AS related_business_no,  -- 关联业务号
  notify_record_chg.send_status                                AS send_status,    -- 状态
  notify_record_chg.send_time                                  AS send_time,      -- 发送时间
  notify_record_chg.fail_reason                                AS fail_reason_desc,  -- 失败原因
  notify_record_chg.tenant_id                                  AS tenant_id,      -- 租户ID
  notify_record_chg.create_time                                AS create_time,    -- 创建时间
  notify_record_chg.update_time                                AS update_time,    -- 更新时间
  notify_template_dim.template_code                            AS template_code,  -- 模板编码
  CASE WHEN notify_record_chg.send_status= 'SUCCESS' THEN 1 ELSE 0 END AS send_success_type,  -- 是否发送成功
  1                                                            AS notify_qty,     -- 发送次数
  CURRENT_TIMESTAMP()                                          AS etl_time        -- ETL 加载时间
FROM notify_record_chg
LEFT JOIN notify_template_dim                                                     -- 关联「通知模板维度」，取 模板编码
  ON notify_template_dim.notify_template_id = notify_record_chg.template_id;      -- 按 template_id→notify_template_id 关联
