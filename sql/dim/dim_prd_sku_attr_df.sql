-- dim.dim_prd_sku_attr_df  SKU票属性维度
-- 粒度：1行=1个SKU×1个票属性
-- 来源：ods_prd_sku_meta_value_df + ods_prd_ticket_meta_df, dim_prd_ticket_meta_f
-- 生成方式：Spark SQL / Hive；字段 11 个：直接翻译 11 · 规则翻译 0 · 待确认 0

INSERT OVERWRITE TABLE dim.dim_prd_sku_attr_df PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  a.id                AS sku_attr_id,           -- SKU票属性值ID（源表主键 id）
  a.sku_id            AS sku_id,                -- SKU ID
  a.attribute_code    AS attribute_code,        -- 属性代码
  a.attribute_value   AS attribute_value_code,  -- 属性值
  a.tenant_id         AS tenant_id,             -- 租户ID
  a.create_time       AS create_time,           -- 创建时间
  a.update_time       AS update_time,           -- 更新时间
  j1.attribute_name   AS attribute_name,        -- 属性名称
  j1.value_type       AS value_type,            -- 值类型
  j2.dict_name        AS attribute_value_name,  -- 属性值中文含义
  CURRENT_TIMESTAMP() AS etl_time               -- ETL 加载时间
FROM ods.ods_prd_sku_meta_value_df a            -- 主表「SKU票属性值」
LEFT JOIN ods.ods_prd_ticket_meta_df j1         -- 关联「票属性元数据」，取 属性名称、值类型
  ON j1.attribute_code = a.attribute_code       -- 按 attribute_code 关联
 AND j1.travel_date = '${bizdate}'              -- 只取当日分区
LEFT JOIN dim.dim_opr_dict_f j2                 -- 关联「枚举码表」，取 属性值中文含义
  ON j2.tenant_id = a.tenant_id                 -- 按 tenant_id 关联
WHERE a.travel_date = '${bizdate}';             -- 只取当日分区
