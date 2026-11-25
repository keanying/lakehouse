-- dim.dim_sup_position_df  岗位维度
-- 粒度：1行=1个岗位
-- 来源：ods_sup_tenant_position_df
-- 生成方式：Spark SQL / Hive；字段 9 个：直接翻译 9 · 规则翻译 0 · 待确认 0

INSERT OVERWRITE TABLE dim.dim_sup_position_df PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  a.id                AS position_id,      -- 岗位定义ID（源表主键 id）
  a.position_no       AS position_no,      -- 岗位编号
  a.tenant_id         AS tenant_id,        -- 租户ID
  a.position_name     AS position_name,    -- 岗位名称
  a.position_code     AS position_code,    -- 岗位编码（租户内唯一
  a.position_status   AS position_status,  -- 状态
  a.create_time       AS create_time,      -- 创建时间
  a.update_time       AS update_time,      -- 更新时间
  CURRENT_TIMESTAMP() AS etl_time          -- ETL 加载时间
FROM ods.ods_sup_tenant_position_df a      -- 主表「岗位定义」
WHERE a.travel_date = '${bizdate}';        -- 只取当日分区
