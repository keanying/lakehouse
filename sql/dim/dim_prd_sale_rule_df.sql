-- dim.dim_prd_sale_rule_df  售卖规则维度
-- 粒度：1行=1条规则×1个条件项
-- 来源：ods_prd_sale_rule_df + ods_prd_sale_rule_item_df
-- 生成方式：Spark SQL / Hive；字段 13 个：直接翻译 13 · 规则翻译 0 · 待确认 0

INSERT OVERWRITE TABLE dim.dim_prd_sale_rule_df PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  a.id                AS sale_rule_item_id,   -- 售卖条件项ID（源表主键 id）
  a.rule_id           AS rule_id,             -- 归属售卖规则ID
  a.rule_type         AS rule_type,           -- 条件类型
  a.rule_value        AS rule_value_desc,     -- 条件值（按rule_type结构化
  a.tenant_id         AS tenant_id,           -- 租户ID
  a.create_time       AS create_time,         -- 创建时间
  a.update_time       AS update_time,         -- 更新时间
  j1.rule_no          AS rule_no,             -- 售卖规则编号
  j1.sku_id           AS sku_id,              -- SKU ID
  j1.effective_from   AS effective_start_time,  -- 规则生效开始时间
  j1.effective_to     AS effective_end_time,  -- 规则生效结束时间
  j1.rule_status      AS rule_status,         -- 规则状态
  CURRENT_TIMESTAMP() AS etl_time             -- ETL 加载时间
FROM ods.ods_prd_sale_rule_item_df a          -- 主表「售卖条件项」
LEFT JOIN ods.ods_prd_sale_rule_df j1         -- 关联「售卖规则」，取 售卖规则编号、SKU ID、规则生效开始时间、规则生效结束时间、规则状态
  ON j1.id = a.rule_id                        -- 按 rule_id→id 关联
 AND j1.travel_date = '${bizdate}'            -- 只取当日分区
WHERE a.travel_date = '${bizdate}';           -- 只取当日分区
