-- dim.dim_opr_app_df  应用维度
-- 粒度：1行=1个应用
-- 来源：ods_opr_app_definition_df
-- 生成方式：Spark SQL / Hive；字段 9 个：直接翻译 9 · 规则翻译 0 · 待确认 0
-- 每个 WITH 逻辑块只取用到的列并先过滤分区

WITH
app_definition_src AS (                           -- 主表「应用定义」，只取用到的列
  SELECT app_code, app_name, app_no, app_status, app_type, create_time, id, update_time
  FROM ods.ods_opr_app_definition_df
  WHERE travel_date = '${bizdate}'                -- 只取当日分区
)
INSERT OVERWRITE TABLE dim.dim_opr_app_df PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  app_definition_src.id          AS app_id,       -- 应用定义ID（源表主键 id）
  app_definition_src.app_no      AS app_no,       -- 应用编号
  app_definition_src.app_name    AS app_name,     -- 应用名称
  app_definition_src.app_code    AS app_code,     -- 应用代码（唯一标识）
  app_definition_src.app_type    AS app_type,     -- 类型
  app_definition_src.app_status  AS app_status,   -- 状态
  app_definition_src.create_time AS create_time,  -- 创建时间
  app_definition_src.update_time AS update_time,  -- 更新时间
  CURRENT_TIMESTAMP()            AS etl_time      -- ETL 加载时间
FROM app_definition_src;
