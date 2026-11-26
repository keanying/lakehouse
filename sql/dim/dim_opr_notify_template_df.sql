-- dim.dim_opr_notify_template_df  通知模板维度
-- 粒度：1行=1个模板
-- 来源：ods_opr_notify_template_df
-- 生成方式：Spark SQL / Hive；字段 11 个：直接翻译 11 · 规则翻译 0 · 待确认 0
-- 每个 WITH 逻辑块只取用到的列并先过滤分区

WITH
notify_template_src AS (                                      -- 主表「通知模板」，只取用到的列
  SELECT create_time, id, notify_channel, scope, template_code, template_name, template_no,
         template_status, tenant_id, update_time
  FROM ods.ods_opr_notify_template_df
  WHERE travel_date = '${bizdate}'                            -- 只取当日分区
)
INSERT OVERWRITE TABLE dim.dim_opr_notify_template_df PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  notify_template_src.id              AS notify_template_id,  -- 通知模板ID（源表主键 id）
  notify_template_src.template_no     AS template_no,         -- 模板编号
  notify_template_src.template_code   AS template_code,       -- 模板代码
  notify_template_src.template_name   AS template_name,       -- 模板名称
  notify_template_src.notify_channel  AS notify_channel_type,  -- 通知渠道
  notify_template_src.scope           AS scope_type,          -- 范围
  notify_template_src.tenant_id       AS tenant_id,           -- 租户ID
  notify_template_src.template_status AS template_status,     -- 状态
  notify_template_src.create_time     AS create_time,         -- 创建时间
  notify_template_src.update_time     AS update_time,         -- 更新时间
  CURRENT_TIMESTAMP()                 AS etl_time             -- ETL 加载时间
FROM notify_template_src;
