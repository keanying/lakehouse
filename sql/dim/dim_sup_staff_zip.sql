-- dim.dim_sup_staff_zip  员工维度
-- 粒度：1行=1个员工×1个有效区间
-- 来源：ods_sup_tenant_staff_df + ods_sup_sys_user_role_df + ods_sup_sys_role_df, dim_sup_org_df, dim_sup_position_df, dim_sup_role_df
-- 生成方式：Spark SQL / Hive（拉链表）；字段 16 个：直接翻译 14 · 规则翻译 0 · 待确认 2
-- 拉链：比对今日源数据与昨日拉链的行哈希，变化的旧版本闭链、新版本开链；源为全量快照，消失的主键闭链
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

WITH src AS (                           -- 今日最新状态
  SELECT
    a.id AS staff_id,                   -- B端员工ID（源表主键 id）
    a.staff_no AS staff_no,             -- 员工编号(工号)
    a.tenant_id AS tenant_id,           -- 所属租户ID
    a.org_id AS org_id,                 -- 所属部门ID(0=未分配
    a.position_id AS position_id,       -- 岗位ID(0=未分配
    a.name AS staff_name,               -- 姓名
    a.phone AS phone_no,                -- 手机号(数据属性
    a.staff_status AS staff_status,     -- 状态
    a.create_time AS create_time,       -- 创建时间
    a.update_time AS update_time,       -- 更新时间
    j1.org_name AS org_name,            -- 所属部门名称
    j1.org_path_desc AS org_path_desc,  -- 部门完整路径
    j2.position_name AS position_name,  -- 岗位名称
    j3.role_code AS role_code_list_desc,  -- 角色编码列表｜待确认：ods_sup_sys_role_df.role_code 经 ods_sup_sys_user_role_df.role_id 聚合
    j5.role_name AS role_name_list_desc  -- 角色名称列表｜待确认：dim_sup_role_df.role_name 聚合
  FROM ods.ods_sup_tenant_staff_df a    -- 主表「B端员工」
  LEFT JOIN dim.dim_sup_org_df j1       -- 关联「部门维度」，取 所属部门名称、部门完整路径
    ON j1.org_id = a.org_id             -- 按 org_id 关联
   AND j1.travel_date = '${bizdate}'    -- 只取当日分区
  LEFT JOIN dim.dim_sup_position_df j2  -- 关联「岗位维度」，取 岗位名称
    ON j2.position_id = a.position_id   -- 按 position_id 关联
   AND j2.travel_date = '${bizdate}'    -- 只取当日分区
  LEFT JOIN ods.ods_sup_sys_role_df j3  -- 关联「RBAC角色」，取 角色编码列表
    ON j3.id = a.org_id                 -- 按 org_id→id 关联
   AND j3.travel_date = '${bizdate}'    -- 只取当日分区
  LEFT JOIN ods.ods_sup_sys_user_role_df j4  -- 关联「员工-角色绑定」
    ON j4.id = a.org_id                 -- 按 org_id→id 关联
   AND j4.travel_date = '${bizdate}'    -- 只取当日分区
  LEFT JOIN dim.dim_sup_role_df j5      -- 关联「角色维度」，取 角色名称列表
    ON j5.tenant_id = a.tenant_id       -- 按 tenant_id 关联
   AND j5.travel_date = '${bizdate}'    -- 只取当日分区
  WHERE a.travel_date = '${bizdate}'    -- 只取当日分区
),
src_h AS (SELECT s.*, MD5(CONCAT_WS('|', CAST(staff_no AS STRING), CAST(tenant_id AS STRING), CAST(org_id AS STRING), CAST(position_id AS STRING), CAST(staff_name AS STRING), CAST(phone_no AS STRING), CAST(staff_status AS STRING), CAST(create_time AS STRING), CAST(update_time AS STRING), CAST(org_name AS STRING), CAST(org_path_desc AS STRING), CAST(position_name AS STRING), CAST(role_code_list_desc AS STRING), CAST(role_name_list_desc AS STRING))) AS row_hash FROM src s),
his AS (                                -- 昨日拉链
  SELECT h.*, MD5(CONCAT_WS('|', CAST(h.staff_no AS STRING), CAST(h.tenant_id AS STRING), CAST(h.org_id AS STRING), CAST(h.position_id AS STRING), CAST(h.staff_name AS STRING), CAST(h.phone_no AS STRING), CAST(h.staff_status AS STRING), CAST(h.create_time AS STRING), CAST(h.update_time AS STRING), CAST(h.org_name AS STRING), CAST(h.org_path_desc AS STRING), CAST(h.position_name AS STRING), CAST(h.role_code_list_desc AS STRING), CAST(h.role_name_list_desc AS STRING))) AS row_hash
  FROM dim.dim_sup_staff_zip h
  WHERE h.travel_date = '${bizdate_prev}'
)
INSERT OVERWRITE TABLE dim.dim_sup_staff_zip PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
-- ① 历史记录：当前有效版本若有变化或已删除则闭链（结束日 = 昨天）
SELECT h.staff_id, h.staff_no, h.tenant_id, h.org_id, h.position_id, h.staff_name, h.phone_no, h.staff_status, h.create_time, h.update_time, h.org_name, h.org_path_desc, h.position_name, h.role_code_list_desc, h.role_name_list_desc,
  h.start_date,
  CASE WHEN h.end_date = '9999-12-31' AND (s.row_hash IS NULL OR s.row_hash <> h.row_hash)
       THEN '${bizdate_prev_dash}' ELSE h.end_date END AS end_date,  -- 拉链结束日期
  CURRENT_TIMESTAMP() AS etl_time       -- ETL 加载时间
FROM his h
LEFT JOIN src_h s ON s.staff_id = h.staff_id
UNION ALL                               -- 合并各来源
-- ② 新增或变化的记录开新链（开始日 = 今天，结束日 = 9999-12-31）
SELECT s.staff_id, s.staff_no, s.tenant_id, s.org_id, s.position_id, s.staff_name, s.phone_no, s.staff_status, s.create_time, s.update_time, s.org_name, s.org_path_desc, s.position_name, s.role_code_list_desc, s.role_name_list_desc,
  '${bizdate_dash}' AS start_date,      -- 拉链开始日期
  '9999-12-31' AS end_date,             -- 拉链结束日期
  CURRENT_TIMESTAMP() AS etl_time       -- ETL 加载时间
FROM src_h s
LEFT JOIN his h ON h.staff_id = s.staff_id AND h.end_date = '9999-12-31'
WHERE h.staff_id IS NULL OR h.row_hash <> s.row_hash;
