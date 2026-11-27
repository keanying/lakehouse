-- dim.dim_prd_sku_attr_df  SKU票属性维度
-- 粒度：1行=1个SKU×1个票属性
-- 来源：ods_prd_sku_meta_value_df + ods_prd_ticket_meta_df, dim_prd_ticket_meta_f
-- 生成方式：Spark SQL / Hive；字段 12 个：直接翻译 11 · 规则翻译 1 · 待确认 0
-- 每个 WITH 逻辑块只取用到的列并先过滤分区；小维表广播关联

WITH
sku_meta_value_src AS (                                        -- 主表「SKU票属性值」，只取用到的列
  SELECT attribute_code, attribute_value, create_time, id, sku_id, tenant_id, update_time
  FROM ods.ods_prd_sku_meta_value_df
  WHERE travel_date = '${bizdate}'                             -- 只取当日分区
),
ticket_meta_src AS (                                           -- 「票属性元数据」当日数据，只取用到的列
  SELECT attribute_code, attribute_name, value_type
  FROM ods.ods_prd_ticket_meta_df
  WHERE travel_date = '${bizdate}'                             -- 只取当日分区
),
dict_dim AS (                                                  -- 「枚举码表」当日数据，只取用到的列
  SELECT dict_type_code, dict_code, dict_name
  FROM dim.dim_opr_dict_f
)
INSERT OVERWRITE TABLE dim.dim_prd_sku_attr_df PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT  /*+ BROADCAST(dict_dim) */
  sku_meta_value_src.id              AS sku_attr_id,           -- SKU票属性值ID（源表主键 id）
  sku_meta_value_src.sku_id          AS sku_id,                -- SKU ID
  sku_meta_value_src.attribute_code  AS attribute_code,        -- 属性代码
  sku_meta_value_src.attribute_value AS attribute_value_code,  -- 属性值
  sku_meta_value_src.tenant_id       AS tenant_id,             -- 租户ID
  sku_meta_value_src.create_time     AS create_time,           -- 创建时间
  sku_meta_value_src.update_time     AS update_time,           -- 更新时间
  ticket_meta_src.attribute_name     AS attribute_name,        -- 属性名称
  ticket_meta_src.value_type         AS value_type,            -- 值类型
  dict_dim.dict_name                 AS attribute_value_name,  -- 属性值中文含义
  CURRENT_TIMESTAMP()                AS etl_time               -- ETL 加载时间
FROM sku_meta_value_src
LEFT JOIN ticket_meta_src                                      -- 关联「票属性元数据」，取 属性名称、值类型
  ON ticket_meta_src.attribute_code = sku_meta_value_src.attribute_code  -- 按 attribute_code 关联
LEFT JOIN dict_dim                                             -- 关联「枚举码表」，取 属性值中文含义
  ON dict_dim.dict_type_code = sku_meta_value_src.attribute_code  -- 按 attribute_code→dict_type_code 关联｜口径说明：属性值按 字典类型 = 属性代码 匹配中文名;
    AND dict_dim.dict_code = sku_meta_value_src.attribute_value
