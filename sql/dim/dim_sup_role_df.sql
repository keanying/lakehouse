-- dim.dim_sup_role_df  角色维度
-- 粒度：1行=1个角色
-- 来源：ods_sup_sys_role_df + ods_sup_sys_role_permission_df + ods_sup_sys_permission_df
-- 生成方式：Spark SQL / Hive；字段 10 个：直接翻译 8 · 规则翻译 1 · 待确认 1
-- 每个 WITH 逻辑块只取用到的列并先过滤分区
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

WITH
sys_role_src AS (                                           -- 主表「RBAC角色」，只取用到的列
  SELECT create_time, id, role_code, role_name, role_status, tenant_id, update_time
  FROM ods.ods_sup_sys_role_df
  WHERE travel_date = '${bizdate}'                          -- 只取当日分区
),
sys_role_permission_count AS (                              -- 「角色-权限绑定」按 id 预聚合
  SELECT id, COUNT(permission_id) AS v
  FROM ods.ods_sup_sys_role_permission_df
  WHERE travel_date = '${bizdate}'                          -- 只取当日分区
  GROUP BY id                                               -- 按粒度键汇总
),
sys_permission_src AS (                                     -- 「权限定义」当日数据，只取用到的列
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
  sys_permission_src.permission_code       AS permission_code_list_desc,  -- 权限编码列表｜待确认：ods_sup_sys_permission_df.permission_code 聚合
  CURRENT_TIMESTAMP()                      AS etl_time      -- ETL 加载时间
FROM sys_role_src
LEFT JOIN sys_role_permission_count                         -- 关联「角色-权限绑定」，取 拥有权限数
  ON sys_role_permission_count.id = sys_role_src.tenant_id  -- 按 tenant_id→id 关联
LEFT JOIN sys_permission_src                                -- 关联「权限定义」，取 权限编码列表
  ON sys_permission_src.id = sys_role_src.tenant_id;        -- 按 tenant_id→id 关联
