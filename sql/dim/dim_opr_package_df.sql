-- dim.dim_opr_package_df  套餐维度
-- 粒度：1行=1个套餐
-- 来源：ods_opr_package_df + ods_opr_app_binding_df, dim_opr_app_df
-- 生成方式：Spark SQL / Hive；字段 14 个：直接翻译 11 · 规则翻译 1 · 待确认 2
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT OVERWRITE TABLE dim.dim_opr_package_df PARTITION (travel_date = '${bizdate}')
SELECT
  a.id                            AS package_id,
  a.package_no                    AS package_no,
  a.package_name                  AS package_name,
  ROUND(a.package_price / 100, 2) AS package_price_amt,
  a.duration_days                 AS duration_day_qty,
  a.feature_permissions           AS feature_permission_list_desc,
  a.resource_limits               AS resource_limit_desc,
  a.package_status                AS package_status,
  a.create_time                   AS create_time,
  a.update_time                   AS update_time,
  COALESCE(j1.v, 0)               AS app_qty,
  j2.app_code                     AS app_code_list_desc,  -- 待确认：dim_opr_app_df.app_code 聚合
  CURRENT_TIMESTAMP()             AS etl_time
FROM ods.ods_opr_package_df a
LEFT JOIN (SELECT package_id, COUNT(app_id) AS v FROM ods.ods_opr_app_binding_df WHERE travel_date = '${bizdate}' GROUP BY package_id) j1
  ON j1.package_id = a.id
LEFT JOIN dim.dim_opr_app_df j2
  ON j2.app_id = a.id
 AND j2.travel_date = '${bizdate}'  -- 待确认：关联键
LEFT JOIN dim.dim_opr_app_df j3
  ON j3.app_id = j2.app_id
 AND j3.travel_date = '${bizdate}'
WHERE a.travel_date = '${bizdate}';
