-- dim.dim_prd_sale_rule_df  售卖规则维度
-- 粒度：1行=1条规则×1个条件项
-- 来源：ods_prd_sale_rule_df + ods_prd_sale_rule_item_df
-- 生成方式：Spark SQL / Hive；字段 13 个：直接翻译 13 · 规则翻译 0 · 待确认 0
-- 每个 WITH 逻辑块只取用到的列并先过滤分区

WITH
sale_rule_item_src AS (                                  -- 主表「售卖条件项」，只取用到的列
  SELECT create_time, id, rule_id, rule_type, rule_value, tenant_id, update_time
  FROM ods.ods_prd_sale_rule_item_df
  WHERE travel_date = '${bizdate}'                       -- 只取当日分区
),
sale_rule_src AS (                                       -- 「售卖规则」当日数据，只取用到的列
  SELECT effective_from, effective_to, id, rule_no, rule_status, sku_id
  FROM ods.ods_prd_sale_rule_df
  WHERE travel_date = '${bizdate}'                       -- 只取当日分区
)
INSERT OVERWRITE TABLE dim.dim_prd_sale_rule_df PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  sale_rule_item_src.id          AS sale_rule_item_id,   -- 售卖条件项ID（源表主键 id）
  sale_rule_item_src.rule_id     AS rule_id,             -- 归属售卖规则ID
  sale_rule_item_src.rule_type   AS rule_type,           -- 条件类型
  sale_rule_item_src.rule_value  AS rule_value_desc,     -- 条件值（按rule_type结构化
  sale_rule_item_src.tenant_id   AS tenant_id,           -- 租户ID
  sale_rule_item_src.create_time AS create_time,         -- 创建时间
  sale_rule_item_src.update_time AS update_time,         -- 更新时间
  sale_rule_src.rule_no          AS rule_no,             -- 售卖规则编号
  sale_rule_src.sku_id           AS sku_id,              -- SKU ID
  sale_rule_src.effective_from   AS effective_start_time,  -- 规则生效开始时间
  sale_rule_src.effective_to     AS effective_end_time,  -- 规则生效结束时间
  sale_rule_src.rule_status      AS rule_status,         -- 规则状态
  CURRENT_TIMESTAMP()            AS etl_time             -- ETL 加载时间
FROM sale_rule_item_src
LEFT JOIN sale_rule_src                                  -- 关联「售卖规则」，取 售卖规则编号、SKU ID、规则生效开始时间、规则生效结束时间、规则状态
  ON sale_rule_src.id = sale_rule_item_src.rule_id;      -- 按 rule_id→id 关联
