-- dim.dim_sup_position_df  岗位维度
-- 粒度：1行=1个岗位
-- 来源：ods_sup_tenant_position_df
-- 生成方式：Spark SQL / Hive；字段 9 个：直接翻译 9 · 规则翻译 0 · 待确认 0
-- 每个 WITH 逻辑块只取用到的列并先过滤分区

WITH
tenant_position_src AS (                                   -- 主表「岗位定义」，只取用到的列
  SELECT create_time, id, position_code, position_name, position_no, position_status, tenant_id,
         update_time                                       -- 更新时间
  FROM ods.ods_sup_tenant_position_df
  WHERE travel_date = '${bizdate}'                         -- 只取当日分区
)
INSERT OVERWRITE TABLE dim.dim_sup_position_df PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  tenant_position_src.id              AS position_id,      -- 岗位定义ID（源表主键 id）
  tenant_position_src.position_no     AS position_no,      -- 岗位编号
  tenant_position_src.tenant_id       AS tenant_id,        -- 租户ID
  tenant_position_src.position_name   AS position_name,    -- 岗位名称
  tenant_position_src.position_code   AS position_code,    -- 岗位编码
  tenant_position_src.position_status AS position_status,  -- 状态
  tenant_position_src.create_time     AS create_time,      -- 创建时间
  tenant_position_src.update_time     AS update_time,      -- 更新时间
  CURRENT_TIMESTAMP()                 AS etl_time          -- ETL 加载时间
FROM tenant_position_src;
