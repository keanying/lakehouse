-- dim.dim_opr_app_df  应用维度
-- 粒度：1行=1个应用
-- 来源：ods_opr_app_definition_df
-- 生成方式：Spark SQL / Hive；字段 9 个：直接翻译 9 · 规则翻译 0 · 待确认 0

INSERT OVERWRITE TABLE dim.dim_opr_app_df PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  a.id                AS app_id,       -- 应用定义ID（源表主键 id）
  a.app_no            AS app_no,       -- 应用编号
  a.app_name          AS app_name,     -- 应用名称
  a.app_code          AS app_code,     -- 应用代码（唯一标识）
  a.app_type          AS app_type,     -- 类型
  a.app_status        AS app_status,   -- 状态
  a.create_time       AS create_time,  -- 创建时间
  a.update_time       AS update_time,  -- 更新时间
  CURRENT_TIMESTAMP() AS etl_time      -- ETL 加载时间
FROM ods.ods_opr_app_definition_df a   -- 主表「应用定义」
WHERE a.travel_date = '${bizdate}';    -- 只取当日分区
