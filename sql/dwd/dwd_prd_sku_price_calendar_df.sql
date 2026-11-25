-- dwd.dwd_prd_sku_price_calendar_df  SKU每日生效价日历
-- 粒度：1行=1个SKU×1个日期×1个渠道×1组扩展维度
-- 来源：ods_prd_price_point_di + ods_prd_pricing_rule_df
-- 生成方式：Spark SQL / Hive；字段 13 个：直接翻译 9 · 规则翻译 0 · 待确认 4
-- ODS 增量按主键取最新一条（ROW_NUMBER），剔除删除记录
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT OVERWRITE TABLE dwd.dwd_prd_sku_price_calendar_df PARTITION (travel_date = '${bizdate}')
SELECT
  a.sku_id                                           AS sku_id,
  j1.date_code                                       AS price_date,
  a.channel                                          AS price_channel_code,
  a.ext_dims                                         AS ext_dim_desc,
  a.price_no                                         AS hit_price_no,  -- 待确认：ods_prd_price_point_di.price_no 按优先级取第一
  a.priority                                         AS hit_priority_no,
  ROUND(a.price / 100, 2)                            AS list_price_amt,
  j2.rule_no                                         AS pricing_rule_no,
  CASE WHEN j2.rule_no IS NOT NULL THEN 1 ELSE 0 END AS rule_price_type,  -- 待确认：ods_prd_pricing_rule_df.rule_no 是否命中
  j2.calculator                                      AS final_price_amt,  -- 待确认：list_price_amt 按 ods_prd_pricing_rule_df.calculator 计算
  a.tenant_id                                        AS tenant_id,
  CURRENT_TIMESTAMP()                                AS etl_time
FROM (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY id ORDER BY binlog_time DESC) AS rn
  FROM ods.ods_prd_price_point_di
  WHERE travel_date = '${bizdate}'
) a
LEFT JOIN dim.dim_opr_date_f j1
  ON j1.date_code = a.id  -- 待确认：关联键
LEFT JOIN ods.ods_prd_pricing_rule_df j2
  ON j2.sku_id = a.sku_id
 AND j2.travel_date = '${bizdate}'
WHERE a.rn = 1
  AND a.binlog_op_type <> 'DELETE';
