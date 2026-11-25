-- dim.dim_opr_notify_template_df  通知模板维度
-- 粒度：1行=1个模板
-- 来源：ods_opr_notify_template_df
-- 生成方式：Spark SQL / Hive；字段 11 个：直接翻译 11 · 规则翻译 0 · 待确认 0

INSERT OVERWRITE TABLE dim.dim_opr_notify_template_df PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  a.id                AS notify_template_id,  -- 通知模板ID（源表主键 id）
  a.template_no       AS template_no,         -- 模板编号
  a.template_code     AS template_code,       -- 模板代码
  a.template_name     AS template_name,       -- 模板名称
  a.notify_channel    AS notify_channel_type,  -- 通知渠道
  a.scope             AS scope_type,          -- 范围
  a.tenant_id         AS tenant_id,           -- 租户ID
  a.template_status   AS template_status,     -- 状态
  a.create_time       AS create_time,         -- 创建时间
  a.update_time       AS update_time,         -- 更新时间
  CURRENT_TIMESTAMP() AS etl_time             -- ETL 加载时间
FROM ods.ods_opr_notify_template_df a         -- 主表「通知模板」
WHERE a.travel_date = '${bizdate}';           -- 只取当日分区
