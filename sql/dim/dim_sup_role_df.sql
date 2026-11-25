-- dim.dim_sup_role_df  角色维度
-- 粒度：1行=1个角色
-- 来源：ods_sup_sys_role_df + ods_sup_sys_role_permission_df + ods_sup_sys_permission_df
-- 生成方式：Spark SQL / Hive；字段 10 个：直接翻译 8 · 规则翻译 1 · 待确认 1
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT OVERWRITE TABLE dim.dim_sup_role_df PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  a.id                AS role_id,                    -- RBAC角色ID（源表主键 id）
  a.role_code         AS role_code,                  -- 角色代码
  a.role_name         AS role_name,                  -- 角色名称
  a.tenant_id         AS tenant_id,                  -- 租户ID
  a.role_status       AS role_status,                -- 状态
  a.create_time       AS create_time,                -- 创建时间
  a.update_time       AS update_time,                -- 更新时间
  COALESCE(j1.v, 0)   AS permission_qty,             -- 拥有权限数
  j2.permission_code  AS permission_code_list_desc,  -- 权限编码列表｜待确认：ods_sup_sys_permission_df.permission_code 聚合
  CURRENT_TIMESTAMP() AS etl_time                    -- ETL 加载时间
FROM ods.ods_sup_sys_role_df a                       -- 主表「RBAC角色」
LEFT JOIN (SELECT id, COUNT(permission_id) AS v FROM ods.ods_sup_sys_role_permission_df WHERE travel_date = '${bizdate}' GROUP BY id) j1  -- 关联「角色-权限绑定」按键聚合，得到 拥有权限数
  ON j1.id = a.tenant_id                             -- 按 tenant_id→id 关联
LEFT JOIN ods.ods_sup_sys_permission_df j2           -- 关联「权限定义」，取 权限编码列表
  ON j2.id = a.tenant_id                             -- 按 tenant_id→id 关联
 AND j2.travel_date = '${bizdate}'                   -- 只取当日分区
WHERE a.travel_date = '${bizdate}';                  -- 只取当日分区
