-- dim.dim_opr_package_df  套餐维度
-- 粒度：1行=1个套餐
-- 来源：ods_opr_package_df + ods_opr_app_binding_df, dim_opr_app_df
-- 生成方式：Spark SQL / Hive；字段 14 个：直接翻译 11 · 规则翻译 1 · 待确认 2
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT OVERWRITE TABLE dim.dim_opr_package_df PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  a.id                            AS package_id,           -- 套餐包ID（源表主键 id）
  a.package_no                    AS package_no,           -- 套餐编号
  a.package_name                  AS package_name,         -- 套餐名称（如"基础版""专业版"）
  ROUND(a.package_price / 100, 2) AS package_price_amt,    -- 套餐价格（元/年）
  a.duration_days                 AS duration_day_qty,     -- 有效期（天）
  a.feature_permissions           AS feature_permission_list_desc,  -- 功能权限项列表
  a.resource_limits               AS resource_limit_desc,  -- 资源额度
  a.package_status                AS package_status,       -- 状态
  a.create_time                   AS create_time,          -- 创建时间
  a.update_time                   AS update_time,          -- 更新时间
  COALESCE(j1.v, 0)               AS app_qty,              -- 包含应用数
  j2.app_code                     AS app_code_list_desc,   -- 包含应用编码列表｜待确认：dim_opr_app_df.app_code 聚合
  CURRENT_TIMESTAMP()             AS etl_time              -- ETL 加载时间
FROM ods.ods_opr_package_df a                              -- 主表「套餐包」
LEFT JOIN (SELECT package_id, COUNT(app_id) AS v FROM ods.ods_opr_app_binding_df WHERE travel_date = '${bizdate}' GROUP BY package_id) j1  -- 关联「套餐-应用绑定」按键聚合，得到 包含应用数
  ON j1.package_id = a.id                                  -- 按 id→package_id 关联
LEFT JOIN dim.dim_opr_app_df j2                            -- 关联「应用维度」，取 包含应用编码列表
  ON j2.app_id = a.id                                      -- 按 id→app_id 关联
 AND j2.travel_date = '${bizdate}'                         -- 只取当日分区｜待确认：关联键
LEFT JOIN dim.dim_opr_app_df j3                            -- 关联「应用维度」
  ON j3.app_id = j2.app_id                                 -- 按 app_id 关联
 AND j3.travel_date = '${bizdate}'                         -- 只取当日分区
WHERE a.travel_date = '${bizdate}';                        -- 只取当日分区
