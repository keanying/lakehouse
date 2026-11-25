-- dim.dim_sup_role_df  角色维度
-- 粒度：1行=1个角色
-- 来源：ods_sup_sys_role_df + ods_sup_sys_role_permission_df + ods_sup_sys_permission_df
-- 生成方式：Spark SQL / Hive；字段 10 个：直接翻译 8 · 规则翻译 1 · 待确认 1
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT OVERWRITE TABLE dim.dim_sup_role_df PARTITION (travel_date = '${bizdate}')
SELECT
  a.id                AS role_id,
  a.role_code         AS role_code,
  a.role_name         AS role_name,
  a.tenant_id         AS tenant_id,
  a.role_status       AS role_status,
  a.create_time       AS create_time,
  a.update_time       AS update_time,
  COALESCE(j1.v, 0)   AS permission_qty,
  j2.permission_code  AS permission_code_list_desc,  -- 待确认：ods_sup_sys_permission_df.permission_code 聚合
  CURRENT_TIMESTAMP() AS etl_time
FROM ods.ods_sup_sys_role_df a
LEFT JOIN (SELECT id, COUNT(permission_id) AS v FROM ods.ods_sup_sys_role_permission_df WHERE travel_date = '${bizdate}' GROUP BY id) j1
  ON j1.id = a.tenant_id
LEFT JOIN ods.ods_sup_sys_permission_df j2
  ON j2.id = a.tenant_id
 AND j2.travel_date = '${bizdate}'
WHERE a.travel_date = '${bizdate}';
