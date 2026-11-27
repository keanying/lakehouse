-- dim.dim_sup_role_df  角色维度
-- 粒度：1行=1个角色
-- 来源：ods_sup_sys_role_df + ods_sup_sys_role_permission_df + ods_sup_sys_permission_df
-- 生成方式：Spark SQL / Hive；字段 11 个：直接翻译 8 · 规则翻译 3 · 待确认 0
-- 每个 WITH 逻辑块只取用到的列并先过滤分区

WITH
sys_role_src AS (                                           -- 主表「RBAC角色」，只取用到的列
  SELECT create_time, id, role_code, role_name, role_status, tenant_id, update_time
  FROM ods.ods_sup_sys_role_df
  WHERE travel_date = '${bizdate}'                          -- 只取当日分区
),
sys_role_permission_count AS (                              -- 「角色-权限绑定」按 role_id 预聚合
  SELECT role_id, COUNT(permission_id) AS v                 -- 拆分 / 展开后的单个值
  FROM ods.ods_sup_sys_role_permission_df
  WHERE travel_date = '${bizdate}'                          -- 只取当日分区
  GROUP BY role_id                                          -- 按粒度键汇总
),
role_perm_agg AS (                                          -- 角色拥有的权限编码（去重排序拼接）  -- 「权限定义」当日数据，只取用到的列
  SELECT rp.role_id, CONCAT_WS(',', SORT_ARRAY(COLLECT_SET(p.permission_code))) AS permission_code_list  -- 权限编码列表
  FROM (SELECT role_id, permission_id FROM ods.ods_sup_sys_role_permission_df WHERE travel_date = '${bizdate}') rp
  JOIN (SELECT id, permission_code FROM ods.ods_sup_sys_permission_df WHERE travel_date = '${bizdate}') p  -- 关联「权限定义」按键聚合
    ON p.id = rp.permission_id                              -- 按 permission_id→id 关联
  GROUP BY rp.role_id                                       -- 按粒度键汇总
),
sys_permission_src AS (
  SELECT id, permission_code
  FROM ods.ods_sup_sys_permission_df
  WHERE travel_date = '${bizdate}'                          -- 只取当日分区
)
INSERT OVERWRITE TABLE dim.dim_sup_role_df PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  sys_role_src.id                          AS role_id,      -- RBAC角色ID（源表主键 id）
  sys_role_src.role_code                   AS role_code,    -- 角色代码
  sys_role_src.role_name                   AS role_name,    -- 角色名称
  sys_role_src.tenant_id                   AS tenant_id,    -- 租户ID
  sys_role_src.role_status                 AS role_status,  -- 状态
  sys_role_src.create_time                 AS create_time,  -- 创建时间
  sys_role_src.update_time                 AS update_time,  -- 更新时间
  COALESCE(sys_role_permission_count.v, 0) AS permission_qty,  -- 拥有权限数
  rpa.permission_code_list AS permission_code_list_desc,    -- 权限编码列表｜口径：角色绑定的权限编码，去重排序后逗号拼接
  CURRENT_TIMESTAMP()                      AS etl_time      -- ETL 加载时间
FROM sys_role_src
LEFT JOIN sys_role_permission_count                         -- 关联「角色-权限绑定」，取 拥有权限数
  ON sys_role_permission_count.role_id = sys_role_src.id    -- 按 id→role_id 关联
LEFT JOIN role_perm_agg rpa                                 -- 关联「权限定义」，取 权限编码列表
  ON rpa.role_id = sys_role_src.id;                         -- 按 id→role_id 关联
