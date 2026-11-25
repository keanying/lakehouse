-- dim.dim_opr_verify_point_df  核销点维度
-- 粒度：1行=1个核销点
-- 来源：ods_opr_verify_point_df
-- 生成方式：Spark SQL / Hive；字段 13 个：直接翻译 12 · 规则翻译 1 · 待确认 0

INSERT OVERWRITE TABLE dim.dim_opr_verify_point_df PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  a.id                AS verify_point_id,        -- 核销点ID（源表主键 id）
  a.verify_point_no   AS verify_point_no,        -- 核销点编号
  a.tenant_id         AS tenant_id,              -- 归属商户ID
  a.poi_id            AS poi_id,                 -- 关联POI ID
  a.point_name        AS verify_point_name,      -- 核销点名称（如"东门闸机组"）
  a.point_type        AS verify_point_type,      -- 类型
  a.point_status      AS verify_point_status,    -- 状态
  a.allowed_sku_ids   AS allowed_sku_list_desc,  -- 允许核销的SKU列表（null=全部）
  a.device_group_id   AS device_group_id,        -- 绑定设备分组ID
  a.create_time       AS create_time,            -- 创建时间
  a.update_time       AS update_time,            -- 更新时间
  COALESCE(j1.v, 0)   AS device_qty,             -- 绑定设备数
  CURRENT_TIMESTAMP() AS etl_time                -- ETL 加载时间
FROM ods.ods_opr_verify_point_df a               -- 主表「核销点」
LEFT JOIN (SELECT device_group_id, COUNT(id) AS v FROM ods.ods_opr_device_df WHERE travel_date = '${bizdate}' GROUP BY device_group_id) j1  -- 关联「设备」按键聚合，得到 绑定设备数
  ON j1.device_group_id = a.device_group_id      -- 按 device_group_id 关联
WHERE a.travel_date = '${bizdate}';              -- 只取当日分区
