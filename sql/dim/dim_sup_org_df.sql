-- dim.dim_sup_org_df  部门维度
-- 粒度：1行=1个部门
-- 来源：ods_sup_org_df
-- 生成方式：Spark SQL / Hive；字段 15 个：直接翻译 9 · 规则翻译 0 · 待确认 6
-- 每个 WITH 逻辑块只取用到的列并先过滤分区
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

WITH
org_src AS (                                 -- 主表「部门架构」，只取用到的列
  SELECT create_time, id, org_name, org_no, org_status, parent_org_id, tenant_id, update_time
  FROM ods.ods_sup_org_df
  WHERE travel_date = '${bizdate}'           -- 只取当日分区
)
INSERT OVERWRITE TABLE dim.dim_sup_org_df PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  org_src.id            AS org_id,           -- 部门架构ID（源表主键 id）
  org_src.org_no        AS org_no,           -- 部门编号
  org_src.org_name      AS org_name,         -- 部门名称
  org_src.parent_org_id AS parent_org_id,    -- 上级部门ID(0=顶级部门)
  org_src.tenant_id     AS tenant_id,        -- 租户ID
  org_src.org_status    AS org_status,       -- 状态
  org_src.create_time   AS create_time,      -- 创建时间
  org_src.update_time   AS update_time,      -- 更新时间
  org_src.parent_org_id AS org_level_no,     -- 部门层级｜待确认：ods_sup_org_df.parent_org_id 递归
  org_src.org_name      AS org_path_desc,    -- 部门完整路径｜待确认：ods_sup_org_df.org_name 递归拼接
  org_src.parent_org_id AS level1_org_id,    -- 一级部门ID｜待确认：ods_sup_org_df.parent_org_id 递归
  org_src.org_name      AS level1_org_name,  -- 一级部门名称｜待确认：ods_sup_org_df.org_name 递归
  org_src.parent_org_id AS level2_org_id,    -- 二级部门ID｜待确认：ods_sup_org_df.parent_org_id 递归
  org_src.org_name      AS level2_org_name,  -- 二级部门名称｜待确认：ods_sup_org_df.org_name 递归
  CURRENT_TIMESTAMP()   AS etl_time          -- ETL 加载时间
FROM org_src;
