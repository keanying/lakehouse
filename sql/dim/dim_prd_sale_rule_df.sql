-- dim.dim_prd_sale_rule_df  售卖规则维度
-- 粒度：1行=1条规则×1个条件项
-- 来源：ods_prd_sale_rule_df + ods_prd_sale_rule_item_df
-- 生成方式：Spark SQL / Hive；字段 13 个：直接翻译 13 · 规则翻译 0 · 待确认 0

INSERT OVERWRITE TABLE dim.dim_prd_sale_rule_df PARTITION (travel_date = '${bizdate}')
SELECT
  a.id                AS sale_rule_item_id,
  a.rule_id           AS rule_id,
  a.rule_type         AS rule_type,
  a.rule_value        AS rule_value_desc,
  a.tenant_id         AS tenant_id,
  a.create_time       AS create_time,
  a.update_time       AS update_time,
  j1.rule_no          AS rule_no,
  j2.sku_id           AS sku_id,
  j2.effective_from   AS effective_start_time,
  j2.effective_to     AS effective_end_time,
  j2.rule_status      AS rule_status,
  CURRENT_TIMESTAMP() AS etl_time
FROM ods.ods_prd_sale_rule_item_df a
LEFT JOIN ods.ods_prd_sale_rule_df j1
  ON j1.id = a.rule_id
 AND j1.travel_date = '${bizdate}'
LEFT JOIN ods.ods_prd_sale_rule_df j2
  ON j2.id = a.tenant_id
 AND j2.travel_date = '${bizdate}'
WHERE a.travel_date = '${bizdate}';
