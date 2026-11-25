-- dim.dim_sup_org_df  部门维度
-- 粒度：1行=1个部门
-- 来源：ods_sup_org_df
-- 生成方式：Spark SQL / Hive；字段 15 个：直接翻译 9 · 规则翻译 0 · 待确认 6
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT OVERWRITE TABLE dim.dim_sup_org_df PARTITION (travel_date = '${bizdate}')
SELECT
  a.id                AS org_id,
  a.org_no            AS org_no,
  a.org_name          AS org_name,
  a.parent_org_id     AS parent_org_id,
  a.tenant_id         AS tenant_id,
  a.org_status        AS org_status,
  a.create_time       AS create_time,
  a.update_time       AS update_time,
  a.parent_org_id     AS org_level_no,  -- 待确认：ods_sup_org_df.parent_org_id 递归
  a.org_name          AS org_path_desc,  -- 待确认：ods_sup_org_df.org_name 递归拼接
  a.parent_org_id     AS level1_org_id,  -- 待确认：ods_sup_org_df.parent_org_id 递归
  a.org_name          AS level1_org_name,  -- 待确认：ods_sup_org_df.org_name 递归
  a.parent_org_id     AS level2_org_id,  -- 待确认：ods_sup_org_df.parent_org_id 递归
  a.org_name          AS level2_org_name,  -- 待确认：ods_sup_org_df.org_name 递归
  CURRENT_TIMESTAMP() AS etl_time
FROM ods.ods_sup_org_df a
WHERE a.travel_date = '${bizdate}';
