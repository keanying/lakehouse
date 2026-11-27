-- dim.dim_sup_org_df  部门维度
-- 粒度：1行=1个部门
-- 来源：ods_sup_org_df
-- 生成方式：手写（结构不适合按字段自动翻译）；业务规则：
--   · 层级 / 路径 / 一二级部门：沿 parent_org_id 逐级向上自关联（最多 5 级），0 = 顶级
--   · 一级部门 = 最顶层祖先（自身为顶级时取自身），二级部门 = 顶层往下第 2 层
-- 性能：
--   · 部门表小，自关联 4 次

WITH o AS (
    SELECT id, org_no, org_name, parent_org_id, tenant_id, org_status, create_time, update_time
    FROM ods.ods_sup_org_df WHERE travel_date = '${bizdate}'
),
x AS (
    SELECT o.*, p1.id AS p1_id, p1.org_name AS p1_name, p2.id AS p2_id, p2.org_name AS p2_name,
           p3.id AS p3_id, p3.org_name AS p3_name, p4.id AS p4_id, p4.org_name AS p4_name,
           1 + IF(p1.id IS NULL, 0, 1) + IF(p2.id IS NULL, 0, 1) + IF(p3.id IS NULL, 0, 1) + IF(p4.id IS NULL, 0, 1) AS lvl
    FROM o
    LEFT JOIN o p1 ON p1.id = o.parent_org_id
    LEFT JOIN o p2 ON p2.id = p1.parent_org_id
    LEFT JOIN o p3 ON p3.id = p2.parent_org_id
    LEFT JOIN o p4 ON p4.id = p3.parent_org_id
)
INSERT OVERWRITE TABLE dim.dim_sup_org_df PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
    id AS org_id, org_no, org_name, parent_org_id, tenant_id, org_status, create_time, update_time,
    lvl                                                                                   AS org_level_no,  -- 部门层级
    CONCAT_WS('/', p4_name, p3_name, p2_name, p1_name, org_name)                          AS org_path_desc,  -- 部门完整路径
    CASE lvl WHEN 1 THEN id WHEN 2 THEN p1_id WHEN 3 THEN p2_id WHEN 4 THEN p3_id ELSE p4_id END             AS level1_org_id,  -- 一级部门ID
    CASE lvl WHEN 1 THEN org_name WHEN 2 THEN p1_name WHEN 3 THEN p2_name WHEN 4 THEN p3_name ELSE p4_name END AS level1_org_name,  -- 一级部门名称
    CASE lvl WHEN 2 THEN id WHEN 3 THEN p1_id WHEN 4 THEN p2_id WHEN 5 THEN p3_id END                       AS level2_org_id,  -- 二级部门ID
    CASE lvl WHEN 2 THEN org_name WHEN 3 THEN p1_name WHEN 4 THEN p2_name WHEN 5 THEN p3_name END           AS level2_org_name,  -- 二级部门名称
    CURRENT_TIMESTAMP() AS etl_time                                               -- ETL 加载时间
FROM x;
