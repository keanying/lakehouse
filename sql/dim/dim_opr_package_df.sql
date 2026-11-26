-- dim.dim_opr_package_df  套餐维度
-- 粒度：1行=1个套餐
-- 来源：ods_opr_package_df + ods_opr_app_binding_df, dim_opr_app_df
-- 生成方式：Spark SQL / Hive；字段 14 个：直接翻译 11 · 规则翻译 1 · 待确认 2
-- 每个 WITH 逻辑块只取用到的列并先过滤分区；小维表广播关联
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

WITH
package_src AS (                                                    -- 主表「套餐包」，只取用到的列
  SELECT create_time, duration_days, feature_permissions, id, package_name, package_no, package_price,
         package_status, resource_limits, update_time
  FROM ods.ods_opr_package_df
  WHERE travel_date = '${bizdate}'                                  -- 只取当日分区
),
app_binding_count AS (                                              -- 「套餐-应用绑定」按 package_id 预聚合
  SELECT package_id, COUNT(app_id) AS v
  FROM ods.ods_opr_app_binding_df
  WHERE travel_date = '${bizdate}'                                  -- 只取当日分区
  GROUP BY package_id                                               -- 按粒度键汇总
),
app_dim AS (                                                        -- 「应用维度」当日数据，只取用到的列
  SELECT app_code, app_id
  FROM dim.dim_opr_app_df
  WHERE travel_date = '${bizdate}'                                  -- 只取当日分区
)
INSERT OVERWRITE TABLE dim.dim_opr_package_df PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT  /*+ BROADCAST(app_dim) */
  package_src.id                            AS package_id,          -- 套餐包ID（源表主键 id）
  package_src.package_no                    AS package_no,          -- 套餐编号
  package_src.package_name                  AS package_name,        -- 套餐名称（如"基础版""专业版"）
  ROUND(package_src.package_price / 100, 2) AS package_price_amt,   -- 套餐价格（元/年）
  package_src.duration_days                 AS duration_day_qty,    -- 有效期（天）
  package_src.feature_permissions           AS feature_permission_list_desc,  -- 功能权限项列表
  package_src.resource_limits               AS resource_limit_desc,  -- 资源额度
  package_src.package_status                AS package_status,      -- 状态
  package_src.create_time                   AS create_time,         -- 创建时间
  package_src.update_time                   AS update_time,         -- 更新时间
  COALESCE(app_binding_count.v, 0)          AS app_qty,             -- 包含应用数
  app_dim.app_code                          AS app_code_list_desc,  -- 包含应用编码列表｜待确认：dim_opr_app_df.app_code 聚合
  CURRENT_TIMESTAMP()                       AS etl_time             -- ETL 加载时间
FROM package_src
LEFT JOIN app_binding_count                                         -- 关联「套餐-应用绑定」，取 包含应用数
  ON app_binding_count.package_id = package_src.id                  -- 按 id→package_id 关联
LEFT JOIN app_dim                                                   -- 关联「应用维度」，取 包含应用编码列表
  ON app_dim.app_id = package_src.id;                               -- 按 id→app_id 关联｜待确认：关联键
