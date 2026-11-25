-- dim.dim_sup_org_df  部门维度
-- 粒度：1行=1个部门
-- 来源：ods_sup_org_df
-- 生成方式：Spark SQL / Hive；字段 15 个：直接翻译 9 · 规则翻译 0 · 待确认 6
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT OVERWRITE TABLE dim.dim_sup_org_df PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  a.id                AS org_id,           -- 部门架构ID（源表主键 id）
  a.org_no            AS org_no,           -- 部门编号
  a.org_name          AS org_name,         -- 部门名称
  a.parent_org_id     AS parent_org_id,    -- 上级部门ID(0=顶级部门)
  a.tenant_id         AS tenant_id,        -- 租户ID
  a.org_status        AS org_status,       -- 状态
  a.create_time       AS create_time,      -- 创建时间
  a.update_time       AS update_time,      -- 更新时间
  a.parent_org_id     AS org_level_no,     -- 部门层级｜待确认：ods_sup_org_df.parent_org_id 递归
  a.org_name          AS org_path_desc,    -- 部门完整路径｜待确认：ods_sup_org_df.org_name 递归拼接
  a.parent_org_id     AS level1_org_id,    -- 一级部门ID｜待确认：ods_sup_org_df.parent_org_id 递归
  a.org_name          AS level1_org_name,  -- 一级部门名称｜待确认：ods_sup_org_df.org_name 递归
  a.parent_org_id     AS level2_org_id,    -- 二级部门ID｜待确认：ods_sup_org_df.parent_org_id 递归
  a.org_name          AS level2_org_name,  -- 二级部门名称｜待确认：ods_sup_org_df.org_name 递归
  CURRENT_TIMESTAMP() AS etl_time          -- ETL 加载时间
FROM ods.ods_sup_org_df a                  -- 主表「部门架构」
WHERE a.travel_date = '${bizdate}';        -- 只取当日分区
