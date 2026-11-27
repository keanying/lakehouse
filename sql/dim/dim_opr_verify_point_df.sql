-- dim.dim_opr_verify_point_df  核销点维度
-- 粒度：1行=1个核销点
-- 来源：ods_opr_verify_point_df
-- 生成方式：Spark SQL / Hive；字段 13 个：直接翻译 12 · 规则翻译 1 · 待确认 0
-- 每个 WITH 逻辑块只取用到的列并先过滤分区

WITH
verify_point_src AS (                                       -- 主表「核销点」，只取用到的列
  SELECT allowed_sku_ids, create_time, device_group_id, id, poi_id, point_name, point_status, point_type,
         tenant_id, update_time, verify_point_no
  FROM ods.ods_opr_verify_point_df
  WHERE travel_date = '${bizdate}'                          -- 只取当日分区
),
device_count AS (                                           -- 「设备」按 device_group_id 预聚合
  SELECT device_group_id, COUNT(id) AS v                    -- 拆分 / 展开后的单个值
  FROM ods.ods_opr_device_df
  WHERE travel_date = '${bizdate}'                          -- 只取当日分区
  GROUP BY device_group_id                                  -- 按粒度键汇总
)
INSERT OVERWRITE TABLE dim.dim_opr_verify_point_df PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  verify_point_src.id              AS verify_point_id,      -- 核销点ID（源表主键 id）
  verify_point_src.verify_point_no AS verify_point_no,      -- 核销点编号
  verify_point_src.tenant_id       AS tenant_id,            -- 归属商户ID
  verify_point_src.poi_id          AS poi_id,               -- 关联POI ID
  verify_point_src.point_name      AS verify_point_name,    -- 核销点名称（如"东门闸机组"）
  verify_point_src.point_type      AS verify_point_type,    -- 类型
  verify_point_src.point_status    AS verify_point_status,  -- 状态
  verify_point_src.allowed_sku_ids AS allowed_sku_list_desc,  -- 允许核销的SKU列表（null=全部）
  verify_point_src.device_group_id AS device_group_id,      -- 绑定设备分组ID
  verify_point_src.create_time     AS create_time,          -- 创建时间
  verify_point_src.update_time     AS update_time,          -- 更新时间
  COALESCE(device_count.v, 0)      AS device_qty,           -- 绑定设备数
  CURRENT_TIMESTAMP()              AS etl_time              -- ETL 加载时间
FROM verify_point_src
LEFT JOIN device_count                                      -- 关联「设备」，取 绑定设备数
  ON device_count.device_group_id = verify_point_src.device_group_id;  -- 按 device_group_id 关联
